#include "policy.h"

#include <math.h>
#include <string.h>

#include "policy_spec_kxrl2gwalk.h"
#include "policy_weights_kxrl2gwalk.h"

namespace {

// Ping-pong buffers sized to the widest layer of any policy. Static rather
// than on the stack: the control task's stack is not large, and there is only
// ever one forward pass in flight.
constexpr size_t kWidest = POLICY_KXRL2GWALK_WIDEST_LAYER;
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

const float* const kWalkW[POLICY_KXRL2GWALK_LAYERS] = {
        kPolicyWKxrl2Gwalk0, kPolicyWKxrl2Gwalk1, kPolicyWKxrl2Gwalk2,
        kPolicyWKxrl2Gwalk3};
const float* const kWalkB[POLICY_KXRL2GWALK_LAYERS] = {
        kPolicyBKxrl2Gwalk0, kPolicyBKxrl2Gwalk1, kPolicyBKxrl2Gwalk2,
        kPolicyBKxrl2Gwalk3};

// kxrl2g (Kondo KXR-L2G, 22 DOF: 2 legs (5-DOF) + 2 arms (3-DOF + 2-gripper) + 2-DOF head)
// four limbs standing on their tips) has no getup policy trained -- unlike
// kxrl4d, this build carries exactly one actor.
const Actor kActors[] = {
        {"walk", kPolicyObsMeanKxrl2Gwalk, kPolicyObsInvStdKxrl2Gwalk, kWalkW,
         kWalkB, kPolicyLayerInKxrl2Gwalk, kPolicyLayerOutKxrl2Gwalk,
         POLICY_KXRL2GWALK_LAYERS, kPolicyHomeRadKxrl2Gwalk,
         kPolicyJointLowRadKxrl2Gwalk, kPolicyJointHighRadKxrl2Gwalk,
         kPolicyServoIdsKxrl2Gwalk, POLICY_KXRL2GWALK_ACTION_SCALE,
         POLICY_KXRL2GWALK_PHASE_PERIOD_S,
         POLICY_KXRL2GWALK_PHASE_STAND_THRESHOLD,
         POLICY_KXRL2GWALK_COMMAND_VX_MIN, POLICY_KXRL2GWALK_COMMAND_VX_MAX,
         POLICY_KXRL2GWALK_COMMAND_WZ_MAX, POLICY_KXRL2GWALK_STANDING_FRACTION,
         kPolicyStanceGravityKxrl2Gwalk, kPolicyRootToGyroKxrl2Gwalk},
};
constexpr size_t kActorCount = sizeof(kActors) / sizeof(kActors[0]);

// Extracted from this robot's own Heart to Heart project by
// tools/motions_from_h4p.py -- see that script for how, and its own comment
// for why most of the 120 onboard slots are not here (factory-empty).
const policy::Motion kMotions[] = {
    {0, "微細歩行前"},
    {1, "微細歩行後"},
    {2, "微細歩行左"},
    {3, "微細歩行右"},
    {4, "ゆっくり歩行前（5回）"},
    {5, "ゆっくり歩行後（5回）"},
    {6, "ゆっくり歩行左（5回）"},
    {7, "ゆっくり歩行右（5回）"},
    {8, "高速歩行前"},
    {9, "高速歩行後"},
    {10, "高速歩行左"},
    {11, "高速歩行右"},
    {12, "高速歩行左旋回"},
    {13, "高速歩行右旋回"},
    {14, "起き上がり（仰向け）"},
    {15, "起き上がり（うつ伏せ）"},
    {16, "起き上がり（方向判別）"},
    {20, "挨拶"},
    {21, "手を振る"},
    {22, "腕立伏せ"},
    {23, "喜ぶ"},
    {24, "がっかり"},
    {25, "シュート左"},
    {26, "シュート右"},
    {27, "パス（左）"},
    {28, "パス（右）"},
    {29, "ゴールキーパー"},
    {30, "パンチ前左"},
    {31, "パンチ前右"},
    {32, "パンチ左"},
    {33, "パンチ右"},
    {34, "防御"},
    {35, "逆立ち"},
    {36, "前転"},
    {38, "ホームポジション"},
    {39, "電圧低下"},
    {40, "ものを掴む→放す左"},
    {41, "左掴み歩行前"},
    {42, "左掴み歩行後"},
    {43, "左掴み歩行左"},
    {44, "左掴み歩行右"},
    {45, "左掴み歩行左旋回"},
    {46, "左掴み歩行右旋回"},
    {47, "左放り投げる"},
    {48, "XL2G_309ものを掴む→放す右"},
    {49, "右掴み歩行前"},
    {50, "右掴み歩行後"},
    {51, "右掴み歩行左"},
    {52, "右掴み歩行右"},
    {53, "右掴み歩行左旋回"},
    {54, "右掴み歩行右旋回"},
    {55, "右放り投げる"},
    {56, "首振り（左右）"},
    {57, "首振りくりかえし"},
    {58, "首振りリモコン"},
    {59, "赤外線あいさつ"},
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
#define POLICY_RAM_WEIGHT_BYTES (POLICY_KXRL2GWALK_WEIGHT_FLOATS * 4)
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

size_t obsDim() { return POLICY_KXRL2GWALK_OBS_DIM; }
size_t actDim() { return POLICY_KXRL2GWALK_ACT_DIM; }

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
    for (size_t i = 0; i < POLICY_KXRL2GWALK_OBS_DIM; i++) {
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

    for (size_t i = 0; i < POLICY_KXRL2GWALK_ACT_DIM; i++) action[i] = in[i];
}

}  // namespace policy
