#include "bridge_mode.h"

#include <M5Unified.h>
#include <net.h>
#include <string.h>

namespace {

/// Draw a labelled lamp: green when the thing works, red when it does not.
void drawLamp(int y, const char* label, bool ok) {
    M5.Display.fillRect(0, y, M5.Display.width(), 22, TFT_BLACK);
    M5.Display.fillRoundRect(4, y + 3, 16, 16, 4, ok ? TFT_GREEN : TFT_RED);
    M5.Display.setTextSize(2);
    M5.Display.setCursor(26, y + 4);
    M5.Display.print(label);
}

}  // namespace

void BridgeMode::enter() {
    M5.Display.clear();
    M5.Display.setCursor(0, 0);
    M5.Display.setTextSize(2);
    M5.Display.println("BRIDGE");
    M5.Display.setTextSize(1);
    M5.Display.setTextColor(TFT_DARKGREY, TFT_BLACK);
    M5.Display.println(ROBOT_NAME);
    M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);
    M5.Display.setTextSize(2);

    // Ask the board once, while the host is not yet talking. A relay on its
    // own cannot tell a silent board from a quiet one -- with nothing wired to
    // the COM port it passes bytes into the dark just the same -- so this is
    // the one moment the bridge can find out and say so.
    board_ok_ = link_.probeBoard();
    imu_ok_ = M5.Imu.isEnabled();
    drawLamp(BOARD_LAMP_Y, "RCB4", board_ok_);
    drawLamp(IMU_LAMP_Y, "IMU", imu_ok_);
}

void BridgeMode::onClick() {
    // One screen, drawn on demand: the lamps are what this mode is for, and
    // the network is what someone asks about once, while setting it up.
    M5.Display.clear();
    M5.Display.setCursor(0, 0);
    M5.Display.setTextSize(1);
    switch (net::status()) {
        case net::Status::UNCONFIGURED:
            M5.Display.println("wifi not set\n\nrun\ntools/wifi_setup.py");
            break;
        case net::Status::CONNECTING:
            M5.Display.printf("connecting to\n%s\n", net::ssid());
            break;
        case net::Status::CONNECTED:
            M5.Display.printf("wifi ok\n%s\n%s\n", net::ssid(),
                              net::ip().toString().c_str());
            break;
        case net::Status::FAILED:
            M5.Display.printf("wifi FAILED\n%s\nretrying\n", net::ssid());
            break;
    }
    M5.Display.printf("heap %uk\n", ESP.getFreeHeap() / 1024);
    // Then back to the lamps, so the screen does not lie about the link once
    // someone stops looking at it.
    board_ok_ = !board_ok_;  // force both lamps to redraw
    enter();
}

void BridgeMode::relay(uint8_t byte) {
    if (link_.feedFromHost(byte)) {
        uint8_t frame[Rcb4Link::IMU_REPLY_SIZE];
        Rcb4Link::buildImuReply(frame);
        Serial.write(frame, sizeof(frame));
    }
}

void BridgeMode::releaseSetup() {
    const size_t held = setup_len_;
    in_setup_ = false;
    setup_len_ = 0;
    for (size_t i = 0; i < held; i++) {
        relay(static_cast<uint8_t>(setup_line_[i]));
    }
}

bool BridgeMode::feedSetup(uint8_t byte) {
    // The prefix that has to match before anything is treated as text. Four
    // bytes: three of "net" and the character that says which command it is.
    static const char* const kPrefix = "net";

    if (!in_setup_) {
        // Only at a frame boundary: mid-frame, every value is data.
        if (byte != kPrefix[0] || link_.midFrame()) return false;
        in_setup_ = true;
        setup_len_ = 0;
    } else if (setup_len_ < 3) {
        if (byte != kPrefix[setup_len_]) {
            // Not "net" after all. Give back what was held, then deal with
            // this byte as an ordinary one.
            releaseSetup();
            relay(byte);
            return true;
        }
    } else if (setup_len_ == 3) {
        if (byte != '?' && byte != '!' && byte != ' ') {
            releaseSetup();
            relay(byte);
            return true;
        }
    }

    if (byte == '\n' || byte == '\r') {
        setup_line_[setup_len_] = '\0';
        in_setup_ = false;
        const size_t len = setup_len_;
        setup_len_ = 0;
        if (len == 0) return true;

        if (!net::handleSetupLine(setup_line_, Serial)) {
            Serial.println("ERR expected: net <ssid>TAB<password>, net?, net!");
        }
        return true;
    }
    if (setup_len_ + 1 >= sizeof(setup_line_)) {
        // Too long to be a setup line; it was never one.
        releaseSetup();
        relay(byte);
        return true;
    }
    setup_line_[setup_len_++] = static_cast<char>(byte);
    return true;
}

void BridgeMode::loop() {
    while (Serial.available()) {
        const uint8_t byte = static_cast<uint8_t>(Serial.read());
        if (feedSetup(byte)) continue;
        relay(byte);
    }
    link_.pumpToHost();

    // Re-check the board, but only in a gap where the host is not talking:
    // probing sends a frame of our own, and injecting that into someone
    // else's exchange would corrupt it.
    //
    // The check has to be a real answer, not merely bytes arriving. With
    // nothing wired to the COM port the RX pin floats, and on an inverted
    // UART that noise turns into plausible-looking bytes -- an earlier
    // version of this lamp counted those and flickered green against a board
    // that was not there.
    const uint32_t now = millis();
    if (link_.sinceHostSpoke() > HOST_IDLE_MS &&
        now - last_probe_ms_ > PROBE_INTERVAL_MS) {
        last_probe_ms_ = now;
        const bool alive = link_.probeBoard();
        if (alive != board_ok_) {
            board_ok_ = alive;
            // Redrawn only on a change: drawing costs milliseconds that a
            // control loop on the far side would feel.
            drawLamp(BOARD_LAMP_Y, "RCB4", board_ok_);
        }
    }
}
