#ifndef BRIDGE_MODE_H
#define BRIDGE_MODE_H

#include <mode.h>
#include <rcb4_link.h>

/// The RCB-4 relay's own lamp display, and this mode's ownership of the
/// real RCB-4 UART.
///
/// The actual byte relay (Serial and, since EspNowLink exists, a PC-side
/// ATOM Echo over ESP-NOW) now runs unconditionally from every Mode -- see
/// HostRelay -- so the IMU/M5StickV opcodes answer no matter what the
/// button has cycled to. What is still exclusive to THIS mode is ordinary
/// RCB-4 passthrough: enter()/exit() are what flip
/// Rcb4Link::setPassthroughEnabled() on and off, since only BRIDGE mode
/// leaves the real RCB-4's own UART free for a host to drive directly (see
/// that function's own comment for why POLICY mode must not).
class BridgeMode : public Mode {
public:
    explicit BridgeMode(Rcb4Link& link) : link_(link) {}

    const char* name() const override { return "BRIDGE"; }

    void enter() override;
    void exit() override;

    /// Show the network state, since a bridge that is also on Wi-Fi has one.
    void onClick() override;
    void loop() override;

private:
    /// 16 px apart, starting after the title row above (now two lines --
    /// ROBOT_NAME at size 2, this mode's own name at size 1 below it, see
    /// enter()'s own comment -- 24 px tall in total) and back to back with
    /// the button legend below them -- see drawLamp()'s own comment on why
    /// its row shrank to match.
    static constexpr int BOARD_LAMP_Y = 24;
    static constexpr int IMU_LAMP_Y = 40;
    /// M5StickV/UnitV bridge, opcode 0x91 -- see M5STICKV_DEFAULT_ADDR's own
    /// comment. A real I2C transaction, not just a label: answers the same
    /// question the RCB4/IMU lamps above already do for their own buses --
    /// is anything actually there right now, not just "does this firmware
    /// know how to talk to one".
    static constexpr int I2C_LAMP_Y = 56;
    /// A PC-side ATOM Echo, reachable over ESP-NOW (see EspNowLink) --
    /// three states, not two, since "linked but idle" and "actively
    /// relaying a frame right now" are both worth telling apart from
    /// "nothing paired has ever been heard from" (see drawEspNowLamp()).
    static constexpr int ESPNOW_LAMP_Y = 72;
    /// A phone's own control page, reachable over Wi-Fi (see
    /// net::phoneActive()) -- two states, not three: unlike EspNowLink's
    /// byte relay, the page's tick() polls at a fixed 10 Hz regardless of
    /// whether the operator is doing anything, so there is no separate
    /// "linked but idle" to distinguish from "actively driving it" the
    /// way the ECHO lamp's own third state does.
    static constexpr int PHONE_LAMP_Y = 88;
    /// How quiet the host has to be before it is safe to send a probe of our
    /// own. Longer than the gap between commands in a control loop, so a
    /// running loop is never interrupted -- the lamp simply stops updating
    /// while the link is busy, which is the honest trade.
    static constexpr uint32_t HOST_IDLE_MS = 500;
    /// How often to re-check an idle link.
    static constexpr uint32_t PROBE_INTERVAL_MS = 1000;
    /// How often the ESP-NOW lamp's own three-state read is refreshed --
    /// cheap (no I/O of its own, just EspNowLink's already-maintained
    /// timestamps), but still not worth redoing every loop() iteration.
    static constexpr uint32_t ESPNOW_LAMP_INTERVAL_MS = 200;

    Rcb4Link& link_;
    uint32_t last_probe_ms_ = 0;
    uint32_t last_espnow_draw_ms_ = 0;
    bool board_ok_ = false;
    bool imu_ok_ = false;
    /// One per possible M5StickV address -- see Rcb4Link::M5STICKV_
    /// DEFAULT_ADDR/M5STICKV_ALT_ADDR's own comment on the stereo pair
    /// this checks for both of, rather than assuming a single unit.
    bool i2c_ok_default_ = false;
    bool i2c_ok_alt_ = false;
    /// 0=not present, 1=linked/idle, 2=actively relaying -- see
    /// drawEspNowLamp(). Redrawn only on change, same reasoning as the
    /// other lamps.
    int espnow_state_ = -1;  // -1: never drawn yet, forces the first paint
    /// Mirrors net::phoneActive() -- see PHONE_LAMP_Y's own comment.
    bool phone_ok_ = false;
};

#endif  // BRIDGE_MODE_H
