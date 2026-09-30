// RCB4無線ブリッジ ATOM S3 ファームウェア(WiFi captive portal版)。
//
// ../../../radxa/atoms3_radxa_setup/atoms3_radxa_setup.ino のcaptive portal
// +QR表示の仕組みをベースに、「Radxa ZeroへWiFi情報を中継する」役割ではなく
// AtomS3自身がそのWiFiへ接続し、RCB4との通信をTCPで直接公開する構成にした
// もの。ESP-NOW/ATOM Echoは使わない(PC側ペアリング不要)。
//
// 【全体の流れ】
//   1. 起動時にSoftAP+captive portalを立て、液晶にQRコードを表示する。
//      スマホでQRを撮ると、まずこのAtomS3自身のSoftAPに接続され、captive
//      portal検知でポータル画面が自動的に開く。
//   2. ポータルで選んだ実WiFiのSSID/パスワードで、AtomS3自身がWiFi.begin()
//      してSTAとして接続する(SoftAPは維持したまま、AP+STA同時動作)。
//   3. 接続成功したら、液晶にIPアドレスとTCPポート番号を表示する。
//   4. PC側は`socat TCP:<IP>:<PORT> PTY,link=/dev/ttyKXR0`等でこのIPの
//      TCPポートへ繋ぐと、/dev/ttyKXR0がRCB4の生シリアルポートであるかの
//      ように振る舞う(euslisp側は変更不要)。AtomS3はTCPクライアントとの
//      生バイトを、そのままRCB4向けUARTへ中継する透過ブリッジとして動く。
//      ただしRCB4の未使用オペコード(0x90、IMU読み出し)だけは、実RCB4へ
//      転送せずAtomS3が横取りして応答する(下記【IMU予約OPCODEプロトコル】)。
//      この横取りはRCB4の通常フレーミング([length,opcode,...,checksum])に
//      従っているだけなので、PC側からは通常のRCB4応答と区別が付かず、
//      透過ブリッジの前提を壊さない。
//
// 【ピン配置】
//   RCB4 UART: G2(TX)/G1(RX)、1.25Mbps, 8E1, 論理反転。Grove(HY2.0-4P)コネクタ
//     (../../s3_echo_bridge/atoms3_simple_robot/と同一配線)。
//   内蔵IMU(MPU6886): G38(SDA)/G39(SCL)。
//   LCD: 内蔵、QR/状態表示用。
//
// 【IMU予約OPCODEプロトコル】(../../s3_echo_with_I2C/, ../../s3_echo_bridge/と共通)
//   リクエスト: [0x03, 0x90, 0x93]
//   応答: [0x0F, 0x90, ax,ay,az(各int16LE, milli-g), gx,gy,gz(各int16LE, 0.1deg/s), checksum]

#include <WiFi.h>
#include <DNSServer.h>
#include <WebServer.h>
#include <M5Unified.h>
#include "driver/uart.h"
#include "driver/gpio.h"
#include "qrcode.h"

// Arduinoの自動プロトタイプ生成は#include直後にまとめて挿入されるため、
// カスタム型を関数の戻り値に使う場合は、その型定義を先にここへ置く必要が
// ある(そうしないと生成されたプロトタイプの時点で型が未定義になり
// "does not name a type" でビルドが失敗する。他構成の.inoと同じ注意点)。
enum Rcb4Status { RCB4_IDLE, RCB4_OK, RCB4_NG };

static auto &display = M5.Display;

