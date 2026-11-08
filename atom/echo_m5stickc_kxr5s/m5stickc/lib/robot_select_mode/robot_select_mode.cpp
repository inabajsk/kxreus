#include "robot_select_mode.h"

#include <M5Unified.h>

void RobotSelectMode::detectFromHardware() {
    uint16_t pulses[Rcb4Link::SERVO_SLOTS];
    // The RCB-4 declines a read while busy with its own servo cycle, same
    // as every other caller of this -- readServoPulses() already retries
    // internally (see its own `attempts`); one more round here would only
    // buy back the rare case of a genuinely slow/loaded board, at the
    // cost of this screen feeling sluggish to open every single time.
    // Leaves detected_valid_/detected_/detected_diff_ untouched on
    // failure -- see this class's own header comment for why.
    if (!link_.readServoPulses(pulses)) return;

    // Slot i is "wired" iff MotorPosition there is non-zero -- see
    // Rcb4Link::readServoPulses()'s own comment: "a slot with no servo in
    // it reads 0".
    bool wired[Rcb4Link::SERVO_SLOTS];
    for (size_t i = 0; i < Rcb4Link::SERVO_SLOTS; i++) {
        wired[i] = pulses[i] != 0;
    }

    bool best_valid = false;
    policy::RobotId best_id = policy::RobotId::KXRL4T;
    size_t best_diff = Rcb4Link::SERVO_SLOTS + 1;  // worse than any real score

    for (size_t r = 0; r < static_cast<size_t>(policy::RobotId::COUNT); r++) {
        const policy::RobotId id = static_cast<policy::RobotId>(r);
        size_t expected_count = 0;
        const uint8_t* expected_ids = policy::servoIdsOfRobot(id, &expected_count);
        if (expected_ids == nullptr) continue;

        // This robot's own expected set, as a bitmap over the same 35
        // slots -- an id the actual body leaves unwired (see the head-
        // axis comments in each robot's own lib/policy_mode/
        // policy_mode.cpp) still falls out for free here, the same
        // bounds check that also drops any id >= SERVO_SLOTS.
        bool expected[Rcb4Link::SERVO_SLOTS] = {false};
        for (size_t i = 0; i < expected_count; i++) {
            const uint8_t id_byte = expected_ids[i];
            if (id_byte < Rcb4Link::SERVO_SLOTS) expected[id_byte] = true;
        }

        // Symmetric difference: counts both "expected here but nothing is
        // wired" and "something is wired here but this robot never uses
        // it" -- the latter is what keeps a smaller robot (fewer ids)
        // from ever out-scoring a larger one just because its own
        // (small) expected set happens to be a subset of what is
        // actually wired.
        size_t diff = 0;
        for (size_t i = 0; i < Rcb4Link::SERVO_SLOTS; i++) {
            if (wired[i] != expected[i]) diff++;
        }

        if (!best_valid || diff < best_diff) {
            best_valid = true;
            best_id = id;
            best_diff = diff;
        }
    }

    if (best_valid) {
        detected_valid_ = true;
        detected_ = best_id;
        detected_diff_ = best_diff;
        wired_count_ = 0;
        for (size_t i = 0; i < Rcb4Link::SERVO_SLOTS; i++) {
            if (wired[i]) wired_ids_[wired_count_++] = static_cast<uint8_t>(i);
        }
    }
}

void RobotSelectMode::enter() {
    // Start the wheel on whatever this unit already is, so "look, it's
    // already right, just confirm" is the common case for a unit being
    // re-checked rather than freshly set up. An unconfigured unit starts
    // at index 0 (kxrl4t) -- as arbitrary a starting point as
    // policy::robotId()'s own meaningless default, since nothing is
    // written until a double click confirms one.
    candidate_ = policy::robotConfigured() ? static_cast<size_t>(policy::robotId())
                                            : 0;
    just_applied_ = false;

    detectFromHardware();
    // A hardware guess overrides the wheel's own starting point (but
    // never what this unit already is, until confirmed) -- if this unit
    // has never been configured, or the servos actually wired to it
    // disagree with what it was last told it is, the hardware is the
    // more current answer of the two.
    if (detected_valid_ &&
        (!policy::robotConfigured() ||
         detected_ != policy::robotId())) {
        candidate_ = static_cast<size_t>(detected_);
    }

    draw();
}

