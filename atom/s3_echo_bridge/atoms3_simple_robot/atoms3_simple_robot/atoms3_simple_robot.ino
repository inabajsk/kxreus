// ロボット側 ATOM S3 用ファームウェア(簡易版・I2C無し)。
//
// ../../s3_echo_with_I2C/atom_s3_robot/atoms3_i2c_robot.ino をベースに、
// M5StickV用外部I2Cブリッジ(G1/G2、予約OPCODE 0x91)を削除し、その代わりに
// RCB4 UARTをG5/G6(基板底面の拡張用GPIOパッド、はんだ付け)からG2(TX)/G1(RX)
// (Grove(HY2.0-4P)コネクタ)へ戻したバリエーション。腕・M5StickVカメラを
// 持たず、IMUによる姿勢表示(euslisp側`:timer-on`)とRCB4無線化だけで足りる
// 機体向けの、配線がGroveコネクタ1本で済む簡易版。
//
// 【ピン配置(ATOM S3、このバリエーション)】
//   RCB4 UART: G2(TX)/G1(RX) -- Grove(HY2.0-4P)コネクタ。はんだ付け不要。
//   IMU(MPU6886, I2C): G38(SDA)/G39(SCL) -- 内蔵。RCB4の予約OPCODE(0x90)を
//     ATOM S3側で横取りしてIMU値を返す(下記【IMU予約OPCODEプロトコル】参照)。
//     euslisp側`(send *ri* :timer-on)`はこの値でロボットモデルの姿勢を
//     Madgwickフィルタ経由でPC(irtviewer)に表示する(`atominterface.l`参照)。
//   LCD: G15,G16,G17,G21,G33,G34 -- 内蔵、認識結果表示に使用。
//
// 【設計方針】音声の入力元(PC側マイク→ESP-NOW)・認識ロジック(Edge Impulse
// run_classifier())・RCB4中継・LCD表示・IMU予約OPCODEは
// ../../s3_echo_with_I2C/atom_s3_robot/atoms3_i2c_robot.ino と同じ。
//
// 【IMU予約OPCODEプロトコル】
// RCB4の実オペコードは *rcb4-instructions* (0x0-0x12, 0xFD, 0xFE)で使用済み。
// 0x90は未使用のため、IMU読み出し用に予約する。PCから来たRCB4コマンドバイト列
// ([length,opcode,...,checksum]、checksumはbytes[0:length-1]の合計&0xFF)を
// 実RCB4へ転送する前に横取りし、一致すればRCB4には送らずIMU値を返す。
//   リクエスト: [0x03, 0x90, 0x93]  (checksum=(3+0x90)&0xFF=0x93)
//   応答: [0x0F, 0x90,
//          ax_lo,ax_hi, ay_lo,ay_hi, az_lo,az_hi,   (加速度 int16 LE, 単位 milli-g)
//          gx_lo,gx_hi, gy_lo,gy_hi, gz_lo,gz_hi,   (角速度 int16 LE, 単位 0.1deg/s)
//          checksum]
// 応答も実RCB4の返信と同じESP-NOW経路(sendChunk、seq+ACK付き)で送り返す。

#include <esp_now.h>
#include <esp_wifi.h>
#include <WiFi.h>
#include <M5Unified.h>
#include "driver/uart.h"
#include "driver/gpio.h"

#include <kxr-voice-commands_inferencing.h>

// Arduinoの自動プロトタイプ生成は#include直後にまとめて挿入されるため、
// カスタム型を関数の戻り値に使う場合は、その型定義を先にここへ置く必要が
// ある(そうしないと生成されたプロトタイプの時点で型が未定義になり
// "does not name a type" でビルドが失敗する。実機確認、2026.8)。
enum Rcb4Status { RCB4_IDLE, RCB4_OK, RCB4_NG };

static auto &display = M5.Display;

static const uint8_t IMU_OPCODE = 0x90;
static const uint8_t IMU_REQUEST[3] = {0x03, IMU_OPCODE, 0x93};
volatile bool imuRequestPending = false;

static const char *MY_NAME = "ATOMS3-ROBOT-SIMPLE";

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

