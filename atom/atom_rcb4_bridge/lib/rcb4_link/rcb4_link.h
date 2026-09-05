#ifndef RCB4_LINK_H
#define RCB4_LINK_H

#include <Arduino.h>
#include <HardwareSerial.h>

/// The RCB-4's COM port, and the one opcode this firmware answers itself.
///
/// The port is an inverted UART at 1.25 Mbps, 8E1, which is why a stock USB
/// serial adapter cannot reach it and this exists at all.
///
/// The RCB-4 does not use opcode 0x90, so the kxreus ATOM firmwares reserve it
/// for the ATOM's own IMU -- the board has none, and this is the only way a
/// host on the far side can read attitude. A request is intercepted here and
/// never forwarded.
///
///     request [0x03, 0x90, 0x93]
///     reply   [0x0F, 0x90, ax,ay,az (int16 LE, milli-g),
///                          gx,gy,gz (int16 LE, 0.1 deg/s), checksum]
class Rcb4Link {
public:
    /// Wiring, confirmed against hardware. The RCB-4's COM connector runs
    /// GND - Rx - Tx counting from the GND end, so the ATOM's TX goes to the
    /// middle pin and its RX to the far one.
    static constexpr int TX_PIN = 2;  ///< ATOM TX (G2) -> RCB-4 Rx
    static constexpr int RX_PIN = 1;  ///< ATOM RX (G1) <- RCB-4 Tx
    /// The board's fast mode. A board set to :slow wants 115200 instead.
    static constexpr uint32_t BAUD = 1250000;

    static constexpr uint8_t IMU_OPCODE = 0x90;
    static constexpr size_t IMU_REPLY_SIZE = 15;

    Rcb4Link() : serial_(1) {}

    void begin();

    /// Ask the board for its firmware version and see if it answers.
    ///
    /// Worth doing before the host starts talking, because a relay cannot
    /// tell a silent board from a quiet one: with nothing wired to the COM
    /// port it passes bytes into the dark exactly as it would to a working
    /// RCB-4. This is the one moment the bridge speaks for itself.
    ///
    /// @param timeout_ms how long to wait for the reply.
    /// @return true if a complete version frame came back.
    bool probeBoard(uint32_t timeout_ms = 200);

    /// Milliseconds since the host last sent a byte, or UINT32_MAX if it
    /// never has. Used to find a gap safe to probe in.
    uint32_t sinceHostSpoke() const;

    /// Feed one byte from the host, forwarding or intercepting it.
    ///
    /// Only the first two bytes of a frame are held back, long enough to read
    /// the length and the opcode. Anything that is not the IMU request is
    /// released at once and the rest of the frame streams through byte by
    /// byte, so a command carries two bytes of extra latency and nothing more.
    ///
    /// @return true if the byte completed an intercepted IMU request.
    bool feedFromHost(uint8_t byte);

    /// Move whatever the board has said back to the host.
    /// @return the number of bytes forwarded.
    size_t pumpToHost();

    /// Fill an IMU reply frame. Zeros if the IMU never came up, which reads as
    /// a zero acceleration vector and so fails on the far side rather than
    /// passing for level and still.
    static void buildImuReply(uint8_t frame[IMU_REPLY_SIZE]);

    // ---------------------------------------------------------------
    // Speaking to the board, rather than relaying for someone who does.
    //
    // The relay above forwards someone else's frames. These build their own,
    // which is what a control loop running here needs. They must not be used
    // while the relay is live: both would be talking on the same wire.
    // ---------------------------------------------------------------

    /// Where the board keeps its per-servo records, and their shape.
    ///
    /// Each ICS device gets a 20 byte record; within it Trim, MotorPosition
    /// (what the servo reports) and Position (what it was told) are three
    /// consecutive 16 bit words starting at offset 2. Published in Kondo's own
    /// RCB-4 Library for Python as ``DeviceAddrOffset``.
    static constexpr uint16_t SERVO_RAM_ADDRESS = 0x0090;
    static constexpr uint8_t SERVO_RECORD_SIZE = 20;
    static constexpr uint8_t SERVO_TRIM_OFFSET = 0x02;
    /// What the servo reports, as opposed to what it was last told.
    static constexpr uint8_t SERVO_MOTOR_POSITION_OFFSET = 0x04;
    /// Records the board keeps, whether or not a servo is plugged into one.
    static constexpr uint8_t SERVO_SLOTS = 35;

