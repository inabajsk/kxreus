#include "rcb4_link.h"

#include <M5Unified.h>
#include <driver/gpio.h>
#include <driver/uart.h>

namespace {
constexpr uint8_t IMU_REQUEST[3] = {0x03, Rcb4Link::IMU_OPCODE, 0x93};

// The M5StickV bridge's I2C transactions go through M5.Ex_I2C (M5Unified's
// own Grove/"external" bus object), NOT a second Wire instance of this
// firmware's own.
//
// A raw `TwoWire(1)` was tried first, on the reasoning that M5StickC's own
// pin table already puts the Grove port and the internal IMU on different
// GPIOs (see rcb4_link.h's own M5STICKV_SDA_PIN comment), so a second I2C
// bus looked like it would simply sit beside M5Unified's own, untouched.
// That reasoning missed one thing, confirmed on real hardware (2026.9): with
// differing SDA/SCL, M5Unified's _setup_i2c() puts the internal IMU (In_I2C)
// on I2C_NUM_1, not I2C_NUM_0 -- and `TwoWire(1)` claims that SAME hardware
// peripheral, just configured for different pins (G32/G33 instead of
// G21/G22). The two configurations fight over one piece of silicon: the
// board still answered an IMU query right after boot (M5Unified's own
// In_I2C.begin() ran first and "won"), but the very first M5StickV I2C
// transaction through the conflicting TwoWire(1) hung the whole firmware
// solid -- unrecoverable without a hardware reset, and reproduced with the
// M5StickV genuinely powered and Grove-connected, ruling out a merely-
// floating bus as the cause.
//
// M5.Ex_I2C avoids this because M5Unified already owns and arbitrates it:
// _setup_i2c() puts Ex_I2C on I2C_NUM_0 for this board (this board's own
// pin table: Ex CL,DA = G33,G32, a DIFFERENT peripheral than In_I2C's
// I2C_NUM_1), and M5.Ex_I2C.begin() (see beginM5StickV()) simply starts
// that peripheral rather than standing up a second, competing one.
constexpr uint32_t kM5StickVFreq = 100000;

bool i2cReadBytes(uint8_t addr, uint8_t reg, uint8_t* out, size_t len) {
    return M5.Ex_I2C.readRegister(addr, reg, out, len, kM5StickVFreq);
}

bool i2cWriteReg(uint8_t addr, uint8_t reg, uint8_t value) {
    return M5.Ex_I2C.writeRegister8(addr, reg, value, kM5StickVFreq);
}

bool i2cProbe(uint8_t addr) {
    // NOT M5.Ex_I2C.start()+stop(): on real M5Stack FIRE hardware (this
    // firmware's own earlier finding, see git history) that reported every
    // address as acking regardless of whether anything was really there --
    // this M5Unified version's I2C_Class does not reflect a slave's real
    // ACK/NACK through start()/stop() the way Wire.endTransmission() does.
    // Reading control register 0x00 (which every device this protocol
    // talks to exposes -- see M5STICKV_OPCODE's own comment) costs one
    // real transaction per address but was confirmed to fail correctly for
    // an address nothing answers at.
    uint8_t dummy;
    return i2cReadBytes(addr, 0x00, &dummy, 1);
}
}  // namespace

void Rcb4Link::begin() {
    // A plain invert=true argument to HardwareSerial::begin() was found
    // unstable on this exact G5/G6 pin pair on real hardware (see
    // atom/s3_echo_with_I2C's own atoms3_i2c_robot.ino, which moved the
    // RCB-4 UART here first -- see TX_PIN/RX_PIN's own comment -- and hit
    // this before this firmware did): begin with invert=false, then set
    // TX/RX inversion directly through ESP-IDF. Pins are reset first so no
    // stale GPIO matrix/IOMUX assignment from a previous begin() (or from
    // whatever used G5/G6 before this firmware did) lingers.
    serial_.end();
    delay(5);
    gpio_reset_pin(static_cast<gpio_num_t>(TX_PIN));
    gpio_reset_pin(static_cast<gpio_num_t>(RX_PIN));
    serial_.begin(BAUD, SERIAL_8E1, RX_PIN, TX_PIN, /*invert=*/false);
    delay(5);
    uart_set_line_inverse(static_cast<uart_port_t>(UART_PORT_NUM),
                          UART_SIGNAL_TXD_INV | UART_SIGNAL_RXD_INV);
}