// RCB4-mini 側 UART 設定。Grove(HY2.0-4P)コネクタ(G1/G2)。
// RCB4-miniのCOMコネクタはGND側から GND-Rx-Tx の順(HeartToHeart4マニュアルより)。
// 無印AtomS3のボード定義でSCL=G1/SDA=G2(I2C用の呼び名)だが、ここではI2Cとしては
// 使わず、単純にUARTのRX/TXとして使う(G1=RX, G2=TX)。
static const int RCB4_TX_PIN = 2;
static const int RCB4_RX_PIN = 1;
static const uint32_t RCB4_BAUD = 1250000;
static const uart_port_t RCB4_UART_NUM = UART_NUM_1;

HardwareSerial RCB4Serial(1);

// HardwareSerial.begin()の単純なinvert引数はESP32-S3で不安定なことが実機で
// わかっているため、invert=falseで開始してからESP-IDFのuart_set_line_inverse()
// でTX/RXの反転を個別に設定する(atoms3_i2c_robot_diagで検証済みの方式)。
// GPIOマトリクス/IOMUXの古い割り当てが残らないよう、begin()前に毎回ピンを
// リセットする。
// 【重要】RCB4_BAUDが1.25Mbpsと非常に高速なため、loop()側のESP-NOW中継
// (sendChunk、ACK待ちで最大ACK_TIMEOUT_MS×ACK_MAX_RETRY=750msブロックしうる)
// が詰まっている間に、デフォルトのRXバッファ(ESP32 Arduinoコアの既定で
// 256byte程度)がすぐに溢れてバイトが欠落する。実機で、call-motionのように
// RCB4からの応答が連続で大量に来る場面で、PC側が「invalid length byte」
// 「timed out waiting for length byte」のような再同期エラーを繰り返す
// (AtomS3のLCDには「RCB4 OK」=RCB4自体は何か返している、と出るのに)という
// 不具合として確認された(2026.8)。RXバッファを大きく確保することで、
// ESP-NOW側のブロック中もRCB4からの応答をハードウェア/ドライバ側で
// 溜めておけるようにし、欠落を減らす。setRxBufferSizeはbegin()より
// 前に呼ぶ必要がある。
static const size_t RCB4_RX_BUFFER_SIZE = 4096;

void beginRcb4Serial() {
  RCB4Serial.end();
  delay(5);
  gpio_reset_pin((gpio_num_t)RCB4_TX_PIN);
  gpio_reset_pin((gpio_num_t)RCB4_RX_PIN);
  RCB4Serial.setRxBufferSize(RCB4_RX_BUFFER_SIZE);
  RCB4Serial.begin(RCB4_BAUD, SERIAL_8E1, RCB4_RX_PIN, RCB4_TX_PIN, /*invert=*/false);
  delay(5);
  uart_set_line_inverse(RCB4_UART_NUM, UART_SIGNAL_TXD_INV | UART_SIGNAL_RXD_INV);
}

volatile uint32_t lastAckMillis = 0;
volatile uint32_t lastRecvMillis = 0;
uint32_t lastSendActivity = 0;
bool lastLinkUp = false;

