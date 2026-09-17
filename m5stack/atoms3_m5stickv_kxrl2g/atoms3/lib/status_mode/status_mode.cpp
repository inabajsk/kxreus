#include "status_mode.h"

#include <M5Unified.h>
#include <net.h>
#include <string.h>

void StatusMode::enter() {
    last_draw_ms_ = 0;  // draw at once rather than after the first interval
    showing_qr_ = false;
    drawn_url_ = "";
    qr_dirty_ = true;
    // apriltag_en (bit 3) of the M5StickV's own control register (reg 0x00)
    // -- off by default on that side (object_detection_I2C_slave.py never
    // sets it on its own), so nothing runs find_apriltags() at all, and
    // reg 0x01/0x02.. simply stay empty, until a host turns it on. This is
    // the only mode that does so on its own rather than waiting for one of
    // BridgeMode's relayed 0x91 requests, since STATUS is the one screen
    // meant to be looked at without any host attached. Ignored if nothing
    // answers at that address -- see drawAprilTag()'s own "not found" case.
    link_.writeM5StickVReg(Rcb4Link::M5STICKV_DEFAULT_ADDR, 0x00, 0x08);
}

void StatusMode::exit() {
    link_.writeM5StickVReg(Rcb4Link::M5STICKV_DEFAULT_ADDR, 0x00, 0x00);
}

void StatusMode::onClick() {
    showing_qr_ = !showing_qr_;
    last_draw_ms_ = 0;
    qr_dirty_ = true;
}

void StatusMode::onDoubleClick() {
    if (net::provisioning() || net::status() == net::Status::STANDALONE_AP) {
        net::stopProvisioning();
    } else {
        net::beginProvisioning();
    }
    // The AP's own name is what a phone with nothing else to go on needs to
    // see, not the QR (there is no address yet to encode).
    showing_qr_ = false;
    last_draw_ms_ = 0;
    qr_dirty_ = true;
}

void StatusMode::drawQr() {
    const String url = net::url();
    // Rendering a QR is not free, so redraw only on a change -- but "the URL
    // is the same" must not swallow the first draw, which is what an empty
    // URL against an empty last-drawn value used to do.
    if (!qr_dirty_ && url == drawn_url_) return;
    qr_dirty_ = false;
    drawn_url_ = url;

    if (url.length() == 0) {
        M5.Display.clear();
        M5.Display.setCursor(0, 0);
        M5.Display.setTextSize(2);
        M5.Display.println("QR");
        M5.Display.setTextSize(1);
        M5.Display.setTextColor(TFT_YELLOW, TFT_BLACK);
        M5.Display.printf("%s\n", net::statusLabel(net::status()));
        M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);
        if (net::ssid()[0] != '\0') {
            M5.Display.printf("\n%s\n", net::ssid());
        }
        M5.Display.println("\nNo address, so\nno QR yet.\n");
        M5.Display.println("tools/wifi_setup.py\n  --show");
        return;
    }
    // White ground and the full panel: a phone camera wants quiet margins
    // more than it wants a label.
    M5.Display.fillScreen(TFT_WHITE);
    const int side = min(M5.Display.width(), M5.Display.height());
    constexpr int kMargin = 6;
    M5.Display.qrcode(url.c_str(), (M5.Display.width() - side) / 2 + kMargin,
                      (M5.Display.height() - side) / 2 + kMargin,
                      side - kMargin * 2, /*version=*/3);
}

void StatusMode::loop() {
    // The Wi-Fi setup text protocol used to be read here (Serial only, and
    // only reachable in this one mode) -- now HostRelay reads it from every
    // mode uniformly (Serial and ESP-NOW alike, gated on the same "net"
    // prefix BridgeMode's own version always required), so this mode no
    // longer needs its own copy.

    const uint32_t now = millis();
    if (now - last_draw_ms_ < REDRAW_INTERVAL_MS) return;
    last_draw_ms_ = now;

    if (showing_qr_) {
        static net::Status last = net::Status::UNCONFIGURED;
        if (net::status() != last) {
            last = net::status();
            qr_dirty_ = true;
        }
        drawQr();
        return;
    }
    drawInfo();
}

