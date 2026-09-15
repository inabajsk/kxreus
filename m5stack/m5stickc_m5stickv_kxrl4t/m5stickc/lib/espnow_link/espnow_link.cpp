#include "espnow_link.h"

#include <esp_now.h>
#include <esp_wifi.h>
#include <string.h>

#include "pc_mac.h"

namespace EspNowLink {
namespace {

/// Matches net.cpp's own WiFi.softAP() default channel -- see espnow_link.h's
/// own top comment for why this is a fixed constant rather than something
/// read back from the WiFi stack.
constexpr uint8_t CHANNEL = 1;
constexpr size_t MAX_CHUNK = 240;
constexpr uint32_t HEARTBEAT_MS = 300;
constexpr uint32_t LINK_TIMEOUT_MS = 1000;
constexpr uint32_t ACK_TIMEOUT_MS = 25;
constexpr int ACK_MAX_RETRY = 30;

constexpr uint8_t PKT_DATA = 0x01;
constexpr uint8_t PKT_PING = 0x02;
constexpr uint8_t PKT_PONG = 0x03;
constexpr uint8_t PKT_DATA_ACK = 0x04;

uint8_t g_peer_mac[6] = PC_MAC_BYTES;

/// Single-producer (the ESP-NOW receive callback, running in the WiFi
/// task's own context, asynchronous to loop()) / single-consumer (read(),
/// called from loop()) ring buffer -- the same shape any Arduino UART
/// driver's own RX ring already is. Sized for several PKT_DATA chunks
/// (240 bytes each) to be in flight before loop() gets back around to
/// draining it.
constexpr size_t RX_BUF_SIZE = 1024;
volatile uint8_t g_rx_buf[RX_BUF_SIZE];
volatile size_t g_rx_head = 0;  // next write index
volatile size_t g_rx_tail = 0;  // next read index

void rxPush(const uint8_t* data, size_t len) {
    for (size_t i = 0; i < len; i++) {
        const size_t next = (g_rx_head + 1) % RX_BUF_SIZE;
        if (next == g_rx_tail) break;  // full: drop rather than clobber unread data
        g_rx_buf[g_rx_head] = data[i];
        g_rx_head = next;
    }
}

volatile uint32_t g_last_recv_ms = 0;
uint32_t g_last_send_activity_ms = 0;
/// Updated only by real PKT_DATA traffic (not the PKT_PING/PONG heartbeat)
/// in either direction -- see isDataActive()'s own comment.
volatile uint32_t g_last_data_ms = 0;

// ---- PKT_DATA's own seq+ACK retry state -- see espnow_link.h's top
// comment for why the physical layer's own retry is not enough on its
// own. ----
uint8_t g_tx_seq = 0;
int32_t g_last_processed_seq = -1;
volatile uint8_t g_last_acked_seq = 0xFF;
volatile bool g_have_ack = false;

void onDataRecv(const uint8_t* mac_addr, const uint8_t* data, int len) {
    if (!mac_addr || memcmp(mac_addr, g_peer_mac, 6) != 0) return;
    g_last_recv_ms = millis();
    if (len < 1) return;

    if (data[0] == PKT_DATA && len > 2) {
        const uint8_t seq = data[1];
        g_last_data_ms = g_last_recv_ms;
        // Ack on receipt, even a duplicate resend -- the sender is waiting
        // on exactly this, not on whether the data was new.
        uint8_t ack[2] = {PKT_DATA_ACK, seq};
        esp_now_send(g_peer_mac, ack, 2);
        if (static_cast<int32_t>(seq) != g_last_processed_seq) {
            rxPush(data + 2, static_cast<size_t>(len - 2));
            g_last_processed_seq = seq;
        }
    } else if (data[0] == PKT_DATA_ACK && len == 2) {
        g_last_acked_seq = data[1];
        g_have_ack = true;
    } else if (data[0] == PKT_PING && len == 5) {
        uint8_t pong[5];
        pong[0] = PKT_PONG;
        memcpy(pong + 1, data + 1, 4);
        esp_now_send(g_peer_mac, pong, 5);
    }
}

void onDataSent(const uint8_t*, esp_now_send_status_t) {}

}  // namespace

void begin() {
    esp_now_init();
    esp_now_register_send_cb(onDataSent);
    esp_now_register_recv_cb(onDataRecv);

    esp_now_peer_info_t peer = {};
    memcpy(peer.peer_addr, g_peer_mac, 6);
    peer.channel = CHANNEL;
    peer.encrypt = false;
    // esp_now_peer_info_t::ifidx defaults (zero-initialised) to
    // WIFI_IF_STA -- wrong for this robot, whose only WiFi mode so far is
    // WIFI_AP (net.cpp's own STANDALONE_AP/provisioning): with no STA
    // interface actually up, packets addressed to that interface cannot go
    // out. esp_now_add_peer() itself reports success either way, which is
    // why this was easy to miss. If this robot ever also runs WIFI_AP_STA
    // or plain WIFI_STA, this constant would need to follow WiFi.getMode()
    // instead of being fixed.
    peer.ifidx = WIFI_IF_AP;
    esp_now_add_peer(&peer);
}

void poll() {
    if (millis() - g_last_send_activity_ms > HEARTBEAT_MS) {
        uint8_t packet[5];
        packet[0] = PKT_PING;
        const uint32_t now = millis();
        memcpy(packet + 1, &now, 4);
        esp_now_send(g_peer_mac, packet, sizeof(packet));
        g_last_send_activity_ms = millis();
    }
}

bool isLinkUp() { return millis() - g_last_recv_ms < LINK_TIMEOUT_MS; }

bool isDataActive() {
    // A short window: this is "is a frame actually going through right
    // now", for a status lamp to distinguish from "linked but idle" --
    // not itself a timeout for anything.
    constexpr uint32_t DATA_ACTIVE_MS = 400;
    return millis() - g_last_data_ms < DATA_ACTIVE_MS;
}

int available() {
    return static_cast<int>((g_rx_head + RX_BUF_SIZE - g_rx_tail) % RX_BUF_SIZE);
}

int read() {
    if (g_rx_tail == g_rx_head) return -1;
    const uint8_t b = g_rx_buf[g_rx_tail];
    g_rx_tail = (g_rx_tail + 1) % RX_BUF_SIZE;
    return b;
}

void write(const uint8_t* data, size_t len) {
    size_t offset = 0;
    while (offset < len) {
        const size_t n = min(MAX_CHUNK, len - offset);
        uint8_t packet[2 + MAX_CHUNK];
        const uint8_t seq = g_tx_seq;
        packet[0] = PKT_DATA;
        packet[1] = seq;
        memcpy(packet + 2, data + offset, n);

        bool acked = false;
        for (int attempt = 0; attempt < ACK_MAX_RETRY && !acked; attempt++) {
            g_have_ack = false;
            esp_now_send(g_peer_mac, packet, n + 2);
            const uint32_t wait_start = millis();
            while (millis() - wait_start < ACK_TIMEOUT_MS) {
                if (g_have_ack && g_last_acked_seq == seq) {
                    acked = true;
                    break;
                }
                delay(1);
            }
        }
        // ACK_MAX_RETRY exhausted: move on rather than block forever -- a
        // dropped chunk is more recoverable than a permanently stuck relay.
        g_tx_seq = static_cast<uint8_t>(g_tx_seq + 1);
        offset += n;
    }
    g_last_send_activity_ms = millis();
    g_last_data_ms = g_last_send_activity_ms;
}

}  // namespace EspNowLink
