// ロボット背中側 ATOM Echo 用ファームウェア(ESP-NOW版、RCB4中継 + Edge Impulse音声コマンド)。
//
// atom_echo_bridge_robot_base.ino がベース(RCB4中継・LED・識別音は共通)。
// これに「PC側から送られてくる約1秒間の音声をEdge Impulseで単語認識し、
// 一致すればRCB4-miniへcall-motionコマンドを直接送って動作させる」機能を
// 追加したもの。
//
// 【2026.8: 認識方式をEdge Impulseに変更】
//   以前は自作の簡易テンプレートマッチング方式で、書き込み直後は毎回シリアル
//   経由で単語を学習させる必要があった(電源を切ると学習結果が消えるため
//   使い勝手が悪かった)。../atom_s3_robot/atoms3_i2c_robot.inoで使っている
//   Edge Impulseの事前学習済みモデル(../edge_impulse/参照)をそのまま移植し、
//   書き込み直後から学習不要で動作するようにした。認識ロジック自体は
//   AtomS3版と全く同じ(信号供給・run_classifier呼び出し・ラベル→motion
//   対応)で、無いもの(LCD)だけRGB LED+スピーカーの合図に置き換えている。
//
// 【2026.8: run_classifier()を別FreeRTOSタスク(別コア)へ分離】
//   素のESP32(ESP-NN高速化カーネルが使えず汎用カーネルにフォールバックする)
//   ではrun_classifier()のブロック時間が長く、loop()内で直接呼ぶとその間
//   RCB4Serialの読み出し・ESP-NOW中継が止まり、:timer-on中のPC<->RCB4通信が
//   壊れる不具合が実機で確認された。classifyTask()という別タスクをコア0へ
//   pinして実行し、loop()(コア1、RCB4/ESP-NOW中継担当)を絶対にブロック
//   しないようにした。ハードウェアアクセス(RCB4Serial/esp_now_send/I2S)は
//   loop()側だけに限定し、classifyTaskは純粋な計算(run_classifier呼び出し)
//   だけを行い、結果をvolatile変数経由でloop()へ渡す(serviceClassifyResult()
//   参照)。
//
// 【RCB4中継プロトコル(2026.8、ACK版に統一)】
//   ../atom_s3_robot/atoms3_i2c_robot.inoと同じシーケンス番号+ACK+タイムアウト
//   再送プロトコル(ESP-NOWの無線層再送だけでは大量連続送信時に取りこぼしが
//   起きることが実機で判明したための対策、詳細はatom_echo_pc/README.md参照)。
//   ACK待ちでブロックする時間が伸びた分、RCB4Serialの受信バッファも拡張して
//   ある(setup()参照)。
//
// 【設計方針・将来の拡張について】
//   音声の入力元は「ESP-NOWで受信したPCのマイク音声」だが、認識ロジック自体は
//   完全にこのロボット側だけで完結している(PCは録音して送るだけで、認識・
//   motion決定・RCB4送信は全てここで行う)。将来「PC側ECHOやPCが無い状態でも
//   動く」バージョンを作る場合は、この認識ロジックはそのまま流用し、音声の
//   入力元を(ESP-NOW受信)から(自分自身のマイクで直接録音)に差し替えるだけで
//   よいはず。
//
// 【motion番号の対応】(kxreus rcb4interface.l :call-motion を実機解析して
//   直接RCB4バイト列を組み立てている。call-motionはRCB4のROM上の
//   モーションテーブル(0x0B80番地から2048byte毎、120スロット)を呼び出す
//   CALL命令を送るだけで、モーションデータ自体は送らない。KXRL2Gの標準
//   プロジェクトが書き込み済みであることが前提)
//     aisatsu (挨拶)  -> スロット20
//     mae     (前)    -> スロット0
//     ushiro  (後)    -> スロット1
//     hidari  (左)    -> スロット2
//     migi    (右)    -> スロット3
//     noise           -> 動作なし

#include <esp_now.h>
#include <esp_wifi.h>
#include <WiFi.h>
#include <Adafruit_NeoPixel.h>
#include <ESP_I2S.h>
#include <kxr-voice-commands_inferencing.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include "explain_clip.h"
#include "response_clips.h"

