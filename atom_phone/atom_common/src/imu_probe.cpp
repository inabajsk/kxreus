// What the IMU actually is, and what it actually reports.
//
// The bridge answers opcode 0x90 with accelerometer values in milli-g. On this
// board that read 998 for one gravity earlier in the session and 18466 later,
// with the same firmware and the same unit -- a magnitude that cannot change
// with attitude. This prints the raw library values and the part M5Unified
// thinks it is talking to, so the scale can be checked rather than assumed.

#include <Arduino.h>
#include <M5Unified.h>

void setup() {
    auto cfg = M5.config();
    M5.begin(cfg);
    Serial.begin(115200);
    const uint32_t deadline = millis() + 10000;
    while (!Serial && millis() < deadline) delay(10);
    delay(300);

    Serial.println("\n=== AtomS3 IMU probe ===");
    Serial.printf("Imu.isEnabled : %s\n", M5.Imu.isEnabled() ? "yes" : "NO");
    Serial.printf("Imu.getType   : %d\n", (int)M5.Imu.getType());
    Serial.println("  (0=none 1=SH200Q 2=MPU6050 3=MPU6886 4=MPU9250"
                   " 5=BMI270 ...)");
    Serial.println("\nlibrary units are g and deg/s; |accel| should be ~1.00");
    for (int i = 0; i < 40; i++) {
        M5.Imu.update();
        auto d = M5.Imu.getImuData();
        const float mag = sqrtf(d.accel.x * d.accel.x + d.accel.y * d.accel.y +
                                d.accel.z * d.accel.z);
        Serial.printf("accel [%+7.3f %+7.3f %+7.3f] |a|=%6.3f   "
                      "gyro [%+8.2f %+8.2f %+8.2f]\n",
                      d.accel.x, d.accel.y, d.accel.z, mag,
                      d.gyro.x, d.gyro.y, d.gyro.z);
        delay(150);
    }
}

void loop() { delay(1000); }
