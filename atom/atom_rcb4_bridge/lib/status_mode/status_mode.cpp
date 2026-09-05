#include "status_mode.h"

#include <M5Unified.h>

void StatusMode::enter() {
    last_draw_ms_ = 0;  // draw at once rather than after the first interval
}

void StatusMode::loop() {
    const uint32_t now = millis();
    if (now - last_draw_ms_ < REDRAW_INTERVAL_MS) return;
    last_draw_ms_ = now;

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
    M5.Display.endWrite();
}
