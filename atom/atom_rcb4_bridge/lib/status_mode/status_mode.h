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
    void loop() override;
    void onClick() override;

private:
    static constexpr uint32_t REDRAW_INTERVAL_MS = 200;

    void drawInfo();
    void drawQr();
    /// Read the text setup protocol. Nothing is being relayed in this mode,
    /// so unlike BRIDGE there is no RCB-4 traffic to disambiguate against and
    /// a line reader is the whole of it.
    void readSetup();

    Rcb4Link& link_;
    uint32_t last_draw_ms_ = 0;
    bool showing_qr_ = false;
    /// Set when the screen must be repainted whatever the URL says. Comparing
    /// against the last URL alone is not enough: with no address yet, "unset"
    /// and "already drew the unset screen" are the same empty string, and the
    /// display silently kept whatever was on it.
    bool qr_dirty_ = true;
    char setup_line_[96] = {0};
    size_t setup_len_ = 0;
    /// What the QR was last drawn for, so a static screen is not redrawn five
    /// times a second -- rendering a QR is not free.
    String drawn_url_;
};

#endif  // STATUS_MODE_H
