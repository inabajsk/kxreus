// Diagnostic-only firmware: brings up WiFi exactly like net::begin() would
// (STANDALONE_AP, same SSID/channel), then ESP-NOW, and prints every
// init/add_peer return code plus every packet seen from the paired PC-side
// ATOM Echo -- unlike the real bridge, this build's Serial is free for
// debug output, since it never carries RCB-4 traffic.
#include <Arduino.h>
#include <M5Unified.h>
#include <WiFi.h>
#include <esp_now.h>
#include <esp_wifi.h>

#include "../lib/espnow_link/pc_mac.h"

namespace {
constexpr uint8_t CHANNEL = 1;
uint8_t peer_mac[6] = PC_MAC_BYTES;

void onRecv(const uint8_t* mac_addr, const uint8_t* data, int len) {
    Serial.printf("[recv] from %02X:%02X:%02X:%02X:%02X:%02X len=%d type=0x%02X\n",
                  mac_addr[0], mac_addr[1], mac_addr[2], mac_addr[3], mac_addr[4],
                  mac_addr[5], len, len > 0 ? data[0] : 0);
}

void onSent(const uint8_t* mac_addr, esp_now_send_status_t status) {
    Serial.printf("[sent] status=%d\n", (int)status);
}
}  // namespace

void setup() {
    Serial.begin(115200);
    const uint32_t deadline = millis() + 8000;
    while (!Serial && millis() < deadline) delay(10);
    delay(300);

    Serial.println("\n=== espnow_probe ===");
    Serial.printf("PC_MAC_BYTES = %02X:%02X:%02X:%02X:%02X:%02X\n", peer_mac[0],
                  peer_mac[1], peer_mac[2], peer_mac[3], peer_mac[4], peer_mac[5]);

    auto cfg = M5.config();
    M5.begin(cfg);

    WiFi.mode(WIFI_AP);
    const bool ap_ok = WiFi.softAP("espnow-probe-ap");
    Serial.printf("WiFi.softAP() = %s\n", ap_ok ? "OK" : "FAILED");
    delay(200);
    Serial.printf("WiFi.channel() = %d\n", WiFi.channel());
    Serial.printf("WiFi macAddress() = %s\n", WiFi.macAddress().c_str());

    const esp_err_t init_err = esp_now_init();
    Serial.printf("esp_now_init() = %d\n", (int)init_err);

    esp_now_register_recv_cb(onRecv);
    esp_now_register_send_cb(onSent);

    esp_now_peer_info_t peer = {};
    memcpy(peer.peer_addr, peer_mac, 6);
    peer.channel = CHANNEL;
    peer.encrypt = false;
    peer.ifidx = WIFI_IF_AP;
    const esp_err_t add_err = esp_now_add_peer(&peer);
    Serial.printf("esp_now_add_peer() = %d (ESP_OK=%d)\n", (int)add_err, (int)ESP_OK);

    Serial.println("Listening for ESP-NOW packets from the peer above ...");
}

void loop() {
    static uint32_t last_ping = 0;
    if (millis() - last_ping > 1000) {
        last_ping = millis();
        uint8_t packet[5] = {0x02, 0, 0, 0, 0};  // PKT_PING, dummy timestamp
        const esp_err_t send_err = esp_now_send(peer_mac, packet, sizeof(packet));
        Serial.printf("[ping] esp_now_send() = %d\n", (int)send_err);
    }
    delay(50);
}
