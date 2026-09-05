// ATOM (ESP32-S3, USB-C) を近藤科学 RCB4-mini 用の
// 「USB Dual Adapter」代替の反転UART-USBブリッジにするスケッチ。
//
// PC 側 USB-CDC (Serial) <---> ATOM <---> UART1 (信号反転, RCB4-mini側)
//
// バイト列をそのまま中継するだけで、RCB4のコマンド解釈やチェックサム計算は
// 一切行わない。プロトコルの中身はPC側(kxreus等)に任せる設計。
//
// 対象ボード: M5Stack AtomS3 / AtomS3 Lite / AtomS3R など、ESP32-S3 系で
//            USBネイティブCDCを持つATOMシリーズ。
// Arduino IDE 設定:
//   - Board: "M5AtomS3" (または該当機種。無ければ "ESP32S3 Dev Module" でも可)
//   - USB CDC On Boot: "Enabled"  (これが無いと Serial がUSB-CDCにならない)

#include <HardwareSerial.h>

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

void setup() {
  Serial.begin(115200);  // USB-CDC側。ここで指定する速度は仮想シリアルなので実際の転送速度には影響しない
  RCB4Serial.begin(RCB4_BAUD, SERIAL_8E1, RCB4_RX_PIN, RCB4_TX_PIN, /*invert=*/true);
}

void loop() {
  uint8_t buf[256];
  int n;

  // PC -> RCB4
  n = 0;
  while (Serial.available() && n < (int)sizeof(buf)) {
    buf[n++] = Serial.read();
  }
  if (n > 0) {
    RCB4Serial.write(buf, n);
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
