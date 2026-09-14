#ifndef MODE_H
#define MODE_H

#include <Arduino.h>

/// Which physical robot this build's AtomS3 is wired to, set per build (see
/// platformio.ini's -DROBOT_NAME). Printed under every mode's title on the
/// LCD -- with several robots each carrying their own AtomS3, "which one is
/// this" has to be answerable by looking at the one screen the firmware has,
/// not by tracing a USB cable.
#ifndef ROBOT_NAME
#define ROBOT_NAME "robot"
#endif

/// One thing the firmware can be doing, chosen with the button.
///
/// Kept deliberately small: enter() and exit() bracket a mode, loop() runs
/// while it is the current one, and name() is what the LCD shows. There is no
/// task per mode -- the relay has to see every byte the moment it arrives, and
/// handing that to a scheduler only adds latency to the one path that cannot
/// afford it.
class Mode {
public:
    virtual ~Mode() = default;

    /// Short label for the LCD. Fits the 128x128 panel at text size 2.
    virtual const char* name() const = 0;

    /// Called once when this mode becomes current.
    virtual void enter() {}

    /// Called once when leaving, before the next mode's enter().
    virtual void exit() {}

    /// Called as fast as the main loop can manage.
    virtual void loop() = 0;

    // The button belongs to whichever mode is current, except for the long
    // press, which always cycles modes. Changing what the firmware IS should
    // take a deliberate gesture; the quick ones are free for whatever the
    // current mode does -- in POLICY, turning the servos on and off.
    //
    // A mode that wants neither simply does not override them.

    /// A short press while this mode is current.
    virtual void onClick() {}

    /// Two short presses.
    virtual void onDoubleClick() {}
};

#endif  // MODE_H
