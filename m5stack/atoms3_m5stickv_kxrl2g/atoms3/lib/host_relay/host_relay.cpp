#include "host_relay.h"

#include <espnow_link.h>
#include <net.h>

namespace HostRelay {
namespace {

/// Which transport a byte came in on -- and so which one its reply, if
/// any, goes back out on. Only one is ever mid-frame at a time in practice
/// (one controlling process at a time), so tracking "whichever host fed
/// the current byte" is enough; there is no need to demultiplex two
/// interleaved frames.
enum class HostSource : uint8_t { USB_SERIAL, ESP_NOW };

/// Whichever host relay() last ran for. Read when a real RCB-4 reply
/// arrives later, asynchronously, from pumpToHost() -- which has no host
/// of its own to ask -- to send it back the same way its request came in.
HostSource g_last_request_host = HostSource::USB_SERIAL;

char g_setup_line[96] = {0};
size_t g_setup_len = 0;
bool g_in_setup = false;

void sendToHost(const uint8_t* data, size_t len, HostSource source) {
    if (source == HostSource::ESP_NOW) {
        EspNowLink::write(data, len);
    } else {
        Serial.write(data, len);
    }
}

void relay(Rcb4Link& link, uint8_t byte, HostSource source) {
    switch (link.feedFromHost(byte)) {
        case Rcb4Link::Intercept::IMU: {
            uint8_t frame[Rcb4Link::IMU_REPLY_SIZE];
            Rcb4Link::buildImuReply(frame);
            sendToHost(frame, sizeof(frame), source);
            break;
        }
        case Rcb4Link::Intercept::M5STICKV: {
            uint8_t frame[Rcb4Link::M5STICKV_REPLY_CAPACITY];
            const size_t len = link.buildM5StickVReply(frame);
            sendToHost(frame, len, source);
            break;
        }
        case Rcb4Link::Intercept::NONE:
            break;
    }
    g_last_request_host = source;
}

void releaseSetup(Rcb4Link& link, HostSource source) {
    const size_t held = g_setup_len;
    g_in_setup = false;
    g_setup_len = 0;
    for (size_t i = 0; i < held; i++) {
        relay(link, static_cast<uint8_t>(g_setup_line[i]), source);
    }
}

/// Take a byte of the text setup protocol, if this is one -- Serial only
/// (see this file's own top comment). Mirrors BridgeMode's own former
/// feedSetup() exactly; see that history for the reasoning behind the
/// "net?"/"net!"/"net " prefix match.
bool feedSetup(Rcb4Link& link, uint8_t byte) {
    static const char* const kPrefix = "net";

    if (!g_in_setup) {
        if (byte != kPrefix[0] || link.midFrame()) return false;
        g_in_setup = true;
        g_setup_len = 0;
    } else if (g_setup_len < 3) {
        if (byte != kPrefix[g_setup_len]) {
            releaseSetup(link, HostSource::USB_SERIAL);
            relay(link, byte, HostSource::USB_SERIAL);
            return true;
        }
    } else if (g_setup_len == 3) {
        if (byte != '?' && byte != '!' && byte != ' ') {
            releaseSetup(link, HostSource::USB_SERIAL);
            relay(link, byte, HostSource::USB_SERIAL);
            return true;
        }
    }

    if (byte == '\n' || byte == '\r') {
        g_setup_line[g_setup_len] = '\0';
        g_in_setup = false;
        const size_t len = g_setup_len;
        g_setup_len = 0;
        if (len == 0) return true;

        if (!net::handleSetupLine(g_setup_line, Serial)) {
            Serial.println("ERR expected: net <ssid>TAB<password>, net?, net!");
        }
        return true;
    }
    if (g_setup_len + 1 >= sizeof(g_setup_line)) {
        releaseSetup(link, HostSource::USB_SERIAL);
        relay(link, byte, HostSource::USB_SERIAL);
        return true;
    }
    g_setup_line[g_setup_len++] = static_cast<char>(byte);
    return true;
}

}  // namespace

void loop(Rcb4Link& link) {
    while (Serial.available()) {
        const uint8_t byte = static_cast<uint8_t>(Serial.read());
        if (feedSetup(link, byte)) continue;
        relay(link, byte, HostSource::USB_SERIAL);
    }
    while (EspNowLink::available() > 0) {
        const uint8_t byte = static_cast<uint8_t>(EspNowLink::read());
        relay(link, byte, HostSource::ESP_NOW);
    }
    uint8_t from_board[256];
    const size_t n = link.pumpToHost(from_board, sizeof(from_board));
    if (n > 0) sendToHost(from_board, n, g_last_request_host);
}

}  // namespace HostRelay
