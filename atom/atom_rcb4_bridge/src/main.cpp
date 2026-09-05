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
// Two of them driving the same wire would corrupt both, which is why STATUS
// stops the relay rather than drawing over it, and why POLICY frees the
// servos on the way out.

#include <Arduino.h>
#include <M5Unified.h>
#include <OneButton.h>
#include <bridge_mode.h>
#include <mode.h>
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

void onClick() { enterMode(current_mode + 1); }

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

    button.attachClick(onClick);
    kModes[current_mode]->enter();
}

void loop() {
    button.tick();
    kModes[current_mode]->loop();
}
