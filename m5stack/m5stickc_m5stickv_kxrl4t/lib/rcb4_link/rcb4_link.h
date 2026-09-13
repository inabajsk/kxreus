#ifndef RCB4_LINK_H
#define RCB4_LINK_H

#include <Arduino.h>
#include <HardwareSerial.h>

/// The RCB-4's COM port, and the two opcodes this firmware answers itself.
///
/// The port is an inverted UART at 1.25 Mbps, 8E1, which is why a stock USB
/// serial adapter cannot reach it and this exists at all.
///
/// The RCB-4 does not use opcode 0x90, so this reserves it for this board's
/// own IMU -- the RCB-4 has none, and this is the only way a host on the far
/// side can read attitude. A request is intercepted here and never
/// forwarded.
///
///     request [0x03, 0x90, 0x93]
///     reply   [0x0F, 0x90, ax,ay,az (int16 LE, milli-g),
///                          gx,gy,gz (int16 LE, 0.1 deg/s), checksum]
///
/// Opcode 0x91 is reserved the same way, for an M5StickV (MaixPy
/// object_detection_I2C_slave, see ~/kxreus/atom/m5stickv) wired to this
/// board's own I2C bus -- see M5STICKV_OPCODE's own comment for the wire
/// protocol.
class Rcb4Link {
public:
    /// Wiring, confirmed against hardware. The RCB-4's COM connector runs
    /// GND - Rx - Tx counting from the GND end, so this board's TX goes to
    /// the middle pin and its RX to the far one.
    ///
    /// M5StickC's bottom HAT connector -- G26(TX)/G36(RX) -- free GPIOs on
    /// this board: not the Grove port (left for the M5StickV, see
    /// M5STICKV_SDA_PIN below), not the LCD's own SPI pins (G5/G13/G14/G15/
    /// G18/G23, see M5GFX's own board_M5StickC autodetect), and not the
    /// internal IMU's bus (G21/G22) either. UART0 (G1/G3) is Serial, carried
    /// out over the CP2104 USB bridge chip, not a native USB CDC port, so it
    /// is not available. G36 is one of this chip's input-only pins
    /// (GPIO34-39), which is fine for RX and is why it, not G26, is the RX
    /// side.
    static constexpr int TX_PIN = 26;  ///< HAT bottom pin -> RCB-4 Rx
    static constexpr int RX_PIN = 36;  ///< HAT bottom pin <- RCB-4 Tx
    /// Which HardwareSerial/UART peripheral TX_PIN/RX_PIN belong to. UART0
    /// is Serial; UART2 is free regardless of which GPIOs it is asked to
    /// use -- the ESP32's UART peripherals route through the GPIO matrix,
    /// so an explicit-pin HardwareSerial::begin() is not limited to a
    /// UART's own "default" pins the way Port C's own G16/G17 happening to
    /// match UART2's defaults might suggest.
    static constexpr int UART_PORT_NUM = 2;
    /// The board's fast mode. A board set to :slow wants 115200 instead.
    static constexpr uint32_t BAUD = 1250000;

    static constexpr uint8_t IMU_OPCODE = 0x90;
    static constexpr size_t IMU_REPLY_SIZE = 15;

