#include "policy.h"

#include <math.h>
#include <string.h>

#include "policy_spec_kxrl4dwalk.h"
#include "policy_spec_kxrl4dgetup.h"
#include "policy_weights_kxrl4dwalk.h"
#include "policy_weights_kxrl4dgetup.h"

namespace {

// Ping-pong buffers sized to the widest layer of any policy. Static rather
// than on the stack: the control task's stack is not large, and there is only
// ever one forward pass in flight.
constexpr size_t kWidest = POLICY_KXRL4DWALK_WIDEST_LAYER;
float g_a[kWidest];
float g_b[kWidest];

/// Everything that distinguishes one trained actor from another.
///
/// The weights themselves stay in flash -- there is room for many, and an
/// image with two costs 235 KiB more of a 3.3 MB partition. What there is not
/// room for is two of them in SRAM: the RAM budget holds one policy's largest
/// layers and nothing more. So a policy is SELECTED, and selecting copies it
/// in; only the active one is fast.
struct Actor {
    const char* name;
    const float* mean;
    const float* inv_std;
    const float* const* weights;
    const float* const* biases;
    const uint16_t* layer_in;
    const uint16_t* layer_out;
    size_t layers;
    const float* home_rad;
    const float* joint_low;
    const float* joint_high;
    const uint8_t* servo_ids;
    float action_scale;
    float phase_period_s;
    float phase_stand_threshold;
    float command_vx_min;
    float command_vx_max;
    float command_wz_max;
    float standing_fraction;
    const float* stance_gravity;
    const float* root_to_gyro;
};

const float* const kWalkW[POLICY_KXRL4DWALK_LAYERS] = {
        kPolicyWKxrl4Dwalk0, kPolicyWKxrl4Dwalk1, kPolicyWKxrl4Dwalk2,
        kPolicyWKxrl4Dwalk3};
const float* const kWalkB[POLICY_KXRL4DWALK_LAYERS] = {
        kPolicyBKxrl4Dwalk0, kPolicyBKxrl4Dwalk1, kPolicyBKxrl4Dwalk2,
        kPolicyBKxrl4Dwalk3};
const float* const kGetupW[POLICY_KXRL4DGETUP_LAYERS] = {
        kPolicyWKxrl4Dgetup0, kPolicyWKxrl4Dgetup1, kPolicyWKxrl4Dgetup2,
        kPolicyWKxrl4Dgetup3};
const float* const kGetupB[POLICY_KXRL4DGETUP_LAYERS] = {
        kPolicyBKxrl4Dgetup0, kPolicyBKxrl4Dgetup1, kPolicyBKxrl4Dgetup2,
        kPolicyBKxrl4Dgetup3};

// kxrl4d (Kondo KXR-L4D, 19 DOF: 2 legs + 2 arms + 3-DOF head) replaces the
// walking hand's 6-actor crawl/omni/walk/legs/rise/sit set on this build --
// the two robots do not share a joint count, so they cannot be compiled in
// together (see lib/policy_mode's fixed POLICY_ACT_DIM-sized buffers).
const Actor kActors[] = {
        {"walk", kPolicyObsMeanKxrl4Dwalk, kPolicyObsInvStdKxrl4Dwalk, kWalkW,
         kWalkB, kPolicyLayerInKxrl4Dwalk, kPolicyLayerOutKxrl4Dwalk,
         POLICY_KXRL4DWALK_LAYERS, kPolicyHomeRadKxrl4Dwalk,
         kPolicyJointLowRadKxrl4Dwalk, kPolicyJointHighRadKxrl4Dwalk,
         kPolicyServoIdsKxrl4Dwalk, POLICY_KXRL4DWALK_ACTION_SCALE,
         POLICY_KXRL4DWALK_PHASE_PERIOD_S,
         POLICY_KXRL4DWALK_PHASE_STAND_THRESHOLD,
         POLICY_KXRL4DWALK_COMMAND_VX_MIN, POLICY_KXRL4DWALK_COMMAND_VX_MAX,
         POLICY_KXRL4DWALK_COMMAND_WZ_MAX, POLICY_KXRL4DWALK_STANDING_FRACTION,
         kPolicyStanceGravityKxrl4Dwalk, kPolicyRootToGyroKxrl4Dwalk},
        {"getup", kPolicyObsMeanKxrl4Dgetup, kPolicyObsInvStdKxrl4Dgetup,
         kGetupW, kGetupB, kPolicyLayerInKxrl4Dgetup,
         kPolicyLayerOutKxrl4Dgetup, POLICY_KXRL4DGETUP_LAYERS,
         kPolicyHomeRadKxrl4Dgetup, kPolicyJointLowRadKxrl4Dgetup,
         kPolicyJointHighRadKxrl4Dgetup, kPolicyServoIdsKxrl4Dgetup,
         POLICY_KXRL4DGETUP_ACTION_SCALE, POLICY_KXRL4DGETUP_PHASE_PERIOD_S,
         POLICY_KXRL4DGETUP_PHASE_STAND_THRESHOLD,
         POLICY_KXRL4DGETUP_COMMAND_VX_MIN, POLICY_KXRL4DGETUP_COMMAND_VX_MAX,
         POLICY_KXRL4DGETUP_COMMAND_WZ_MAX,
         POLICY_KXRL4DGETUP_STANDING_FRACTION,
         kPolicyStanceGravityKxrl4Dgetup, kPolicyRootToGyroKxrl4Dgetup},
};
constexpr size_t kActorCount = sizeof(kActors) / sizeof(kActors[0]);

// Extracted from this robot's own Heart to Heart project by
// tools/motions_from_h4p.py -- see that script for how, and its own comment
// for why most of the 120 onboard slots are not here (factory-empty).
const policy::Motion kMotions[] = {
    {0, "一定歩行前（3歩）"},
    {1, "一定歩行後（3歩）"},
    {2, "一定歩行左（3歩）"},
    {3, "一定歩行右（3歩）"},
    {4, "RC歩行前"},
    {5, "RC歩行後"},
    {6, "RC歩行左"},
    {7, "RC歩行右"},
    {8, "RC歩行左旋回"},
    {9, "RC歩行右旋回"},
    {10, "起き上がり左"},
    {11, "起き上がり右"},
    {20, "挨拶"},
    {21, "しゃがむ"},
    {22, "威嚇する"},
    {23, "喜ぶ"},
    {24, "伏せ"},
    {25, "足踏み"},
    {26, "シュート（左足）"},
    {27, "シュート（右足）"},
    {30, "ものを掴む"},
    {31, "掴みRC歩行前"},
    {32, "掴みRC歩行後"},
    {33, "掴みRC歩行左"},
    {34, "掴みRC歩行右"},
    {35, "掴みRC歩行左旋回"},
    {36, "掴みRC歩行右旋回"},
    {37, "放り投げる"},
    {39, "ホームポジション"},
    {40, "電圧低下"},
};
constexpr size_t kMotionCount = sizeof(kMotions) / sizeof(kMotions[0]);
const policy::Motion kNoMotion = {0xFF, "none"};

size_t g_selected = 0;

// What run() actually reads. Points into flash until select() moves it.
const float* g_weights[POLICY_MAX_LAYERS];
const float* g_biases[POLICY_MAX_LAYERS];
bool g_in_ram = false;

#ifdef POLICY_WEIGHTS_IN_RAM
#ifndef POLICY_RAM_WEIGHT_BYTES
#define POLICY_RAM_WEIGHT_BYTES (POLICY_KXRL4DWALK_WEIGHT_FLOATS * 4)
#endif
constexpr size_t kRamFloats = POLICY_RAM_WEIGHT_BYTES / sizeof(float);
float g_ram[kRamFloats];
size_t g_layers_in_ram = 0;
#endif

/// ELU with alpha = 1, which is what the ONNX Elu node defaults to.
inline float elu(float x) { return x > 0.0f ? x : expm1f(x); }

}  // namespace