void Rcb4Link::beginM5StickV() {
    // Starts M5.Ex_I2C on this board's own Grove pins (I2C_NUM_0, G33/G32 --
    // see the .cpp's own top-of-file comment for why this, not a second Wire
    // instance, is what avoids fighting M5Unified's internal-IMU peripheral).
    // M5.begin() does not already do this itself: M5Unified only calls
    // Ex_I2C.begin() on its own when cfg.external_imu or cfg.external_rtc is
    // set, both false by this firmware's default M5.config(), so it is done
    // explicitly here instead.
    M5.Ex_I2C.begin();
}

bool Rcb4Link::probeBoard(uint32_t timeout_ms) {
    // [length, Version, checksum]; the reply is a 35 byte frame whose first
    // byte is its own length.
    static constexpr uint8_t VERSION_REQUEST[3] = {0x03, 0xFD, 0x00};
    static constexpr size_t VERSION_REPLY_SIZE = 0x23;

    while (serial_.available()) serial_.read();
    serial_.write(VERSION_REQUEST, sizeof(VERSION_REQUEST));

    uint8_t reply[VERSION_REPLY_SIZE];
    size_t got = 0;
    const uint32_t deadline = millis() + timeout_ms;
    while (millis() < deadline && got < VERSION_REPLY_SIZE) {
        if (!serial_.available()) continue;
        reply[got++] = serial_.read();
        if (got == 1 && reply[0] != VERSION_REPLY_SIZE) {
            got = 0;  // not a version frame; resynchronise on the next byte
        }
    }
    return got == VERSION_REPLY_SIZE;
}

uint32_t Rcb4Link::sinceHostSpoke() const {
    if (!host_spoke_) return UINT32_MAX;
    return millis() - last_host_ms_;
}

void Rcb4Link::buildImuReply(uint8_t frame[IMU_REPLY_SIZE]) {
    m5::imu_data_t data = {};
    if (M5.Imu.isEnabled()) {
        M5.Imu.update();
        data = M5.Imu.getImuData();
    }
    const int16_t values[6] = {
            static_cast<int16_t>(lroundf(data.accel.x * 1000.0f)),  // milli-g
            static_cast<int16_t>(lroundf(data.accel.y * 1000.0f)),
            static_cast<int16_t>(lroundf(data.accel.z * 1000.0f)),
            static_cast<int16_t>(lroundf(data.gyro.x * 10.0f)),  // 0.1 deg/s
            static_cast<int16_t>(lroundf(data.gyro.y * 10.0f)),
            static_cast<int16_t>(lroundf(data.gyro.z * 10.0f)),
    };
    frame[0] = IMU_REPLY_SIZE;
    frame[1] = IMU_OPCODE;
    for (int i = 0; i < 6; i++) {
        frame[2 + i * 2] = static_cast<uint8_t>(values[i] & 0xFF);
        frame[3 + i * 2] = static_cast<uint8_t>((values[i] >> 8) & 0xFF);
    }
    uint16_t sum = 0;
    for (size_t i = 0; i < IMU_REPLY_SIZE - 1; i++) sum += frame[i];
    frame[IMU_REPLY_SIZE - 1] = static_cast<uint8_t>(sum & 0xFF);
}

bool Rcb4Link::readM5StickV(uint8_t addr, uint8_t* out, uint8_t* len) {
    // detection data length register
    uint8_t data_len = 0;
    if (!i2cReadBytes(addr, 0x01, &data_len, 1)) {
        *len = 0;
        return false;
    }
    if (data_len > M5STICKV_MAX_READ) data_len = M5STICKV_MAX_READ;

    // detection data register
    uint8_t got = 0;
    if (data_len > 0 && i2cReadBytes(addr, 0x02, out, data_len)) got = data_len;
    *len = got;
    return true;
}

