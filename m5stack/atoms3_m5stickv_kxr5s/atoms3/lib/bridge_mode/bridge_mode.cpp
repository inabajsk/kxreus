#include "bridge_mode.h"

#include <M5Unified.h>
#include <espnow_link.h>
#include <net.h>

namespace {

/// Draw a labelled lamp: green when the thing works, red when it does not.
///
/// Small on purpose -- text size 1, a 16 px row -- so the button legend
/// below (see BridgeMode::enter()'s own comments) can afford to be the
/// bigger, easier-to-read text instead: which gesture does what matters
/// more moment to moment than a label already said twice over by this
/// row's own colour.
void drawLamp(int y, const char* label, bool ok) {
    M5.Display.fillRect(0, y, M5.Display.width(), 16, TFT_BLACK);
    M5.Display.fillRoundRect(4, y + 2, 12, 12, 3, ok ? TFT_GREEN : TFT_RED);
    M5.Display.setTextSize(1);
    M5.Display.setCursor(22, y + 4);
    M5.Display.print(label);
}

/// Same shape as drawLamp(), but three states rather than two: a PC-side
/// ATOM Echo (see EspNowLink) can be absent, linked but idle, or actively
/// exchanging a frame right now, and only the first of those is really
/// "not working" -- the other two both mean the link itself is fine.
void drawEspNowLamp(int y, int state) {
    uint16_t color;
    const char* label;
    switch (state) {
        case 2:
            color = TFT_CYAN;
            label = "ECHO*";  // actively relaying a frame
            break;
        case 1:
            color = TFT_GREEN;
            label = "ECHO";  // linked, idle
            break;
        default:
            color = TFT_RED;
            label = "ECHO";  // not present
            break;
    }
    M5.Display.fillRect(0, y, M5.Display.width(), 16, TFT_BLACK);
    M5.Display.fillRoundRect(4, y + 2, 12, 12, 3, color);
    M5.Display.setTextSize(1);
    M5.Display.setCursor(22, y + 4);
    M5.Display.print(label);
}

/// "RCB4 1.25M" / "RCB4 625K" -- the RCB4 lamp's own label, with which of
/// Rcb4Link::BAUD/BAUD_FALLBACK is currently active appended so a fallback
/// (see Rcb4Link::probeBoardWithFallback()'s own comment) is visible, not
/// just the fact that the link is green.
const char* rcb4Label(const Rcb4Link& link) {
    return link.currentBaud() == Rcb4Link::BAUD ? "RCB4 1.25M" : "RCB4 625K";
}

/// "I2C 0x24 0x25" -- one M5StickV bus can carry two units at once (see
/// Rcb4Link::M5STICKV_DEFAULT_ADDR/M5STICKV_ALT_ADDR's own comment on the
/// stereo left/right-eye pair), so this checks for both rather than one
/// lamp speaking for a single assumed unit: each address's own text is
/// green if it answered, grey if not.
void drawI2cLamp(int y, bool ok_alt, bool ok_default) {
    M5.Display.fillRect(0, y, M5.Display.width(), 16, TFT_BLACK);
    M5.Display.fillRoundRect(4, y + 2, 12, 12, 3,
                             (ok_alt || ok_default) ? TFT_GREEN : TFT_RED);
    M5.Display.setTextSize(1);
    M5.Display.setCursor(22, y + 4);
    M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);
    M5.Display.print("I2C ");
    M5.Display.setTextColor(ok_alt ? TFT_GREEN : TFT_DARKGREY, TFT_BLACK);
    M5.Display.print("0x24");
    M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);
    M5.Display.print(" ");
    M5.Display.setTextColor(ok_default ? TFT_GREEN : TFT_DARKGREY, TFT_BLACK);
    M5.Display.print("0x25");
    // Restored, not left green/grey: every drawLamp() call after this one
    // prints with whatever colour is currently set (it does not set its
    // own), same as this function inherited TFT_WHITE from BridgeMode::
    // enter()'s own setTextColor() before touching it here.
    M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);
}

}  // namespace