void StatusMode::drawInfo() {
    if (net::provisioning()) {
        // Nothing else on this screen matters while the phone still has no
        // way to reach the robot at all -- this is the one thing to read.
        M5.Display.startWrite();
        M5.Display.clear();
        M5.Display.setCursor(0, 0);
        M5.Display.setTextSize(2);
        M5.Display.println("WIFI SETUP");
        M5.Display.setTextSize(1);
        M5.Display.println("\non your phone,\njoin wifi:\n");
        M5.Display.setTextColor(TFT_CYAN, TFT_BLACK);
        M5.Display.println(ROBOT_NAME "-wifi");
        M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);
        M5.Display.println("\n(no password)\n\nthen open the\npage that pops up\n"
                           "(or 192.168.4.1)");
        M5.Display.println("\ndblclick: cancel");
        M5.Display.endWrite();
        return;
    }
    m5::imu_data_t imu = {};
    const bool has_imu = M5.Imu.isEnabled();
    if (has_imu) {
        M5.Imu.update();
        imu = M5.Imu.getImuData();
    }

    M5.Display.startWrite();
    M5.Display.clear();
    M5.Display.setCursor(0, 0);
    M5.Display.setTextSize(2);
    M5.Display.println("STATUS");
    M5.Display.setTextSize(1);
    M5.Display.setTextColor(TFT_DARKGREY, TFT_BLACK);
    M5.Display.println(ROBOT_NAME);
    M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);
    M5.Display.println("relay stopped");
    M5.Display.printf("to board %lu\n", link_.bytesToBoard());
    M5.Display.printf("to host  %lu\n", link_.bytesToHost());
    M5.Display.printf("imu req  %lu\n", link_.imuRequests());
    if (has_imu) {
        M5.Display.printf("a %+.2f %+.2f %+.2f\n", imu.accel.x, imu.accel.y,
                          imu.accel.z);
        M5.Display.printf("g %+.1f %+.1f %+.1f\n", imu.gyro.x, imu.gyro.y,
                          imu.gyro.z);
    } else {
        M5.Display.println("IMU NOT FOUND");
    }
    M5.Display.setTextColor(TFT_CYAN, TFT_BLACK);
    M5.Display.printf("%s\n", net::statusLabel(net::status()));
    if (net::status() == net::Status::CONNECTED ||
        net::status() == net::Status::STANDALONE_AP) {
        M5.Display.printf("%s\n", net::ip().toString().c_str());
    }
    M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);
    M5.Display.printf("heap %uk\n", ESP.getFreeHeap() / 1024);
    M5.Display.println("click: QR");
    M5.Display.println("dblclick: wifi setup");
    drawAprilTag();
    M5.Display.endWrite();
}

void StatusMode::drawAprilTag() {
    M5.Display.println();
    M5.Display.setTextColor(TFT_YELLOW, TFT_BLACK);
    M5.Display.println("M5StickV (AprilTag)");
    M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);

    // The control register (reg 0x00) this same enter() writes apriltag_en
    // into -- read back and shown rather than assumed, since a host talking
    // over the relayed 0x91 protocol (or the phone page) can turn any of
    // these bits on/off independently of what this mode itself asked for,
    // and the one thing worth showing at a glance is what is ACTUALLY
    // running right now, not what STATUS requested on entry.
    uint8_t ctrl = 0;
    const bool ctrl_ok =
            link_.readM5StickVReg(Rcb4Link::M5STICKV_DEFAULT_ADDR, 0x00, &ctrl);
    if (ctrl_ok) {
        auto flag = [&](const char* label, uint8_t bit) {
            M5.Display.setTextColor((ctrl & bit) ? TFT_GREEN : TFT_DARKGREY,
                                    TFT_BLACK);
            M5.Display.printf("%s ", label);
        };
        flag("NN", 1 << 2);
        flag("AT", 1 << 3);
        flag("RD", 1 << 4);
        flag("GR", 1 << 5);
        M5.Display.println();
        M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);
    }

    uint8_t buf[Rcb4Link::M5STICKV_MAX_READ];
    uint8_t len = 0;
    const bool ok =
            link_.readM5StickV(Rcb4Link::M5STICKV_DEFAULT_ADDR, buf, &len);
    if (!ok) {
        M5.Display.println("not found");
        return;
    }

    // Parse concatenated detection records looking for the first AprilTag
    // one -- see rcb4_link.h's own M5STICKV_OPCODE comment for the register
    // map and object_detection_I2C_slave.py's own TYPE_NN/TYPE_APRILTAG/
    // color constants for these sizes and the byte layout below. Other
    // record types are skipped by their own size so a layout mismatch
    // cannot walk this past the end of a shorter record.
    constexpr uint8_t kTypeApriltag = 1;
    constexpr float kQqvgaScale = 400.0f;  // object_detection_I2C_slave.py's QQVGA_SCALE
    size_t i = 0;
    bool found = false;
    while (i < len) {
        const uint8_t type = buf[i];
        size_t record_size;
        switch (type) {
            case 0: record_size = 11; break;          // NN
            case kTypeApriltag: record_size = 20; break;
            case 2:
            case 3: record_size = 9; break;            // red/green blob
            default: record_size = 0; break;           // unrecognised; stop
        }
        if (record_size == 0 || i + record_size > len) break;
        if (type == kTypeApriltag) {
            const auto word = [&](size_t off) -> int16_t {
                return static_cast<int16_t>(buf[i + off] |
                                            (buf[i + off + 1] << 8));
            };
            const int16_t tag_id = word(17);
            const uint8_t confidence = buf[i + 19];
            // Center as corner0/corner2's midpoint (opposite corners of the
            // quad) rather than averaging all four -- cheaper, and close
            // enough for a status line.
            const float cx = (word(1) + word(9)) / 2.0f / kQqvgaScale;
            const float cy = (word(3) + word(11)) / 2.0f / kQqvgaScale;
            M5.Display.printf("id %d  conf %u\n", tag_id, confidence);
            M5.Display.printf("at (%.0f, %.0f)\n", cx, cy);
            found = true;
            break;
        }
        i += record_size;
    }
    if (!found) M5.Display.println("no tag in view");
}