// ---- RCB4リンク状態(液晶表示用)。feedClientByte()/handleBridge()より前に
// 宣言する必要がある(そちらで参照するため)。----
static const uint32_t RCB4_IDLE_TIMEOUT_MS = 3000;
static const uint32_t RCB4_REPLY_TIMEOUT_MS = 1000;
volatile uint32_t lastRcb4TxMillis = 0;
uint32_t lastRcb4RxMillis = 0;
Rcb4Status rcb4Status() {
  uint32_t now = millis();
  if (now - lastRcb4TxMillis > RCB4_IDLE_TIMEOUT_MS) return RCB4_IDLE;
  if (lastRcb4RxMillis >= lastRcb4TxMillis) return RCB4_OK;
  if (now - lastRcb4TxMillis > RCB4_REPLY_TIMEOUT_MS) return RCB4_NG;
  return RCB4_OK;
}

// ---- RCB4 UART (s3_echo_bridge/atoms3_simple_robot.ino と同一配線・設定) ----
static const int RCB4_TX_PIN = 2;
static const int RCB4_RX_PIN = 1;
static const uint32_t RCB4_BAUD = 1250000;
static const uart_port_t RCB4_UART_NUM = UART_NUM_1;
static const size_t RCB4_RX_BUFFER_SIZE = 4096;
HardwareSerial RCB4Serial(1);

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

// ---- IMU予約OPCODE(0x90) ----
static const uint8_t IMU_OPCODE = 0x90;
static const uint8_t IMU_REQUEST[3] = {0x03, IMU_OPCODE, 0x93};
volatile bool imuRequestPending = false;

// ---- TCPブリッジ ----
// PCからの生RCB4フレーム([length,opcode,...,checksum])を受信するたびに、
// IMU予約OPCODEかどうかだけ判定して横取りし、それ以外は素通しでRCB4Serialへ
// 書く。長さバイトで区切りが明確なため、AtomS3側からの応答(RCB4からの
// 応答・IMU合成応答)をそのままTCPへ書き戻すだけで透過ブリッジとして動く。
static const uint16_t BRIDGE_PORT = 4000;
WiFiServer bridgeServer(BRIDGE_PORT);
WiFiClient bridgeClient;

enum FrameState { FRAME_WAIT_LEN, FRAME_WAIT_BODY };
FrameState frameState = FRAME_WAIT_LEN;
uint8_t frameBuf[256];
uint8_t frameLen = 0;
uint8_t frameIdx = 0;
uint32_t frameStartMillis = 0;
// 長さバイトだけを頼りに区切っているため、何らかの理由(クライアント側の
// 実装不備によるフレーム境界のズレ等)で一度ズレると、自力では二度と正しい
// 境界に戻れず、以降ずっと無応答になる不具合が実機で確認された(2026.9)。
// フレーム途中で一定時間バイトが来なければ強制的にFRAME_WAIT_LENへ戻し、
// 次に届くバイトを新しいフレームの長さとして再解釈することで自己復帰する。
static const uint32_t FRAME_TIMEOUT_MS = 200;

void feedClientByte(uint8_t b) {
  if (frameState == FRAME_WAIT_LEN) {
    frameLen = b;
    frameBuf[0] = b;
    frameIdx = 1;
    frameStartMillis = millis();
    if (frameLen <= 1) {
      // 長さ1以下は本来あり得ないフレームだが、判断せずそのままRCB4へ流す
      // (実RCB4側で弾かれるのに任せ、ブリッジ側では余計な検証をしない)。
      RCB4Serial.write(frameBuf, frameIdx);
      lastRcb4TxMillis = millis();
      frameState = FRAME_WAIT_LEN;
      return;
    }
    frameState = FRAME_WAIT_BODY;
  } else {
    frameBuf[frameIdx++] = b;
    if (frameIdx >= frameLen) {
      if (frameLen == 3 && memcmp(frameBuf, IMU_REQUEST, 3) == 0) {
        imuRequestPending = true;
      } else if (frameLen >= 2 && frameBuf[1] == IMU_OPCODE) {
        // フレーム境界がズレた場合等、長さ・内容が完全一致しなくても
        // オペコードバイトがIMU予約OPCODE(0x90)なら実RCB4には絶対に
        // 転送しない(実RCB4はこのオペコードを理解できず、誤動作の原因に
        // なりうるため)。想定外の形なので単に捨てる。
      } else {
        RCB4Serial.write(frameBuf, frameLen);
        lastRcb4TxMillis = millis();
      }
      frameState = FRAME_WAIT_LEN;
    }
  }
}

