// M5Stack FIRE を、近藤科学 RCB4-mini 用の「USB Dual Adapter」の
// WiFi/UDP版にするスケッチ。
//
// PC (atominterface.l/rcb4interface.l) <--WiFi/UDP--> FIRE <--UART(Port C, 反転)--> RCB4-mini
//
// ../atoms3_rcb4_adapter/atoms3_rcb4_adapter.ino(USB版、AtomS3専用)を
// 見本にしているが、中継の単位がバイト列(USB-CDCはストリーム)ではなく
// UDPデータグラム(メッセージ単位)である点が本質的に違う。RCB4のコマンド
// フレームは [LEN][CMD]...[checksum] で、rcb4interface.l側の
// uart-interface/udp-interface はどちらも「1回のwrite = 1個の完全な
// フレーム」を前提にしている(rcb4interface.l:write は1回の:write-dataで
// メッセージ全体を渡す)ので、PC側から届く1個のUDPパケット =
// ちょうど1個の完全なRCB4コマンドフレームになる。USB版のような
// バイト単位のフレーム再構成(feedFrameParser)は不要で、
// 受信したパケットをそのままRCB4へ書き、RCB4からの応答フレームを
// LENバイトぶんだけ読み切ってから1個のUDPパケットとして送り返せばよい
// (rcb4interface.l側のudp-interface:read-dataがまさにこの「1回のrecvで
// 1個のフレーム全体を受け取る」という前提で実装されている。1バイトずつ
// recvするとUDPはメッセージ境界を超えて残りを捨ててしまうため、これを
// 逆にすると壊れる -- uart.lのudp-interfaceにある通り実機で確認済みの
// 制約)。
//
// IMU予約OPCODE(0x90)は他のブリッジ(atoms3_rcb4_adapter.ino、
// ../s3_echo_bridge/atoms3_simple_robot/)と同一プロトコルで用意しているが、
// このFIRE個体のIMU取り付け向き補正(IMU_Y_SIGN/IMU_Z_SIGN相当)は
// 未計測(実機確認前のプレースホルダ、恒等変換)。まず動かしてから
// atoms3_rcb4_adapter.ino同様、実機のIMU_Y_SIGN的な符号合わせを行うこと。
//
// 対象ボード: M5Stack FIRE (M5Stack Core + PSRAM/9軸IMU/スピーカー版)。
// ほかのCore系(Core2/CoreS3等)でもPort Cのピン番号さえ合っていれば
// 動くはずだが、このピン番号(G16/G17)はFIRE(無印Core系)のもの。
// Arduino IDE設定:
//   - Board: "M5Stack-Fire"
//   - Upload Speed: 921600 (FIREはUSBシリアル変換チップ経由なので
//     AtomS3のようなネイティブUSB-CDCではない)

#include <HardwareSerial.h>
#include <M5Unified.h>
#include <WiFi.h>
#include <WiFiUdp.h>

// ---- WiFi設定(まず動かすための決め打ち。書き込み前に書き換えること) ----
// atom_phone/atom_common/lib/net(NVS保存+captive portal設定画面)ほどの
// 仕組みはまだ無い、一番簡単な決め打ち版。同じような設定画面が要るなら
// 別途相談。
static const char *WIFI_SSID = "CHANGE_ME_SSID";
static const char *WIFI_PASSWORD = "CHANGE_ME_PASSWORD";

// UDPの待受ポート。rcb4interface.l側の既定 (:com-init :udp-host ...
// の :udp-port キーワードの既定値2000、uart.lのudp-interface参照)と
// 揃えてある。変える場合は両方合わせて変えること。
static const uint16_t UDP_PORT = 2000;