    /// M5StickV I2C bridge, reserved opcode 0x91. Register map is the
    /// M5StickV-side firmware's own (object_detection_I2C_slave.py): reg
    /// 0x00 control (bit3 = apriltag_en, etc.), reg 0x01 detection data
    /// length, reg 0x02+ the detection data itself.
    ///
    /// Request (never forwarded to the real RCB-4, same as the IMU one):
    ///   [length, 0x91, i2c_addr, subcmd, (subcmd 3: regAddr), (subcmd 1 or
    ///    3: value), checksum]
    ///     subcmd 0 (READ)      : reg 0x01 then reg 0x02.. from i2c_addr
    ///     subcmd 1 (WRITE)     : value into i2c_addr's reg 0x00
    ///     subcmd 2 (SCAN)      : which addresses answer on this bus at all
    ///     subcmd 3 (WRITE_REG) : value into i2c_addr's own regAddr
    /// Reply:
    ///   subcmd 0: [len, 0x91, addr, 0, i2c_ok, dataLen, data.., checksum]
    ///   subcmd 1: [6,   0x91, addr, 1, i2c_ok, checksum]
    ///   subcmd 2: [len, 0x91, 0,    2, count, addr.., checksum]
    ///   subcmd 3: [6,   0x91, addr, 3, i2c_ok, checksum]
    /// i2c_ok is whether the I2C transaction to that address itself
    /// succeeded (Wire's endTransmission() == 0) -- distinct from a
    /// dataLen of 0, which is a real answer saying "nothing detected".
    static constexpr uint8_t M5STICKV_OPCODE = 0x91;
    /// The Grove connector (G33 SCL/G32 SDA) -- a bus of its own on THIS
    /// board, unlike M5Stack FIRE/GRAY (the Core-series boards), where the
    /// equivalent "Port A" Grove connector shares its two GPIOs with the
    /// internal IMU (see M5Unified's board_M5Stack pin table -- "In CL,DA"
    /// and "EX CL,DA" both G22/G21 there), which was measured on that
    /// hardware (2026.9) corrupting the internal IMU's own readings just
    /// from an M5StickV's passive presence on the shared bus, and
    /// sometimes failing IMU detection outright.
    ///
    /// M5StickC does not have that problem to begin with: M5Unified's own
    /// board_M5StickC pin table gives the internal IMU G22/G21 and the
    /// Grove port G33/G32 -- already two separate buses, on a chip
    /// (ESP32 PICO-D4) with two independent I2C peripherals to put them on.
    /// So the M5StickV simply plugs into the stock Grove port here; no
    /// free-GPIO hunting or case modification needed the way the Core-series
    /// boards required.
    ///
    /// The .cpp's i2c*() helpers go through M5.Ex_I2C, NOT a second Wire
    /// instance of this firmware's own -- a raw `TwoWire(1)` was tried first
    /// and hung the whole firmware solid on real hardware (2026.9), because
    /// this board's differing In_I2C/Ex_I2C pins make M5Unified itself put
    /// the internal IMU on I2C_NUM_1, and `TwoWire(1)` claims that exact
    /// same peripheral out from under it. See the .cpp's own top-of-file
    /// comment for the full story.
    static constexpr int M5STICKV_SCL_PIN = 33;  ///< Grove (G33)
    static constexpr int M5STICKV_SDA_PIN = 32;  ///< Grove (G32)
    /// This project's own M5StickV (atom/m5stickv's object_detection_I2C_
    /// slave.py), not a protocol constant -- a bus can carry other I2C
    /// addresses too, which is what subcmd 2 (SCAN) is for.
    static constexpr uint8_t M5STICKV_DEFAULT_ADDR = 0x25;
    static constexpr size_t M5STICKV_MAX_READ = 60;
    /// [length, opcode, addr, subcmd, i2c_ok, dataLen, data.., checksum].
    static constexpr size_t M5STICKV_REPLY_CAPACITY = 6 + M5STICKV_MAX_READ;

    /// What feedFromHost() just captured a complete request for, so the
    /// caller knows which of buildImuReply()/buildM5StickVReply() to call
    /// (and which reply to send back) -- seeing this rather than a bool is
    /// what lets the same relay carry both reserved opcodes.
    enum class Intercept : uint8_t { NONE, IMU, M5STICKV };

    Rcb4Link() : serial_(UART_PORT_NUM) {}

    void begin();

    /// Brings up the M5StickV's own I2C bus: M5.Ex_I2C, on the Grove
    /// connector (M5STICKV_SDA_PIN/M5STICKV_SCL_PIN) -- a peripheral
    /// completely separate from M5.Imu's own internal bus on this board.
    /// See M5STICKV_SDA_PIN's own comment for why that separation matters,
    /// and why this goes through M5.Ex_I2C rather than a second Wire of
    /// this firmware's own.
    static void beginM5StickV();

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
    /// the length and the opcode. Anything that is not an IMU or M5StickV
    /// request is released at once and the rest of the frame streams through
    /// byte by byte, so a command carries two bytes of extra latency and
    /// nothing more. An M5StickV request holds the whole frame instead (its
    /// length varies by subcmd, see M5STICKV_OPCODE's own comment), since
    /// there is no fixed byte count to compare against the way the IMU
    /// request's three bytes are.
    ///
    /// @return which reserved opcode, if any, this byte just completed.
    Intercept feedFromHost(uint8_t byte);

    /// Whether a frame from the host is part-way through being relayed.
    ///
    /// Anything sharing this byte stream has to know: a byte in the middle of
    /// an RCB-4 frame means whatever the frame says it means, and can look
    /// like anything at all.
    bool midFrame() const { return body_remaining_ > 0 || pending_len_ > 0; }

    /// Move whatever the board has said back to the host.
    /// @return the number of bytes forwarded.
    size_t pumpToHost();

