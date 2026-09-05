#pragma once

#include <stddef.h>

#include "policy_spec.h"

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
