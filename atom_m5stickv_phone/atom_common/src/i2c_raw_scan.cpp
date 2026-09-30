// Minimal, standalone I2C bus scanner for the M5StickV/UnitV external bus --
// bypasses Rcb4Link/the opcode-0x91 protocol entirely, to test the raw
// Wire/M5.Ex_I2C path on its own when the higher-level bridge finds nothing.
//
// AtomS3: Wire.begin(SDA=G2, SCL=G1). FIRE: M5.Ex_I2C, already brought up by
// M5.begin() -- see rcb4_link.h's own M5STICKV_SDA_PIN/SCL_PIN comment.
#include <Arduino.h>
#include <M5Unified.h>
#if !defined(ARDUINO_M5STACK_FIRE)
#include <Wire.h>
#endif

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

    Serial.println("\n=== raw I2C scan ===");
}

void loop() {
    Serial.println("scanning 0x08..0x77 ...");
    int found = 0;
    for (uint8_t addr = 0x08; addr <= 0x77; addr++) {
#if defined(ARDUINO_M5STACK_FIRE)
        uint8_t dummy;
        const bool ok = M5.Ex_I2C.readRegister(addr, 0x00, &dummy, 1, 100000);
#else
        Wire.beginTransmission(addr);
        const bool ok = (Wire.endTransmission() == 0);
#endif
        if (ok) {
            Serial.printf("  found 0x%02X\n", addr);
            found++;
        }
    }
    Serial.printf("done: %d found\n\n", found);
    delay(3000);
}
