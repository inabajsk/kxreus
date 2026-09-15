// Diagnostic-only firmware for the PC-side ATOM Echo: prints every
// init/add_peer/send return code plus every packet seen from the robot
// (M5StickC), to Serial -- unlike atom_echo_espnow_bridge.ino, this one's
// Serial is free for debug output since it carries no RCB-4 traffic.
#include <esp_now.h>
#include <esp_wifi.h>
#include <WiFi.h>

#include "../atom_echo_espnow_bridge/robot_mac.h"

static const uint8_t WIFI_CHANNEL = 1;
static uint8_t PEER_MAC[6] = ROBOT_MAC_BYTES;

void onDataRecv(const esp_now_recv_info_t *info, const uint8_t *data, int len) {
  Serial.printf("[recv] from %02X:%02X:%02X:%02X:%02X:%02X len=%d type=0x%02X\n",
                info->src_addr[0], info->src_addr[1], info->src_addr[2],
                info->src_addr[3], info->src_addr[4], info->src_addr[5], len,
                len > 0 ? data[0] : 0);
}

void onDataSent(const wifi_tx_info_t *info, esp_now_send_status_t status) {
  Serial.printf("[sent] status=%d\n", (int)status);
}

void setup() {
  Serial.begin(115200);
  uint32_t deadline = millis() + 8000;
  while (!Serial && millis() < deadline) delay(10);
  delay(300);

  Serial.println("\n=== atom_echo_espnow_probe ===");
  Serial.printf("ROBOT_MAC_BYTES = %02X:%02X:%02X:%02X:%02X:%02X\n", PEER_MAC[0],
                PEER_MAC[1], PEER_MAC[2], PEER_MAC[3], PEER_MAC[4], PEER_MAC[5]);

  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  esp_err_t ch_err = esp_wifi_set_channel(WIFI_CHANNEL, WIFI_SECOND_CHAN_NONE);
  Serial.printf("esp_wifi_set_channel() = %d\n", (int)ch_err);
  esp_wifi_set_ps(WIFI_PS_NONE);
  delay(200);

  uint8_t primary;
  wifi_second_chan_t second;
  esp_wifi_get_channel(&primary, &second);
  Serial.printf("esp_wifi_get_channel() -> primary=%d\n", (int)primary);
  Serial.printf("WiFi macAddress() = %s\n", WiFi.macAddress().c_str());

  esp_err_t init_err = esp_now_init();
  Serial.printf("esp_now_init() = %d\n", (int)init_err);

  esp_now_register_send_cb(onDataSent);
  esp_now_register_recv_cb(onDataRecv);

  esp_now_peer_info_t peerInfo = {};
  memcpy(peerInfo.peer_addr, PEER_MAC, 6);
  peerInfo.channel = WIFI_CHANNEL;
  peerInfo.encrypt = false;
  esp_err_t add_err = esp_now_add_peer(&peerInfo);
  Serial.printf("esp_now_add_peer() = %d (ESP_OK=%d)\n", (int)add_err, (int)ESP_OK);

  Serial.println("Listening for ESP-NOW packets from the robot above ...");
}

void loop() {
  static uint32_t lastPing = 0;
  if (millis() - lastPing > 1000) {
    lastPing = millis();
    uint8_t packet[5] = {0x02, 0, 0, 0, 0};  // PKT_PING
    esp_err_t send_err = esp_now_send(PEER_MAC, packet, sizeof(packet));
    Serial.printf("[ping] esp_now_send() = %d\n", (int)send_err);
  }
  delay(50);
}