static const char *MY_NAME = "ECHO1-ROBOT";

// 相手(PC側ATOM Echo)のMACアドレス。pc_mac.hは../atom_echo_pc/の
// get_my_mac.shで生成される(手動編集しないこと。詳細はREADME.md参照)。
#include "pc_mac.h"
static uint8_t PEER_MAC[6] = PC_MAC_BYTES;

static const uint8_t WIFI_CHANNEL = 1;
static const size_t MAX_CHUNK = 240;
static const uint32_t HEARTBEAT_MS = 300;
static const uint32_t LINK_TIMEOUT_MS = 1000;

static const uint8_t PKT_DATA = 0x01;
static const uint8_t PKT_PING = 0x02;
static const uint8_t PKT_PONG = 0x03;
static const uint8_t PKT_VOICE_AUDIO = 0x0A;
static const uint8_t PKT_VOICE_END = 0x0B;
static const uint8_t PKT_DATA_ACK = 0x04;  // PKT_DATA 1個分の受信確認応答

static const uint32_t AUDIO_SAMPLE_RATE = 8000;

// RCB4-mini 側 UART 設定。ATOM EchoのGrove(Port A)ピン。
static const int RCB4_TX_PIN = 26;
static const int RCB4_RX_PIN = 32;
static const uint32_t RCB4_BAUD = 1250000;

// 【重要】RCB4_BAUDが1.25Mbpsと非常に高速なため、loop()側のESP-NOW中継
// (sendChunk、ACK待ちで最大ACK_TIMEOUT_MS×ACK_MAX_RETRY=750msブロックしうる)
// が詰まっている間に、デフォルトのRXバッファ(ESP32 Arduinoコアの既定で
// 256byte程度)がすぐに溢れてバイトが欠落しうる(atoms3_i2c_robot.inoで
// 実機確認済みの不具合と同じ構造)。setRxBufferSizeはbegin()より前に呼ぶ
// 必要がある。
static const size_t RCB4_RX_BUFFER_SIZE = 4096;

// RGB LED (SK6812, G27)
static const int PIN_LED = 27;
Adafruit_NeoPixel pixel(1, PIN_LED, NEO_GRB + NEO_KHZ800);

// ボタン (G39, 押下でLOW)
static const int PIN_BTN = 39;

// I2S (speaker: NS4168)
static const int I2S_BCLK = 19;
static const int I2S_LRCK = 33;
static const int I2S_DOUT = 22;
I2SClass audioI2S;

HardwareSerial RCB4Serial(1);

volatile uint32_t lastAckMillis = 0;
volatile uint32_t lastRecvMillis = 0;
uint32_t lastSendActivity = 0;
bool lastLinkUp = false;

// ---- PKT_DATA用の確認応答・再送プロトコル(atoms3_i2c_robot.ino/atom_echo_pc/
// atom_echo_voice_cmd_pc.inoと共通の形式。詳細は同ファイルのコメント参照) ----
static uint8_t txSeq = 0;                // 送信側: 次に使うシーケンス番号
static int32_t lastProcessedSeq = -1;    // 受信側: 直前に処理したシーケンス番号(-1=まだ無し)
volatile uint8_t lastAckedSeq = 0xFF;    // 直近ACKされたシーケンス番号
volatile bool haveAck = false;
static const uint32_t ACK_TIMEOUT_MS = 25;
static const int ACK_MAX_RETRY = 30;

void onDataSent(const wifi_tx_info_t *info, esp_now_send_status_t status) {
  if (status == ESP_NOW_SEND_SUCCESS) {
    lastAckMillis = millis();
  }
}

// ---- 音声コマンドの録音バッファ(ESP-NOW受信コールバックはここに積むだけ) ----
// EI_CLASSIFIER_RAW_SAMPLE_COUNT はEdge Impulseの学習設定(8kHz, window 1000ms)
// から生成される定数で、8000になる(このモデル固有の値。atoms3_i2c_robot.ino
// と同じモデルを使っているため同じ値になるはず)。

static_assert(EI_CLASSIFIER_RAW_SAMPLE_COUNT == 8000, "モデルの入力サンプル数が想定と異なる");