    /// Degrees to servo pulse: ``pulse = deg * DEG_TO_PULSE + PULSE_NEUTRAL``.
    ///
    /// Measured against this board rather than assumed: its joint-to-actuator
    /// matrix is diagonal with every entry 29.62963 and every offset 7500, so
    /// the general matrix the host library carries collapses to these two
    /// numbers. A board configured differently would need the matrix back.
    static constexpr float DEG_TO_PULSE = 29.62962962962963f;
    static constexpr float PULSE_NEUTRAL = 7500.0f;

    /// Read `size` bytes out of the board's RAM.
    ///
    /// @param addr    RAM address to read from.
    /// @param size    bytes to read; at most 126, above which the board's
    ///                replies collapse (measured: 51 Hz at 126, 6 Hz at 140).
    /// @param out     `size` bytes of output.
    /// @param timeout_ms  how long to wait for the reply. The board declines a
    ///                read while it is busy with its own servo cycle, so a
    ///                caller should retry rather than treat this as fatal.
    /// @return true if a whole, correctly sized frame came back.
    bool readRam(uint16_t addr, uint8_t size, uint8_t* out,
                 uint32_t timeout_ms = 20);

    /// Read every servo's current position, in pulses.
    ///
    /// Fills `SERVO_SLOTS` entries; a slot with no servo in it reads 0. This
    /// is MotorPosition -- what the servo reports -- not Position, which is
    /// only what it was last told.
    ///
    /// @param attempts  retries per chunk before giving up.
    /// @return true if the whole table came back.
    bool readServoPulses(uint16_t* pulses, uint8_t attempts = 4);

    /// Read the current position of just the servos named, in pulses.
    ///
    /// Preferred over `readServoPulses()` whenever only some servos matter,
    /// which for a policy is always. The board answers a read at about
    /// 54 us per byte -- six times slower than its own 1.25 Mbps wire, and
    /// measured on this hardware -- against a fixed 0.72 ms per transaction.
    /// Bytes therefore dominate: pulling the whole 630 byte table to extract
    /// 38 useful bytes costs 37 ms, while asking for each 2 byte
    /// MotorPosition on its own costs about 16 ms despite the extra round
    /// trips. Merging even two adjacent servos into one read loses, because
    /// the 20 byte record stride costs more than a second transaction does.
    ///
    /// @param ids    servo ids to read; any order, need not be sorted.
    /// @param out    one pulse per id.
    /// @param count  how many.
    /// @return true if every one came back.
    bool readServoPulsesFor(const uint8_t* ids, uint16_t* out, uint8_t count,
                            uint8_t attempts = 4);

    /// Write the same holding stiffness into a set of servos.
    ///
    /// The board's only servo parameter command carries stretch and speed;
    /// current and temperature limits live in the servo's own EEPROM, which
    /// the RCB-4 has no route to. Set those with `ics-manager` instead.
    ///
    /// @param ids     servo ids, ASCENDING, as for writeServoPulses.
    /// @param value   1..127.
    /// @return true if the board acknowledged.
    bool writeServoStretch(const uint8_t* ids, uint8_t count, uint8_t value,
                           uint32_t timeout_ms = 20);

    /// Command a set of servos to positions.
    ///
    /// @param ids     servo ids, ASCENDING. The board reads positions in id
    ///                order against a bitmap, so an unsorted list silently
    ///                sends each angle to the wrong servo.
    /// @param pulses  one position per id. 0x8000 frees a servo, 0x7FFF holds.
    /// @param count   how many, at most 40.
    /// @param frames  interpolation time in 10 ms frames, 1..255.
    /// @return true if the board acknowledged.
    bool writeServoPulses(const uint8_t* ids, const uint16_t* pulses,
                          uint8_t count, uint8_t frames,
                          uint32_t timeout_ms = 20);

    /// Bytes seen in each direction, for the status display.
    uint32_t bytesToBoard() const { return to_board_; }
    uint32_t bytesToHost() const { return to_host_; }
    uint32_t imuRequests() const { return imu_requests_; }

private:
    void releasePending();

    /// Send a command and read the frame that answers it.
    ///
    /// @param reply_size  the exact length expected, which for the RCB-4 is
    ///                    always known from the command; a frame of any other
    ///                    length is a desync and is reported as failure.
    bool transact(const uint8_t* cmd, size_t cmd_len, uint8_t* reply,
                  size_t reply_size, uint32_t timeout_ms);

    HardwareSerial serial_;
    uint8_t pending_[2] = {0, 0};
    int pending_len_ = 0;
    int body_remaining_ = 0;
    uint32_t to_board_ = 0;
    uint32_t last_host_ms_ = 0;
    bool host_spoke_ = false;
    uint32_t to_host_ = 0;
    uint32_t imu_requests_ = 0;
};

#endif  // RCB4_LINK_H
