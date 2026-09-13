#include "policy.h"

#include <math.h>
#include <string.h>

#include "policy_spec_kxrl6walk.h"
#include "policy_weights_kxrl6walk.h"

namespace {

// Ping-pong buffers sized to the widest layer of any policy. Static rather
// than on the stack: the control task's stack is not large, and there is only
// ever one forward pass in flight.
constexpr size_t kWidest = POLICY_KXRL6WALK_WIDEST_LAYER;
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

const float* const kWalkW[POLICY_KXRL6WALK_LAYERS] = {
        kPolicyWKxrl6Walk0, kPolicyWKxrl6Walk1, kPolicyWKxrl6Walk2,
        kPolicyWKxrl6Walk3};
const float* const kWalkB[POLICY_KXRL6WALK_LAYERS] = {
        kPolicyBKxrl6Walk0, kPolicyBKxrl6Walk1, kPolicyBKxrl6Walk2,
        kPolicyBKxrl6Walk3};

// kxrl6 (Kondo KXR-L6, 18 DOF: 6 limbs x 3-DOF each)
// four limbs standing on their tips) has no getup policy trained -- unlike
// kxrl4d, this build carries exactly one actor.
const Actor kActors[] = {
        {"walk", kPolicyObsMeanKxrl6Walk, kPolicyObsInvStdKxrl6Walk, kWalkW,
         kWalkB, kPolicyLayerInKxrl6Walk, kPolicyLayerOutKxrl6Walk,
         POLICY_KXRL6WALK_LAYERS, kPolicyHomeRadKxrl6Walk,
         kPolicyJointLowRadKxrl6Walk, kPolicyJointHighRadKxrl6Walk,
         kPolicyServoIdsKxrl6Walk, POLICY_KXRL6WALK_ACTION_SCALE,
         POLICY_KXRL6WALK_PHASE_PERIOD_S,
         POLICY_KXRL6WALK_PHASE_STAND_THRESHOLD,
         POLICY_KXRL6WALK_COMMAND_VX_MIN, POLICY_KXRL6WALK_COMMAND_VX_MAX,
         POLICY_KXRL6WALK_COMMAND_WZ_MAX, POLICY_KXRL6WALK_STANDING_FRACTION,
         kPolicyStanceGravityKxrl6Walk, kPolicyRootToGyroKxrl6Walk},
};
constexpr size_t kActorCount = sizeof(kActors) / sizeof(kActors[0]);

// Extracted from this robot's own Heart to Heart project by
// tools/motions_from_h4p.py -- see that script for how, and its own comment
// for why most of the 120 onboard slots are not here (factory-empty).
const policy::Motion kMotions[] = {
    {0, "一定歩行前（3回）"},
    {1, "一定歩行後（3回）"},
    {2, "一定歩行左（3回）"},
    {3, "一定歩行右（3回）"},
    {4, "RC歩行前"},
    {5, "RC歩行後"},
    {6, "RC歩行左"},
    {7, "RC歩行右"},
    {8, "RC歩行左旋回"},
    {9, "RC歩行右旋回"},
    {10, "ゆっくり歩行前"},
    {11, "ゆっくり歩行後"},
    {12, "高姿勢歩行スタンバイ"},
    {13, "高姿勢歩行前"},
    {14, "高姿勢歩行後"},
    {15, "高姿勢歩行左"},
    {16, "高姿勢移動右"},
    {17, "高姿勢歩行左旋回"},
    {18, "高姿勢歩行右旋回"},
    {20, "手を振る"},
    {21, "バタバタする"},
    {22, "威嚇する"},
    {30, "ホームポジション"},
    {31, "電圧低下"},
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
#define POLICY_RAM_WEIGHT_BYTES (POLICY_KXRL6WALK_WEIGHT_FLOATS * 4)
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

size_t obsDim() { return POLICY_KXRL6WALK_OBS_DIM; }
size_t actDim() { return POLICY_KXRL6WALK_ACT_DIM; }

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
    for (size_t i = 0; i < POLICY_KXRL6WALK_OBS_DIM; i++) {
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

    for (size_t i = 0; i < POLICY_KXRL6WALK_ACT_DIM; i++) action[i] = in[i];
}

}  // namespace policy
