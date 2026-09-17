#ifndef ROBOT_SELECT_MODE_H
#define ROBOT_SELECT_MODE_H

#include <mode.h>
#include <policy.h>

/// Lets an operator standing at the robot -- no PC, no USB cable, nothing
/// but the button -- choose which of the three robots THIS M5StickC is.
///
/// The other way to do this is net.cpp's own serial "robot <name>"
/// command (see host_relay.cpp's own feedSetup()), which needs a USB
/// connection and a terminal. This exists for the common case instead: a
/// fresh M5StickC that has just been screwed into a robot's body, with
/// nothing plugged into its USB port at all.
///
/// A click only moves a HIGHLIGHTED candidate -- nothing is written to
/// NVS, and nothing this unit already is changes, until a double click
/// deliberately confirms it, the same "looking must not be doing"
/// principle StatusMode's own QR screen and PolicyMode's onClick() both
/// already follow. Confirming restarts the device itself right away
/// (see policy::setRobotId()'s own comment on why a robot switch only
/// ever takes effect on the next boot) -- there is no PC on hand to send
/// a reboot from, so this closes the loop on its own instead of leaving
/// the screen saying "reboot to apply" with no way to do it.
class RobotSelectMode : public Mode {
public:
    const char* name() const override { return "ROBOT"; }

    void enter() override;
    void loop() override;

    /// Cycle the highlighted candidate. Purely cosmetic -- see this
    /// class's own top comment.
    void onClick() override;

    /// Commit the highlighted candidate to NVS and restart.
    void onDoubleClick() override;

private:
    void draw();

    size_t candidate_ = 0;
    bool just_applied_ = false;
};

#endif  // ROBOT_SELECT_MODE_H