void RobotSelectMode::onClick() {
    candidate_ = (candidate_ + 1) % static_cast<size_t>(policy::RobotId::COUNT);
    just_applied_ = false;
    draw();
}

void RobotSelectMode::onDoubleClick() {
    if (!policy::setRobotId(static_cast<policy::RobotId>(candidate_))) {
        // NVS write failed (see setRobotId()'s own comment) -- say so
        // rather than restarting into whatever this unit already was,
        // silently, with no sign anything went wrong.
        M5.Display.clear();
        M5.Display.setCursor(0, 0);
        M5.Display.setTextSize(1);
        M5.Display.setTextColor(TFT_RED, TFT_BLACK);
        M5.Display.println("ERR could not\nsave to NVS");
        return;
    }
    just_applied_ = true;
    draw();
    // A person on hand at the robot, with no PC to send a reboot from, is
    // exactly who this mode is for -- restarting here itself is what
    // makes the button alone enough. See policy::setRobotId()'s own
    // comment for why a robot switch does not take effect any sooner
    // than this than a reboot ever would.
    delay(1200);  // let the confirmation actually be read first
    ESP.restart();
}

void RobotSelectMode::loop() {}

void RobotSelectMode::draw() {
    M5.Display.clear();
    M5.Display.setCursor(0, 0);
    M5.Display.setTextSize(2);
    M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);
    M5.Display.println("ROBOT?");
    M5.Display.setTextSize(1);
    M5.Display.setTextColor(TFT_DARKGREY, TFT_BLACK);
    M5.Display.print("now: ");
    M5.Display.println(policy::robotConfigured()
                                ? policy::robotIdName(policy::robotId())
                                : "(none)");
    M5.Display.setTextSize(2);
    M5.Display.setTextColor(TFT_CYAN, TFT_BLACK);
    M5.Display.println(
            policy::robotIdName(static_cast<policy::RobotId>(candidate_)));
    M5.Display.setTextSize(1);
    M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);
    if (just_applied_) {
        M5.Display.setTextColor(TFT_GREEN, TFT_BLACK);
        M5.Display.println("saved -- restarting...");
    } else {
        // The hardware guess, shown regardless of where candidate_ has
        // since moved to -- see this class's own header comment on why
        // this is a hint, never applied on its own.
        if (detected_valid_) {
            M5.Display.setTextColor(detected_diff_ == 0 ? TFT_GREEN
                                                          : TFT_YELLOW);
            M5.Display.printf("wired: %s (%u differ)\n",
                              policy::robotIdName(detected_),
                              static_cast<unsigned>(detected_diff_));
            // The raw id list itself -- see this class's own header
            // comment on wired_ids_ for why the diff count alone is not
            // enough to tell "expected for how far this build has got"
            // from "actually wired wrong". Wrapped by the display's own
            // default text wrap, not by anything counted here -- with up
            // to 35 two-digit ids this can run to several lines, more of
            // them on this board's own narrower (80 px) panel than
            // AtomS3's.
            M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);
            M5.Display.print("ids:");
            if (wired_count_ == 0) {
                M5.Display.print(" (none)");
            } else {
                for (size_t i = 0; i < wired_count_; i++) {
                    M5.Display.printf(" %u", wired_ids_[i]);
                }
            }
            M5.Display.println();
        } else {
            M5.Display.setTextColor(TFT_DARKGREY, TFT_BLACK);
            M5.Display.println("wired: no RCB-4 seen");
        }
        M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);
        M5.Display.println("1=next 2=ok long=mode");
    }
}