namespace policy {

size_t count() { return kActorCount; }

const char* name(size_t index) {
    return index < kActorCount ? kActors[index].name : "";
}

size_t selected() { return g_selected; }

bool select(size_t index) {
    if (index >= kActorCount) return false;
    g_selected = index;
    const Actor& a = kActors[index];
    for (size_t i = 0; i < a.layers; i++) {
        g_weights[i] = a.weights[i];
        g_biases[i] = a.biases[i];
    }
    g_in_ram = false;

#ifdef POLICY_WEIGHTS_IN_RAM
    // Largest layer first. The cost being avoided is cache line fills, which
    // is proportional to bytes read, so a partial budget buys the most by
    // taking the biggest matrices -- and a layer left in flash still works,
    // just slower.
    size_t order[POLICY_MAX_LAYERS];
    for (size_t i = 0; i < a.layers; i++) order[i] = i;
    for (size_t i = 1; i < a.layers; i++) {
        const size_t key = order[i];
        const size_t key_size =
                static_cast<size_t>(a.layer_in[key]) * a.layer_out[key];
        size_t j = i;
        while (j > 0 && static_cast<size_t>(a.layer_in[order[j - 1]]) *
                                        a.layer_out[order[j - 1]] < key_size) {
            order[j] = order[j - 1];
            j--;
        }
        order[j] = key;
    }

    size_t at = 0;
    g_layers_in_ram = 0;
    for (size_t i = 0; i < a.layers; i++) {
        const size_t layer = order[i];
        const size_t n_in = a.layer_in[layer];
        const size_t n_out = a.layer_out[layer];
        const size_t need = n_in * n_out + n_out;
        if (at + need > kRamFloats) continue;  // stays in flash
        memcpy(g_ram + at, a.weights[layer], n_in * n_out * sizeof(float));
        g_weights[layer] = g_ram + at;
        at += n_in * n_out;
        memcpy(g_ram + at, a.biases[layer], n_out * sizeof(float));
        g_biases[layer] = g_ram + at;
        at += n_out;
        g_layers_in_ram++;
    }
    g_in_ram = g_layers_in_ram > 0;
#endif
    return true;
}

bool begin() { return select(g_selected); }

size_t layers() { return kActors[g_selected].layers; }

size_t layersInRam() {
#ifdef POLICY_WEIGHTS_IN_RAM
    return g_layers_in_ram;
#else
    return 0;
#endif
}

bool weightsInRam() { return g_in_ram; }

size_t motionCount() { return kMotionCount; }
const Motion& motion(size_t index) {
    return index < kMotionCount ? kMotions[index] : kNoMotion;
}

size_t obsDim() { return POLICY_KXRL4DWALK_OBS_DIM; }
size_t actDim() { return POLICY_KXRL4DWALK_ACT_DIM; }

const float* homeRad() { return kActors[g_selected].home_rad; }

const float* homeRadOf(size_t index) {
    return kActors[index < kActorCount ? index : g_selected].home_rad;
}
const float* jointLowRad() { return kActors[g_selected].joint_low; }
const float* jointHighRad() { return kActors[g_selected].joint_high; }
const uint8_t* servoIds() { return kActors[g_selected].servo_ids; }
float actionScale() { return kActors[g_selected].action_scale; }
float phasePeriodS() { return kActors[g_selected].phase_period_s; }
float phaseStandThreshold() {
    return kActors[g_selected].phase_stand_threshold;
}
float commandVxMin() { return kActors[g_selected].command_vx_min; }
float commandVxMax() { return kActors[g_selected].command_vx_max; }
float commandWzMax() { return kActors[g_selected].command_wz_max; }

float commandVxMinOf(size_t index) {
    return kActors[index < kActorCount ? index : g_selected].command_vx_min;
}
float commandVxMaxOf(size_t index) {
    return kActors[index < kActorCount ? index : g_selected].command_vx_max;
}
float commandWzMaxOf(size_t index) {
    return kActors[index < kActorCount ? index : g_selected].command_wz_max;
}
float standingFraction() { return kActors[g_selected].standing_fraction; }
const float* stanceGravity() { return kActors[g_selected].stance_gravity; }
const float* rootToGyro() { return kActors[g_selected].root_to_gyro; }

void run(const float* obs, float* action) {
    const Actor& a = kActors[g_selected];
    for (size_t i = 0; i < POLICY_KXRL4DWALK_OBS_DIM; i++) {
        g_a[i] = (obs[i] - a.mean[i]) * a.inv_std[i];
    }

    const float* in = g_a;
    float* out = g_b;
    for (size_t layer = 0; layer < a.layers; layer++) {
        const size_t n_in = a.layer_in[layer];
        const size_t n_out = a.layer_out[layer];
        const float* w = g_weights[layer];
        const float* bias = g_biases[layer];
        const bool last = layer + 1 == a.layers;
        // The weight matrix is row major as (out x in), so each output is one
        // contiguous sweep -- which is what keeps the flash cache useful.
        for (size_t o = 0; o < n_out; o++) {
            const float* row = w + o * n_in;
            float sum = bias[o];
            for (size_t i = 0; i < n_in; i++) sum += row[i] * in[i];
            out[o] = last ? sum : elu(sum);
        }
        in = out;
        out = (out == g_b) ? g_a : g_b;
    }

    for (size_t i = 0; i < POLICY_KXRL4DWALK_ACT_DIM; i++) action[i] = in[i];
}

}  // namespace policy
