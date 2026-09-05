#ifndef NET_H
#define NET_H

#include <Arduino.h>
#include <IPAddress.h>
#include <Print.h>

/// The radio, and the one link the control protocol needs over it.
///
/// This joins an access point rather than being one. A SoftAP would need no
/// infrastructure, but it takes the phone off the network it was on -- iOS
/// notices the lack of internet and starts offering to leave -- and it leaves
/// the PC unable to reach the robot and the internet at once. Joining the lab
/// AP keeps everyone on one network, which is also what makes a QR code of
/// the robot's own address useful.
///
/// Credentials live in NVS, not in this repository. `tools/wifi_setup.py`
/// writes them once over USB.
///
/// The transport is UDP, and the frames on it are exactly the ones the USB
/// link already carries -- 9 bytes in, 34 bytes out, described in
/// lib/policy_mode/policy_mode.h. UDP because the protocol is already built
/// for loss: the host repeats its command at 10 Hz and the device frees the
/// servos if it stops, so a retransmitted stale command is worse than a
/// dropped one.
namespace net {

/// Where the connection has got to.
enum class Status : uint8_t {
    /// No credentials stored; nothing to connect to.
    UNCONFIGURED,
    /// Trying.
    CONNECTING,
    /// On the network, with an address.
    CONNECTED,
    /// Tried and failed. Retried on a timer, so this is not final.
    FAILED,
};

/// Read the stored credentials and start connecting, if there are any.
///
/// Returns immediately: connecting takes seconds and the control loop cannot
/// wait. Call `poll()` to make progress.
void begin();

/// Advance the connection state machine. Cheap; call it from the main loop.
void poll();

Status status();

/// The address the AP handed out, or 0.0.0.0.
IPAddress ip();

/// The SSID being used, or an empty string.
const char* ssid();

/// The URL a phone should open, e.g. "http://192.168.1.23". Empty until
/// connected. This is what goes in the QR code.
const char* url();

/// Store credentials and reconnect. Passing an empty ssid clears them.
///
/// "Store" means NVS, which is not encrypted: anyone holding the board can
/// read the password back out with esptool. That is the price of a robot that
/// joins the network by itself after a power cycle. See `connect()` for the
/// other side of the trade.
void configure(const char* ssid, const char* password);

/// Connect without writing anything down.
///
/// The credentials live in RAM and are gone at the next power cycle, so
/// nothing on the device can be read back. The cost is that the robot cannot
/// get onto the network on its own -- it needs a USB host to tell it, every
/// boot -- which for a machine meant to run untethered is usually the wrong
/// trade. Offered because it is sometimes the right one.
void connect(const char* ssid, const char* password);

/// Whether the current credentials came from NVS or were given at runtime.
bool credentialsStored();

/// Act on one line of the text setup protocol, and print the answer.
///
///     net?                                what is stored and where it got to
///     net!                                forget the network
///     net <ssid>TAB<password>             store and connect
///     net <ssid>TAB<password>TABvolatile  connect without storing
///
/// The reply never includes the password. This is the one command anyone with
/// the cable can run, and it answers "is it on the network", not "what is the
/// key".
///
/// Lives here rather than in a mode because "is the Wi-Fi up?" is a question
/// worth being able to ask at any time -- it was answerable only in BRIDGE,
/// which is exactly the mode you are not in when you are looking at the
/// network screen and wondering.
///
/// @return true if the line was one of these.
bool handleSetupLine(const char* line, Print& out);

// ---------------------------------------------------------------------
// The page, and the task that serves it
//
// The web server runs in its own FreeRTOS task pinned to core 0, next to the
// Wi-Fi stack, while Arduino's loop() and the control loop have core 1. That
// is not tidiness: a server driven from the control loop only answers while
// that loop is running, so the page would not load unless POLICY were
// already active -- and POLICY is exactly what someone is trying to reach
// when they scan the QR code. Serving from the mode that draws the QR code
// would have had the same shape of problem one mode along.
//
// It also keeps a slow client off the control loop's clock. handleClient()
// blocks for as long as a browser takes; a control step has 33 ms.
//
// The two cores meet at exactly two places, both small and both locked: a
// telemetry snapshot the page reads, and a single pending command slot the
// control loop drains.
// ---------------------------------------------------------------------

/// Publish what the control loop is doing, for the page to display.
///
/// A snapshot rather than a live read: the server task runs whenever a
/// browser asks, which is not a moment the control loop can be interrupted to
/// be measured. One control step of staleness costs nothing on a display that
/// refreshes ten times a second.
/// @param debug  the loop's own view of why it is in the state it is in:
///               the request it last understood, how long since a host
///               spoke, frames accepted, step count, homing attempt, and
///               the latched home error. Not decoration -- a state machine
///               that flaps between two states cannot be diagnosed from the
///               outside by watching it flap.
/// A snapshot of what the control loop is doing.
struct Telemetry {
    uint8_t state;
    float vx;
    float wz;
    uint32_t loop_us;
    uint32_t errors;
    uint32_t overruns;
    uint32_t draw_us;
    uint32_t updated_ms;
};

struct Debug {
    uint8_t request;
    uint32_t quiet_ms;
    uint32_t host_frames;
    uint32_t step;
    uint8_t homing_attempt;
    int16_t home_err;
};
void setTelemetry(uint8_t state, float vx, float wz, uint32_t loop_us,
                  uint32_t errors, uint32_t overruns, uint32_t draw_us,
                  const Debug& debug);

/// Take one waiting command frame, from UDP or from the page.
///
/// @param frame  where to put it.
/// @param len    its length; a datagram of any other size is dropped, since
///               the protocol has exactly one inbound frame size.
/// @return true if a frame was copied out.
bool receiveCommand(uint8_t* frame, size_t len);

/// Whether the last command came over UDP, and so wants a UDP answer. A
/// command from the page was answered by the server task already.
bool lastCommandWasUdp();

/// Send a telemetry frame back to whoever last sent a UDP command.
///
/// Deliberately not a broadcast: the reply goes to the address and port the
/// last command came from, so the device never has to be told where its
/// operator is.
void send(const uint8_t* frame, size_t len);

/// Whether a command has arrived over UDP recently enough to answer.
bool hasPeer();

/// Whether the control loop has published telemetry recently.
///
/// False means nothing is reading commands -- the AtomS3 is not in POLICY
/// mode -- which the page then says out loud instead of looking broken.
bool policyLive();

/// Read back the last published telemetry.
///
/// For the display, which draws the control loop's screen from core 0 for the
/// same reason the server does: repainting this panel costs 16.5 ms, measured,
/// against a 33 ms control period, and it was being paid by the loop four
/// times a second.
Telemetry telemetry();

}  // namespace net

#endif  // NET_H
