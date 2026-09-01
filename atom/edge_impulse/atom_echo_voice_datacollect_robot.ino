// ロボット背中側 ATOM Echo 用ファームウェア(Edge Impulse学習データ収集専用)。
//
// atom_echo_voice_cmd_robot.ino から自作の認識ロジック(DTWマッチング等)を
// 取り除き、代わりに「PC側から届いた1回分の発話を、そのまま生PCMデータとして
// デバッグ用USBシリアルにダンプするだけ」にしたもの。ホスト側の
// collect_edge_impulse_data.py がこれを受信してWAVファイルに保存し、
// Edge Impulse Studioへアップロードして本格的な学習(MFCC + 小型CNN)を行う。
//
// 【ラベルの選び方】ロボット側のデバッグ用USBシリアル(115200bps)に
// '0'〜'5' の数字を送ると、以後の発話がその番号のラベルとして記録され続ける
// (学習デモ版と違い、1回で自動解除されない。同じ単語を連続して何度も
// 録音できるようにするため)。
//   0=aisatsu(挨拶) 1=mae(前) 2=ushiro(後) 3=hidari(左) 4=migi(右)
//   5=noise(雑音/無関係な音。Edge Impulseの「unknown」クラス用)
//
// 【シリアルのフレーミング】人間可読なログと同じSerialに混在させるため、
// 0xAA 0x55 の同期バイト列 + ラベル(1byte) + サンプル数(uint16 LE) +
// 生PCM16(LE, リトルエンディアン)を送る。0xAA はASCII印字可能文字には
// 出現しないため、ログ文字列と衝突しない。

#include <esp_now.h>
#include <esp_wifi.h>
#include <WiFi.h>
#include <Adafruit_NeoPixel.h>
#include <ESP_I2S.h>

static const char *MY_NAME = "ECHO1-ROBOT";

// 相手(ECHO1-PC)のMACアドレス。esptool chip_id で確認したベースMAC。
static uint8_t PEER_MAC[6] = {0x64, 0xB7, 0x08, 0x8A, 0x24, 0xB4};

static const uint8_t WIFI_CHANNEL = 1;
static const size_t MAX_CHUNK = 240;
static const uint32_t HEARTBEAT_MS = 300;
static const uint32_t LINK_TIMEOUT_MS = 1000;

static const uint8_t PKT_DATA = 0x01;
static const uint8_t PKT_PING = 0x02;
static const uint8_t PKT_PONG = 0x03;
static const uint8_t PKT_VOICE_AUDIO = 0x0A;
static const uint8_t PKT_VOICE_END = 0x0B;

static const uint32_t AUDIO_SAMPLE_RATE = 8000;

// RCB4-mini 側 UART 設定(このファームウェアでは実際には使わないが、配線・
// 設定を他のバリアントと揃えておく)。
static const int RCB4_TX_PIN = 26;
static const int RCB4_RX_PIN = 32;
static const uint32_t RCB4_BAUD = 1250000;

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

void onDataSent(const wifi_tx_info_t *info, esp_now_send_status_t status) {
  if (status == ESP_NOW_SEND_SUCCESS) {
    lastAckMillis = millis();
  }
}

// ---- 音声コマンドの録音バッファ(ESP-NOW受信コールバックはここに積むだけ) ----

static const size_t VOICE_BUF_SAMPLES = 8000;  // 1.0秒 @ 8kHz
int16_t voiceBuf[VOICE_BUF_SAMPLES];
volatile size_t voiceBufLen = 0;
volatile bool voiceUtteranceReady = false;

void onDataRecv(const esp_now_recv_info_t *info, const uint8_t *data, int len) {
  if (!info->src_addr || memcmp(info->src_addr, PEER_MAC, 6) != 0) {
    return;
  }
  lastRecvMillis = millis();
  if (len < 1) return;

  if (data[0] == PKT_DATA && len > 1) {
    RCB4Serial.write(data + 1, len - 1);
  } else if (data[0] == PKT_PING && len == 5) {
    uint8_t pong[5];
    pong[0] = PKT_PONG;
    memcpy(pong + 1, data + 1, 4);
    esp_now_send(PEER_MAC, pong, 5);
  } else if (data[0] == PKT_VOICE_AUDIO && len > 1) {
    size_t n = (len - 1) / 2;
    for (size_t i = 0; i < n; i++) {
      if (voiceBufLen >= VOICE_BUF_SAMPLES) break;
      int16_t s = (int16_t)(data[1 + i * 2] | (data[1 + i * 2 + 1] << 8));
      voiceBuf[voiceBufLen++] = s;
    }
  } else if (data[0] == PKT_VOICE_END) {
    voiceUtteranceReady = true;
  }
}