// ---- 実機で確認すること: Port C のピン番号 ----
// M5Stack FIRE(Core系)のGroveポート規約でPort C = UART2 (RXD2=G16,
// TXD2=G17)。Port A=I2C(G21/G22, M5StickV接続に使用), Port B=GPIO
// (G36/G26) とは別。
static const int RCB4_RX_PIN = 16;  // FIRE Port C RXD2 <- RCB4-mini Tx
static const int RCB4_TX_PIN = 17;  // FIRE Port C TXD2 -> RCB4-mini Rx

// kxreus (rcb4interface.l) の既定の高速モードと同じ 1.25Mbps, 8bit,
// Even, 1stop。ロボット側を低速(:slow)設定で使っている場合は115200に
// 変更する。
static const uint32_t RCB4_BAUD = 1250000;

// RCB4-miniはUART信号が反転している(HeartToHeart4/USB Dual Adapterと
// 同じ規約)。atoms3_rcb4_adapter.ino自身のコメントにある通り、
// HardwareSerial::begin()のinvert引数はESP32-S3では不安定だったため
// uart_set_line_inverse()を後から呼ぶ回避策が要ったが、FIREは無印ESP32
// (S3ではない)なので、まずinvert引数をそのまま試す。もし実機で信号が
// 反転していない(RCB4が応答しない)場合は、begin()後に
// uart_set_line_inverse(UART_NUM_2, true) を呼ぶ形に変更すること。
HardwareSerial RCB4Serial(2);  // UART2をRCB4-mini用に使う(Port Cの実体)

WiFiUDP udp;

// ---- IMU予約OPCODE(0x90)。atoms3_rcb4_adapter.ino/atoms3_i2c_robot.ino
// と同一プロトコル ----
static const uint8_t IMU_OPCODE = 0x90;
static const uint8_t IMU_REQUEST[3] = {0x03, IMU_OPCODE, 0x93};

// このFIRE個体のIMU取り付け向き補正。atoms3_rcb4_adapter.ino同様の
// 符号反転(90度の軸入れ替えではなく180度の符号反転)を想定した作りに
// してあるが、値そのものは未計測(恒等 = 補正なし)。実機で
// atominterface.lの:timer-onを使い、姿勢表示がおかしければ
// atoms3_rcb4_adapter.ino本体のコメントにある調べ方(Madgwick
// シミュレーションで実機の生値と突き合わせる)で決め直すこと。
static const int IMU_Y_SIGN = 1;
static const int IMU_Z_SIGN = 1;

// ---- 画面表示 ----
static uint32_t lastActivityMs = 0;
static int lastActiveShown = -1;
static IPAddress myIp;

void drawStaticHeader() {
  M5.Display.fillScreen(TFT_BLACK);
  M5.Display.setTextSize(3);
  M5.Display.setTextColor(TFT_YELLOW, TFT_BLACK);
  M5.Display.setCursor(2, 0);
  M5.Display.println("RCB4/UDP");
  M5.Display.setTextSize(2);
  M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);
  M5.Display.setCursor(2, 30);
  M5.Display.println("Grove PortC");
  M5.Display.println("GND,RX,TX2");
}

void drawWifiStatus(bool connected) {
  M5.Display.setTextSize(2);
  M5.Display.setCursor(2, 90);
  M5.Display.setTextColor(connected ? TFT_GREEN : TFT_RED, TFT_BLACK);
  if (connected) {
    M5.Display.printf("%s:%u    ", myIp.toString().c_str(), UDP_PORT);
  } else {
    M5.Display.print("connecting...    ");
  }
}

void updateActivityIndicator() {
  bool active = (millis() - lastActivityMs) < 200;
  if ((int)active == lastActiveShown) return;
  lastActiveShown = (int)active;
  M5.Display.setTextSize(2);
  M5.Display.setCursor(2, 116);
  M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);
  M5.Display.print("RCB4:");
  M5.Display.fillRect(66, 118, 14, 14, active ? TFT_GREEN : TFT_DARKGREY);
}