int16_t voiceBuf[EI_CLASSIFIER_RAW_SAMPLE_COUNT];
volatile size_t voiceBufLen = 0;  // 現在埋まっているサンプル数

// 【2026.8】run_classifier()は素のESP32(ESP-NN高速化カーネルが使えず汎用
// カーネルにフォールバックする)ではブロックする時間が長く、loop()内で直接
// 呼ぶとその間RCB4Serialの読み出し・ESP-NOW中継が止まり、:timer-on中の
// PC<->RCB4通信が壊れる不具合が実機で確認された。run_classifier()自体は
// 分割実行できないため、別のFreeRTOSタスク(もう一方のCPUコア)へ切り出し、
// loop()(RCB4/ESP-NOW中継担当)を絶対にブロックしないようにする。
// classifyBusy中は新しい発話の録音を受け付けない(voiceBufの競合防止。
// 認識は短時間で終わるため実用上問題にならない想定)。
TaskHandle_t classifyTaskHandle = NULL;
volatile bool classifyBusy = false;        // 分類タスクが実行中(録音中も含む)
volatile bool classifyResultReady = false; // 分類タスクが結果を書き終えた(loop()側で消費待ち)
volatile int classifyBestIdx = -1;
volatile float classifyBestValue = -1.0f;
const char *classifyLabel = nullptr;       // モデル内の静的文字列を指すだけなのでコピー不要

void onDataRecv(const esp_now_recv_info_t *info, const uint8_t *data, int len) {
  if (!info->src_addr || memcmp(info->src_addr, PEER_MAC, 6) != 0) {
    return;
  }
  lastRecvMillis = millis();
  if (len < 1) return;

  if (data[0] == PKT_DATA && len > 2) {
    uint8_t seq = data[1];
    // 受信できた時点で(重複再送であっても)必ずACKを返す。
    uint8_t ackPkt[2] = {PKT_DATA_ACK, seq};
    esp_now_send(PEER_MAC, ackPkt, 2);
    // 「直前に処理したseqと完全一致」の場合だけ、ACKが届かず送信側が再送した
    // 重複パケットとみなして捨てる。それ以外はどんなseq値でも新規データとして
    // 処理する(片方だけ再起動してもシーケンス番号が食い違ったまま復帰できるように)。
    if ((int32_t)seq != lastProcessedSeq) {
      RCB4Serial.write(data + 2, len - 2);
      lastProcessedSeq = seq;
    }
  } else if (data[0] == PKT_DATA_ACK && len == 2) {
    lastAckedSeq = data[1];
    haveAck = true;
  } else if (data[0] == PKT_PING && len == 5) {
    uint8_t pong[5];
    pong[0] = PKT_PONG;
    memcpy(pong + 1, data + 1, 4);
    esp_now_send(PEER_MAC, pong, 5);
  } else if (data[0] == PKT_VOICE_AUDIO && len > 1) {
    if (classifyBusy) return;  // 分類中は新しい発話のバッファ書き込みを避ける
    size_t n = (len - 1) / 2;  // int16サンプル数
    for (size_t i = 0; i < n; i++) {
      if (voiceBufLen >= EI_CLASSIFIER_RAW_SAMPLE_COUNT) break;
      int16_t s = (int16_t)(data[1 + i * 2] | (data[1 + i * 2 + 1] << 8));
      voiceBuf[voiceBufLen++] = s;
    }
  } else if (data[0] == PKT_VOICE_END) {
    if (classifyBusy) return;
    // 発話が短くてバッファが埋まりきらなかった場合は残りを無音(0)で埋める
    // (EI_CLASSIFIER_RAW_SAMPLE_COUNT ぴったりの長さが必要なため)。
    while (voiceBufLen < EI_CLASSIFIER_RAW_SAMPLE_COUNT) {
      voiceBuf[voiceBufLen++] = 0;
    }
    classifyBusy = true;
    xTaskNotifyGive(classifyTaskHandle);  // 分類タスクを起こす(loop()はブロックしない)
  }
}

bool isLinkUp() {
  uint32_t now = millis();
  return (now - lastRecvMillis < LINK_TIMEOUT_MS);
}