void BridgeMode::enter() {
    M5.Display.clear();
    M5.Display.setCursor(0, 0);
    // The robot's own name, big, then the mode name small below it -- the
    // same split PolicyMode/StatusMode already use. "ROBOT_NAME-CAM" used
    // to be one size-2 line, which fit AtomS3's wider panel but not
    // M5StickC's own 80 px width: at size 2 even "kxrl4t-CAM" (10 chars,
    // ~120 px) ran off the edge, and the one word ("-CAM") that said BRIDGE
    // mode's own RCB-4 UART leaves Port A free for the M5StickV was
    // exactly the part cut off -- unreadable on the one build that most
    // needed the mode name legible to tell BRIDGE apart from STATUS/POLICY
    // at a glance.
    M5.Display.setTextSize(2);
    M5.Display.println(robotName());
    M5.Display.setTextSize(1);
    M5.Display.setTextColor(TFT_DARKGREY, TFT_BLACK);
    M5.Display.println(name());
    M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);

    // Only BRIDGE mode leaves the real RCB-4's own UART free for a host to
    // drive directly -- see Rcb4Link::setPassthroughEnabled's own comment
    // for why POLICY mode must not have this on.
    link_.setPassthroughEnabled(true);

    // Ask the board once, while the host is not yet talking. A relay on its
    // own cannot tell a silent board from a quiet one -- with nothing wired to
    // the COM port it passes bytes into the dark just the same -- so this is
    // the one moment the bridge can find out and say so.
    board_ok_ = link_.probeBoardWithFallback();
    imu_ok_ = M5.Imu.isEnabled();
    uint8_t unused = 0;
    i2c_ok_alt_ =
            link_.readM5StickVReg(Rcb4Link::M5STICKV_ALT_ADDR, 0x00, &unused);
    i2c_ok_default_ =
            link_.readM5StickVReg(Rcb4Link::M5STICKV_DEFAULT_ADDR, 0x00, &unused);
    drawLamp(BOARD_LAMP_Y, rcb4Label(link_), board_ok_);
    drawLamp(IMU_LAMP_Y, "IMU", imu_ok_);
    drawI2cLamp(I2C_LAMP_Y, i2c_ok_alt_, i2c_ok_default_);
    espnow_state_ = -1;  // force the ESP-NOW lamp's first paint too
    phone_ok_ = net::phoneActive();
    drawLamp(PHONE_LAMP_Y, "PHONE", phone_ok_);

    // What each gesture does, since there is no other label on any of them
    // -- the same reasoning PolicyMode::draw() already gives its own
    // button legend. Size 1, not 2: even the shortest of these three
    // ("x3=wifi", 7 chars) is 84 px at size 2, past M5StickC's own 80 px
    // width -- the same fit problem the title just above had.
    M5.Display.setTextSize(1);
    M5.Display.setCursor(0, 104);
    M5.Display.setTextColor(TFT_DARKGREY, TFT_BLACK);
    M5.Display.println("clk=info");
    M5.Display.println("long=mode");
    M5.Display.println("x3=wifi");
}

void BridgeMode::exit() {
    // Leaving BRIDGE mode hands the real RCB-4's own UART to whatever the
    // next mode does with it (POLICY drives it directly) -- see
    // Rcb4Link::setPassthroughEnabled's own comment.
    link_.setPassthroughEnabled(false);
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

void BridgeMode::loop() {
    // The byte relay itself (Serial and ESP-NOW alike) now runs
    // unconditionally, from main.cpp, regardless of which mode is
    // current -- see HostRelay. This mode's own loop() only owns its
    // lamps and the RCB-4-alive probe below.

    if (millis() - last_espnow_draw_ms_ > ESPNOW_LAMP_INTERVAL_MS) {
        last_espnow_draw_ms_ = millis();
        const int state = !EspNowLink::isLinkUp() ? 0
                         : EspNowLink::isDataActive() ? 2
                         : 1;
        if (state != espnow_state_) {
            espnow_state_ = state;
            drawEspNowLamp(ESPNOW_LAMP_Y, espnow_state_);
        }
        const bool phone_now = net::phoneActive();
        if (phone_now != phone_ok_) {
            phone_ok_ = phone_now;
            drawLamp(PHONE_LAMP_Y, "PHONE", phone_ok_);
        }
    }

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
        const uint32_t baud_before = link_.currentBaud();
        const bool alive = link_.probeBoardWithFallback();
        if (alive != board_ok_ || link_.currentBaud() != baud_before) {
            board_ok_ = alive;
            // Redrawn only on a change: drawing costs milliseconds that a
            // control loop on the far side would feel.
            drawLamp(BOARD_LAMP_Y, rcb4Label(link_), board_ok_);
        }
    }
}
