#pragma once

#include <stddef.h>

#include <stdint.h>

#include "policy_spec_kxrl2gwalk.h"

/// The most layers any actor on this device has.
#define POLICY_MAX_LAYERS 8

// Every robot kxr5s carries shares these -- confirmed identical across
// kxrl4t/kxrl4d/kxrl6/kxrl2g's own policy_spec_*.h files (all four trained
// at the same control rate, same stretch, same obs layout up to where the
// per-robot joint count takes over) rather than assumed. Bound to
// kxrl2gwalk's own spec arbitrarily -- any one of the four would give the
// same numbers.
#define POLICY_SERVO_FRAME_COUNT POLICY_KXRL2GWALK_SERVO_FRAME_COUNT
#define POLICY_HOME_FRAME_COUNT POLICY_KXRL2GWALK_HOME_FRAME_COUNT
#define POLICY_SERVO_STRETCH POLICY_KXRL2GWALK_SERVO_STRETCH
#define POLICY_CONTROL_HZ POLICY_KXRL2GWALK_CONTROL_HZ
#define POLICY_JOINT_VEL_WINDOW_S POLICY_KXRL2GWALK_JOINT_VEL_WINDOW_S
#define POLICY_OBS_BASE_ANG_VEL_START POLICY_KXRL2GWALK_OBS_BASE_ANG_VEL_START
#define POLICY_OBS_PROJECTED_GRAVITY_START POLICY_KXRL2GWALK_OBS_PROJECTED_GRAVITY_START
#define POLICY_OBS_COMMAND_START POLICY_KXRL2GWALK_OBS_COMMAND_START
#define POLICY_OBS_PHASE_START POLICY_KXRL2GWALK_OBS_PHASE_START
#define POLICY_OBS_JOINT_POS_START POLICY_KXRL2GWALK_OBS_JOINT_POS_START
// OBS_JOINT_VEL_START/OBS_ACTIONS_START are NOT here: unlike the constants
// above, these two really do depend on the per-robot actDim() (joint pos,
// then joint vel, then last action, each actDim() wide, packed back to
// back from OBS_JOINT_POS_START) -- see policy_mode.cpp's own buildObs(),
// which computes them inline as POLICY_OBS_JOINT_POS_START +
// policy::actDim() and + 2 * policy::actDim() rather than reading a
// compiled-in constant that would be wrong for every robot but one.

/// Upper bounds every buffer on this device is sized to, NOT any one
/// robot's own obs/act dim -- kxr5s carries four robots' worth of actors
/// in the same flash image and picks ONE to actually run via a robot
/// identity stored in NVS (see robotId()), not a compile-time choice, so
/// nothing here can be sized to "the" robot the way a per-robot tree's
/// own policy_spec.h constant could be. Headroom kept above kxrl2g's own
/// 77/22 (the largest compiled in today): kxreus's own convention keeps
/// every one of these robots at or under 36 actuators and 96 observations.
/// Loops iterate to policy::obsDim()/policy::actDim() (the SELECTED
/// robot's own real width), never to these -- these are capacity, not a
/// robot's own shape.
#define POLICY_OBS_DIM 96
#define POLICY_ACT_DIM 36
#define POLICY_WIDEST_LAYER 256

