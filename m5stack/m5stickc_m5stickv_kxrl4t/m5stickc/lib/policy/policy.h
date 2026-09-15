#pragma once

#include <stddef.h>

#include <stdint.h>

#include "policy_spec_kxrl4twalk.h"

/// The most layers any actor on this device has.
#define POLICY_MAX_LAYERS 8

// The firmware's own names for the selected actor's constants. Everything
// that used to be a macro is now a call, because which policy is loaded is a
// runtime choice: several live in flash and one at a time is copied to RAM.
//
// Bound to kxrl4twalk rather than an arbitrary actor because every actor
// compiled into THIS build (kxrl4t's only actor: walk) shares one obs/action
// layout and control rate -- they are the same robot's two skills, not two
// different robots the way crawl/omni/etc were.
#define POLICY_OBS_DIM POLICY_KXRL4TWALK_OBS_DIM
#define POLICY_ACT_DIM POLICY_KXRL4TWALK_ACT_DIM
#define POLICY_SERVO_FRAME_COUNT POLICY_KXRL4TWALK_SERVO_FRAME_COUNT
#define POLICY_HOME_FRAME_COUNT POLICY_KXRL4TWALK_HOME_FRAME_COUNT
#define POLICY_SERVO_STRETCH POLICY_KXRL4TWALK_SERVO_STRETCH
#define POLICY_CONTROL_HZ POLICY_KXRL4TWALK_CONTROL_HZ
#define POLICY_JOINT_VEL_WINDOW_S POLICY_KXRL4TWALK_JOINT_VEL_WINDOW_S
#define POLICY_OBS_BASE_ANG_VEL_START POLICY_KXRL4TWALK_OBS_BASE_ANG_VEL_START
#define POLICY_OBS_PROJECTED_GRAVITY_START POLICY_KXRL4TWALK_OBS_PROJECTED_GRAVITY_START
#define POLICY_OBS_COMMAND_START POLICY_KXRL4TWALK_OBS_COMMAND_START
#define POLICY_OBS_PHASE_START POLICY_KXRL4TWALK_OBS_PHASE_START
#define POLICY_OBS_JOINT_POS_START POLICY_KXRL4TWALK_OBS_JOINT_POS_START
#define POLICY_OBS_JOINT_VEL_START POLICY_KXRL4TWALK_OBS_JOINT_VEL_START
#define POLICY_OBS_ACTIONS_START POLICY_KXRL4TWALK_OBS_ACTIONS_START

/// The trained actor, running on the device.
///
/// The network is a four-layer ELU MLP behind a mean/std input normaliser --
/// small enough that the weights live in flash as `.rodata` and the forward
/// pass is written out directly. There is no runtime to configure and no
/// allocation: `run()` is the whole interface.
///
/// The dimensions and control constants come from `policy_spec.h`, which
/// this header re-exports; the weights themselves live in
/// `policy_weights.h`, which only policy.cpp includes so that touching
/// the policy does not recompile 235 KiB of float literals everywhere.
/// Both come from
/// `tools/export_policy.py`, which generates them from the ONNX actor and
/// checks them against onnxruntime before writing. Nothing is
/// hand-transcribed.
namespace policy {

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

/// How many actors are compiled in, and their names.
///
/// Flash holds all of them -- another 235 KiB of a 3.3 MB partition -- but
/// SRAM holds one. `select()` copies the chosen one in, which is why changing
/// policy is a deliberate act and not something to do mid-stride.
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
float actionScale();
float phasePeriodS();
float phaseStandThreshold();
float commandVxMin();
float commandVxMax();
float commandWzMax();

/// The trained command band of actor 0 specifically -- by this firmware's
/// own convention (see policy.cpp's kActors[]) always the walking actor,
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

/// How many onboard motions this robot's build knows the names of.
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
/// as an actor) is left alone -- its buffer stays live -- until this one
/// also finishes successfully.
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
/// @return false if there is not enough free heap right now to even try --
///         uploadExpectedBytes() is a little over 100 KiB, and Wi-Fi/BT
///         alone can leave less than that free (see policy.cpp's own
///         comment). The caller (net.cpp) turns this straight into an
///         HTTP error rather than accepting bytes it cannot keep.
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

}  // namespace policy
