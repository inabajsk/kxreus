#ifndef STATUS_MODE_H
#define STATUS_MODE_H

#include <mode.h>
#include <rcb4_link.h>

/// Show what the link, the IMU and the network are doing, without relaying.
///
/// Deliberately not a passive overlay on BRIDGE: drawing to the LCD takes
/// milliseconds, and a control loop on the far side notices. Stopping the
/// relay to look at it is the honest trade, and the display says so.
///
/// A click switches to the robot's own address as a QR code, filling the
/// panel. That is how a phone gets here: the operator scans the screen and
/// the browser opens the control page, with no address typed, no app, and
/// nothing to discover. The panel is 128x128, so the QR needs all of it --
/// which is why this is a second page rather than a corner of the first.
class StatusMode : public Mode {
public:
    explicit StatusMode(Rcb4Link& link) : link_(link) {}

    const char* name() const override { return "STATUS"; }

    void enter() override;
    /// Turns the M5StickV's apriltag_en control bit back off (see enter()'s
    /// own comment) -- leaving it on would keep the camera doing tag
    /// detection work on every frame even after this mode is no longer the
    /// one reading the results.
    void exit() override;
    void loop() override;
    void onClick() override;

    /// Start (or, while it is up, cancel) the robot's own "<ROBOT_NAME>-wifi"
    /// setup access point -- see net::beginProvisioning(). The gesture that
    /// changes what the radio IS gets the same deliberateness the button's
    /// long press
    /// already gives to changing what the firmware IS: a phone joining that
    /// AP by accident can only reach a form, but it is still not something a
    /// single click should start.
    void onDoubleClick() override;

private:
    static constexpr uint32_t REDRAW_INTERVAL_MS = 200;

    void drawInfo();
    /// Read one M5StickV detection frame and, if an AprilTag is in it, show
    /// its id/confidence/center under the rest of drawInfo()'s own text.
    /// STATUS doesn't relay, so unlike BridgeMode/PolicyMode this can poll
    /// the I2C bus directly on its own schedule rather than only answering
    /// a host's own 0x91 request -- see rcb4_link.h's own M5STICKV_OPCODE
    /// comment for the wire format this parses.
    void drawAprilTag();
    void drawQr();

    Rcb4Link& link_;
    uint32_t last_draw_ms_ = 0;
    bool showing_qr_ = false;
    /// Set when the screen must be repainted whatever the URL says. Comparing
    /// against the last URL alone is not enough: with no address yet, "unset"
    /// and "already drew the unset screen" are the same empty string, and the
    /// display silently kept whatever was on it.
    bool qr_dirty_ = true;
    /// What the QR was last drawn for, so a static screen is not redrawn five
    /// times a second -- rendering a QR is not free.
    String drawn_url_;
};

#endif  // STATUS_MODE_H
