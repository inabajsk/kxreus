// PC側 ATOM Echo 用ファームウェア(ESP-NOW版、RCB4中継 + 音声コマンドデモ)。
//
// atom_echo_bridge_pc_base.ino がベース(RCB4中継・LED・識別音は共通)。
// これに「前面ボタンを押すと、その場の一言をロボット側へ送って単語認識させる」
// 音声コマンド機能を追加したもの。
//
// 【設計方針】
//   - 認識処理自体はロボット側(atom_echo_voice_cmd_robot.ino)で行う。PC側は
//     「ボタンを押した直後の約1秒間のマイク音声を、そのままロボットへ送るだけ」。
//     こうしておくことで、将来「PC側ECHOやPCが無い状態でも動く」バージョンを
//     作る際、ロボット側の認識ロジックはそのまま流用でき、音声の入力元を
//     (ESP-NOWで受信したもの)から(自分自身のマイク)に差し替えるだけで済む。
//   - PTT(トランシーバー)機能とは異なり、AGC(自動音量調整)やノイズゲートは
//     かけない。生の振幅の変化(エネルギー包絡線)が単語認識の特徴量になるため、
//     ゲインをいじると認識精度に悪影響が出るおそれがあるため。
//   - ボタンを押した瞬間の電気的ノイズ(PTT開発時に判明した既知の現象)を避けるため、
//     押してから最初の150msは録音を破棄してから本番の1秒間を送る。
//
// マイクのDATAピンは公式仕様通りG23、CLKはG33(スピーカーLRCKと共用、
// PTT版と同じ配線)。

#include <esp_now.h>
#include <esp_wifi.h>
#include <WiFi.h>
#include <Adafruit_NeoPixel.h>
#include <ESP_I2S.h>

static const char *MY_NAME = "ECHO1-PC";

// 相手(ロボット側AtomS3)のMACアドレス。robot_mac.hは../atom_s3_robot/の
// get_my_mac.shで生成される(手動編集しないこと。詳細はREADME.md参照)。
#include "robot_mac.h"
static uint8_t PEER_MAC[6] = ROBOT_MAC_BYTES;

static const uint8_t WIFI_CHANNEL = 1;
static const size_t MAX_CHUNK = 240;
static const uint32_t HEARTBEAT_MS = 300;
static const uint32_t LINK_TIMEOUT_MS = 1000;

static const uint8_t PKT_DATA = 0x01;
static const uint8_t PKT_PING = 0x02;
static const uint8_t PKT_PONG = 0x03;
static const uint8_t PKT_VOICE_AUDIO = 0x0A;  // 音声コマンド用の生PCMチャンク
static const uint8_t PKT_VOICE_END = 0x0B;    // 1回分の録音終了を知らせる
static const uint8_t PKT_DATA_ACK = 0x04;     // PKT_DATA 1個分の受信確認応答

static const uint32_t AUDIO_SAMPLE_RATE = 8000;
static const size_t AUDIO_CHUNK_BYTES = 240;

// RGB LED (SK6812, G27)
static const int PIN_LED = 27;
Adafruit_NeoPixel pixel(1, PIN_LED, NEO_GRB + NEO_KHZ800);

// ボタン (G39, 押下でLOW)
static const int PIN_BTN = 39;

// I2S (speaker: NS4168 / mic: SPM1423 PDM)
static const int I2S_BCLK = 19;
static const int I2S_LRCK = 33;  // 公式仕様の正しいAMP LRCKピン
static const int I2S_DOUT = 22;
static const int I2S_PDM_CLK = 33;
static const int I2S_PDM_DIN = 23;  // 公式仕様のマイクDATAピン
I2SClass audioI2S;

volatile uint32_t lastRecvMillis = 0;
volatile int32_t lastRtt = -1;
uint32_t lastSendActivity = 0;
bool lastLinkUp = false;

