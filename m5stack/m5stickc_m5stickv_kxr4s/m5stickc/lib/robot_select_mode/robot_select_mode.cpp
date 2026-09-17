#include "robot_select_mode.h"

#include <M5Unified.h>

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
    M5.Display.println();
    M5.Display.setTextSize(2);
    M5.Display.setTextColor(TFT_CYAN, TFT_BLACK);
    M5.Display.println(
            policy::robotIdName(static_cast<policy::RobotId>(candidate_)));
    M5.Display.setTextSize(1);
    M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);
    M5.Display.println();
    if (just_applied_) {
        M5.Display.setTextColor(TFT_GREEN, TFT_BLACK);
        M5.Display.println("saved -- restarting...");
    } else {
        M5.Display.println("1=next 2=confirm+reboot");
        M5.Display.println("long=mode");
    }
}
