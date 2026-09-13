// Mirrors Rcb4Link::readM5StickVReg() exactly (write one register-address
// byte, then a repeated START to read one data byte back) -- unlike
// i2c_single_probe.cpp, which only checks a bare address ACK with no data
// phase at all. Tests whether the two-phase register read specifically is
// what still fails even after the ACK-only probe succeeds.
#include <Arduino.h>
#include <M5Unified.h>
#if !defined(ARDUINO_M5STACK_FIRE)
#include <Wire.h>
#include <driver/i2c.h>
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
    Wire.begin(2, 1);
    Wire.setClock(100000);
    Wire.setTimeOut(1000);
    // Wire.setTimeOut() controls the driver's overall wait, NOT the ESP32
    // I2C peripheral's own hardware SCL-low (clock-stretch) timeout
    // register -- a separate, lower-level limit measured in APB clock
    // cycles, not milliseconds. endTransmission() was measured returning 5
    // (ESP_ERR_TIMEOUT) specifically on the first DATA byte after an
    // address that itself ACKs fine -- exactly what a slave clock-stretching
    // longer than this register allows would look like. Wire uses I2C_NUM_0
    // by default; set its hardware timeout to the chip's own maximum
    // directly via the lower-level driver.
    i2c_set_timeout(I2C_NUM_0, 0xFFFFF);  // this chip's 20-bit SCL-timeout register, maxed out
#endif

    Serial.println("\n=== register read/write probe (0x25, reg 0x00) ===");
}

void loop() {
    // Reads and writes as two separate, well-spaced runs (not interleaved)
    // so neither can leave the K210 slave's own state machine mid-transition
    // for the other -- isolates whether one direction works while the other
    // does not, rather than lumping both into one combined pass/fail count.
    int reads_ok = 0;
    for (int i = 0; i < 20; i++) {
        uint8_t value = 0xFF;
        bool read_ok;
#if defined(ARDUINO_M5STACK_FIRE)
        read_ok = M5.Ex_I2C.readRegister(kAddr, 0x00, &value, 1, 100000);
#else
        Wire.beginTransmission(kAddr);
        Wire.write((uint8_t)0x00);
        const uint8_t err = Wire.endTransmission(true);
        read_ok = (err == 0);
        delay(20);
        uint8_t got = 0;
        if (read_ok) {
            got = Wire.requestFrom((int)kAddr, 1);
            read_ok = (got == 1);
            if (read_ok) value = Wire.read();
        }
        Serial.printf("  endTransmission=%u requestFrom_got=%u\n", err, got);
#endif
        if (read_ok) {
            reads_ok++;
            Serial.printf("  read ok, value=0x%02X\n", value);
        }
        delay(200);
    }
    Serial.printf("reads: %d/20 ok\n", reads_ok);
    delay(1000);

    int writes_ok = 0;
    for (int i = 0; i < 20; i++) {
        bool write_ok;
#if defined(ARDUINO_M5STACK_FIRE)
        write_ok = M5.Ex_I2C.writeRegister8(kAddr, 0x00, 0x00, 100000);
#else
        Wire.beginTransmission(kAddr);
        Wire.write((uint8_t)0x00);
        Wire.write((uint8_t)0x00);
        write_ok = (Wire.endTransmission() == 0);
#endif
        if (write_ok) writes_ok++;
        delay(200);
    }
    Serial.printf("writes: %d/20 ok\n", writes_ok);
    delay(1000);
}
