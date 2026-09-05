#ifndef MODE_H
#define MODE_H

#include <Arduino.h>

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
};

#endif  // MODE_H