void sendChunk(const uint8_t *data, size_t len) {
  uint8_t packet[2 + MAX_CHUNK];
  size_t offset = 0;
  while (offset < len) {
    size_t n = min(MAX_CHUNK, len - offset);
    uint8_t seq = txSeq;
    packet[0] = PKT_DATA;
    packet[1] = seq;
    memcpy(packet + 2, data + offset, n);

    bool acked = false;
    for (int attempt = 0; attempt < ACK_MAX_RETRY && !acked; attempt++) {
      haveAck = false;
      esp_now_send(PEER_MAC, packet, n + 2);
      uint32_t waitStart = millis();
      while (millis() - waitStart < ACK_TIMEOUT_MS) {
        if (haveAck && lastAckedSeq == seq) {
          acked = true;
          break;
        }
        delay(1);
      }
    }
    // ACK_MAX_RETRY回試しても失敗した場合、これ以上は待たず先に進む
    // (無限に止まるよりはデータ欠落の方がまだ回復しやすいため)。
    txSeq = (uint8_t)(txSeq + 1);
    offset += n;
  }
  lastSendActivity = millis();
}

void sendPing() {
  uint8_t packet[5];
  packet[0] = PKT_PING;
  uint32_t now = millis();
  memcpy(packet + 1, &now, 4);
  esp_now_send(PEER_MAC, packet, 5);
  lastSendActivity = millis();
}

void initEspNow() {
  esp_now_init();
  esp_now_register_send_cb(onDataSent);
  esp_now_register_recv_cb(onDataRecv);

  esp_now_peer_info_t peerInfo = {};
  memcpy(peerInfo.peer_addr, PEER_MAC, 6);
  peerInfo.channel = WIFI_CHANNEL;
  peerInfo.encrypt = false;
  esp_now_add_peer(&peerInfo);
}

// ---- 音関連 ----

void playTone(int freqHz, int durationMs, int amplitude = 6000) {
  const int sampleRate = 8000;
  audioI2S.end();
  audioI2S.setPins(I2S_BCLK, I2S_LRCK, I2S_DOUT);
  bool ok = audioI2S.begin(I2S_MODE_STD, sampleRate, I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_STEREO);
  if (!ok) {
    // 以前はここで無言でreturnしており、I2S初期化失敗なのか別原因かログから
    // 区別できなかった。空きヒープも併せて出力しておく。
    // 【2026.9】ATOM Echoには液晶が無くUSBはPC側との中継専用のため、デバッグ
    // 出力はコメントアウトする(atom_echo_voice_cmd_pc.inoで実際にSerial共用
    // による中継プロトコル破壊バグが見つかったため、念のため全ファームウェアで
    // 統一。このファイルのRCB4通信自体はRCB4Serial(UART1)でSerialとは別)。
    // Serial.printf("[audio] audioI2S.begin failed! freeHeap=%u\n", (unsigned)ESP.getFreeHeap());
    return;
  }
  int halfWave = sampleRate / freqHz / 2;
  if (halfWave < 1) halfWave = 1;
  int totalSamples = sampleRate * durationMs / 1000;
  int16_t sample = amplitude;
  // 【2026.9、根本原因】ESP_I2S::write(uint8_t)は内部でwrite(&d,1)を呼ぶが、
  // 16bitモードではmin_size=2のため、1バイトずつの呼び出しは毎回
  // 「size(1) < min_size(2)」に該当し、エラーも出さず何もせず0を返して
  // 終了する(ライブラリ側の実装。ESP_I2S.cppのwrite(buffer,size)参照)。
  // 従来の1バイトずつのwrite()は実際には一度もデータを送信しておらず、
  // これが「begin()は成功するのに音が一切鳴らない」不具合の真の原因だった
  // (実機確認、2026.9)。1サンプル(L+R)分をバッファへまとめてbulk writeする。
  int16_t buf[2];
  for (int i = 0; i < totalSamples; i++) {
    if (i % halfWave == 0) sample = -sample;
    buf[0] = sample;
    buf[1] = sample;  // モノラル音源をL/R両方に複製
    audioI2S.write((const uint8_t *)buf, sizeof(buf));
  }
  audioI2S.end();
}