    /// Fill an IMU reply frame. Zeros if the IMU never came up, which reads as
    /// a zero acceleration vector and so fails on the far side rather than
    /// passing for level and still.
    static void buildImuReply(uint8_t frame[IMU_REPLY_SIZE]);

    /// Fill the reply frame for whatever M5StickV request feedFromHost()
    /// just finished capturing (Intercept::M5STICKV), performing the actual
    /// I2C transaction now. Not static, unlike buildImuReply(): the request
    /// (address, subcmd, and its arguments) is instance state captured
    /// byte-by-byte, not a fixed request with nothing to remember.
    ///
    /// Runs from the caller's own context (BridgeMode::relay()), not from
    /// feedFromHost() itself -- an I2C transaction can take a few ms, and
    /// that must not block the byte-at-a-time UART relay loop mid-frame.
    ///
    /// @return the reply's length, at most M5STICKV_REPLY_CAPACITY.
    size_t buildM5StickVReply(uint8_t frame[M5STICKV_REPLY_CAPACITY]);

    /// Subcmd 0 (READ) of the M5StickV bridge protocol, performed directly
    /// rather than framed as an RCB-4 reply -- for a caller with no host
    /// frame to answer in the first place, like PolicyMode's own periodic
    /// poll for the phone's display (see net::Telemetry's m5stickv fields).
    ///
    /// @param addr  I2C address (see M5STICKV_OPCODE's own comment).
    /// @param out   up to M5STICKV_MAX_READ detection bytes.
    /// @param len   how many of those were actually read; 0 if the address
    ///              never answered at all.
    /// @return whether the address answered (matches this call's own
    ///         reply-frame "i2c_ok" field) -- NOT whether it had anything to
    ///         report, which `*len == 0` already distinguishes on its own.
    bool readM5StickV(uint8_t addr, uint8_t* out, uint8_t* len);

    /// One arbitrary M5StickV register, read or written directly (this
    /// firmware's own object_detection_I2C_slave.py addresses its whole
    /// 256 byte register file the same way regardless of which one -- see
    /// M5STICKV_OPCODE's own comment for the two named ones, reg 0x00
    /// (control) and reg 0xFE (which detections also trigger a spoken
    /// announcement), that the M5StickV settings page actually shows).
    /// Used for a status display (the settings page has to know a
    /// register's CURRENT value before offering to flip one bit in it) and
    /// for applying a phone-requested toggle (see
    /// net::requestM5StickVWrite(), consumed by PolicyMode's own poll --
    /// same reasoning as the periodic detection read, one I2C bus, one
    /// task ever touching it).
    /// @return whether the I2C transaction itself succeeded.
    bool readM5StickVReg(uint8_t addr, uint8_t reg_addr, uint8_t* value);
    bool writeM5StickVReg(uint8_t addr, uint8_t reg_addr, uint8_t value);

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

    /// Jump the board's own program counter into one of its 120 onboard
    /// motion-table slots (Kondo Heart to Heart's "motion"; ``:call`` in
    /// kxreus's rcb4asm.l), which then runs on the board entirely on its
    /// own -- the same interpreter that runs the board's main loop, not
    /// something this link keeps driving. This is a DIFFERENT source of
    /// servo commands than writeServoPulses(), and the two must never be
    /// used at once: the caller is responsible for not writing servo
    /// targets for as long as a motion might still be running (there is no
    /// "motion finished" the COM protocol makes visible, so that is a
    /// policy decision, not this link's).
    ///
    /// Address = 2944 + number * 2048 (rcb4asm.l's ``*rcb4-rom-address*``
    /// ``:MotionTable`` entry, confirmed byte-identical against a real
    /// Heart to Heart project's own recorded per-motion ``<Address>``). Frame
    /// shape and the ACK/NCK reply are both confirmed against Kondo's own
    /// RCB-4HV command reference (JUMP/CALL section), not guessed.
    ///
    /// @param number  motion table slot, 0..119.
    /// @return true if the board ACKed (accepted the jump, NOT that whatever
    ///         the motion does has finished -- the protocol has no signal
    ///         for that). False on a NCK, a checksum mismatch, or no reply.
    bool callMotion(uint8_t number, uint32_t timeout_ms = 50);

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

    /// An M5StickV request being captured whole by feedFromHost() (see its
    /// own comment) -- [length, opcode, addr, subcmd, ...] up to 7 bytes,
    /// the longest valid one (subcmd 3, WRITE_REG).
    uint8_t m5stickv_req_[7] = {0};
    size_t m5stickv_req_len_ = 0;
    bool capturing_m5stickv_ = false;
};

#endif  // RCB4_LINK_H
