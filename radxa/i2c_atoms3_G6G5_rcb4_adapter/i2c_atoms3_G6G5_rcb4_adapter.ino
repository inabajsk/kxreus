// AtomS3をRadxa ZeroのI2Cポート(I2C_EE_M1)とRCB4-mini用UARTの間の
// ブリッジにするスケッチ。液晶表示は ../../atom/atoms3_rcb4_adapter/ を、
// RCB4 UART配線・反転設定は ../atoms3_radxa_setup/ を踏襲している。
//
//   Radxa(I2C_EE_M1, マスター) <--I2C--> AtomS3(スレーブ, G1=SCL/G2=SDA)
//   AtomS3(UART1, G6=TX/G5=RX, 反転) <--UART(1.25Mbps)--> RCB4-mini
//
// ../../atom/atoms3_rcb4_adapter/ (USB接続・PCがマスター側)との違いは、
// PCの代わりにRadxaがI2Cマスターとしてこの中継を叩く点と、AtomS3背面の
// G1/G2(Grove)をRCB4用ではなくRadxa向けI2Cスレーブに使う点(RCB4 UARTは
// 代わりにG6/G5(基板底面拡張パッド)へ移した)。
//
// 【Radxa側のI2Cポートについての注意】
// 「I2C_EE_M1」はRadxa Zeroのピンヘッダ上のラベルで、Linux側で実際に
// どの/dev/i2c-Nに対応するかは機体・OSイメージ(カーネルのdevice tree設定)
// 次第で変わりうる。実機で`i2cdetect -l`を実行して確認すること(未検証)。
//
// 【I2Cワイヤプロトコル】(../i2c_rcb4_bridge.py と対になっている)
//   書き込み(Radxa -> AtomS3 -> RCB4): 1回のI2C書き込みトランザクションに
//     RCB4向け生フレーム([length,opcode,...,checksum])をラッパー無しで
//     そのまま乗せる(RCB4フレーム自体が先頭バイトに全長を持つため、
//     追加のラッパーは不要)。そのままRCB4Serialへ転送するだけで、
//     ../../atom/atom_rcb4_bridge/ 系と同じくプロトコル解釈はしない。
//   読み出し(RCB4 -> AtomS3 -> Radxa): I2Cの読み出しは常に固定
//     FIXED_READ_LEN(64)バイト。内訳は
//       byte[0]      = 有効バイト数(0〜FIXED_READ_LEN-1)
//       byte[1..]    = データ(有効バイト数ぶんのみ意味を持つ、残りは0埋め)
//     RCB4からの受信をリングバッファに貯めておき、Radxaが読み出す(=I2Cの
//     onRequest)たびに溜まっている分を返す。1回の読み出しで収まらない
//     場合は次の読み出しに残りが持ち越される。

#include <Wire.h>
#include <HardwareSerial.h>
#include <M5Unified.h>
#include "driver/uart.h"
#include "driver/gpio.h"

static auto &display = M5.Display;

// ---- RCB4 UART中継 (atoms3_radxa_setup.ino と同一の配線・設定) ----
static const int RCB4_TX_PIN = 6;  // G6
static const int RCB4_RX_PIN = 5;  // G5
static const uint32_t RCB4_BAUD = 1250000;
static const uart_port_t RCB4_UART_NUM = UART_NUM_1;
HardwareSerial RCB4Serial(1);

void beginRcb4Serial() {
  RCB4Serial.end();
  delay(5);
  gpio_reset_pin((gpio_num_t)RCB4_TX_PIN);
  gpio_reset_pin((gpio_num_t)RCB4_RX_PIN);
  RCB4Serial.setRxBufferSize(4096);
  RCB4Serial.begin(RCB4_BAUD, SERIAL_8E1, RCB4_RX_PIN, RCB4_TX_PIN, /*invert=*/false);
  delay(5);
  uart_set_line_inverse(RCB4_UART_NUM, UART_SIGNAL_TXD_INV | UART_SIGNAL_RXD_INV);
}

// ---- Radxaとの通信用I2C(スレーブ)。G2=SDA, G1=SCL ----
static const int RADXA_SDA_PIN = 2;  // G2
static const int RADXA_SCL_PIN = 1;  // G1
// 0x08はI2C予約範囲(0x00-0x07, 0x78-0x7F)を避けた任意の選択。
// 変える場合はi2c_rcb4_bridge.py側の--addrも合わせること。
static const uint8_t I2C_SLAVE_ADDR = 0x08;
static const uint32_t I2C_FREQ = 100000;

static const int FIXED_READ_LEN = 64;  // i2c_rcb4_bridge.pyと合わせる

// RCB4からの受信を貯めるリングバッファ(Radxaが読み出すまでの間の一時保管)。
static const int RX_RING_SIZE = 512;
uint8_t rxRing[RX_RING_SIZE];
volatile int rxHead = 0, rxTail = 0;
int rxRingCount() { return (rxHead - rxTail + RX_RING_SIZE) % RX_RING_SIZE; }
void rxRingPush(uint8_t b) {
  int next = (rxHead + 1) % RX_RING_SIZE;
  if (next == rxTail) return;  // 満杯。Radxa側が読み出しを止めている異常時のみ想定、黙って捨てる。
  rxRing[rxHead] = b;
  rxHead = next;
}
uint8_t rxRingPop() {
  uint8_t b = rxRing[rxTail];
  rxTail = (rxTail + 1) % RX_RING_SIZE;
  return b;
}