/// The trained actor, running on the device.
///
/// The network is a four-layer ELU MLP behind a mean/std input normaliser --
/// small enough that the weights live in flash as `.rodata` and the forward
/// pass is written out directly. There is no runtime to configure and no
/// allocation: `run()` is the whole interface.
///
/// kxr5s carries every one of kxrl4t/kxrl4d/kxrl6/kxrl2g's own trained
/// actors in the SAME flash image (kxrl4d's own two, walk and getup; one
/// each for the other three) rather than the one-tree-per-robot split
/// every earlier build used -- see robotId()'s own comment for how one of
/// them becomes "the" robot this particular unit is.
namespace policy {

/// Which physical robot this unit's own flash has been told it is --
/// stored in NVS (see setRobotId()), not chosen at compile time the way
/// ROBOT_NAME used to be: the whole point of this tree over a per-robot
/// one is that the SAME .bin serves any of the five, and only a
/// lightweight per-unit step (a serial "robot <name>" command, or
/// tools/set_robot.py) says which.
///
/// KXRA6G is unlike the other four: its body is modular (arms and lower
/// body both swap independently -- see ~/kxreus/tmp_scripts_archive/
/// README.md's own onboard legtype dispatcher), so it has no ONE fixed
/// servo layout to train a walking actor against and carries no actor at
/// all here (see policy.cpp's own kRobots[] row for it, actor_count 0).
/// What it carries instead is its own onboard motion table (see
/// motionCount()/motion()), which PolicyMode's own Request::MOTION already
/// calls through Rcb4Link::callMotion() regardless of whether an actor is
/// selected -- movement for this one robot is the RCB-4's own onboard
/// dispatcher choosing the right walk for whichever lower body is
/// currently attached, not a policy running on this chip.
enum class RobotId : uint8_t { KXRL4T, KXRL4D, KXRL6, KXRL2G, KXRA6G, COUNT };

/// "kxrl4t" etc -- also this robot's own net::HOSTNAME/provisionSsid()
/// prefix and BridgeMode's own on-screen title, now that neither can be
/// the ROBOT_NAME compile-time string a per-robot tree used.
const char* robotIdName(RobotId id);

/// RobotId::COUNT if `name` does not match any of the five -- callers
/// (net.cpp's own serial command, tools/set_robot.py's reply) treat that
/// as a rejected request, not a silent fallback to some default.
RobotId robotIdFromName(const char* name);

/// Whether setRobotId() has ever been called successfully on this unit.
/// An unconfigured unit has no safe default to guess: every robot's own
/// servo_ids/servo_direction is meaningless applied to a different one's
/// wiring, so PolicyMode refuses to run at all (see its own begin*()
/// guards) until this is true, the same way net::Status::UNCONFIGURED
/// already refuses to guess a Wi-Fi network.
bool robotConfigured();

/// The currently configured robot -- meaningless (returns KXRL4T, the
/// enum's own zero value, purely so callers get SOME valid array index
/// rather than undefined behaviour) unless robotConfigured() is true; every
/// real caller checks that first.
RobotId robotId();

/// Store a new robot identity in NVS. Takes effect on the NEXT begin()
/// (a reboot) -- switching which actor's weights and servo layout are
/// active while POLICY mode might be running is not something to do
/// live, the same reasoning select() already has for switching actors
/// within one robot.
bool setRobotId(RobotId id);

/// This unit's own LCD mounting -- 0 or 2 (180 degrees), read off the
/// configured robot's own kRobots[] row rather than a single compile-time
/// DISPLAY_ROTATION the way a per-robot tree had. Every row is 2 today:
/// confirmed on real hardware that this project's AtomS3 case mounts the
/// board the same way regardless of which of the five robots it is
/// configured as -- swapping identity via setRobotId() does not re-mount
/// the physical board, so this is not really "one value per robot" so
/// much as "one value per physical case", incidentally read out of the
/// per-robot table because that is where every other per-unit constant
/// already lives. A genuinely differently-mounted unit would need its
/// own real per-unit setting instead of a different guess here.
int displayRotation();

/// Copy the weights into RAM, if this build asks for it.
///
/// Call once before `run()`. Without it the forward pass reads its weights
/// straight out of memory-mapped flash, which works but is an order of
/// magnitude slower: 235 KiB streamed per inference is thousands of cache
/// line fills, and measured on an AtomS3 that alone was 9.8 ms of a 25 ms
/// control step. Doing nothing is the right behaviour when
/// POLICY_WEIGHTS_IN_RAM is not defined.
///
/// @return true if the weights are now in RAM, false if the allocation
///         failed -- in which case `run()` still works, from flash.
bool begin();

/// Whether `run()` is currently reading any weights out of RAM.
bool weightsInRam();

/// How many of the POLICY_LAYERS layers made it into RAM. Fewer than all of
/// them means the budget ran out, which is expected once the Wi-Fi stack is
/// linked in -- the rest are read from flash and are simply slower.
size_t layersInRam();

/// How many layers the selected actor has. Not a constant any more: the
/// actors on this device need not be the same shape as each other, so "how
/// many of them are in RAM" only means something against this.
size_t layers();

/// How many actors THE CONFIGURED ROBOT carries, and their names --
/// kxrl4d's own two (walk, getup), one each for the other three. Flash
/// holds every robot's own actors, not just the configured one's, but
/// count()/name()/select() only ever see the configured robot's own
/// slice -- see robotId()'s own comment for why an unconfigured unit
/// cannot safely pick anything at all.
size_t count();
const char* name(size_t index);
size_t selected();

/// Choose the actor to run, copying its weights into RAM.
///
/// Takes a few milliseconds and leaves `run()` unusable while it happens, so
/// the caller must have the servos idle or held first.
bool select(size_t index);

/// The selected actor's constants. Calls rather than macros, because which
/// policy is loaded is decided at runtime.
const float* homeRad();

/// The home pose of ANY actor, not just the selected one. A transition ramps
/// into the stance of the actor it is about to hand over to, which is not the
/// one currently loaded.
const float* homeRadOf(size_t index);
const float* jointLowRad();
const float* jointHighRad();
const uint8_t* servoIds();

/// The compiled-in servo id list for the NAMED robot's own "walk" actor
/// (index 0 -- see policy.cpp's own kRobots[] convention), regardless of
/// which robot is actually CONFIGURED right now. Every other accessor on
/// this page answers for "the configured robot"; this one exists only
/// for RobotSelectMode's own hardware auto-detect (see
/// lib/robot_select_mode), which has to compare a live RCB-4 servo scan
/// against EVERY candidate robot, not just whichever one happens to be
/// selected -- there being no configured robot yet is the exact case
/// that feature is for.
///
/// @param id     which robot's own table to read.
/// @param count  set to that robot's own actDim() -- how many entries
///                `*count` are valid. 0 (and a null return) if `id` is
///                out of range.
const uint8_t* servoIdsOfRobot(RobotId id, size_t* count);
/// The board's own positive-rotation sign for each servo, in the same
/// per-joint order servoIds() is (see kxreus/rcb4robotconfig.l's own
/// per-servo direction annotation, next to each robot's joint name --
/// this mirrors it exactly, hand-transcribed rather than routed through
/// the ONNX export pipeline since it never changes with retraining).
/// +1 or -1: multiply a joint's own clamped target angle by this,
/// immediately before the RCB-4 pulse conversion (see PolicyMode::
/// writeJointTargets()), never earlier -- clamping against
/// jointLowRad()/jointHighRad() happens in the policy's own (undirected)
/// convention.
const int8_t* servoDirection();
float actionScale();
float phasePeriodS();
float phaseStandThreshold();
float commandVxMin();
float commandVxMax();
float commandWzMax();

/// The trained command band of actor 0 specifically -- by this firmware's
/// own convention (see policy.cpp's kAllActors[]) always the walking actor,
/// whichever else a build carries -- rather than whichever one
/// select()/g_selected currently has loaded. For the phone page's joystick,
/// set up once from /info: reading commandVxMin() et al. instead would work
/// right up until /info happened to be fetched while GETUP (command band
/// [0,0]) was selected, and bake a stuck joystick into that whole session.
float commandVxMinOf(size_t index);
float commandVxMaxOf(size_t index);
float commandWzMaxOf(size_t index);
/// Fraction of training environments given a zero command. Zero means this
/// actor has never been asked to stand still.
float standingFraction();

/// Gravity in the root frame for this actor's own stance. The fallback when
/// no IMU is attached -- and never right for a transition, whose whole job is
/// to change the attitude.
const float* stanceGravity();

/// v_gyro = R_root_to_gyro @ v_root, row major. base_ang_vel is observed in
/// the URDF base link frame while projected_gravity is in root.
const float* rootToGyro();

/// One of this robot's RCB-4 onboard motion-table slots worth offering from
/// the phone -- not all 120 (most are factory-empty on any given board), just
/// the ones a real Heart to Heart project for this robot actually names. See
/// tools/motions_from_h4p.py.
struct Motion {
    uint8_t number;
    const char* name;
};

/// How many onboard motions the CONFIGURED robot's build knows the names
/// of -- each robot's own table, not one shared list.
size_t motionCount();

/// The index'th one, 0 <= index < motionCount(). Out of range returns a
/// motion numbered 0xFF ("none"), never reads past the table.
const Motion& motion(size_t index);

/// Observation width the actor was trained on.
size_t obsDim();

/// Number of joint actions it emits.
size_t actDim();

/// Run one forward pass.
///
/// @param obs     obsDim() observations, in the order deploy_spec.json lists.
/// @param action  actDim() outputs, an offset from the home pose in radians
///                once multiplied by POLICY_ACTION_SCALE.
void run(const float* obs, float* action);

// ---------------------------------------------------------------------
// Runtime policy upload -- see net.cpp's own /policy POST endpoint, which
// is what actually calls these, from the phone page's own upload form.
// Lets a different TRAINED CHECKPOINT of this same actor (mean/inv_std/
// weights/biases only) be tried without reflashing, to compare gaits --
// NOT a way to load a differently-shaped network: layer sizes, servo_ids,
// action_scale, joint limits, home pose and every other constant stay
// whatever the compiled-in "walk" actor already has. One upload lives at
// a time (uploading again replaces it); the compiled-in actor(s) are
// never touched.
// ---------------------------------------------------------------------

/// Exact byte count one upload's body must be -- see beginUpload()'s own
/// comment for the layout this must match. A wrong-sized upload is
/// rejected outright rather than guessed at.
size_t uploadExpectedBytes();

/// Start (or restart) receiving an upload. Any previous one still in
/// progress is discarded; an earlier COMPLETED upload (already installed
/// as an actor) is left alone -- reused in place -- until this one also
/// finishes successfully.
///
/// Byte layout, little-endian, uploadExpectedBytes() total:
///   mean[obsDim()]         (float32)
///   inv_std[obsDim()]      (float32)
///   weight_scale[layers()] (float32, one per layer)
///   bias_scale[layers()]   (float32, one per layer)
///   then per layer (layers(), compiled-in "walk" actor's own shapes):
///     weight[layer_out * layer_in] (int16, row major out x in),
///     bias[layer_out] (int16)
/// All four scale floats sit together up front, rather than each pair
/// beside its own layer's int16 data, purely so every float in the whole
/// payload lands on a 4-byte boundary without either side (this firmware
/// or tools/export_policy_upload.py) having to pad a layer whose element
/// count happens to be odd.
///
/// Weights and biases are fixed-point, not float32: a trained network's
/// own values fit comfortably in 16 bits of range (see this project's
/// own tools/export_policy_upload.py, which picks each layer's two scales
/// as max(abs(weight))/32767 and max(abs(bias))/32767 and quantizes
/// round(value / scale) into that range) and halving every weight/bias
/// from 4 bytes to 2 is what makes one whole extra copy of a network
/// this size affordable to hold in RAM at all, on a chip already sharing
/// its ~320 KiB with Wi-Fi/BT (see policy.cpp's own comment on run()'s
/// quantized path, which reads these directly -- nothing is ever
/// expanded back into a second, float32-sized buffer). mean/inv_std stay
/// float32: 82 numbers is noise next to the ~52 K weights+biases below,
/// and they feed the very first subtraction/multiply every observation
/// goes through, where a bad scale would cost more than it saves.
///
/// @return false if this device could not even try: begin()'s own early
///         malloc of the ~103 KiB buffer this writes into failed (see its
///         own comment on why that happens once, at boot, rather than
///         fresh on every call -- a fragmented heap can refuse a single
///         allocation this size even with plenty of TOTAL free heap left,
///         which used to make this call fail unpredictably depending on
///         how long the device had been running), or the "uploaded" actor
///         -- the very buffer this would overwrite -- is the one
///         currently selected and running. The caller (net.cpp) turns
///         this straight into an HTTP error rather than accepting bytes
///         it cannot keep.
bool beginUpload();

/// Append received bytes to the upload in progress.
/// @return false (aborting the upload) if this would exceed
///         uploadExpectedBytes() -- more bytes than expected is a protocol
///         mismatch, not something to silently truncate.
bool appendUpload(const uint8_t* data, size_t len);

/// Bytes received so far in the upload currently in progress (0 once one
/// finishes or is abandoned) -- for a progress display.
size_t uploadBytesReceived();

/// Finish the upload: must have received exactly uploadExpectedBytes().
/// On success, installs it as one more selectable actor, named
/// "uploaded" (see count()/name()/select()) -- WITHOUT selecting it: the
/// same deliberate act selecting any other actor already is (see
/// PolicyMode's own beginActor()).
/// @return true if installed.
bool finishUpload();

// ---------------------------------------------------------------------
// Saved policies -- an upload above lives only in RAM (g_upload_buf) and
// is gone on the next reboot; these persist the exact same bytes to
// flash (LittleFS, the "spiffs" partition this board's own partition
// table already carries -- see tools/README or the partition table
// itself, unused until this), under an operator-given name, scoped to
// whichever robot is CONFIGURED at the time it is saved (the byte
// layout is that robot's own actor shape; a name means nothing for a
// different one). Meant for a hand-trained checkpoint (the phone
// page's own upload form, "hatori", "pro1", etc.) that is worth keeping
// around without re-uploading it after every power cycle.
//
// A saved file is not automatically loaded or selected at boot -- same
// "selecting is a deliberate act" reasoning finishUpload() already
// follows for the plain upload slot. It becomes reachable again (an
// entry in savedName()) as soon as anything asks, with no boot-time
// cost until it does.
// ---------------------------------------------------------------------

/// Save the CURRENT contents of the upload slot (the actor finishUpload()
/// most recently installed, still exactly what a phone last uploaded)
/// under `name`, for the CONFIGURED robot. Overwrites a previous save of
/// the same name for the same robot.
///
/// `name` becomes part of a filename: kept short (32 bytes, checked) and
/// restricted to letters, digits, '-' and '_' -- anything else is
/// rejected outright rather than silently mangled into something else on
/// disk.
///
/// @return false if there is nothing uploaded to save (finishUpload()
///         never succeeded this session), `name` is invalid, or the
///         write itself failed (LittleFS not available, or genuinely out
///         of the space "Flash容量が許す限り" -- see savedBytesFree()).
bool saveUploaded(const char* name);

/// How many policies are saved on flash for the CONFIGURED robot.
size_t savedCount();

/// The index'th one's own name, 0 <= index < savedCount(). Empty string
/// out of range.
const char* savedName(size_t index);

/// Read a saved policy back off flash into the upload slot (the same
/// slot finishUpload() installs into -- see count()/name()/select(),
/// index count()-1 once this returns true) WITHOUT selecting it, same
/// deliberate-act reasoning as finishUpload(). Refuses (false, nothing
/// changed) if that slot is the one actually SELECTED and RUNNING right
/// now -- same guard beginUpload() already has, for the same reason:
/// overwriting the weights run() is reading live, from a different core,
/// is not survivable. Also refuses if the saved file's own byte length
/// no longer matches this robot's current uploadExpectedBytes() (a stale
/// save from a build whose actor shape has since changed).
bool loadSaved(size_t index);

/// Remove a saved policy from flash. Safe to call on the one currently
/// loaded into the upload slot (see loadSaved()) -- that copy is already
/// in RAM and unaffected; only the flash file goes away.
bool deleteSaved(size_t index);

/// Flash bytes free for MORE saves like this one, on the "spiffs"
/// partition every save above shares with every other saved policy for
/// every robot (not just the configured one) -- "Flash容量が許す限り"
/// literally: nothing here reserves a per-robot quota, so this is the
/// one honest answer to "how many more can I keep".
size_t savedBytesFree();

}  // namespace policy