// IMU予約OPCODEの応答フレームを組み立てて、直前にリクエストを送ってきた
// UDP相手へ返す(atoms3_rcb4_adapter.ino::sendImuReply と同一フォーマット)。
void sendImuReply(IPAddress replyIp, uint16_t replyPort) {
  m5::imu_data_t data = {};
  if (M5.Imu.isEnabled()) {
    M5.Imu.update();
    data = M5.Imu.getImuData();
  }
  int16_t ax = (int16_t)lroundf(data.accel.x * 1000.0f);  // milli-g
  int16_t ay = (int16_t)lroundf(IMU_Y_SIGN * data.accel.y * 1000.0f);
  int16_t az = (int16_t)lroundf(IMU_Z_SIGN * data.accel.z * 1000.0f);
  int16_t gx = (int16_t)lroundf(data.gyro.x * 10.0f);          // 0.1 deg/s
  int16_t gy = (int16_t)lroundf(IMU_Y_SIGN * data.gyro.y * 10.0f);
  int16_t gz = (int16_t)lroundf(IMU_Z_SIGN * data.gyro.z * 10.0f);

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

  udp.beginPacket(replyIp, replyPort);
  udp.write(frame, sizeof(frame));
  udp.endPacket();
  lastActivityMs = millis();
}

// RCB4からの応答フレームを1個分(先頭バイト=LEN、LENバイト丁度)読み切る。
// 読み切れなかった分は timeout_ms 経過で諦めて、そこまでに読めた分だけを
// 返す(0 = 応答なし)。USB版と違い、これは「1回のUDPパケット =
// 1個の完全なフレーム」で送り返す前提の下請けなので、途中で諦めた場合も
// 半端なフレームをそのまま送り返す(呼び出し側でn==0の時だけ送らない)。
int readRcb4Response(uint8_t *buf, int maxlen, uint32_t timeout_ms) {
  uint32_t deadline = millis() + timeout_ms;
  int n = 0;
  int total = -1;
  while ((int32_t)(millis() - deadline) < 0) {
    if (RCB4Serial.available()) {
      buf[n++] = RCB4Serial.read();
      if (n == 1) total = buf[0];
      if (total > 0 && n >= total) break;
      if (n >= maxlen) break;
    }
  }
  return n;
}

void setup() {
  auto cfg = M5.config();
  M5.begin(cfg);
  drawStaticHeader();

  RCB4Serial.begin(RCB4_BAUD, SERIAL_8E1, RCB4_RX_PIN, RCB4_TX_PIN, /*invert=*/true);

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  drawWifiStatus(false);
  while (WiFi.status() != WL_CONNECTED) {
    delay(200);
  }
  myIp = WiFi.localIP();
  drawWifiStatus(true);
  udp.begin(UDP_PORT);
}

void loop() {
  M5.update();

  int packetSize = udp.parsePacket();
  if (packetSize > 0) {
    uint8_t buf[256];
    int n = udp.read(buf, sizeof(buf));
    IPAddress fromIp = udp.remoteIP();
    uint16_t fromPort = udp.remotePort();
    lastActivityMs = millis();

    if (n == 3 && memcmp(buf, IMU_REQUEST, 3) == 0) {
      // IMU予約OPCODEはRCB4へ転送せず、この場で横取りして返す。
      sendImuReply(fromIp, fromPort);
    } else if (n > 0) {
      // 1個のUDPパケット = 1個の完全なRCB4コマンドフレーム(uart-interface/
      // udp-interfaceどちらもrcb4interface.l:writeが1回で1メッセージぶんを
      // 渡す設計なので、届いたバイト列をそのままRCB4へ書けばよい --
      // USB版のfeedFrameParserのようなバイト列再構成は不要)。
      RCB4Serial.write(buf, n);

      uint8_t resp[256];
      int rn = readRcb4Response(resp, sizeof(resp), 300);
      if (rn > 0) {
        udp.beginPacket(fromIp, fromPort);
        udp.write(resp, rn);
        udp.endPacket();
      }
      lastActivityMs = millis();
    }
  }

  updateActivityIndicator();
}
