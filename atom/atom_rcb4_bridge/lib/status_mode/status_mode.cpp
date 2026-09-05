#include "status_mode.h"

#include <M5Unified.h>
#include <net.h>
#include <string.h>

void StatusMode::enter() {
    last_draw_ms_ = 0;  // draw at once rather than after the first interval
    showing_qr_ = false;
    drawn_url_ = "";
    qr_dirty_ = true;
    setup_len_ = 0;
}

void StatusMode::onClick() {
    showing_qr_ = !showing_qr_;
    last_draw_ms_ = 0;
    qr_dirty_ = true;
}

void StatusMode::readSetup() {
    while (Serial.available()) {
        const char c = static_cast<char>(Serial.read());
        if (c == '\n' || c == '\r') {
            setup_line_[setup_len_] = '\0';
            if (setup_len_ > 0 && !net::handleSetupLine(setup_line_, Serial)) {
                Serial.println("ERR expected: net <ssid>TAB<password>, net?, net!");
            }
            setup_len_ = 0;
            continue;
        }
        if (setup_len_ + 1 >= sizeof(setup_line_)) {
            setup_len_ = 0;  // nothing this long is one of these commands
            continue;
        }
        setup_line_[setup_len_++] = c;
    }
}

namespace {

const char* statusText(net::Status status) {
    switch (status) {
        case net::Status::UNCONFIGURED: return "no wifi set";
        case net::Status::CONNECTING: return "connecting";
        case net::Status::CONNECTED: return "connected";
        case net::Status::FAILED: return "wifi failed";
    }
    return "?";
}

}  // namespace

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
        M5.Display.printf("%s\n", statusText(net::status()));
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
    readSetup();

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
    M5.Display.printf("%s\n", statusText(net::status()));
    if (net::status() == net::Status::CONNECTED) {
        M5.Display.printf("%s\n", net::ip().toString().c_str());
    }
    M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);
    M5.Display.printf("heap %uk\n", ESP.getFreeHeap() / 1024);
    M5.Display.println("click: QR");
    M5.Display.endWrite();
}
