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
    void loop() override;

private:
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
    uint32_t last_probe_ms_ = 0;
    bool board_ok_ = false;
    bool imu_ok_ = false;
};

#endif  // BRIDGE_MODE_H
