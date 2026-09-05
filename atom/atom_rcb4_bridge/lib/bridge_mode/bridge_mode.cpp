#include "bridge_mode.h"

#include <M5Unified.h>

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

    // Ask the board once, while the host is not yet talking. A relay on its
    // own cannot tell a silent board from a quiet one -- with nothing wired to
    // the COM port it passes bytes into the dark just the same -- so this is
    // the one moment the bridge can find out and say so.
    board_ok_ = link_.probeBoard();
    imu_ok_ = M5.Imu.isEnabled();
    drawLamp(BOARD_LAMP_Y, "RCB4", board_ok_);
    drawLamp(IMU_LAMP_Y, "IMU", imu_ok_);
}

void BridgeMode::loop() {
    while (Serial.available()) {
        if (link_.feedFromHost(static_cast<uint8_t>(Serial.read()))) {
            uint8_t frame[Rcb4Link::IMU_REPLY_SIZE];
            Rcb4Link::buildImuReply(frame);
            Serial.write(frame, sizeof(frame));
        }
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