void handleBridge() {
  if (bridgeServer.hasClient()) {
    // 既存の接続が生きている間は新規接続を拒否する。以前は無条件で古い
    // 接続を切って新しい方を受け入れていたが、それだと(誤って別プロセスが
    // 一時的に繋いだだけでも)正規のクライアントの接続が問答無用で奪われ、
    // socat側もそれを検知して終了し、euslisp側のブロッキングreadが
    // 応答不能になる、という事故が実機で起きた(2026.9)。既存接続が
    // 本当に切れている場合だけ、新しい接続を受け入れて引き継ぐ。
    WiFiClient incoming = bridgeServer.available();
    if (bridgeClient && bridgeClient.connected()) {
      incoming.stop();
    } else {
      bridgeClient = incoming;
      frameState = FRAME_WAIT_LEN;  // 接続が変わったらフレーム状態もリセット
    }
  }

  if (frameState == FRAME_WAIT_BODY && millis() - frameStartMillis > FRAME_TIMEOUT_MS) {
    frameState = FRAME_WAIT_LEN;  // フレーム境界がズレた場合の自己復帰
  }

  if (bridgeClient && bridgeClient.connected()) {
    while (bridgeClient.available()) {
      feedClientByte((uint8_t)bridgeClient.read());
    }
  }

  // RCB4からの応答は、クライアントが繋がっていればそのまま転送。繋がって
  // いなければ読み捨てる(バッファ溢れ防止)。
  while (RCB4Serial.available()) {
    uint8_t b = (uint8_t)RCB4Serial.read();
    lastRcb4RxMillis = millis();
    if (bridgeClient && bridgeClient.connected()) {
      bridgeClient.write(b);
    }
  }
}

void sendImuReply() {
  m5::imu_data_t data = {};
  if (M5.Imu.isEnabled()) {
    M5.Imu.update();
    data = M5.Imu.getImuData();
  }
  int16_t ax = (int16_t)lroundf(data.accel.x * 1000.0f);
  int16_t ay = (int16_t)lroundf(data.accel.y * 1000.0f);
  int16_t az = (int16_t)lroundf(data.accel.z * 1000.0f);
  int16_t gx = (int16_t)lroundf(data.gyro.x * 10.0f);
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

  if (bridgeClient && bridgeClient.connected()) {
    bridgeClient.write(frame, sizeof(frame));
  }
}

// ---- WiFi SoftAP + captive portal + 実WiFi接続 ----

// QRコードはAlphanumericモード対応文字(数字/大文字/記号)だけで組み立てる。
// 理由は../../../radxa/atoms3_radxa_setup/atoms3_radxa_setup.ino参照
// (小さい液晶でも読み取りやすいQRバージョンに収めるため)。
static const char RANDCHARS[] = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
String randomToken(int len) {
  String s;
  for (int i = 0; i < len; i++) {
    s += RANDCHARS[esp_random() % (sizeof(RANDCHARS) - 1)];
  }
  return s;
}

String apSsid;
String apPassword;
IPAddress apIP(192, 168, 4, 1);
DNSServer dnsServer;
WebServer server(80);
String portalHtml;

