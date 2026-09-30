// Probes ONE fixed I2C address (0x25) repeatedly, unlike i2c_raw_scan.cpp's
// full 0x08..0x77 sweep -- a full sweep sends a burst of ~112 back-to-back
// START/STOP conditions, and the M5StickV/UnitV side's I2C slave ISR calls
// straight into MicroPython for every one of them (see object_detection_
// I2C_slave.py's own on_event, and its "this print is necessary" comment on
// on_receive -- a documented, already-discovered timing sensitivity in that
// exact callback path). This is a gentler, single-target probe to test
// whether that burst rate specifically is what crashes the K210 side.
#include <Arduino.h>
#include <M5Unified.h>
#if !defined(ARDUINO_M5STACK_FIRE)
#include <Wire.h>
#endif

namespace {
constexpr uint8_t kAddr = 0x25;
}  // namespace

void setup() {
    auto cfg = M5.config();
    M5.begin(cfg);
    Serial.begin(115200);
    const uint32_t deadline = millis() + 10000;
    while (!Serial && millis() < deadline) delay(10);
    delay(300);

#if !defined(ARDUINO_M5STACK_FIRE)
    Wire.begin(2, 1);  // SDA=G2, SCL=G1
    Wire.setClock(100000);
#endif

    Serial.println("\n=== single-address I2C probe (0x25) ===");
}

void loop() {
    // The K210's own per-frame camera+NN work may leave only brief, scattered
    // windows where its I2C slave callback can actually run -- see this
    // file's own header comment. Burst 40 quick attempts (roughly 2 seconds
    // total) instead of one, to see if ANY of them land in such a window.
    int acks = 0;
    for (int i = 0; i < 40; i++) {
#if defined(ARDUINO_M5STACK_FIRE)
        uint8_t dummy;
        const bool ok = M5.Ex_I2C.readRegister(kAddr, 0x00, &dummy, 1, 100000);
#else
        Wire.beginTransmission(kAddr);
        const bool ok = (Wire.endTransmission() == 0);
#endif
        if (ok) acks++;
        delay(50);
    }
    Serial.printf("burst of 40: %d ACKed\n", acks);
}