// 【2026.9、根本原因】write()がDMAバッファへの書き込み成功を返しても、実際に
// スピーカーから音が出るまでには立ち上がりの物理的な遅延があり、120ms程度の
// 短い音だとその間に直後の.end()で打ち切られ、音として出る前に終わって
// しまうことが実機で確認された(atom_echo_pc側で先に発覚)。各音を最低
// 200ms程度以上にすることで解決したため、以下すべて延長してある。
void playMelodyRobot() {
  playTone(330, 300);
  playTone(262, 350);
}

void playChimeConnected() {
  playTone(523, 200);
  playTone(784, 250);
}

void playChimeDisconnected() {
  playTone(784, 200);
  playTone(392, 250);
}

void playChimeNotRecognized() {
  playTone(300, 250);
}

// ボタン押下時の説明音声(open_jtalk+meiボイスで生成し、explain_clip.hへ
// 8kHz/16bit/monoのPCM配列として埋め込んだもの。SDカードが無いATOM Echoでは
// 音声本体をプログラムコードに直接含める必要がある)。playTone()と同じ
// I2S初期化・bulk write方式を使う(実機確認済みの方式、詳細はplayTone()の
// コメント参照)。
// PCMクリップ(explain_clip.h/response_clips.hの配列)をそのまま再生する共通処理。
// 【重要】このクリップは長い(最大1.6秒程度)ため、単純にブロックして再生すると
// その間RCB4Serialのリレーが止まり、run_classifier()と同様に:timer-on中の
// PC<->RCB4通信を乱す不具合を再発しうる。再生ループの合間に定期的に
// RCB4Serialを読み出してsendChunk()で中継し、リレーを止めないようにする。
void playPcmClip(const int16_t *clip, size_t len, uint32_t sampleRate) {
  audioI2S.end();
  audioI2S.setPins(I2S_BCLK, I2S_LRCK, I2S_DOUT);
  if (!audioI2S.begin(I2S_MODE_STD, sampleRate, I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_STEREO)) {
    // Serial.printf("[audio] audioI2S.begin(clip) failed! freeHeap=%u\n", (unsigned)ESP.getFreeHeap());
    return;
  }
  int16_t buf[2];
  static const size_t RCB4_POLL_INTERVAL_SAMPLES = 400;  // 8kHzで約50msごと
  for (size_t i = 0; i < len; i++) {
    buf[0] = clip[i];
    buf[1] = clip[i];  // モノラル音源をL/R両方に複製
    audioI2S.write((const uint8_t *)buf, sizeof(buf));
    if (i % RCB4_POLL_INTERVAL_SAMPLES == 0) {
      uint8_t rcb4buf[MAX_CHUNK];
      int n = 0;
      while (RCB4Serial.available() && n < (int)sizeof(rcb4buf)) {
        rcb4buf[n++] = RCB4Serial.read();
      }
      if (n > 0) {
        sendChunk(rcb4buf, n);
      }
    }
  }
  audioI2S.end();
}

void playExplainClip() {
  playPcmClip(EXPLAIN_CLIP, EXPLAIN_CLIP_LEN, EXPLAIN_CLIP_SAMPLE_RATE);
}

// 単語認識時の応答音声(motionForLabel()の対応表と同じラベルで引く)。
void playResponseClip(const char *label) {
  if (strcmp(label, "aisatsu") == 0) {
    playPcmClip(RESP_AISATSU, RESP_AISATSU_LEN, RESPONSE_CLIP_SAMPLE_RATE);
  } else if (strcmp(label, "mae") == 0) {
    playPcmClip(RESP_MAE, RESP_MAE_LEN, RESPONSE_CLIP_SAMPLE_RATE);
  } else if (strcmp(label, "ushiro") == 0) {
    playPcmClip(RESP_USHIRO, RESP_USHIRO_LEN, RESPONSE_CLIP_SAMPLE_RATE);
  } else if (strcmp(label, "hidari") == 0) {
    playPcmClip(RESP_HIDARI, RESP_HIDARI_LEN, RESPONSE_CLIP_SAMPLE_RATE);
  } else if (strcmp(label, "migi") == 0) {
    playPcmClip(RESP_MIGI, RESP_MIGI_LEN, RESPONSE_CLIP_SAMPLE_RATE);
  }
}

// ---- 音声コマンド認識(Edge Impulse) ----

