#ifndef STATUS_MODE_H
#define STATUS_MODE_H

#include <mode.h>
#include <rcb4_link.h>

/// Show what the link and the IMU are doing, without relaying anything.
///
/// Deliberately not a passive overlay on BRIDGE: drawing to the LCD takes
/// milliseconds, and a control loop on the far side notices. Stopping the
/// relay to look at it is the honest trade, and the display says so.
class StatusMode : public Mode {
public:
    explicit StatusMode(Rcb4Link& link) : link_(link) {}

    const char* name() const override { return "STATUS"; }

    void enter() override;
    void loop() override;

private:
    static constexpr uint32_t REDRAW_INTERVAL_MS = 200;

    Rcb4Link& link_;
    uint32_t last_draw_ms_ = 0;
};

#endif  // STATUS_MODE_H