bool Rcb4Link::readM5StickVReg(uint8_t addr, uint8_t reg_addr, uint8_t* value) {
    return i2cReadBytes(addr, reg_addr, value, 1);
}

bool Rcb4Link::writeM5StickVReg(uint8_t addr, uint8_t reg_addr, uint8_t value) {
    return i2cWriteReg(addr, reg_addr, value);
}

size_t Rcb4Link::buildM5StickVReply(uint8_t frame[M5STICKV_REPLY_CAPACITY]) {
    const uint8_t addr = m5stickv_req_[2];
    const uint8_t subcmd = m5stickv_req_[3];
    size_t total;

    if (subcmd == 2) {
        // SCAN: which addresses on this bus answer at all, so a caller need
        // not guess (e.g. 0x24 vs. 0x25) -- see M5STICKV_OPCODE's own
        // comment.
        frame[1] = M5STICKV_OPCODE;
        frame[2] = 0;
        frame[3] = 2;
        size_t idx = 5;
        uint8_t count = 0;
        for (uint8_t a = 0x08; a <= 0x77 && idx < M5STICKV_REPLY_CAPACITY - 1; a++) {
            if (i2cProbe(a)) {
                frame[idx++] = a;
                count++;
            }
        }
        frame[4] = count;
        total = idx + 1;
    } else if (subcmd == 1) {
        // WRITE: the control register (0x00) specifically -- kept as its
        // own subcmd for callers that predate subcmd 3 (WRITE_REG).
        const bool ok = writeM5StickVReg(addr, 0x00, m5stickv_req_[4]);
        frame[1] = M5STICKV_OPCODE;
        frame[2] = addr;
        frame[3] = 1;
        frame[4] = ok ? 1 : 0;
        total = 6;
    } else if (subcmd == 3) {
        // WRITE_REG: any register, not just the control one.
        const bool ok = writeM5StickVReg(addr, m5stickv_req_[4], m5stickv_req_[5]);
        frame[1] = M5STICKV_OPCODE;
        frame[2] = addr;
        frame[3] = 3;
        frame[4] = ok ? 1 : 0;
        total = 6;
    } else {
        // subcmd 0 (READ), and the fallback for anything unrecognised.
        uint8_t data[M5STICKV_MAX_READ];
        uint8_t got = 0;
        const bool i2c_ok = readM5StickV(addr, data, &got);
        frame[1] = M5STICKV_OPCODE;
        frame[2] = addr;
        frame[3] = 0;
        frame[4] = i2c_ok ? 1 : 0;
        frame[5] = got;
        size_t idx = 6;
        for (uint8_t i = 0; i < got; i++) frame[idx++] = data[i];
        total = idx + 1;
    }

    frame[0] = static_cast<uint8_t>(total);
    uint16_t sum = 0;
    for (size_t i = 0; i < total - 1; i++) sum += frame[i];
    frame[total - 1] = static_cast<uint8_t>(sum & 0xFF);
    return total;
}

void Rcb4Link::releasePending() {
    if (pending_len_ > 0) {
        serial_.write(pending_, pending_len_);
        to_board_ += pending_len_;
        pending_len_ = 0;
    }
}