// run_classifier() に渡す信号のデータ供給コールバック。学習時のWAVも同じ生
// PCMスケールのため、正規化はせず単純にint16のままfloatへキャストするだけでよい。
int rawFeatureGetData(size_t offset, size_t length, float *out_ptr) {
  numpy::int16_to_float(&voiceBuf[offset], out_ptr, length);
  return 0;
}

// 単語ラベル(Edge Impulse側はアルファベット順: aisatsu,hidari,mae,migi,noise,ushiro)
// と、対応するKXRL2Gの:call-motion番号。"noise"は動作を割り当てない(何もしない)。
struct WordMotion {
  const char *label;
  int motion;  // -1 = 動作なし
};
static const WordMotion WORD_MOTIONS[] = {
  {"aisatsu", 20},
  {"mae", 0},
  {"ushiro", 1},
  {"hidari", 2},
  {"migi", 3},
  {"noise", -1},
};
static const int NUM_WORD_MOTIONS = sizeof(WORD_MOTIONS) / sizeof(WORD_MOTIONS[0]);

// 認識の信頼度しきい値。atoms3_i2c_robot.inoと同じ値(Edge Impulse Studioでの
// 検証精度77.4%を踏まえたもの)。
static const float CONFIDENCE_THRESHOLD = 0.6f;

void sendCallMotion(uint8_t n) {
  uint32_t addr = 0x0B80UL + (uint32_t)n * 2048UL;
  uint8_t frame[7];
  frame[0] = 0x07;
  frame[1] = 0x0C;  // CALL命令
  frame[2] = addr & 0xFF;
  frame[3] = (addr >> 8) & 0xFF;
  frame[4] = (addr >> 16) & 0xFF;
  frame[5] = 0x00;  // 条件フラグ(無条件)
  uint16_t sum = 0;
  for (int i = 0; i < 6; i++) sum += frame[i];
  frame[6] = sum & 0xFF;
  RCB4Serial.write(frame, sizeof(frame));
}

int motionForLabel(const char *label) {
  for (int i = 0; i < NUM_WORD_MOTIONS; i++) {
    if (strcmp(WORD_MOTIONS[i].label, label) == 0) {
      return WORD_MOTIONS[i].motion;
    }
  }
  return -1;
}

// 分類タスク本体(loop()とは別のFreeRTOSタスク/コアで動く)。run_classifier()
// の重い計算だけをここで行い、RCB4Serial/esp_now_send/I2Sなどのハードウェア
// アクセスは一切行わない(結果はvolatile変数経由でloop()へ渡し、実際の
// call-motion送信・チャイム再生はloop()側で行う。ハードウェアアクセスを
// 複数タスクから行わないようにするための切り分け)。
void classifyTask(void *pvParameters) {
  for (;;) {
    ulTaskNotifyTake(pdTRUE, portMAX_DELAY);  // onDataRecvからの通知を待つ

    signal_t signal;
    signal.total_length = EI_CLASSIFIER_RAW_SAMPLE_COUNT;
    signal.get_data = &rawFeatureGetData;

    ei_impulse_result_t result = {0};
    EI_IMPULSE_ERROR res = run_classifier(&signal, &result, false /* debug */);
    if (res != EI_IMPULSE_OK) {
      // Serial.printf("[voice] run_classifier failed (%d)\n", res);
      classifyBestIdx = -1;
      classifyResultReady = true;
      continue;
    }

    int bestIdx = -1;
    float bestValue = -1.0f;
    for (size_t i = 0; i < EI_CLASSIFIER_LABEL_COUNT; i++) {
      // Serial.printf("[voice]   %s: %.3f\n", result.classification[i].label, result.classification[i].value);
      if (result.classification[i].value > bestValue) {
        bestValue = result.classification[i].value;
        bestIdx = (int)i;
      }
    }

    classifyBestIdx = bestIdx;
    classifyBestValue = bestValue;
    classifyLabel = (bestIdx >= 0) ? result.classification[bestIdx].label : nullptr;
    classifyResultReady = true;  // ここまで書き終えてから立てる(loop()側の読み出し順序と対応)
  }
}