bool isLinkUp() {
  uint32_t now = millis();
  return (now - lastRecvMillis < LINK_TIMEOUT_MS);
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

// ---- 音関連(チャイムのみ。データ収集自体には使わない) ----

void playTone(int freqHz, int durationMs, int amplitude = 6000) {
  const int sampleRate = 8000;
  audioI2S.end();
  audioI2S.setPins(I2S_BCLK, I2S_LRCK, I2S_DOUT);
  if (!audioI2S.begin(I2S_MODE_STD, sampleRate, I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_MONO)) {
    return;
  }
  int halfWave = sampleRate / freqHz / 2;
  if (halfWave < 1) halfWave = 1;
  int totalSamples = sampleRate * durationMs / 1000;
  int16_t sample = amplitude;
  for (int i = 0; i < totalSamples; i++) {
    if (i % halfWave == 0) sample = -sample;
    audioI2S.write((uint8_t)(sample & 0xFF));
    audioI2S.write((uint8_t)((sample >> 8) & 0xFF));
  }
  audioI2S.end();
}

void playMelodyRobot() {
  playTone(330, 120);
  delay(30);
  playTone(262, 160);
}

void playChimeConnected() {
  playTone(523, 80);
  delay(20);
  playTone(784, 120);
}

void playChimeDisconnected() {
  playTone(784, 80);
  delay(20);
  playTone(392, 160);
}

void playChimeCaptured() {
  playTone(1000, 50);
}

// ---- データ収集(ラベル付きの生PCMをSerialへフレーム化して送るだけ) ----

static const int NUM_LABELS = 6;
static const char *labelNames[NUM_LABELS] = {
  "aisatsu", "mae", "ushiro", "hidari", "migi", "noise"
};
int activeLabel = -1;  // -1 = 未設定(記録しない)

void dumpUtterance() {
  if (activeLabel < 0) {
    // 【2026.9】このSerialは(a)人間向けのデバッグ文字列と(b)0xAA 0x55マジック
    // バイトで始まる収集データの生バイナリの両方を流しており、他ファームで
    // 見つかったSerial共用による中継/プロトコル破壊バグと同じ構造を持つ。
    // ホスト側パーサがマジックバイト再同期に対応していない場合、この文字列が
    // 挟まると以降のフレームがずれる恐れがあるためコメントアウトする。
    // Serial.println("[collect] utterance captured but no label armed (send '0'-'5' first)");
    return;
  }
  uint16_t n = (uint16_t)voiceBufLen;
  Serial.write((uint8_t)0xAA);
  Serial.write((uint8_t)0x55);
  Serial.write((uint8_t)activeLabel);
  Serial.write((uint8_t)(n & 0xFF));
  Serial.write((uint8_t)((n >> 8) & 0xFF));
  Serial.write((const uint8_t *)voiceBuf, (size_t)n * 2);
  Serial.flush();
  playChimeCaptured();
}

void serviceLabelCommands() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c >= '0' && c <= '0' + NUM_LABELS - 1) {
      activeLabel = c - '0';
      // Serial.printf("[collect] active label -> %d (%s). Press PC button and speak to record.\n",
      //               activeLabel, labelNames[activeLabel]);
    }
  }
}

// ---- setup / loop ----

void setup() {
  Serial.begin(115200);  // データ収集・デバッグ用。RCB4通信には使わない

  pixel.begin();
  pixel.setPixelColor(0, pixel.Color(0, 0, 0));
  pixel.show();

  pinMode(PIN_BTN, INPUT);

  RCB4Serial.begin(RCB4_BAUD, SERIAL_8E1, RCB4_RX_PIN, RCB4_TX_PIN, /*invert=*/true);

  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  esp_wifi_set_channel(WIFI_CHANNEL, WIFI_SECOND_CHAN_NONE);
  esp_wifi_set_ps(WIFI_PS_NONE);

  initEspNow();

  playMelodyRobot();

  // Serial.println("[collect] ready. send '0'-'5' via Serial to set the active label, then press PC button and speak.");
  // Serial.println("[collect] labels: 0=aisatsu 1=mae 2=ushiro 3=hidari 4=migi 5=noise");
}

bool lastBtnState = HIGH;

void loop() {
  // ESP-NOW <-> RCB4 UART 中継(このファームウェアでは未使用だが配線確認用に残す)
  uint8_t buf[MAX_CHUNK];
  int n = 0;
  while (RCB4Serial.available() && n < (int)sizeof(buf)) {
    buf[n++] = RCB4Serial.read();
  }
  if (millis() - lastSendActivity > HEARTBEAT_MS) {
    sendPing();
  }

  // 音声データの処理(1発話分が届いたらSerialへダンプ)
  if (voiceUtteranceReady) {
    dumpUtterance();
    voiceUtteranceReady = false;
    voiceBufLen = 0;
  }

  serviceLabelCommands();

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

  bool btnState = digitalRead(PIN_BTN);
  if (btnState == LOW && lastBtnState == HIGH) {
    playMelodyRobot();
  }
  lastBtnState = btnState;
}
