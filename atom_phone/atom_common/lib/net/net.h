#ifndef NET_H
#define NET_H

#include <Arduino.h>
#include <IPAddress.h>
#include <Print.h>

#include <policy.h>  // POLICY_ACT_DIM -- this header is recompiled per robot

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
    /// Broadcasting its own access point so a phone with no other way in can
    /// hand it the SSID/password of whichever network this robot is at
    /// today. See beginProvisioning().
    PROVISIONING,
    /// Broadcasting its own access point PERMANENTLY and serving the control
    /// page over it, rather than joining anyone else's network at all. For
    /// wherever this robot goes that has no Wi-Fi to join in the first
    /// place. See useOwnAccessPoint().
    STANDALONE_AP,
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

/// Open this robot's own access point (no password, SSID below) and a
/// captive-portal DNS so ANY phone -- Android or iPhone, on no network at all
/// yet -- can join it and be handed a form for the SSID/password of whatever
/// Wi-Fi this robot should use here. No USB, no PC, no app: joining the AP is
/// enough for a phone's OS to pop the "sign in to network" page on its own.
///
/// Tears down any current STA connection first (this robot can be at only
/// one place on the radio at a time), which is the point when moving it to a
/// new site: call this again to reconfigure rather than needing a cable.
void beginProvisioning();

/// Leave provisioning, e.g. because it was entered by mistake. Submitting the
/// form calls configure() instead, which leaves it on its own. Also leaves
/// STANDALONE_AP, the same gesture undoing either of this device's two ways
/// of running its own access point.
void stopProvisioning();

/// Whether the setup AP above is currently up (not STANDALONE_AP -- that one
/// answers to status(), the way a normal Wi-Fi join does).
bool provisioning();

/// Stop trying to join anyone else's network and broadcast this robot's own
/// access point (see beginProvisioning()'s SSID) for good, serving the
/// control page over it directly. Persisted like configure()'s credentials
/// are, so it survives a power cycle without the button dance that reaches
/// it the first time -- the point is a robot that comes up ready to control
/// from a phone wherever it is unboxed, Wi-Fi or not.
void useOwnAccessPoint();

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
    /// Gravity in the root frame -- the same vector buildObs() feeds the
    /// policy as projected_gravity, published unconditionally (not just
    /// while running) so a phone can draw an attitude indicator regardless
    /// of state. A unit vector; [0,0,-1] is level.
    float gravity[3];
    /// The IMU chip's own reading, BEFORE kImuToRoot (each robot's mounting
    /// rotation) is applied -- accel in g, gyro in deg/s, M5Unified's native
    /// units, in the AtomS3's own frame. Published unconditionally and
    /// independent of use_imu_: `gravity` above is what the POLICY sees
    /// (control-facing, honours use_imu_'s fixed-value fallback), this is
    /// what the CHIP actually reports regardless of whether that feeds
    /// control -- kept so a field log can re-derive or check a robot's own
    /// mounting rotation after the fact, without having to trust or invert
    /// whatever kImuToRoot happened to be baked into the firmware that
    /// produced the log. Zero if no IMU answered at all.
    float accel_raw[3];
    float gyro_raw[3];
    /// How many of the two arrays below are real servos (see PolicyMode's
    /// own g_servo_count): a joint with no wired servo -- the head/gripper
    /// joints on some of these robots -- is never included, so this can be
    /// smaller than POLICY_ACT_DIM. Both arrays are in the same fixed order
    /// as /info's own "servoIds" (see setServoIds()), set once at startup
    /// and never repeated here since it never changes at runtime.
    uint8_t servo_count;
    /// The pulse last read back from the board for each real servo (RCB-4's
    /// own native position unit -- see Rcb4Link::PULSE_NEUTRAL/DEG_TO_PULSE
    /// -- not degrees or radians), and the target writeJointTargets() asked
    /// of that same joint on the same control step, in radians (an offset
    /// from home, before the pulse conversion). servo_pulse is refreshed
    /// every telemetry tick regardless of state (a throttled extra read
    /// while idle/homing/fault/motion, the control loop's own read while
    /// RUNNING/HOLDING -- see sendTelemetry()'s and loop()'s own comments);
    /// joint_target_rad has no meaning outside RUNNING/HOLDING (nothing is
    /// being commanded) and is simply stale then. kWebPage's FieldLog is
    /// what actually persists these, for a later training run to compare
    /// "what the policy wanted" against "what the hardware did" per joint,
    /// not just in aggregate (see also last_gravity_root_'s own comment on
    /// why this kind of caching exists at all) -- and, combined with
    /// accel_raw/gyro_raw above, to tell a genuine known-pose idle sample
    /// (servo_pulse close to home) apart from an arbitrary hand-posed FREE
    /// one, which a mounting-rotation estimate must not be fit against.
    uint16_t servo_pulse[POLICY_ACT_DIM];
    float joint_target_rad[POLICY_ACT_DIM];
    /// The actor's own last output (raw network action, BEFORE the
    /// action_scale/home offset that turns it into joint_target_rad) --
    /// this is literally the `actions` observation term
    /// (buildObs()'s own `obs[POLICY_OBS_ACTIONS_START + i]`), fed back into
    /// the network on the NEXT step. Without it, a field log cannot
    /// reconstruct the full observation vector the policy actually saw --
    /// gravity/ang_vel/command/joint_pos/joint_vel are covered above and by
    /// phase (reconstructable off Debug::step alone), but the network's own
    /// prior action is state that exists ONLY here, nowhere physical to
    /// re-derive it from. Same validity window as joint_target_rad (stale
    /// outside RUNNING/HOLDING/SEQUENCE, since nothing is being produced).
    float last_action[POLICY_ACT_DIM];
};

struct Debug {
    uint8_t request;
    /// Which actor is loaded, and where a transition has got to. Without
    /// these, "did the policy change?" cannot be answered from outside --
    /// which is exactly the question a hand that judders after a sit raises.
    uint8_t actor;
    uint8_t sequence_step;
    uint32_t quiet_ms;
    uint32_t host_frames;
    uint32_t step;
    uint8_t homing_attempt;
    int16_t home_err;
};
void setTelemetry(uint8_t state, float vx, float wz, uint32_t loop_us,
                  uint32_t errors, uint32_t overruns, uint32_t draw_us,
                  const Debug& debug, const float* gravity,
                  const float* accel_raw, const float* gyro_raw,
                  const uint16_t* servo_pulse, const float* joint_target_rad,
                  const float* last_action, uint8_t servo_count);

/// Called once, from PolicyMode::enter() right after buildServoOrder(): the
/// real servo ids, in the fixed order every Telemetry's servo_pulse /
/// joint_target_rad line up with. Reported by /info (fetched once by
/// kWebPage on load) rather than repeated in Telemetry, since -- unlike
/// those two -- this never changes at runtime.
void setServoIds(const uint8_t* ids, uint8_t count);

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

/// Read back the last published debug snapshot -- host_frames in particular
/// is the one number that tells "nothing is being asked to move" (device
/// idle, waiting) apart from "commands are not reaching this device at all"
/// (it stays at 0 no matter what a phone or PC does).
Debug debugInfo();

/// A short word for `status()`, shared so more than one mode's screen can
/// show the same word for the same state -- see PolicyMode::draw() and
/// StatusMode::drawInfo(), which used to keep separate copies of this
/// switch.
const char* statusLabel(Status status);

}  // namespace net

#endif  // NET_H
