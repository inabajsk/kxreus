#include "rcb4_link.h"

#include <M5Unified.h>

namespace {
constexpr uint8_t IMU_REQUEST[3] = {0x03, Rcb4Link::IMU_OPCODE, 0x93};
}  // namespace

void Rcb4Link::begin() {
    serial_.begin(BAUD, SERIAL_8E1, RX_PIN, TX_PIN, /*invert=*/true);
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

void Rcb4Link::releasePending() {
    if (pending_len_ > 0) {
        serial_.write(pending_, pending_len_);
        to_board_ += pending_len_;
        pending_len_ = 0;
    }
}

bool Rcb4Link::feedFromHost(uint8_t byte) {
    host_spoke_ = true;
    last_host_ms_ = millis();

    // Mid-frame: the opcode is already known, so this is just a relay.
    if (body_remaining_ > 0) {
        serial_.write(byte);
        to_board_++;
        body_remaining_--;
        return false;
    }

    // Waiting on the checksum of what looks like an IMU request.
    if (pending_len_ == 2 && pending_[0] == IMU_REQUEST[0] &&
        pending_[1] == IMU_REQUEST[1]) {
        pending_len_ = 0;
        if (byte == IMU_REQUEST[2]) {
            imu_requests_++;
            return true;
        }
        // Checksum does not match, so this was not the IMU request after all.
        // Hand the whole thing to the board and let it judge.
        serial_.write(IMU_REQUEST, 2);
        serial_.write(byte);
        to_board_ += 3;
        return false;
    }

    pending_[pending_len_++] = byte;
    if (pending_len_ == 1) {
        // A length of 0 or 1 cannot be a frame; pass it on rather than
        // waiting for an opcode that will never come.
        if (byte < 2) releasePending();
        return false;
    }

    if (pending_[0] == IMU_REQUEST[0] && pending_[1] == IMU_REQUEST[1]) {
        return false;  // Hold for the checksum.
    }

    // An ordinary frame: release the two held bytes and stream the rest.
    body_remaining_ = static_cast<int>(pending_[0]) - 2;
    if (body_remaining_ < 0) body_remaining_ = 0;
    releasePending();
    return false;
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
