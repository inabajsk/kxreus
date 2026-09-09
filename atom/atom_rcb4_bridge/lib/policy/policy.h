#pragma once

#include <stddef.h>

#include <stdint.h>

#include "policy_spec_omni.h"

/// The most layers any actor on this device has.
#define POLICY_MAX_LAYERS 8

// The firmware's own names for the selected actor's constants. Everything
// that used to be a macro is now a call, because which policy is loaded is a
// runtime choice: several live in flash and one at a time is copied to RAM.
#define POLICY_OBS_DIM POLICY_OMNI_OBS_DIM
#define POLICY_ACT_DIM POLICY_OMNI_ACT_DIM
#define POLICY_SERVO_FRAME_COUNT POLICY_OMNI_SERVO_FRAME_COUNT
#define POLICY_HOME_FRAME_COUNT POLICY_OMNI_HOME_FRAME_COUNT
#define POLICY_SERVO_STRETCH POLICY_OMNI_SERVO_STRETCH
#define POLICY_CONTROL_HZ POLICY_OMNI_CONTROL_HZ
#define POLICY_JOINT_VEL_WINDOW_S POLICY_OMNI_JOINT_VEL_WINDOW_S
#define POLICY_OBS_BASE_ANG_VEL_START POLICY_OMNI_OBS_BASE_ANG_VEL_START
#define POLICY_OBS_PROJECTED_GRAVITY_START POLICY_OMNI_OBS_PROJECTED_GRAVITY_START
#define POLICY_OBS_COMMAND_START POLICY_OMNI_OBS_COMMAND_START
#define POLICY_OBS_PHASE_START POLICY_OMNI_OBS_PHASE_START
#define POLICY_OBS_JOINT_POS_START POLICY_OMNI_OBS_JOINT_POS_START
#define POLICY_OBS_JOINT_VEL_START POLICY_OMNI_OBS_JOINT_VEL_START
#define POLICY_OBS_ACTIONS_START POLICY_OMNI_OBS_ACTIONS_START

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

}  // namespace policy