Rcb4Link::Intercept Rcb4Link::feedFromHost(uint8_t byte) {
    host_spoke_ = true;
    last_host_ms_ = millis();

    // An M5StickV request being captured whole (see M5STICKV_OPCODE's own
    // comment on why this cannot be held back the same fixed-length way
    // the IMU request is): every byte from here to the length this frame
    // itself announced is part of it, none of it goes to the board.
    if (capturing_m5stickv_) {
        m5stickv_req_[m5stickv_req_len_++] = byte;
        if (m5stickv_req_len_ >= m5stickv_req_[0]) {
            capturing_m5stickv_ = false;
            return Intercept::M5STICKV;
        }
        return Intercept::NONE;
    }

    // Mid-frame: the opcode is already known, so this is just a relay.
    if (body_remaining_ > 0) {
        serial_.write(byte);
        to_board_++;
        body_remaining_--;
        return Intercept::NONE;
    }

    // Waiting on the checksum of what looks like an IMU request.
    if (pending_len_ == 2 && pending_[0] == IMU_REQUEST[0] &&
        pending_[1] == IMU_REQUEST[1]) {
        pending_len_ = 0;
        if (byte == IMU_REQUEST[2]) {
            imu_requests_++;
            return Intercept::IMU;
        }
        // Checksum does not match, so this was not the IMU request after all.
        // Hand the whole thing to the board and let it judge.
        serial_.write(IMU_REQUEST, 2);
        serial_.write(byte);
        to_board_ += 3;
        return Intercept::NONE;
    }

    pending_[pending_len_++] = byte;
    if (pending_len_ == 1) {
        // A length of 0 or 1 cannot be a frame; pass it on rather than
        // waiting for an opcode that will never come.
        if (byte < 2) releasePending();
        return Intercept::NONE;
    }

    if (pending_[0] == IMU_REQUEST[0] && pending_[1] == IMU_REQUEST[1]) {
        return Intercept::NONE;  // Hold for the checksum.
    }

    // A request for the M5StickV bridge: captured whole rather than relayed,
    // the same reasoning as the IMU one. Guarded on a length this protocol
    // could actually produce (at most 7 bytes, subcmd 3 -- see
    // M5STICKV_OPCODE's own comment) so a stray frame that merely happens to
    // share this opcode byte cannot overrun m5stickv_req_.
    if (pending_[1] == M5STICKV_OPCODE && pending_[0] <= sizeof(m5stickv_req_)) {
        m5stickv_req_[0] = pending_[0];
        m5stickv_req_[1] = pending_[1];
        m5stickv_req_len_ = 2;
        pending_len_ = 0;
        if (m5stickv_req_len_ >= m5stickv_req_[0]) {
            // A degenerate "frame" with no addr/subcmd at all: nothing to
            // act on, and nothing further to capture either.
            return Intercept::NONE;
        }
        capturing_m5stickv_ = true;
        return Intercept::NONE;
    }

    // An ordinary frame: release the two held bytes and stream the rest.
    body_remaining_ = static_cast<int>(pending_[0]) - 2;
    if (body_remaining_ < 0) body_remaining_ = 0;
    releasePending();
    return Intercept::NONE;
}

size_t Rcb4Link::pumpToHost() {
    uint8_t buf[256];
    size_t n = 0;
    while (serial_.available() && n < sizeof(buf)) {
        buf[n++] = serial_.read();
    }
    if (n > 0) {
        Serial.write(buf, n);
        to_host_ += n;
    }
    return n;
}

// ---------------------------------------------------------------------------
// Speaking to the board
// ---------------------------------------------------------------------------

bool Rcb4Link::transact(const uint8_t* cmd, size_t cmd_len, uint8_t* reply,
                        size_t reply_size, uint32_t timeout_ms) {
    while (serial_.available()) serial_.read();
    serial_.write(cmd, cmd_len);

    size_t got = 0;
    const uint32_t deadline = millis() + timeout_ms;
    while (got < reply_size) {
        if (!serial_.available()) {
            if (millis() >= deadline) return false;
            continue;
        }
        const uint8_t byte = serial_.read();
        // Every RCB-4 reply opens with its own length, and the length is known
        // from the command, so a first byte that disagrees is not the reply --
        // it is a leftover from a frame that timed out earlier. Dropping it
        // resynchronises instead of returning a shifted frame.
        if (got == 0 && byte != reply_size) continue;
        reply[got++] = byte;
    }
    uint16_t sum = 0;
    for (size_t i = 0; i + 1 < reply_size; i++) sum += reply[i];
    return static_cast<uint8_t>(sum & 0xFF) == reply[reply_size - 1];
}

