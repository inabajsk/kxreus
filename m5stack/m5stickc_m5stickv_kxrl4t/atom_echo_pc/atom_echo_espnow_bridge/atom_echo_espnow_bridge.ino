// PC側 ATOM Echo 用ファームウェア(ESP-NOW版、RCB4中継専用)。
//
// ~/kxreus/atom/s3_echo_bridge/atom_echo_pc/atom_echo_voice_cmd_pc.ino の
// RCB4中継部分だけを取り出したもの(音声コマンド録音・認識トリガーは
// このロボット(kxrl4t、M5StickC)側には無いので削除)。プロトコル
// (PKT_DATA+seq+ACK、PKT_PING/PONGハートビート)はそちらと完全に同一 --
// 詳細な設計理由のコメントは元ファイル参照。
//
// 【役割】
// PC(kxreus/atominterface.l)とUSBシリアルで繋がるATOM Echo。PCがUSB
// シリアルへ送ったRCB4バイト列を、そのままESP-NOW経由でロボット側
// (M5StickC、m5stickc_m5stickv_kxrl4t/m5stickc/)へ転送し、応答も同じ経路
// でPCへ返す。ロボット側から見るとRCB4が直結されているのと同じに見える
// 透過ブリッジ -- ロボット側のBridgeMode::relay()がSerialとESP-NOWの
// どちらから来たバイトも同じように扱う(BridgeMode::HostSource参照)ので、
// このファームウェアの相手をUSBケーブルからこれに差し替えるだけで、
// atominterface.l側のコードは一切変更不要。

#include <esp_now.h>
#include <esp_wifi.h>
#include <WiFi.h>
#include <Adafruit_NeoPixel.h>

static const char *MY_NAME = "ECHO-KXRL4T-PC";

// 相手(ロボット側M5StickC)のMACアドレス。robot_mac.hはこのディレクトリの
// 隣、m5stickc/の get_pc_atom_echo_mac.sh から生成される(手動編集しない
// こと。詳細は../README.md参照)。
#include "robot_mac.h"
static uint8_t PEER_MAC[6] = ROBOT_MAC_BYTES;

static const uint8_t WIFI_CHANNEL = 1;
static const size_t MAX_CHUNK = 240;
static const uint32_t HEARTBEAT_MS = 300;
static const uint32_t LINK_TIMEOUT_MS = 1000;

static const uint8_t PKT_DATA = 0x01;
static const uint8_t PKT_PING = 0x02;
static const uint8_t PKT_PONG = 0x03;
static const uint8_t PKT_DATA_ACK = 0x04;  // PKT_DATA 1個分の受信確認応答

// RGB LED (SK6812, G27)
static const int PIN_LED = 27;
Adafruit_NeoPixel pixel(1, PIN_LED, NEO_GRB + NEO_KHZ800);

volatile uint32_t lastRecvMillis = 0;
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

// ---- setup / loop ----

void setup() {
  // ATOM EchoのUSBシリアルは(AtomS3のネイティブUSB-CDCと違い)本物のFTDIチップ経由の
  // UART配線のため、ホスト側が実際に設定するボーレートと一致していないと通信できない。
  // 実機検証の結果、この個体では500000/750000だけが確実に通信できた
  // (atom/s3_echo_bridge側の実機確認結果を流用)。
  Serial.begin(500000);

  pixel.begin();
  pixel.setPixelColor(0, pixel.Color(40, 0, 0));  // 起動直後はLINK NG(赤)から始める
  pixel.show();

  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  esp_wifi_set_channel(WIFI_CHANNEL, WIFI_SECOND_CHAN_NONE);
  esp_wifi_set_ps(WIFI_PS_NONE);

  initEspNow();
}

void loop() {
  // RCB4中継(PKT_DATA)を最優先。それ以外はハートビート。
  uint8_t buf[MAX_CHUNK];
  int n = 0;
  while (Serial.available() && n < (int)sizeof(buf)) {
    buf[n++] = Serial.read();
  }
  if (n > 0) {
    sendChunk(buf, n);
  } else if (millis() - lastSendActivity > HEARTBEAT_MS) {
    sendPing();
  }

  bool up = isLinkUp();
  if (up != lastLinkUp) {
    pixel.setPixelColor(0, up ? pixel.Color(0, 40, 0) : pixel.Color(40, 0, 0));
    pixel.show();
    lastLinkUp = up;
  }
}
