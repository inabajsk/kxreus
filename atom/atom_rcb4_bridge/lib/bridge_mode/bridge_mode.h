#ifndef BRIDGE_MODE_H
#define BRIDGE_MODE_H

#include <mode.h>
#include <rcb4_link.h>

/// Relay the host's bytes to the RCB-4 and back, answering 0x90 locally.
///
/// This is what the adapter is for, so it is the mode the firmware starts in.
/// The loop does nothing but move bytes: no drawing, no delays, nothing that
/// could sit between a command and the board.
class BridgeMode : public Mode {
public:
    explicit BridgeMode(Rcb4Link& link) : link_(link) {}

    const char* name() const override { return "BRIDGE"; }

    void enter() override;

    /// Show the network state, since a bridge that is also on Wi-Fi has one.
    void onClick() override;
    void loop() override;

private:
    /// Take a byte of the text setup protocol, if this is one.
    ///
    /// The relay is byte-transparent by design, so anything sharing the
    /// stream has to be unambiguous against RCB-4 traffic -- and 'n' alone is
    /// not: it is 0x6E, a perfectly good frame length. So the first four
    /// bytes are held and checked against "net?", "net!" and "net ", and the
    /// moment they diverge every held byte is handed to the relay in order,
    /// as though it had never been looked at. A 110 byte frame therefore
    /// costs four bytes of delay and nothing else.
    ///
    /// Only ever entered at a frame boundary, so a byte in the middle of
    /// someone's frame -- which can be any value at all -- is never examined.
    ///
    /// @return true if the byte was consumed by the setup protocol.
    bool feedSetup(uint8_t byte);

    /// Hand one byte to the relay, answering the IMU opcode if it completes
    /// one. The single path by which a host byte reaches the board.
    void relay(uint8_t byte);

    /// Give back every byte held by an attempt at the setup prefix.
    void releaseSetup();
    static constexpr int BOARD_LAMP_Y = 40;
    static constexpr int IMU_LAMP_Y = 68;
    /// How quiet the host has to be before it is safe to send a probe of our
    /// own. Longer than the gap between commands in a control loop, so a
    /// running loop is never interrupted -- the lamp simply stops updating
    /// while the link is busy, which is the honest trade.
    static constexpr uint32_t HOST_IDLE_MS = 500;
    /// How often to re-check an idle link.
    static constexpr uint32_t PROBE_INTERVAL_MS = 1000;

    Rcb4Link& link_;
    char setup_line_[96] = {0};
    size_t setup_len_ = 0;
    bool in_setup_ = false;
    uint32_t last_probe_ms_ = 0;
    bool board_ok_ = false;
    bool imu_ok_ = false;
};

#endif  // BRIDGE_MODE_H