bool Rcb4Link::readRam(uint16_t addr, uint8_t size, uint8_t* out,
                       uint32_t timeout_ms) {
    if (size == 0 || size > 126) return false;
    // MOV with sub-command RAM->COM. The three zero bytes are the destination
    // address, unused when the destination is the COM port.
    uint8_t cmd[10] = {0x0A, 0x00, 0x20, 0x00, 0x00, 0x00,
                       static_cast<uint8_t>(addr & 0xFF),
                       static_cast<uint8_t>((addr >> 8) & 0xFF), size, 0};
    uint16_t sum = 0;
    for (size_t i = 0; i + 1 < sizeof(cmd); i++) sum += cmd[i];
    cmd[9] = static_cast<uint8_t>(sum & 0xFF);

    // [length][data...][checksum]
    uint8_t reply[129];
    const size_t reply_size = static_cast<size_t>(size) + 3;
    if (!transact(cmd, sizeof(cmd), reply, reply_size, timeout_ms)) return false;
    memcpy(out, reply + 2, size);
    return true;
}

bool Rcb4Link::readServoPulses(uint16_t* pulses, uint8_t attempts) {
    // Seven records fit in one 126 byte read, and 35 slots is exactly five of
    // them. Reading the whole table costs no more round trips than picking out
    // the servos actually in use would.
    constexpr uint8_t kPerChunk = 7;
    // Six whole records plus the three words the seventh starts with: the read
    // begins at Trim, so the last record's tail is never needed. That is 126
    // bytes, which is also as much as the board will return in one go.
    constexpr uint8_t kChunk = (kPerChunk - 1) * SERVO_RECORD_SIZE + 6;
    static_assert(kChunk == 126, "a chunk is one 126 byte read");
    uint8_t buf[kChunk];

    for (uint8_t j = 0; j < SERVO_SLOTS / kPerChunk; j++) {
        const uint16_t addr = SERVO_RAM_ADDRESS +
                              SERVO_RECORD_SIZE * j * kPerChunk +
                              SERVO_TRIM_OFFSET;
        bool ok = false;
        for (uint8_t attempt = 0; attempt < attempts && !ok; attempt++) {
            ok = readRam(addr, kChunk, buf);
        }
        if (!ok) return false;
        // Within a record: [Trim][MotorPosition][Position] as 16 bit words,
        // so MotorPosition is word 1 of every 10.
        for (uint8_t i = 0; i < kPerChunk; i++) {
            const size_t word = static_cast<size_t>(i) * 10 + 1;
            pulses[j * kPerChunk + i] =
                    static_cast<uint16_t>(buf[word * 2]) |
                    (static_cast<uint16_t>(buf[word * 2 + 1]) << 8);
        }
    }
    return true;
}

bool Rcb4Link::writeServoPulses(const uint8_t* ids, const uint16_t* pulses,
                                uint8_t count, uint8_t frames,
                                uint32_t timeout_ms) {
    if (count == 0 || count > 40) return false;
    if (frames == 0) frames = 1;

    // [length][0x10 MultiServoSingleVelocity][id bitmap, 5 bytes][frames]
    // [position lo,hi per id][checksum]
    const size_t len = 9 + 2 * static_cast<size_t>(count);
    uint8_t cmd[9 + 2 * 40];
    cmd[0] = static_cast<uint8_t>(len);
    cmd[1] = 0x10;
    memset(cmd + 2, 0, 5);
    for (uint8_t i = 0; i < count; i++) {
        const uint8_t id = ids[i];
        if (id >= 40) return false;
        if (i > 0 && id <= ids[i - 1]) return false;  // must ascend; see header
        cmd[2 + (id >> 3)] |= static_cast<uint8_t>(1u << (id & 7));
    }
    cmd[7] = frames;
    for (uint8_t i = 0; i < count; i++) {
        cmd[8 + i * 2] = static_cast<uint8_t>(pulses[i] & 0xFF);
        cmd[9 + i * 2] = static_cast<uint8_t>((pulses[i] >> 8) & 0xFF);
    }
    uint16_t sum = 0;
    for (size_t i = 0; i + 1 < len; i++) sum += cmd[i];
    cmd[len - 1] = static_cast<uint8_t>(sum & 0xFF);

    uint8_t reply[4];
    return transact(cmd, len, reply, sizeof(reply), timeout_ms);
}