// ---- RCB4コマンドのLEN/CMD/チェックサム表示用パーサ ----
// ../../atom/atoms3_rcb4_adapter/ と同じ考え方(表示専用、中継処理には
// 影響しない)。ただしこちらはRadxaからの書き込み(I2C onReceive)を
// 直接1トランザクション=1フレームとして扱える(atoms3_rcb4_adapterの
// ようにUSBバイト列を1バイトずつ状態機械で追う必要が無い)。
static uint8_t lastLen = 0;
static uint8_t lastCmd = 0;
static bool lastChecksumOk = true;
static bool lenCmdDirty = true;

void checkRcb4Frame(const uint8_t *buf, int n) {
  if (n < 3) {
    lastLen = (n > 0) ? buf[0] : 0;
    lastCmd = (n > 1) ? buf[1] : 0;
    lastChecksumOk = false;  // LEN・CMD・checksumの最低3バイトすら無い
    lenCmdDirty = true;
    return;
  }
  lastLen = buf[0];
  lastCmd = buf[1];
  uint16_t sum = 0;
  int total = min((int)lastLen, n);
  for (int i = 0; i < total - 1; i++) sum += buf[i];
  uint8_t expect = (uint8_t)(sum & 0xff);
  lastChecksumOk = (total == lastLen) && (buf[total - 1] == expect);
  lenCmdDirty = true;
}

// ---- I2Cコールバック ----
volatile uint32_t lastActivityMs = 0;
// bool(false初期値)だと、setup()のM5.begin()に数百ms掛かることが多いため、
// loop()の初回呼び出し時点で既にactiveがfalseになっていて「初回から変化
// なし」と判定され、RCB4:ラベル・インジケータが一度も描画されないまま
// 通信が起きるまで見えなくなるバグがあった(実機確認)。-1は
// true/falseどちらとも一致しないため、初回は必ず描画される。
static int lastActiveShown = -1;

void onI2CReceive(int numBytes) {
  uint8_t buf[255];
  int n = 0;
  while (Wire.available() && n < (int)sizeof(buf)) {
    buf[n++] = Wire.read();
  }
  while (Wire.available()) Wire.read();  // 想定外に多い場合の読み捨て
  if (n > 0) {
    checkRcb4Frame(buf, n);
    RCB4Serial.write(buf, n);
    lastActivityMs = millis();
  }
}

void onI2CRequest() {
  uint8_t out[FIXED_READ_LEN];
  int n = 0;
  while (rxRingCount() > 0 && n < FIXED_READ_LEN - 1) {
    out[1 + n] = rxRingPop();
    n++;
  }
  out[0] = (uint8_t)n;
  for (int i = 1 + n; i < FIXED_READ_LEN; i++) out[i] = 0;
  Wire.write(out, FIXED_READ_LEN);
  if (n > 0) lastActivityMs = millis();
}

// ---- 画面レイアウト ----
static const int STATUS_Y = 90;

void drawStaticHeader() {
  display.fillScreen(TFT_BLACK);

  display.setTextSize(3);
  display.setTextColor(TFT_YELLOW, TFT_BLACK);
  display.setCursor(2, 0);
  display.println("RCB4");

  display.setTextSize(2);
  display.setTextColor(TFT_WHITE, TFT_BLACK);
  display.setCursor(2, 26);
  display.println("I2C(Radxa)");
  display.println("G1,G2");
  display.setTextColor(TFT_CYAN, TFT_BLACK);
  display.println("-> RCB4");
  display.setTextColor(TFT_WHITE, TFT_BLACK);
  display.println("G6,G5");
}

void updateStatusDisplay() {
  bool active = (millis() - lastActivityMs) < 200;
  if ((int)active != lastActiveShown) {
    display.setTextSize(2);
    display.setCursor(2, STATUS_Y);
    display.setTextColor(TFT_WHITE, TFT_BLACK);
    display.print("RCB4:");
    display.fillRect(66, STATUS_Y + 2, 14, 14, active ? TFT_GREEN : TFT_DARKGREY);
    lastActiveShown = (int)active;
  }

  if (lenCmdDirty) {
    display.setTextSize(2);
    display.setCursor(2, STATUS_Y + 20);
    if (lastChecksumOk) {
      display.setTextColor(TFT_WHITE, TFT_BLACK);
      display.print("L=");
      display.setTextColor(TFT_GREENYELLOW, TFT_BLACK);
      display.printf("%-3d", lastLen);
      display.setTextColor(TFT_WHITE, TFT_BLACK);
      display.print("C=");
      display.setTextColor(TFT_ORANGE, TFT_BLACK);
      display.printf("%-3d", lastCmd);
    } else {
      display.setTextColor(TFT_RED, TFT_BLACK);
      display.printf("L=%-3dC=%-3d", lastLen, lastCmd);
    }
    lenCmdDirty = false;
  }
}

void setup() {
  auto cfg = M5.config();
  M5.begin(cfg);
  drawStaticHeader();

  beginRcb4Serial();

  Wire.setBufferSize(256);  // RCB4フレーム最大255byteを1トランザクションで受けるため(既定128byteでは不足)
  Wire.begin(I2C_SLAVE_ADDR, RADXA_SDA_PIN, RADXA_SCL_PIN, I2C_FREQ);
  Wire.onReceive(onI2CReceive);
  Wire.onRequest(onI2CRequest);
}

void loop() {
  uint8_t buf[256];
  int n = 0;
  while (RCB4Serial.available() && n < (int)sizeof(buf)) {
    buf[n++] = RCB4Serial.read();
  }
  for (int i = 0; i < n; i++) rxRingPush(buf[i]);

  updateStatusDisplay();
}
