// ATOM (ESP32-S3, USB-C) を近藤科学 RCB4-mini 用の
// 「USB Dual Adapter」代替の反転UART-USBブリッジにするスケッチ。
//
// PC 側 USB-CDC (Serial) <---> ATOM <---> UART1 (信号反転, RCB4-mini側)
//
// バイト列は基本的にそのまま中継し、RCB4のコマンド解釈やチェックサム計算は
// 行わない。プロトコルの中身はPC側(kxreus等)に任せる設計。
//
// 【例外: IMU予約OPCODE(0x90)】
// RCB4は0x90を使わないため、他のkxreus ATOMファーム(s3_echo_bridge,
// s3_echo_with_I2C, s3_wifi_captiv)と同じくIMU読み出し用に予約する。PCから
// 来たフレームがIMUリクエストだった場合だけ、実RCB4には転送せずATOM自身の
// IMU(MPU6886)値を返す。RCB4-miniにはIMUが無いので、これがPC側から姿勢を
// 得る唯一の経路になる。
//
//   リクエスト: [0x03, 0x90, 0x93]            (checksum=(0x03+0x90)&0xFF)
//   応答:      [0x0F, 0x90,
//               ax,ay,az (各int16 LE, milli-g),
//               gx,gy,gz (各int16 LE, 0.1deg/s), checksum]
//
// 中継のレイテンシを増やさないため、フレーム先頭の2バイト(長さ+オペコード)
// だけを保留して判定し、0x90でなければ即座に吐き出して残りは素通しする。
// 保留するのは1フレームにつき2バイトだけで、それ以降はバイト単位の中継に戻る。
//
// 対象ボード: M5Stack AtomS3 / AtomS3 Lite / AtomS3R など、ESP32-S3 系で
//            USBネイティブCDCを持つATOMシリーズ。
// Arduino IDE 設定:
//   - Board: "M5AtomS3" (または該当機種。無ければ "ESP32S3 Dev Module" でも可)
//   - USB CDC On Boot: "Enabled"  (これが無いと Serial がUSB-CDCにならない)
//   - ライブラリ: M5Unified (IMU読み出しに使用。flash.sh が未導入なら入れる)

#include <HardwareSerial.h>
#include <M5Unified.h>

// ---- 実機で確認済みのピン割り当て ----
// RCB4-mini の COM コネクタはGND側から GND - Rx - Tx の順(HeartToHeart4マニュアルより)。
// 今回の配線(GND側から2番目=Rx をATOMのG2、3番目=Tx をATOMのG1に接続)に対応する
// ピン割り当ては以下の通り。配線を変えた場合はここも合わせて変更すること。
static const int RCB4_TX_PIN = 2;  // ATOM TX(G2) -> RCB4-mini Rx
static const int RCB4_RX_PIN = 1;  // ATOM RX(G1) <- RCB4-mini Tx

// kxreus (rcb4interface.l) の既定の高速モードと同じ 1.25Mbps, 8bit, Even, 1stop。
// ロボット側を低速(:slow)設定で使っている場合は 115200 に変更する。
static const uint32_t RCB4_BAUD = 1250000;

HardwareSerial RCB4Serial(1);  // UART1 を RCB4-mini 用に使う

// ---- IMU予約OPCODE(0x90) ----
static const uint8_t IMU_OPCODE = 0x90;
static const uint8_t IMU_REQUEST[3] = {0x03, IMU_OPCODE, 0x93};

// PC->RCB4方向のフレーム解析状態。
// pendingLen は「まだRCB4へ送っていない、フレーム先頭の保留バイト数」(0..2)。
// bodyRemaining は「オペコードまで判定済みで、あとは素通しするバイト数」。
static uint8_t pending[2];
static int pendingLen = 0;
static int bodyRemaining = 0;

void sendImuReply() {
  m5::imu_data_t data = {};
  if (M5.Imu.isEnabled()) {
    M5.Imu.update();
    data = M5.Imu.getImuData();
  }
  // IMUが無い/初期化できない場合は全ゼロで応答する(他のkxreusファームと同じ)。
  // 加速度が零ベクトルになるので、重力方向を求める側で必ず失敗する。黙って
  // それらしい値を作らないこと。

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

  Serial.write(frame, sizeof(frame));
}

// PCから来た1バイトを、フレーム境界を追いながら処理する。
void handleHostByte(uint8_t b) {
  if (bodyRemaining > 0) {
    // オペコード判定済みのフレームの続き。素通し。
    RCB4Serial.write(b);
    bodyRemaining--;
    return;
  }

  pending[pendingLen++] = b;
  if (pendingLen == 1) {
    // 長さバイトだけではまだ判定できない。オペコードを待つ。
    // 長さ0/1は不正だが、RCB4に判断させるためそのまま流す。
    if (b < 2) {
      RCB4Serial.write(pending, 1);
      pendingLen = 0;
    }
    return;
  }

  if (pending[0] == IMU_REQUEST[0] && pending[1] == IMU_REQUEST[1]) {
    // IMUリクエストの可能性。残りはチェックサム1バイトだけなので、
    // それを見てから確定させる。ここでは何も転送しない。
    bodyRemaining = 0;
    pendingLen = 2;
    // 3バイト目は次の呼び出しで拾う。フラグ代わりに pendingLen==2 かつ
    // pending が IMU_REQUEST 前半、という状態を使う。
    return;
  }

  // IMUリクエストではないので、保留していた2バイトを吐き出して素通しに戻る。
  RCB4Serial.write(pending, 2);
  bodyRemaining = (int)pending[0] - 2;
  if (bodyRemaining < 0) bodyRemaining = 0;
  pendingLen = 0;
}

// pendingLen==2 で IMU_REQUEST 前半のときに来る3バイト目を処理する。
void handleImuCandidateByte(uint8_t b) {
  if (b == IMU_REQUEST[2]) {
    // 確定。RCB4には送らず、ATOM自身のIMUで応答する。
    sendImuReply();
  } else {
    // チェックサム違い。横取りせず、そのままRCB4へ流して判断させる。
    RCB4Serial.write(pending, 2);
    RCB4Serial.write(b);
  }
  pendingLen = 0;
  bodyRemaining = 0;
}

void setup() {
  auto cfg = M5.config();
  M5.begin(cfg);
  Serial.begin(115200);  // USB-CDC側。仮想シリアルなので速度指定は転送速度に影響しない
  RCB4Serial.begin(RCB4_BAUD, SERIAL_8E1, RCB4_RX_PIN, RCB4_TX_PIN, /*invert=*/true);
}

void loop() {
  uint8_t buf[256];
  int n;

  // PC -> RCB4 (IMU予約OPCODEだけ横取りする)
  while (Serial.available()) {
    uint8_t b = Serial.read();
    if (pendingLen == 2 && pending[0] == IMU_REQUEST[0] &&
        pending[1] == IMU_REQUEST[1]) {
      handleImuCandidateByte(b);
    } else {
      handleHostByte(b);
    }
  }

  // RCB4 -> PC
  n = 0;
  while (RCB4Serial.available() && n < (int)sizeof(buf)) {
    buf[n++] = RCB4Serial.read();
  }
  if (n > 0) {
    Serial.write(buf, n);
  }
}