// RCB4とのUART中継状態を、液晶で目視確認できるようにするための状態。
// AtomS3はRGB LEDを使っていない(液晶があるため)ので、代わりに液晶へ
// LINK/RCB4の状態を出す。
// RCB4はPCからのコマンドに応答する方式で、PCが何も送っていない間は
// 当然RCB4からのバイトも無い(実機確認、2026.8: 受信の有無だけを見る
// 単純な判定だと、PC側が単に待機中なだけの正常な状態でも赤(異常)表示に
// なってしまい紛らわしかった)。そこで「最後にRCB4へ送った時刻」と
// 「最後にRCB4から受けた時刻」を両方追跡し、次の3状態で表示する:
//   IDLE(灰): 最近RCB4へ何も送っていない(PC側が待機中。異常ではない)
//   OK(緑)  : 送信の後、ちゃんと応答(またはその後の通常バイト)を受信できている
//   NG(赤)  : 送信したのに、タイムアウトまでに応答が来ていない(本当の異常)
static const uint32_t RCB4_IDLE_TIMEOUT_MS = 3000;   // この時間送信が無ければ「待機中」
static const uint32_t RCB4_REPLY_TIMEOUT_MS = 1000;  // 送信後この時間応答が無ければ「異常」
volatile uint32_t lastRcb4TxMillis = 0;
uint32_t lastRcb4RxMillis = 0;
uint32_t lastStatusDrawMillis = 0;
Rcb4Status lastRcb4Status = RCB4_IDLE;
Rcb4Status rcb4Status() {
  uint32_t now = millis();
  if (now - lastRcb4TxMillis > RCB4_IDLE_TIMEOUT_MS) return RCB4_IDLE;
  if (lastRcb4RxMillis >= lastRcb4TxMillis) return RCB4_OK;
  if (now - lastRcb4TxMillis > RCB4_REPLY_TIMEOUT_MS) return RCB4_NG;
  return RCB4_OK;  // 送信直後、まだ応答タイムアウト猶予内
}

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
  if (status == ESP_NOW_SEND_SUCCESS) {
    lastAckMillis = millis();
  }
}

// ---- 音声コマンドの録音バッファ(ESP-NOW受信コールバックはここに積むだけ) ----
// EI_CLASSIFIER_RAW_SAMPLE_COUNT はEdge Impulseの学習設定(8kHz, window 1000ms)
// から生成される定数で、8000になる(このモデル固有の値)。

static_assert(EI_CLASSIFIER_RAW_SAMPLE_COUNT == 8000, "モデルの入力サンプル数が想定と異なる");