enum SetupState { STATE_SHOW_QR, STATE_CONNECTING, STATE_CONNECTED, STATE_FAILED };
SetupState setupState = STATE_SHOW_QR;
SetupState lastDrawnState = (SetupState)-1;
String connectedIp;
String failReason;
uint32_t connectingSince = 0;
uint32_t failedScreenSince = 0;
static const uint32_t CONNECTING_TIMEOUT_MS = 20000;
static const uint32_t FAILED_SCREEN_HOLD_MS = 6000;
// 接続済み(STATE_CONNECTED)からボタン長押しでQR画面(再設定モード)へ入った
// ことを示すフラグ。このモード中はSTA接続を切らずに維持したままにしておき、
// QR画面表示中に短押しされたら何もせず元の接続状態(STATE_CONNECTED)へ
// キャンセル復帰できるようにする(実際にポータルでSSID/PWが送信された
// 時だけWiFi.begin()で本当に繋ぎ変える。handleSave()参照)。
bool reconfiguring = false;

void qrDisplayCallback(esp_qrcode_handle_t qrcode) {
  int size = esp_qrcode_get_size(qrcode);
  display.fillScreen(TFT_WHITE);
  int scale = min(display.width(), display.height()) / (size + 2);
  if (scale < 1) scale = 1;
  int qrPixelSize = size * scale;
  int ox = (display.width() - qrPixelSize) / 2;
  int oy = (display.height() - qrPixelSize) / 2;
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      if (esp_qrcode_get_module(qrcode, x, y)) {
        display.fillRect(ox + x * scale, oy + y * scale, scale, scale, TFT_BLACK);
      }
    }
  }
}

void drawQRCode(const String &text) {
  esp_qrcode_config_t cfg = ESP_QRCODE_CONFIG_DEFAULT();
  cfg.display_func = qrDisplayCallback;
  cfg.qrcode_ecc_level = ESP_QRCODE_ECC_LOW;
  esp_qrcode_generate(&cfg, text.c_str());
}

void drawRcb4StatusLine() {
  Rcb4Status st = rcb4Status();
  display.setTextSize(1);
  display.setCursor(1, display.height() - 9);
  switch (st) {
    case RCB4_OK: display.setTextColor(TFT_GREEN, TFT_BLACK); display.print("RCB4 OK"); break;
    case RCB4_NG: display.setTextColor(TFT_RED, TFT_BLACK); display.print("RCB4 NG"); break;
    default: display.setTextColor(TFT_DARKGREY, TFT_BLACK); display.print("RCB4 --"); break;
  }
}

void drawConnectingScreen() {
  display.fillScreen(TFT_BLACK);
  display.setTextColor(TFT_WHITE, TFT_BLACK);
  display.setTextSize(1.3);
  display.setCursor(2, display.height() / 2 - 16);
  display.println("WiFi接続中...");
  drawRcb4StatusLine();
}

void drawConnectedScreen() {
  display.fillScreen(TFT_BLACK);
  display.setTextColor(TFT_GREEN, TFT_BLACK);
  display.setTextSize(1.4);
  display.setCursor(2, 8);
  display.println("接続成功");
  display.setTextColor(TFT_WHITE, TFT_BLACK);
  display.setTextSize(1.1);
  display.setCursor(2, 40);
  display.println(connectedIp);
  display.printf("port %u\n", BRIDGE_PORT);
  drawRcb4StatusLine();
}

void drawFailedScreen() {
  display.fillScreen(TFT_BLACK);
  display.setTextColor(TFT_RED, TFT_BLACK);
  display.setTextSize(1.4);
  display.setCursor(2, 8);
  display.println("接続失敗");
  display.setTextColor(TFT_WHITE, TFT_BLACK);
  display.setTextSize(1.0);
  display.setCursor(2, 40);
  display.println(failReason);
  drawRcb4StatusLine();
}