bool Rcb4Link::callMotion(uint8_t number, uint32_t timeout_ms) {
    if (number >= 120) return false;
    // Opcode 0x0C (:call in rcb4asm.l's *rcb4-instructions*). Body is the jump
    // target as a 3 byte little-endian ROM address, then a 1 byte condition
    // (0 = unconditional -- rcb4-cond-code of an empty condition list).
    const uint32_t addr = 2944u + static_cast<uint32_t>(number) * 2048u;
    uint8_t cmd[7] = {0x07, 0x0C,
                      static_cast<uint8_t>(addr & 0xFF),
                      static_cast<uint8_t>((addr >> 8) & 0xFF),
                      static_cast<uint8_t>((addr >> 16) & 0xFF),
                      0x00, 0x00};
    uint16_t sum = 0;
    for (size_t i = 0; i + 1 < sizeof(cmd); i++) sum += cmd[i];
    cmd[6] = static_cast<uint8_t>(sum & 0xFF);

    // Confirmed against Kondo's own RCB-4HV command reference (JUMP/CALL,
    // "COMから実行した場合"): a COM-issued JUMP/CALL answers with exactly
    // [SIZE=4][CMD][ACK 06h or NCK 15h][SUM] -- 4 bytes, and byte 2 says
    // whether the board actually accepted it, which transact()'s checksum
    // check alone does not (a checksum-valid NCK still passes that).
    uint8_t reply[4];
    if (!transact(cmd, sizeof(cmd), reply, sizeof(reply), timeout_ms)) {
        return false;
    }
    return reply[2] == 0x06;
}

bool Rcb4Link::readServoPulsesFor(const uint8_t* ids, uint16_t* out,
                                  uint8_t count, uint8_t attempts) {
    for (uint8_t i = 0; i < count; i++) {
        if (ids[i] >= SERVO_SLOTS) return false;
        const uint16_t addr = SERVO_RAM_ADDRESS +
                              SERVO_RECORD_SIZE * ids[i] +
                              SERVO_MOTOR_POSITION_OFFSET;
        uint8_t word[2];
        bool ok = false;
        for (uint8_t attempt = 0; attempt < attempts && !ok; attempt++) {
            ok = readRam(addr, 2, word);
        }
        if (!ok) return false;
        out[i] = static_cast<uint16_t>(word[0]) |
                 (static_cast<uint16_t>(word[1]) << 8);
    }
    return true;
}

bool Rcb4Link::writeServoStretch(const uint8_t* ids, uint8_t count,
                                 uint8_t value, uint32_t timeout_ms) {
    if (count == 0 || count > 40) return false;
    if (value < 1) value = 1;
    if (value > 127) value = 127;

    // [length][0x12 ServoParam][id bitmap, 5 bytes][0x01 Stretch]
    // [value per id][checksum]
    const size_t len = 9 + static_cast<size_t>(count);
    uint8_t cmd[9 + 40];
    cmd[0] = static_cast<uint8_t>(len);
    cmd[1] = 0x12;
    memset(cmd + 2, 0, 5);
    for (uint8_t i = 0; i < count; i++) {
        const uint8_t id = ids[i];
        if (id >= 40) return false;
        if (i > 0 && id <= ids[i - 1]) return false;  // must ascend
        cmd[2 + (id >> 3)] |= static_cast<uint8_t>(1u << (id & 7));
    }
    cmd[7] = 0x01;  // ServoParams::Stretch
    for (uint8_t i = 0; i < count; i++) cmd[8 + i] = value;
    uint16_t sum = 0;
    for (size_t i = 0; i + 1 < len; i++) sum += cmd[i];
    cmd[len - 1] = static_cast<uint8_t>(sum & 0xFF);

    uint8_t reply[4];
    return transact(cmd, len, reply, sizeof(reply), timeout_ms);
}