// ---- PKT_DATA用の確認応答・再送プロトコル ----
// ESP-NOWの物理層再送だけでは、実機テストで確認したように大量の連続送信
// (ROMのモーションデータ読み書きなど)で取りこぼしが発生することが判明した。
// RCB4のUARTバイトストリームは1バイトでも欠落すると以降のフレーミングが
// 全てずれてチェックサム不一致を引き起こすため、アプリケーション層で
// シーケンス番号+ACK+タイムアウト再送によるstop-and-wait方式を追加する。
static uint8_t txSeq = 0;                // 送信側: 次に使うシーケンス番号
static int32_t lastProcessedSeq = -1;    // 受信側: 直前に処理したシーケンス番号(-1=まだ無し)
volatile uint8_t lastAckedSeq = 0xFF;    // 直近ACKされたシーケンス番号
volatile bool haveAck = false;
static const uint32_t ACK_TIMEOUT_MS = 25;
static const int ACK_MAX_RETRY = 30;

void onDataSent(const wifi_tx_info_t *info, esp_now_send_status_t status) {
  // このPC側は送達確認をLINK判定に使わない(受信ベースで判定するため)。
}

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
      Serial.write(data + 2, len - 2);
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
  } else if (data[0] == PKT_PONG && len == 5) {
    uint32_t sentAt;
    memcpy(&sentAt, data + 1, 4);
    lastRtt = (int32_t)(millis() - sentAt);
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

// ---- 音関連(チャイム用。マイクと排他利用のため都度end/beginする) ----

// 【2026.9、根本原因1】ESP_I2S::write(uint8_t)は内部でwrite(&d,1)を呼ぶが、
// 16bitモードではmin_size=2のため、1バイトずつの呼び出しは毎回
// 「size(1) < min_size(2)」に該当し、エラーも出さず何もせず0を返して
// 終了する(ライブラリ側の実装。ESP_I2S.cppのwrite(buffer,size)参照)。
// 従来の1バイトずつのwrite()は実際には一度もデータを送信しておらず、これが
// 「begin()は成功するのに音が一切鳴らない」不具合の原因の1つだった
// (実機確認、2026.9、atom_echo_robot側で先に発覚)。1サンプル(L+R)分を
// バッファへまとめてbulk writeする。
//
// 【2026.9、根本原因2】上記を直しても、120ms程度の短い音はまだ鳴らなかった。
// write()がDMAバッファへの書き込み成功(バイト数一致)を返しても、実際に
// スピーカーから音が出るまでには立ち上がりの物理的な遅延があり、短い音だと
// その間に直後の.end()で打ち切られ、音として出る前に終わってしまうことが
// 実機で確認された。各音を最低200ms程度以上にすることで解決した
// (詳細はplayMelodyPC()等の各チャイム関数のコメント参照)。
void playTone(int freqHz, int durationMs, int amplitude = 6000) {
  const int sampleRate = 8000;
  audioI2S.end();
  audioI2S.setPins(I2S_BCLK, I2S_LRCK, I2S_DOUT);
  // 【2026.9】このSerialはEusLisp<->RCB4の透過的バイト中継(loop()のSerial.read/
  // write)と共用のUSBシリアルであり、ここへの1回のprintfがRCB4プロトコルの
  // フレーミングを永久に破壊し、make-kxr-robot/:timer-onが復旧不能になる不具合の
  // 原因だった(実機確認、2026.9)。デバッグ出力はこのSerialへは一切出さない。
  if (!audioI2S.begin(I2S_MODE_STD, sampleRate, I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_STEREO)) {
    // Serial.printf("[audio] audioI2S.begin failed! freeHeap=%u\n", (unsigned)ESP.getFreeHeap());
    return;
  }
  int halfWave = sampleRate / freqHz / 2;
  if (halfWave < 1) halfWave = 1;
  int totalSamples = sampleRate * durationMs / 1000;
  int16_t sample = amplitude;
  int16_t buf[2];
  for (int i = 0; i < totalSamples; i++) {
    if (i % halfWave == 0) sample = -sample;
    buf[0] = sample;
    buf[1] = sample;  // モノラル音源をL/R両方に複製
    audioI2S.write((const uint8_t *)buf, sizeof(buf));
  }
  audioI2S.end();
}

void playMelodyPC() {
  // 【2026.9、根本原因】write()がDMAバッファへの書き込み成功を返しても、実際に
  // スピーカーから音が出るまでには立ち上がりの物理的な遅延があり、120ms程度の
  // 短い音だとその間に.end()で打ち切られ、音として出る前に終わってしまう
  // ことが実機で確認された。1音あたり十分な長さ(300ms前後)を確保し、
  // 3音の上昇アルペジオで約1秒の心地よいチャイムにする。
  playTone(523, 300);  // C5
  playTone(659, 300);  // E5
  playTone(784, 350);  // G5
}

void playChimeConnected() {
  playTone(523, 200);
  playTone(784, 250);
}

void playChimeDisconnected() {
  playTone(784, 200);
  playTone(392, 250);
}

void playChimeListenStart() {
  // 録音開始の合図(短く高い1音)。60msでは短すぎて実機で聞こえなかったため
  // 200msに延長(理由はplayMelodyPC()のコメント参照)。
  playTone(1200, 200);
}

// ---- 音声コマンド録音(ボタンを押した直後の一言を録ってロボットへ送るだけ) ----

enum VoiceState { VOICE_IDLE,
                   VOICE_MASKING,
                   VOICE_CAPTURING };
VoiceState voiceState = VOICE_IDLE;
uint32_t voiceStateStartMillis = 0;

static const uint32_t VOICE_MASK_MS = 150;     // ボタン押下直後の電気ノイズを避けるため読み捨てる時間
static const uint32_t VOICE_CAPTURE_MS = 1000;  // 本番録音時間(1秒固定)

// 【2026.9】以前はマイク(PDM_RX)のaudioI2S.begin()が失敗した場合、voiceStateを
// VOICE_MASKINGへ進めずreturnしていたため、voiceStateがVOICE_IDLEのまま残り、
// 次のloop()で(ボタンのチャタリング等により)即座にまたstartVoiceCapture()が
// 呼ばれ、[audio] playTone(1200,60,...)の合図音が高速に鳴り続ける無限ループに
// なる不具合が実機で確認された。voiceStateの状態に関わらず、直前の試行から
// 最低VOICE_RETRIGGER_COOLDOWN_MS経過するまでは再トリガーしないようにする。
static const uint32_t VOICE_RETRIGGER_COOLDOWN_MS = 1000;
uint32_t lastVoiceCaptureAttemptMillis = 0;  // 起動から1秒間だけ余分にクールダウンされるが無害

void startVoiceCapture() {
  if (millis() - lastVoiceCaptureAttemptMillis < VOICE_RETRIGGER_COOLDOWN_MS) {
    return;
  }
  lastVoiceCaptureAttemptMillis = millis();

  // 【重要】録音開始の合図音は、マイク(PDM RX)に切り替える前、スピーカー(STD)の
  // ままの状態で鳴らす。以前はマスク時間が終わった後(録音フェーズの直前)に
  // 鳴らしていたが、playTone()はSTDモードに切り替えてしまうため、その後マイクを
  // PDM RXへ戻し忘れており、録音フェーズが常に無音になってしまうバグがあった。
  playChimeListenStart();

  audioI2S.end();
  audioI2S.setPinsPdmRx(I2S_PDM_CLK, I2S_PDM_DIN);
  // 【2026.9】playTone()のbegin失敗時と同じ理由でSerial.printfをコメントアウト
  // (このSerialはRCB4中継と共用のため、デバッグ出力を混ぜてはいけない)。
  bool ok = audioI2S.begin(I2S_MODE_PDM_RX, AUDIO_SAMPLE_RATE, I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_MONO);
  // Serial.printf("[audio] mic audioI2S.begin(PDM_RX) -> %s\n", ok ? "OK" : "FAILED");
  if (!ok) {
    return;
  }
  voiceState = VOICE_MASKING;
  voiceStateStartMillis = millis();
  pixel.setPixelColor(0, pixel.Color(60, 0, 60));  // 録音中は紫
  pixel.show();
}

// 音声コマンドの状態機械を1ステップ進める(loop()から毎回呼ぶ)。
void serviceVoiceCapture() {
  if (voiceState == VOICE_IDLE) return;

  uint8_t buf[AUDIO_CHUNK_BYTES];
  uint32_t elapsed = millis() - voiceStateStartMillis;

  if (voiceState == VOICE_MASKING) {
    audioI2S.readBytes((char *)buf, sizeof(buf));  // 読み捨てる
    if (elapsed >= VOICE_MASK_MS) {
      voiceState = VOICE_CAPTURING;
      voiceStateStartMillis = millis();
    }
    return;
  }

  // VOICE_CAPTURING
  if (elapsed >= VOICE_CAPTURE_MS) {
    audioI2S.end();
    uint8_t endPkt = PKT_VOICE_END;
    esp_now_send(PEER_MAC, &endPkt, 1);
    voiceState = VOICE_IDLE;
    bool up = isLinkUp();
    pixel.setPixelColor(0, up ? pixel.Color(0, 40, 0) : pixel.Color(40, 0, 0));
    pixel.show();
    return;
  }
  size_t got = audioI2S.readBytes((char *)buf, sizeof(buf));
  if (got > 0) {
    uint8_t packet[1 + AUDIO_CHUNK_BYTES];
    packet[0] = PKT_VOICE_AUDIO;
    memcpy(packet + 1, buf, got);
    esp_now_send(PEER_MAC, packet, got + 1);
  }
}

// ---- setup / loop ----

void setup() {
  // ATOM EchoのUSBシリアルは(AtomS3のネイティブUSB-CDCと違い)本物のFTDIチップ経由の
  // UART配線のため、ホスト側が実際に設定するボーレートと一致していないと通信できない。
  // 実機検証の結果、この個体では500000/750000だけが確実に通信できた
  // (詳細はAtomEcho/README.md参照)。
  Serial.begin(500000);

  pixel.begin();
  pixel.setPixelColor(0, pixel.Color(40, 0, 0));  // 起動直後はLINK NG(赤)から始める
  pixel.show();

  // 【2026.9】G39はESP32のinput-onlyパッド(GPIO34-39)の1つで内部プルアップを
  // 持たないため、INPUT_PULLUPを指定してもESP-IDFがエラーを返すだけで効果が
  // 無い(実機確認: "gpio: gpio_pullup_en: GPIO number error"のログが出る)。
  // 基板側に外付けプルアップがある前提のINPUTのままにする。ボタンが押されて
  // いないのに繰り返し反応する場合は、外付けプルアップの有無を確認すること。
  pinMode(PIN_BTN, INPUT);

  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  esp_wifi_set_channel(WIFI_CHANNEL, WIFI_SECOND_CHAN_NONE);
  esp_wifi_set_ps(WIFI_PS_NONE);

  initEspNow();
}

bool lastBtnState = HIGH;
bool bootMelodyPlayed = false;

void loop() {
  // 【2026.9】setup()内で直接I2Sを呼ぶより、loop()の最初の1回で呼ぶ方が
  // 安定して鳴ることが実機で確認された(理由の詳細は不明。Arduino-ESP32の
  // setup()→loop()移行時の何らかの初期化状態の違いによるものと見られる)。
  if (!bootMelodyPlayed) {
    bootMelodyPlayed = true;
    playMelodyPC();
  }

  // ボタン押下(立下り) -> 録音シーケンス開始(録音中は再度押しても無視)
  bool btnState = digitalRead(PIN_BTN);
  if (btnState == LOW && lastBtnState == HIGH && voiceState == VOICE_IDLE) {
    startVoiceCapture();
  }
  lastBtnState = btnState;

  // RCB4中継(PKT_DATA)を最優先。次に音声コマンド録音、最後にハートビート。
  uint8_t buf[MAX_CHUNK];
  int n = 0;
  while (Serial.available() && n < (int)sizeof(buf)) {
    buf[n++] = Serial.read();
  }
  if (n > 0) {
    sendChunk(buf, n);
  } else if (voiceState != VOICE_IDLE) {
    serviceVoiceCapture();
  } else if (millis() - lastSendActivity > HEARTBEAT_MS) {
    sendPing();
  }

  bool up = isLinkUp();
  if (up != lastLinkUp) {
    if (voiceState == VOICE_IDLE) {
      pixel.setPixelColor(0, up ? pixel.Color(0, 40, 0) : pixel.Color(40, 0, 0));
      pixel.show();
      if (up) {
        playChimeConnected();
      } else {
        playChimeDisconnected();
      }
    }
    lastLinkUp = up;
  }
}
