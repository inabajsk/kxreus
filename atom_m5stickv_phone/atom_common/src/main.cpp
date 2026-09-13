// AtomS3 as the RCB-4's COM adapter.
//
//   PC --USB-CDC-- AtomS3 --inverted UART 1.25Mbps 8E1-- RCB-4 mini
//
// Bytes are relayed as they arrive. The exceptions are two of the RCB-4's
// unused opcodes: 0x90, which this answers with its own IMU (the board has
// none, so this is the only way a host on the far side can read attitude),
// and 0x91, an I2C bridge to an M5StickV wired to this ATOM's Grove
// connector (G1/G2, freed for this by moving the RCB-4 UART itself to
// G5/G6 -- see lib/rcb4_link's own comment). See lib/rcb4_link for both
// protocols and README.md for the wiring.
//
// The button cycles three modes, and they are modes rather than options
// because each one wants the RCB-4's UART to itself:
//
//   BRIDGE  the PC speaks RCB-4 and this carries bytes. The default.
//   STATUS  relaying stops; shows what has been going through.
//   POLICY  this speaks RCB-4 and runs the trained actor itself, with the PC
//           reduced to sending three numbers of velocity command. See
//           lib/policy_mode.
//
// A LONG press cycles them. A short press, and a double press, go to whatever
// the current mode makes of them -- in POLICY, servos on and off, and the
// policy running or not, so the hand can be brought to its stance with
// nothing attached but power. A TRIPLE click, in every mode, forces Wi-Fi
// setup back up (see onMultiClick) -- the one gesture that does not answer
// to whatever mode is current, for a robot stuck with no other way for a
// phone to reach it at all.
//
// Two of them driving the same wire would corrupt both, which is why STATUS
// stops the relay rather than drawing over it, and why POLICY frees the
// servos on the way out.

#include <Arduino.h>
#include <M5Unified.h>
#include <OneButton.h>
#include <bridge_mode.h>
#include <mode.h>
#include <net.h>
#include <policy_mode.h>
#include <policy.h>
#include <rcb4_link.h>
#include <status_mode.h>

namespace {

#if !defined(ARDUINO_M5STACK_FIRE)
// The AtomS3's LCD is the button.
constexpr uint8_t BUTTON_PIN = 41;
#endif

Rcb4Link rcb4_link;
BridgeMode bridge_mode(rcb4_link);
StatusMode status_mode(rcb4_link);
PolicyMode policy_mode(rcb4_link);

Mode* const kModes[] = {&bridge_mode, &status_mode, &policy_mode};
constexpr size_t kModeCount = sizeof(kModes) / sizeof(kModes[0]);

// Which mode the firmware comes up in. BRIDGE, unless a build says otherwise:
// booting straight into POLICY is for testing it from a PC with no one
// standing at the button, and it is safe only because POLICY arrives with the
// servos freed and stays that way until a host asks it to run.
#ifndef START_MODE_INDEX
#define START_MODE_INDEX 0
#endif
size_t current_mode = START_MODE_INDEX;

// M5Stack FIRE has no touch-screen button to wire a GPIO to like AtomS3's
// LCD: it has three physical buttons instead, already read by M5Unified
// (M5.BtnA/B/C, updated by M5.update() -- see loop()). BtnA (the front-left
// "M5" button) stands in for AtomS3's single button one-for-one, since
// Button_Class already tracks click count and hold the same way OneButton
// does below (see onLongPress/onClick/onDoubleClick/onMultiClick's own
// dispatch, shared by both boards).
#if defined(ARDUINO_M5STACK_FIRE)
constexpr uint32_t BUTTON_GAP_MS = 700;
#else
OneButton button(BUTTON_PIN, /*activeLow=*/true, /*pullupActive=*/false);
#endif

void enterMode(size_t index) {
    kModes[current_mode]->exit();
    current_mode = index % kModeCount;
    kModes[current_mode]->enter();
}

// A long press changes what the firmware is; a short one asks the current
// mode to do something. The slow gesture guards the change that matters:
// leaving POLICY frees the servos and hands the UART to the relay, which is
// not something to do by brushing the screen.
void onLongPress() { enterMode(current_mode + 1); }
void onClick() { kModes[current_mode]->onClick(); }
void onDoubleClick() { kModes[current_mode]->onDoubleClick(); }

// A Wi-Fi recovery gesture reachable from WHATEVER mode is showing, not only
// from STATUS's own double-click (see StatusMode::onDoubleClick) -- the
// situation this exists for is a robot stuck retrying Wi-Fi credentials it
// cannot get in on, with no phone able to reach it at all, and kxrl4d and
// friends all boot straight into POLICY (see START_MODE_INDEX below), not
// STATUS. A single or double click was not free to reuse for this: every
// mode already answers to both (POLICY's own onDoubleClick starts and stops
// the policy, for one), and a long press already means "cycle modes" --
// reusing either here would have broken something that already works.
// A triple click is free in every mode, so this runs instead of, not on top
// of, whatever the current mode would have done with it.
void onMultiClick() {
    if (!net::provisioning() && net::status() != net::Status::STANDALONE_AP) {
        net::beginProvisioning();
    }
}

}  // namespace