// classifyTaskが書いた結果を消費し、実際のチャイム再生・call-motion送信を行う
// (ハードウェアアクセスはloop()側だけに限定する)。loop()から毎回呼ぶ。
void serviceClassifyResult() {
  if (!classifyResultReady) return;
  classifyResultReady = false;

  int bestIdx = classifyBestIdx;
  float bestValue = classifyBestValue;

  if (bestIdx < 0 || bestValue < CONFIDENCE_THRESHOLD) {
    // Serial.printf("[voice] not confident enough (best=%.3f)\n",
    //               bestIdx >= 0 ? bestValue : 0.0f);
    playChimeNotRecognized();
  } else {
    const char *label = classifyLabel;
    int motion = motionForLabel(label);
    if (motion < 0) {
      // Serial.printf("[voice] recognized \"%s\" (%.3f) -> no motion assigned\n", label, bestValue);
      playChimeNotRecognized();
    } else {
      // Serial.printf("[voice] recognized \"%s\" (%.3f) -> call-motion %d\n", label, bestValue, motion);
      playResponseClip(label);
      sendCallMotion((uint8_t)motion);
    }
  }

  // 結果を消費し終えたので、次の発話の録音を受け付けられるようにする。
  voiceBufLen = 0;
  classifyBusy = false;
}

// ---- setup / loop ----

void setup() {
  Serial.begin(115200);  // デバッグ出力用。RCB4通信には使わない

  pixel.begin();
  pixel.setPixelColor(0, pixel.Color(0, 0, 0));
  pixel.show();

  // 【2026.9】G39はESP32のinput-onlyパッド(GPIO34-39)の1つで内部プルアップを
  // 持たないため、INPUT_PULLUPを指定してもESP-IDFがエラーを返すだけで効果が
  // 無い(実機確認: "gpio: gpio_pullup_en: GPIO number error"のログが出る、
  // atom_echo_pc側で先に発覚)。基板側に外付けプルアップがある前提のINPUTの
  // ままにする。
  pinMode(PIN_BTN, INPUT);

  RCB4Serial.setRxBufferSize(RCB4_RX_BUFFER_SIZE);
  RCB4Serial.begin(RCB4_BAUD, SERIAL_8E1, RCB4_RX_PIN, RCB4_TX_PIN, /*invert=*/true);

  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  esp_wifi_set_channel(WIFI_CHANNEL, WIFI_SECOND_CHAN_NONE);
  esp_wifi_set_ps(WIFI_PS_NONE);

  initEspNow();

  // run_classifier()をloop()と別のコア(0番)で動かすタスクを作る(setup/loop
  // はArduinoの既定でコア1で動くため)。詳細はclassifyTask直前のコメント参照。
  xTaskCreatePinnedToCore(classifyTask, "classifyTask", 8192, NULL, 1, &classifyTaskHandle, 0);

  playMelodyRobot();

  // Serial.println("[voice] ready (Edge Impulse model loaded, no training needed).");
}

bool lastBtnState = HIGH;

void loop() {
  // ESP-NOW <-> RCB4 UART 中継(最優先)
  uint8_t buf[MAX_CHUNK];
  int n = 0;
  while (RCB4Serial.available() && n < (int)sizeof(buf)) {
    buf[n++] = RCB4Serial.read();
  }
  if (n > 0) {
    sendChunk(buf, n);
  } else if (millis() - lastSendActivity > HEARTBEAT_MS) {
    sendPing();
  }

  // 音声コマンドの認識結果を消費(run_classifier()自体は別タスクで実行済み、
  // ここでは結果に応じたチャイム再生・call-motion送信だけを行う)
  serviceClassifyResult();

  // LINK状態 -> LED、変化時のみチャイム
  bool up = isLinkUp();
  if (up != lastLinkUp) {
    pixel.setPixelColor(0, up ? pixel.Color(0, 0, 40) : pixel.Color(40, 0, 0));
    pixel.show();
    if (up) {
      playChimeConnected();
    } else {
      playChimeDisconnected();
    }
    lastLinkUp = up;
  }

  // ボタン押下 -> 使い方の説明音声(デバウンス込み)
  bool btnState = digitalRead(PIN_BTN);
  if (btnState == LOW && lastBtnState == HIGH) {
    playExplainClip();
  }
  lastBtnState = btnState;
}