int16_t voiceBuf[EI_CLASSIFIER_RAW_SAMPLE_COUNT];
volatile size_t voiceBufLen = 0;
volatile bool voiceUtteranceReady = false;

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
      if (len - 2 == 3 && memcmp(data + 2, IMU_REQUEST, 3) == 0) {
        // IMU予約OPCODE: 実RCB4には転送せず、loop()側でIMUを読んで返信する。
        imuRequestPending = true;
      } else {
        RCB4Serial.write(data + 2, len - 2);
        lastRcb4TxMillis = millis();
      }
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
    size_t n = (len - 1) / 2;
    for (size_t i = 0; i < n; i++) {
      if (voiceBufLen >= EI_CLASSIFIER_RAW_SAMPLE_COUNT) break;
      int16_t s = (int16_t)(data[1 + i * 2] | (data[1 + i * 2 + 1] << 8));
      voiceBuf[voiceBufLen++] = s;
    }
  } else if (data[0] == PKT_VOICE_END) {
    // 発話が短くてバッファが埋まりきらなかった場合は残りを無音(0)で埋める
    // (EI_CLASSIFIER_RAW_SAMPLE_COUNT ぴったりの長さが必要なため)。
    while (voiceBufLen < EI_CLASSIFIER_RAW_SAMPLE_COUNT) {
      voiceBuf[voiceBufLen++] = 0;
    }
    voiceUtteranceReady = true;
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

// IMU予約OPCODEの応答フレームを組み立て、実RCB4応答と同じ経路(sendChunk)で送る。
void sendImuReply() {
  m5::imu_data_t data = {};
  if (M5.Imu.isEnabled()) {
    M5.Imu.update();
    data = M5.Imu.getImuData();
  }

  int16_t ax = (int16_t)lroundf(data.accel.x * 1000.0f);  // milli-g
  int16_t ay = (int16_t)lroundf(data.accel.y * 1000.0f);
  int16_t az = (int16_t)lroundf(data.accel.z * 1000.0f);
  int16_t gx = (int16_t)lroundf(data.gyro.x * 10.0f);  // 0.1 deg/s
  int16_t gy = (int16_t)lroundf(data.gyro.y * 10.0f);
  int16_t gz = (int16_t)lroundf(data.gyro.z * 10.0f);

  uint8_t frame[15];
  frame[0] = 0x0F;
  frame[1] = IMU_OPCODE;
  int16_t vals[6] = {ax, ay, az, gx, gy, gz};
  for (int i = 0; i < 6; i++) {
    frame[2 + i * 2] = (uint8_t)(vals[i] & 0xFF);
    frame[3 + i * 2] = (uint8_t)((vals[i] >> 8) & 0xFF);
  }
  uint16_t sum = 0;
  for (int i = 0; i < 14; i++) sum += frame[i];
  frame[14] = sum & 0xFF;

  sendChunk(frame, sizeof(frame));
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

// 認識の信頼度しきい値。Edge Impulse Studioでの検証精度(77.4%)を踏まえ、
// 確信度が低い(僅差で最有力になっただけ)の場合は「認識できず」として無視する。
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

// ---- LCD表示 ----

// 画面上端に、ESP-NOWリンクとRCB4 UART中継の状態を小さく表示する。
// showIdle/showRecognition/showNotConfident はfillScreenで画面全体を
// 消してしまうので、それらの描画の後に必ず呼び直すこと。
void drawLinkStatus() {
  bool linkUp = isLinkUp();
  Rcb4Status st = rcb4Status();
  display.fillRect(0, 0, display.width(), 10, TFT_BLACK);
  display.setTextSize(1);
  display.setCursor(1, 1);
  display.setTextColor(linkUp ? TFT_GREEN : TFT_RED, TFT_BLACK);
  display.print(linkUp ? "LINK OK" : "LINK NG");
  display.setCursor(display.width() - 46, 1);
  switch (st) {
    case RCB4_OK:
      display.setTextColor(TFT_GREEN, TFT_BLACK);
      display.print("RCB4 OK");
      break;
    case RCB4_NG:
      display.setTextColor(TFT_RED, TFT_BLACK);
      display.print("RCB4 NG");
      break;
    default:  // RCB4_IDLE
      display.setTextColor(TFT_DARKGREY, TFT_BLACK);
      display.print("RCB4 --");
      break;
  }
}

void showIdle() {
  display.fillScreen(TFT_BLACK);
  display.setTextColor(TFT_WHITE, TFT_BLACK);
  display.setTextSize(1.4);
  display.setCursor(4, display.height() / 2 - 8);
  display.println("listening...");
  drawLinkStatus();
}

// 認識結果(単語ラベル・信頼度・実行するモーション番号)をLCDに表示する。
// motion<0 は「動作なし」(noiseラベル、または未割り当ての単語)を意味する。
void showRecognition(const char *label, float confidence, int motion) {
  display.fillScreen(TFT_BLACK);
  display.setCursor(0, 2);

  display.setTextSize(1.6);
  display.setTextColor(TFT_YELLOW, TFT_BLACK);
  display.println(label);

  display.setTextSize(1.1);
  display.setTextColor(TFT_CYAN, TFT_BLACK);
  display.printf("conf %.0f%%\n", confidence * 100.0f);

  display.setTextSize(1.4);
  if (motion >= 0) {
    display.setTextColor(TFT_GREEN, TFT_BLACK);
    display.printf("motion %d", motion);
  } else {
    display.setTextColor(TFT_RED, TFT_BLACK);
    display.println("no motion");
  }
  drawLinkStatus();
}

void showNotConfident(float bestValue) {
  display.fillScreen(TFT_BLACK);
  display.setTextColor(TFT_DARKGREY, TFT_BLACK);
  display.setTextSize(1.2);
  display.setCursor(0, display.height() / 2 - 16);
  display.println("(unclear)");
  display.printf("best %.0f%%\n", bestValue * 100.0f);
  drawLinkStatus();
}

void processVoiceUtterance() {
  signal_t signal;
  signal.total_length = EI_CLASSIFIER_RAW_SAMPLE_COUNT;
  signal.get_data = &rawFeatureGetData;

  ei_impulse_result_t result = {0};
  EI_IMPULSE_ERROR res = run_classifier(&signal, &result, false /* debug */);
  if (res != EI_IMPULSE_OK) {
    // 【2026.9】ATOM S3は液晶(display)で状態表示できるためSerialデバッグ出力は
    // 本来不要であり、atom_echo_voice_cmd_pc.inoで見つかったSerial共用による
    // 中継プロトコル破壊バグの再発防止も兼ねてコメントアウトする(このファイルの
    // RCB4通信はRCB4Serial(UART1)でSerial(USB)とは別だが念のため統一)。
    // Serial.printf("[voice] run_classifier failed (%d)\n", res);
    return;
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

  if (bestIdx < 0 || bestValue < CONFIDENCE_THRESHOLD) {
    // Serial.printf("[voice] not confident enough (best=%.3f)\n",
    //               bestIdx >= 0 ? bestValue : 0.0f);
    showNotConfident(bestIdx >= 0 ? bestValue : 0.0f);
    return;
  }

  const char *label = result.classification[bestIdx].label;
  int motion = motionForLabel(label);
  if (motion < 0) {
    // Serial.printf("[voice] recognized \"%s\" (%.3f) -> no motion assigned\n", label, bestValue);
    showRecognition(label, bestValue, -1);
    return;
  }

  // Serial.printf("[voice] recognized \"%s\" (%.3f) -> call-motion %d\n", label, bestValue, motion);
  showRecognition(label, bestValue, motion);
  sendCallMotion((uint8_t)motion);
}

// ---- setup / loop ----

void setup() {
  Serial.begin(115200);  // デバッグ用。RCB4通信には使わない

  auto cfg = M5.config();
  M5.begin(cfg);
  if (display.width() < display.height()) {
    display.setRotation(display.getRotation() ^ 1);
  }
  // ロボットにATOM S3を上下逆さに取り付けているため、表示も180度回転させる。
  display.setRotation((display.getRotation() + 2) % 4);
  showIdle();

  if (!M5.Imu.isEnabled()) {
    // Serial.println("[imu] not detected (IMU予約OPCODEは常に0を返す)");
  }

  beginRcb4Serial();

  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  esp_wifi_set_channel(WIFI_CHANNEL, WIFI_SECOND_CHAN_NONE);
  esp_wifi_set_ps(WIFI_PS_NONE);

  initEspNow();

  // Serial.println("[voice] ready (Edge Impulse model: kxr-voice-commands). Simple variant (RCB4 UART on G1/G2, no I2C).");
  // Serial.println("[voice] words: aisatsu(gree) mae(fwd) ushiro(back) hidari(left) migi(right)");
}

void loop() {
  // ESP-NOW <-> RCB4 UART 中継(最優先)
  uint8_t buf[MAX_CHUNK];
  int n = 0;
  while (RCB4Serial.available() && n < (int)sizeof(buf)) {
    buf[n++] = RCB4Serial.read();
  }
  if (n > 0) {
    lastRcb4RxMillis = millis();
    sendChunk(buf, n);
  } else if (millis() - lastSendActivity > HEARTBEAT_MS) {
    sendPing();
  }

  // 音声コマンドの処理(1発話分が届いたら認識を実行)
  if (voiceUtteranceReady) {
    processVoiceUtterance();
    voiceUtteranceReady = false;
    voiceBufLen = 0;
  }

  // IMU予約OPCODEリクエストの処理(ESP-NOW受信コールバックからは重いI2C読み出しを
  // 避けるため、ここでフラグを見て処理する)。
  if (imuRequestPending) {
    imuRequestPending = false;
    sendImuReply();
  }

  // LINK状態変化のログを出す(LEDが無いため)。あわせて液晶の状態表示も、
  // 変化があった時とそれ以外も定期的に(300ms毎)更新する。
  bool up = isLinkUp();
  if (up != lastLinkUp) {
    // Serial.printf("[link] %s\n", up ? "UP" : "DOWN");
    lastLinkUp = up;
  }
  Rcb4Status st = rcb4Status();
  if (st != lastRcb4Status) {
    const char *names[] = {"IDLE", "OK", "NG"};
    // Serial.printf("[rcb4] %s\n", names[st]);
    lastRcb4Status = st;
  }
  if (millis() - lastStatusDrawMillis > 300) {
    drawLinkStatus();
    lastStatusDrawMillis = millis();
  }
}
