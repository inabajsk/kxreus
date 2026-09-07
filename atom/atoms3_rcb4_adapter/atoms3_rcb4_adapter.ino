// AtomS3 (ESP32-S3, USB-C, 液晶付き) を近藤科学 RCB4-mini 用の
// 「USB Dual Adapter」代替の反転UART-USBブリッジにするスケッチ。
// ../atom_rcb4_bridge/ (液晶なしATOM系でも動くバイト中継専用の素の版)を
// ベースに、液晶へ配線早見表・通信中インジケータ・RCB4コマンドのLEN/CMD/
// checksum検証結果を表示する機能を追加したAtomS3専用版。
//
// PC 側 USB-CDC (Serial) <---> AtomS3 <---> UART1 (信号反転, RCB4-mini側)
//
// 中継自体はバイト列をそのまま流すだけで、RCB4のコマンド解釈や
// チェックサム計算の結果をRCB4側への転送に反映することは一切ない
// (checksum検証は液晶表示のみに使う、副作用のない覗き見)。
// プロトコルの中身の処理はPC側(kxreus等)に任せる設計。
//
// 対象ボード: M5Stack AtomS3 / AtomS3 Lite / AtomS3R など、ESP32-S3 系で
//            USBネイティブCDCと液晶を持つATOMシリーズ限定
//            (液晶の無いプレーンなATOMには書き込めない。その場合は
//            ../atom_rcb4_bridge/atom_rcb4_bridge.ino を使うこと)。
// Arduino IDE 設定:
//   - Board: "M5AtomS3" (または該当機種。無ければ "ESP32S3 Dev Module" でも可)
//   - USB CDC On Boot: "Enabled"  (これが無いと Serial がUSB-CDCにならない)

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

static auto &display = M5.Display;

// ---- 画面レイアウト(単語の途中で改行しないよう、あらかじめ短い行に分けてある) ----
// 静止部分(setup()で一度だけ描画): タイトル+配線早見表。
// 可変部分(loop()で更新): 通信中インジケータ(■)とRCB4コマンドのLEN/CMD。
static const int STATUS_Y = 90;  // 可変部分の描画開始Y座標

void drawStaticHeader() {
  display.fillScreen(TFT_BLACK);

  display.setTextSize(3);
  display.setTextColor(TFT_YELLOW, TFT_BLACK);
  display.setCursor(2, 0);
  display.println("RCB4");

  display.setTextSize(2);
  display.setTextColor(TFT_WHITE, TFT_BLACK);
  display.setCursor(2, 26);
  display.println("Grove");
  display.println("GND,G1,G2");
  display.setTextColor(TFT_CYAN, TFT_BLACK);
  display.println("-> RCB4");
  display.setTextColor(TFT_WHITE, TFT_BLACK);
  display.println("GND,RX,TX2");
}

// ---- RCB4コマンドのLEN/CMD/チェックサム検査用パーサ(表示専用。中継処理自体には影響しない) ----
// RCB4のコマンド形式(PC -> RCB4方向、rcb4asm.lの rcb4-checksum と同じ計算式):
//   1バイト目      = LEN  … このフレーム全体のバイト数(LEN自身とchecksumも含む)
//   2バイト目      = CMD  … コマンド番号
//   3バイト目以降  = ボディ(あれば)
//   最後の1バイト  = checksum … 「LEN自身からchecksum直前まで」の総和の下位8bit
// 例: "03 FD 00"(バージョン問い合わせ) は LEN=3,CMD=0xFD,checksum=(3+0xFD)&0xff=0x00。
enum FrameState { FS_WAIT_LEN, FS_BODY };
static FrameState frameState = FS_WAIT_LEN;
static int frameTotal = 0;   // このフレームの総バイト数(=LEN)
static int consumed = 0;     // このフレームで既に消費したバイト数
static uint16_t runSum = 0;  // checksum直前までの総和
static uint8_t lastLen = 0;
static uint8_t lastCmd = 0;
static bool lastChecksumOk = true;  // false = RCB4コマンドフォーマット違反(checksum不一致 or LEN不正)
static bool lenCmdDirty = true;

static uint32_t lastActivityMs = 0;
// bool(false初期値)だと、setup()のM5.begin()に数百ms掛かることが多いため、
// loop()の初回呼び出し時点で既にactiveがfalseになっていて「初回から変化
// なし」と判定され、RCB4:ラベル・インジケータが一度も描画されないまま
// 通信が起きるまで見えなくなるバグがあった(実機確認)。-1は
// true/falseどちらとも一致しないため、初回は必ず描画される。
static int lastActiveShown = -1;

void feedFrameParser(const uint8_t *buf, int n) {
  for (int i = 0; i < n; i++) {
    uint8_t b = buf[i];

    if (frameState == FS_WAIT_LEN) {
      lastLen = b;
      frameTotal = b;
      consumed = 1;
      runSum = b;
      lenCmdDirty = true;
      if (frameTotal < 3) {
        // LEN・CMD・checksumの最低3バイトすら無く、この時点でフォーマット違反。
        // 1バイトだけでは再同期できないので、次のバイトを新しいLENとして扱う
        // (このフレームには乗らず、WAIT_LENのまま次バイトへ)。
        lastCmd = 0;
        lastChecksumOk = false;
        continue;
      }
      frameState = FS_BODY;
      continue;
    }

    // FS_BODY
    consumed++;
    if (consumed == 2) {
      lastCmd = b;
      runSum += b;
      lenCmdDirty = true;
    } else if (consumed < frameTotal) {
      runSum += b;
    } else {
      // consumed == frameTotal: このバイトがchecksum。
      uint8_t expect = (uint8_t)(runSum & 0xff);
      lastChecksumOk = (b == expect);
      lenCmdDirty = true;
      frameState = FS_WAIT_LEN;
    }
  }
}

void updateStatusDisplay() {
  bool active = (millis() - lastActivityMs) < 200;

  // 通信中インジケータ: 通信があれば緑、無ければ暗いグレーの■。
  // 状態が変わった時だけ描き直す(毎ループ描くとチラつく・SPIが遅くなる)。
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
      // checksum不一致(またはLEN<3の異常フレーム): フォーマット違反として全体を赤で表示。
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
    feedFrameParser(buf, n);
    RCB4Serial.write(buf, n);
    lastActivityMs = millis();
  }

  // RCB4 -> PC
  n = 0;
  while (RCB4Serial.available() && n < (int)sizeof(buf)) {
    buf[n++] = RCB4Serial.read();
  }
  if (n > 0) {
    Serial.write(buf, n);
    lastActivityMs = millis();
  }

  updateStatusDisplay();
}
