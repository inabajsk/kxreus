#ifndef ROBOT_SELECT_MODE_H
#define ROBOT_SELECT_MODE_H

#include <mode.h>
#include <policy.h>
#include <rcb4_link.h>

/// Lets an operator standing at the robot -- no PC, no USB cable, nothing
/// but the button -- choose which of the five robots THIS AtomS3 is.
///
/// The other way to do this is net.cpp's own serial "robot <name>"
/// command (see host_relay.cpp's own feedSetup()), which needs a USB
/// connection and a terminal. This exists for the common case instead: a
/// fresh AtomS3 that has just been screwed into a robot's body, with
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
///
/// enter() also tries a hardware guess, over the RCB-4 UART this mode's
/// own Rcb4Link shares with BRIDGE/POLICY: the RCB-4 keeps a live RAM
/// table of every servo's own current position (see Rcb4Link::
/// readServoPulses()'s own comment), 35 slots regardless of which are
/// actually wired, and an empty slot reads back exactly 0 -- so which
/// slots are non-zero says which servo ids are physically present on
/// THIS body, before anyone has told the firmware which robot it is.
/// Compared against each of the five robots' own compiled-in id list
/// (policy::servoIdsOfRobot() -- for kxra6g, whose modular body has no
/// ONE fixed set to compile in, the union of every part it could carry;
/// see that function's own comment), the fewest differences wins and
/// becomes the starting candidate -- a suggestion, not an answer: still
/// only a click away from being overridden, and still not written
/// anywhere until the same double click every other path here already
/// needs. No RCB-4 attached (or one that never answers) leaves the
/// candidate at whatever this unit already is, same as before this
/// existed.
class RobotSelectMode : public Mode {
public:
    explicit RobotSelectMode(Rcb4Link& link) : link_(link) {}

    const char* name() const override { return "ROBOT"; }

    void enter() override;
    void loop() override;

    /// Cycle the highlighted candidate. Purely cosmetic -- see this
    /// class's own top comment.
    void onClick() override;

    /// Commit the highlighted candidate to NVS and restart.
    void onDoubleClick() override;

private:
    /// Scan the RCB-4's own live servo table and score every robot
    /// against it -- see this class's own top comment. Sets
    /// detected_valid_/detected_/detected_diff_; leaves them alone (does
    /// NOT clear a previous result) if the scan itself fails, so a board
    /// that answered once and then, say, a cable wiggled loose mid-menu
    /// does not erase a suggestion that was good a moment ago.
    void detectFromHardware();

    void draw();

    Rcb4Link& link_;

    size_t candidate_ = 0;
    bool just_applied_ = false;

    /// This boot's own hardware guess, from detectFromHardware() -- shown
    /// on screen as a hint regardless of what candidate_ has moved to
    /// since, so a click away from it is never silently lost.
    bool detected_valid_ = false;
    policy::RobotId detected_ = policy::RobotId::KXRL4T;
    /// How many of the up-to-35 servo slots disagreed with detected_'s
    /// own expected id list. 0 is an exact match; the phone-facing number
    /// an operator uses to judge "trust this" versus "check the wiring".
    size_t detected_diff_ = 0;

    /// The wired ids themselves (see detectFromHardware()'s own comment),
    /// shown on screen alongside the guess -- an incomplete or
    /// mid-assembly body (arms not on yet, a 2-axis leg standing in for
    /// its final 5-axis one) will never score 0 against any of the four
    /// fixed-body robots (or, most of the time, against kxra6g's own
    /// union set either -- see servoIdsOfRobot()'s own comment), and the
    /// raw id list is what lets an operator tell "this is normal for how
    /// far the build has got" from "something is actually wired wrong" --
    /// the diff count alone cannot say which.
    uint8_t wired_ids_[Rcb4Link::SERVO_SLOTS] = {0};
    size_t wired_count_ = 0;
};

#endif  // ROBOT_SELECT_MODE_H