uint32_t lastStatusDrawMillis = 0;
void updateScreen() {
  bool stateChanged = (setupState != lastDrawnState);
  if (stateChanged) {
    switch (setupState) {
      case STATE_SHOW_QR: {
        String joinString = "WIFI:T:WPA;S:" + apSsid + ";P:" + apPassword + ";;";
        drawQRCode(joinString);
        break;
      }
      case STATE_CONNECTING: drawConnectingScreen(); break;
      case STATE_CONNECTED: drawConnectedScreen(); break;
      case STATE_FAILED: drawFailedScreen(); break;
    }
    lastDrawnState = setupState;
    lastStatusDrawMillis = millis();
    return;
  }
  if (setupState != STATE_SHOW_QR && millis() - lastStatusDrawMillis > 1000) {
    drawRcb4StatusLine();
    lastStatusDrawMillis = millis();
  }
  if (setupState == STATE_FAILED && millis() - failedScreenSince > FAILED_SCREEN_HOLD_MS) {
    setupState = STATE_SHOW_QR;
  }
  if (setupState == STATE_CONNECTING) {
    if (WiFi.status() == WL_CONNECTED) {
      connectedIp = WiFi.localIP().toString();
      setupState = STATE_CONNECTED;
    } else if (millis() - connectingSince > CONNECTING_TIMEOUT_MS) {
      failReason = "接続タイムアウト(SSID/PW確認)";
      setupState = STATE_FAILED;
      failedScreenSince = millis();
      WiFi.disconnect();
    }
  }
}

String htmlEscape(const String &s) {
  String out;
  for (size_t i = 0; i < s.length(); i++) {
    char c = s[i];
    if (c == '&') out += "&amp;";
    else if (c == '"') out += "&quot;";
    else if (c == '<') out += "&lt;";
    else if (c == '>') out += "&gt;";
    else out += c;
  }
  return out;
}

void buildPortalHtml() {
  String options;
  int n = WiFi.scanNetworks();
  for (int i = 0; i < n; i++) {
    options += "<option value=\"" + htmlEscape(WiFi.SSID(i)) + "\">";
  }
  WiFi.scanDelete();

  portalHtml =
    "<!DOCTYPE html><html><head><meta charset=\"utf-8\">"
    "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
    "<title>KXR WiFi設定</title>"
    "<style>body{font-family:sans-serif;margin:20px;}"
    "input{width:100%;padding:8px;margin:6px 0;font-size:16px;box-sizing:border-box;}"
    "button{width:100%;padding:12px;font-size:16px;margin-top:10px;}</style>"
    "</head><body>"
    "<h3>AtomS3を接続するWiFiを設定してください</h3>"
    "<form method=\"POST\" action=\"/save\">"
    "<label>SSID</label>"
    "<input list=\"ssids\" name=\"ssid\" required>"
    "<datalist id=\"ssids\">" + options + "</datalist>"
    "<label>パスワード</label>"
    "<input type=\"password\" name=\"password\">"
    "<button type=\"submit\">接続する</button>"
    "</form></body></html>";
}

void handleRoot() {
  server.send(200, "text/html", portalHtml);
}

void handleSave() {
  String ssid = server.arg("ssid");
  String password = server.arg("password");

  WiFi.begin(ssid.c_str(), password.c_str());
  setupState = STATE_CONNECTING;
  connectingSince = millis();
  reconfiguring = false;  // 新しい接続先へ実際に切り替えるため、もう「キャンセルで元に戻す」対象ではない

  server.send(200, "text/html; charset=utf-8",
    "<!DOCTYPE html><html><head><meta charset=\"utf-8\">"
    "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"></head>"
    "<body style=\"font-family:sans-serif;margin:20px;\">"
    "<p>送信しました。AtomS3本体の液晶で接続結果を確認してください。</p>"
    "</body></html>");
}

