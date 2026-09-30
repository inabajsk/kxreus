// AtomS3 as the RCB-4's COM adapter.
//
//   PC --USB-CDC-- AtomS3 --inverted UART 1.25Mbps 8E1-- RCB-4 mini
//
// Bytes are relayed as they arrive. The one exception is the RCB-4's unused
// opcode 0x90, which this answers with its own IMU: the board has none, so
// this is the only way a host on the far side can read attitude. See
// lib/rcb4_link for the protocol and README.md for the wiring.
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

// The AtomS3's LCD is the button.
constexpr uint8_t BUTTON_PIN = 41;

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

OneButton button(BUTTON_PIN, /*activeLow=*/true, /*pullupActive=*/false);

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

void setup() {
    auto cfg = M5.config();
    M5.begin(cfg);
    M5.Display.setRotation(0);
    M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);

    // The speed given here is ignored: this is USB-CDC, not a UART.
    Serial.begin(115200);
    rcb4_link.begin();
    // Move the actor's weights into RAM once, here, rather than the first
    // time POLICY mode is entered: 235 KiB of memcpy in the middle of a mode
    // switch would look like a hang.
    policy::begin();
    // Joins the lab AP if credentials were stored; returns at once either
    // way, because connecting takes seconds the setup cannot spend.
    net::begin();

    button.attachClick(onClick);
    button.attachDoubleClick(onDoubleClick);
    button.attachMultiClick(onMultiClick);
    button.attachLongPressStart(onLongPress);
    kModes[current_mode]->enter();
}

void loop() {
    button.tick();
    net::poll();
    kModes[current_mode]->loop();
}
