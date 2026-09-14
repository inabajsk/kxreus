// M5StickC as the RCB-4's COM adapter.
//
//   PC --USB(CP2104 UART0)-- StickC --inverted UART 1.25Mbps 8E1-- RCB-4 mini
//
// Bytes are relayed as they arrive. The exceptions are two of the RCB-4's
// unused opcodes: 0x90, which this answers with its own IMU (the RCB-4 has
// none, so this is the only way a host on the far side can read attitude),
// and 0x91, an I2C bridge to an M5StickV wired to this board's Grove
// connector. See lib/rcb4_link for both protocols.
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
#include <bridge_mode.h>
#include <mode.h>
#include <net.h>
#include <policy_mode.h>
#include <policy.h>
#include <rcb4_link.h>
#include <status_mode.h>

namespace {

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

// M5StickC's front "M5" button, already read by M5Unified as M5.BtnA
// (updated by M5.update() -- see loop()); its click-count/hold tracking (see
// onLongPress/onClick/onDoubleClick/onMultiClick's own dispatch) already
// does everything OneButton would. The side button (M5.BtnB) exists too but
// nothing here uses it.
constexpr uint32_t BUTTON_GAP_MS = 700;

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
// cannot get in on, with no phone able to reach it at all, and robots that
// boot straight into POLICY (see START_MODE_INDEX below) never see STATUS.
// A single or double click was not free to reuse for this: every mode
// already answers to both (POLICY's own onDoubleClick starts and stops the
// policy, for one), and a long press already means "cycle modes" -- reusing
// either here would have broken something that already works. A triple
// click is free in every mode, so this runs instead of, not on top of,
// whatever the current mode would have done with it.
void onMultiClick() {
    if (!net::provisioning() && net::status() != net::Status::STANDALONE_AP) {
        net::beginProvisioning();
    }
}

}  // namespace

// 0 unless a build overrides it. Per-robot rather than hard-coded here for
// the same reason ROBOT_NAME is: this source is shared across every robot
// this board type runs.
#ifndef DISPLAY_ROTATION
#define DISPLAY_ROTATION 0
#endif

void setup() {
    auto cfg = M5.config();
    M5.begin(cfg);
    M5.Display.setRotation(DISPLAY_ROTATION);
    M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);

    // This board's Serial is a real UART0 carried out over its CP2104 USB
    // bridge chip, so the speed given here is the one the PC's serial port
    // must also be opened at.
    Serial.begin(115200);
    rcb4_link.begin();
    // Brings up the M5StickV's I2C bus -- see Rcb4Link::beginM5StickV's own
    // comment. Called unconditionally, same as the RCB-4 UART above, since
    // nothing here can yet tell whether an M5StickV is actually wired up --
    // the I2C calls that would fail on their own if not, not this.
    Rcb4Link::beginM5StickV();
    // Move the actor's weights into RAM once, here, rather than the first
    // time POLICY mode is entered: 235 KiB of memcpy in the middle of a mode
    // switch would look like a hang.
    policy::begin();
    // Joins the lab AP if credentials were stored; returns at once either
    // way, because connecting takes seconds the setup cannot spend.
    net::begin();

    M5.BtnA.setHoldThresh(BUTTON_GAP_MS);
    kModes[current_mode]->enter();
}

void loop() {
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
    net::poll();
    kModes[current_mode]->loop();
}