void startSetupApAndPortal() {
  // ESP.getEfuseMac()はLSB側(mac&0xFF, (mac>>8)&0xFF, ...)がMAC表記の先頭
  // バイトから順に入っている。先頭3バイトはEspressifの共通OUI(実機確認:
  // 複数のAtomS3で"dc:54:75"が共通)のため、そこを使うと同じロットの機体
  // 同士でSoftAPのSSIDが衝突する(実機確認、2026.9)。個体ごとに異なる
  // 末尾2バイト((mac>>32)/(mac>>40)、表記上5,6バイト目)を使う。
  uint64_t mac = ESP.getEfuseMac();
  char suffix[5];
  snprintf(suffix, sizeof(suffix), "%02X%02X", (uint8_t)(mac >> 32), (uint8_t)(mac >> 40));
  apSsid = String("KXR-") + suffix;
  apPassword = randomToken(8);

  WiFi.mode(WIFI_AP_STA);
  buildPortalHtml();  // WIFI_AP_STAでSTA側スキャンしてからAPを起動する
  WiFi.softAPConfig(apIP, apIP, IPAddress(255, 255, 255, 0));
  WiFi.softAP(apSsid.c_str(), apPassword.c_str());

  dnsServer.start(53, "*", apIP);

  server.on("/", handleRoot);
  server.on("/generate_204", handleRoot);
  server.on("/gen_204", handleRoot);
  server.on("/hotspot-detect.html", handleRoot);
  server.on("/library/test/success.html", handleRoot);
  server.on("/ncsi.txt", handleRoot);
  server.on("/connecttest.txt", handleRoot);
  server.on("/fwlink", handleRoot);
  server.on("/save", HTTP_POST, handleSave);
  server.onNotFound(handleRoot);
  server.begin();
}

// ---- setup / loop ----

void setup() {
  Serial.begin(115200);  // デバッグ用(RCB4通信とは無関係。TCPブリッジがRCB4の通信経路)

  auto cfg = M5.config();
  M5.begin(cfg);
  if (display.width() < display.height()) {
    display.setRotation(display.getRotation() ^ 1);
  }
  // ロボットへの取り付けが上下逆さのため、表示も180度回転させる。
  display.setRotation((display.getRotation() + 2) % 4);

  beginRcb4Serial();
  startSetupApAndPortal();
  bridgeServer.begin();

  // 起動時、前回接続したWiFiの情報がNVSに残っていれば自動再接続を試みる
  // (WiFi.begin()を引数無しで呼ぶと、ESP32 Arduinoコアが保存済みのSSID/
  // パスワードを使う)。毎回QRを撮り直す必要が無いようにするため。
  // 【注意】WiFi.SSID()は「現在接続中のSSID」を返すため、この時点(まだ
  // 接続を試みる前、かつ直前のbuildPortalHtml()内scanNetworks()で一時的に
  // 未接続状態になっている)では保存済み設定があっても空文字列になり、
  // 事前チェックとして使えない(実機確認、2026.9)。そのため無条件で
  // WiFi.begin()を試みる。保存済み設定が無い場合はCONNECTING_TIMEOUT_MS後に
  // 失敗扱いとなり、通常通りQR画面へ自動的に戻る。
  WiFi.begin();
  setupState = STATE_CONNECTING;
  connectingSince = millis();
}

void loop() {
  M5.update();

  handleBridge();

  if (imuRequestPending) {
    imuRequestPending = false;
    sendImuReply();
  }

  dnsServer.processNextRequest();
  server.handleClient();

  updateScreen();

  // 接続成功後にボタン長押しで再設定モードへ(WiFi環境が変わった場合の再
  // セットアップ用)。STA接続はまだ切らない(キャンセル時にそのまま復帰
  // できるようにするため。実際に切り替わるのはhandleSave()でWiFi.begin()
  // が呼ばれた時)。
  if (M5.BtnA.wasHold() && setupState == STATE_CONNECTED) {
    reconfiguring = true;
    setupState = STATE_SHOW_QR;
    lastDrawnState = (SetupState)-1;
  }
  // 再設定モード中(QR画面表示中)の短押しでキャンセルし、元の接続状態へ戻す。
  if (M5.BtnA.wasClicked() && setupState == STATE_SHOW_QR && reconfiguring) {
    reconfiguring = false;
    setupState = STATE_CONNECTED;
    lastDrawnState = (SetupState)-1;
  }
}