// 0 for every robot except one whose AtomS3 sits mounted upside down on the
// body -- see kxrl2g's own platformio.ini, the only build that overrides
// this to 2 (180 degrees). Per-robot rather than hard-coded here for the
// same reason ROBOT_NAME is: this source is shared across all of them.
#ifndef DISPLAY_ROTATION
#define DISPLAY_ROTATION 0
#endif

void setup() {
    auto cfg = M5.config();
    M5.begin(cfg);
    M5.Display.setRotation(DISPLAY_ROTATION);
    M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);

#if defined(ARDUINO_M5STACK_FIRE)
    // Unlike AtomS3's native USB-CDC, this board's Serial is a real UART0
    // carried out over its CP2104 USB bridge chip, so the speed given here
    // is the one the PC's serial port must also be opened at.
#else
    // The speed given here is ignored: this is USB-CDC, not a UART.
#endif
    Serial.begin(115200);
    rcb4_link.begin();
    // A separate bus on AtomS3, the same one M5.begin() already brought up
    // on M5Stack FIRE (see Rcb4Link::beginM5StickV's own comment); called
    // unconditionally either way, same as the RCB-4 UART above, since
    // nothing here can yet tell whether an M5StickV is actually wired to
    // Port A -- the I2C calls that would fail on their own if not, not this.
    Rcb4Link::beginM5StickV();
    // Move the actor's weights into RAM once, here, rather than the first
    // time POLICY mode is entered: 235 KiB of memcpy in the middle of a mode
    // switch would look like a hang.
    policy::begin();
    // Joins the lab AP if credentials were stored; returns at once either
    // way, because connecting takes seconds the setup cannot spend.
    net::begin();

#if defined(ARDUINO_M5STACK_FIRE)
    M5.BtnA.setHoldThresh(BUTTON_GAP_MS);
#else
    button.attachClick(onClick);
    button.attachDoubleClick(onDoubleClick);
    button.attachMultiClick(onMultiClick);
    button.attachLongPressStart(onLongPress);
#endif
    kModes[current_mode]->enter();
}

void loop() {
#if defined(ARDUINO_M5STACK_FIRE)
    M5.update();
    if (M5.BtnA.wasHold()) {
        onLongPress();
    } else if (M5.BtnA.wasDecideClickCount()) {
        switch (M5.BtnA.getClickCount()) {
            case 1: onClick(); break;
            case 2: onDoubleClick(); break;
            default: onMultiClick(); break;  // 3 or more
        }
    }
#else
    button.tick();
#endif
    net::poll();
    kModes[current_mode]->loop();
}
