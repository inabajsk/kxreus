#include "policy.h"

#include <math.h>
#include <string.h>

#include "policy_spec_crawl.h"
#include "policy_spec_omni.h"
#include "policy_spec_walk.h"
#include "policy_spec_legs.h"
#include "policy_spec_rise.h"
#include "policy_spec_sit.h"
#include "policy_weights_crawl.h"
#include "policy_weights_omni.h"
#include "policy_weights_walk.h"
#include "policy_weights_legs.h"
#include "policy_weights_rise.h"
#include "policy_weights_sit.h"

namespace {

// Ping-pong buffers sized to the widest layer of any policy. Static rather
// than on the stack: the control task's stack is not large, and there is only
// ever one forward pass in flight.
constexpr size_t kWidest = POLICY_OMNI_WIDEST_LAYER;
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

const float* const kCrawlW[POLICY_CRAWL_LAYERS] = {
        kPolicyWCrawl0, kPolicyWCrawl1, kPolicyWCrawl2, kPolicyWCrawl3};
const float* const kCrawlB[POLICY_CRAWL_LAYERS] = {
        kPolicyBCrawl0, kPolicyBCrawl1, kPolicyBCrawl2, kPolicyBCrawl3};
const float* const kOmniW[POLICY_OMNI_LAYERS] = {
        kPolicyWOmni0, kPolicyWOmni1, kPolicyWOmni2, kPolicyWOmni3};
const float* const kOmniB[POLICY_OMNI_LAYERS] = {
        kPolicyBOmni0, kPolicyBOmni1, kPolicyBOmni2, kPolicyBOmni3};
const float* const kWalkW[POLICY_WALK_LAYERS] = {
        kPolicyWWalk0, kPolicyWWalk1, kPolicyWWalk2, kPolicyWWalk3};
const float* const kWalkB[POLICY_WALK_LAYERS] = {
        kPolicyBWalk0, kPolicyBWalk1, kPolicyBWalk2, kPolicyBWalk3};
const float* const kLegsW[POLICY_LEGS_LAYERS] = {
        kPolicyWLegs0, kPolicyWLegs1, kPolicyWLegs2, kPolicyWLegs3};
const float* const kLegsB[POLICY_LEGS_LAYERS] = {
        kPolicyBLegs0, kPolicyBLegs1, kPolicyBLegs2, kPolicyBLegs3};
const float* const kRiseW[POLICY_RISE_LAYERS] = {
        kPolicyWRise0, kPolicyWRise1, kPolicyWRise2, kPolicyWRise3};
const float* const kRiseB[POLICY_RISE_LAYERS] = {
        kPolicyBRise0, kPolicyBRise1, kPolicyBRise2, kPolicyBRise3};
const float* const kSitW[POLICY_SIT_LAYERS] = {
        kPolicyWSit0, kPolicyWSit1, kPolicyWSit2, kPolicyWSit3};
const float* const kSitB[POLICY_SIT_LAYERS] = {
        kPolicyBSit0, kPolicyBSit1, kPolicyBSit2, kPolicyBSit3};

const Actor kActors[] = {
        {"crawl", kPolicyObsMeanCrawl, kPolicyObsInvStdCrawl, kCrawlW, kCrawlB,
         kPolicyLayerInCrawl, kPolicyLayerOutCrawl, POLICY_CRAWL_LAYERS,
         kPolicyHomeRadCrawl, kPolicyJointLowRadCrawl, kPolicyJointHighRadCrawl,
         kPolicyServoIdsCrawl, POLICY_CRAWL_ACTION_SCALE,
         POLICY_CRAWL_PHASE_PERIOD_S, POLICY_CRAWL_PHASE_STAND_THRESHOLD,
         POLICY_CRAWL_COMMAND_VX_MIN, POLICY_CRAWL_COMMAND_VX_MAX,
         POLICY_CRAWL_COMMAND_WZ_MAX, POLICY_CRAWL_STANDING_FRACTION,
         kPolicyStanceGravityCrawl, kPolicyRootToGyroCrawl},
        {"omni", kPolicyObsMeanOmni, kPolicyObsInvStdOmni, kOmniW, kOmniB,
         kPolicyLayerInOmni, kPolicyLayerOutOmni, POLICY_OMNI_LAYERS,
         kPolicyHomeRadOmni, kPolicyJointLowRadOmni, kPolicyJointHighRadOmni,
         kPolicyServoIdsOmni, POLICY_OMNI_ACTION_SCALE,
         POLICY_OMNI_PHASE_PERIOD_S, POLICY_OMNI_PHASE_STAND_THRESHOLD,
         POLICY_OMNI_COMMAND_VX_MIN, POLICY_OMNI_COMMAND_VX_MAX,
         POLICY_OMNI_COMMAND_WZ_MAX, POLICY_OMNI_STANDING_FRACTION,
         kPolicyStanceGravityOmni, kPolicyRootToGyroOmni},
        {"walk", kPolicyObsMeanWalk, kPolicyObsInvStdWalk, kWalkW, kWalkB,
         kPolicyLayerInWalk, kPolicyLayerOutWalk, POLICY_WALK_LAYERS,
         kPolicyHomeRadWalk, kPolicyJointLowRadWalk, kPolicyJointHighRadWalk,
         kPolicyServoIdsWalk, POLICY_WALK_ACTION_SCALE,
         POLICY_WALK_PHASE_PERIOD_S, POLICY_WALK_PHASE_STAND_THRESHOLD,
         POLICY_WALK_COMMAND_VX_MIN, POLICY_WALK_COMMAND_VX_MAX,
         POLICY_WALK_COMMAND_WZ_MAX, POLICY_WALK_STANDING_FRACTION,
         kPolicyStanceGravityWalk, kPolicyRootToGyroWalk},
        {"legs", kPolicyObsMeanLegs, kPolicyObsInvStdLegs, kLegsW, kLegsB,
         kPolicyLayerInLegs, kPolicyLayerOutLegs, POLICY_LEGS_LAYERS,
         kPolicyHomeRadLegs, kPolicyJointLowRadLegs, kPolicyJointHighRadLegs,
         kPolicyServoIdsLegs, POLICY_LEGS_ACTION_SCALE,
         POLICY_LEGS_PHASE_PERIOD_S, POLICY_LEGS_PHASE_STAND_THRESHOLD,
         POLICY_LEGS_COMMAND_VX_MIN, POLICY_LEGS_COMMAND_VX_MAX,
         POLICY_LEGS_COMMAND_WZ_MAX, POLICY_LEGS_STANDING_FRACTION,
         kPolicyStanceGravityLegs, kPolicyRootToGyroLegs},
        {"rise", kPolicyObsMeanRise, kPolicyObsInvStdRise, kRiseW, kRiseB,
         kPolicyLayerInRise, kPolicyLayerOutRise, POLICY_RISE_LAYERS,
         kPolicyHomeRadRise, kPolicyJointLowRadRise, kPolicyJointHighRadRise,
         kPolicyServoIdsRise, POLICY_RISE_ACTION_SCALE,
         POLICY_RISE_PHASE_PERIOD_S, POLICY_RISE_PHASE_STAND_THRESHOLD,
         POLICY_RISE_COMMAND_VX_MIN, POLICY_RISE_COMMAND_VX_MAX,
         POLICY_RISE_COMMAND_WZ_MAX, POLICY_RISE_STANDING_FRACTION,
         kPolicyStanceGravityRise, kPolicyRootToGyroRise},
        {"sit", kPolicyObsMeanSit, kPolicyObsInvStdSit, kSitW, kSitB,
         kPolicyLayerInSit, kPolicyLayerOutSit, POLICY_SIT_LAYERS,
         kPolicyHomeRadSit, kPolicyJointLowRadSit, kPolicyJointHighRadSit,
         kPolicyServoIdsSit, POLICY_SIT_ACTION_SCALE,
         POLICY_SIT_PHASE_PERIOD_S, POLICY_SIT_PHASE_STAND_THRESHOLD,
         POLICY_SIT_COMMAND_VX_MIN, POLICY_SIT_COMMAND_VX_MAX,
         POLICY_SIT_COMMAND_WZ_MAX, POLICY_SIT_STANDING_FRACTION,
         kPolicyStanceGravitySit, kPolicyRootToGyroSit},
};
constexpr size_t kActorCount = sizeof(kActors) / sizeof(kActors[0]);

size_t g_selected = 0;

// What run() actually reads. Points into flash until select() moves it.
const float* g_weights[POLICY_MAX_LAYERS];
const float* g_biases[POLICY_MAX_LAYERS];
bool g_in_ram = false;

#ifdef POLICY_WEIGHTS_IN_RAM
#ifndef POLICY_RAM_WEIGHT_BYTES
#define POLICY_RAM_WEIGHT_BYTES (POLICY_OMNI_WEIGHT_FLOATS * 4)
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

size_t obsDim() { return POLICY_OMNI_OBS_DIM; }
size_t actDim() { return POLICY_OMNI_ACT_DIM; }

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
float standingFraction() { return kActors[g_selected].standing_fraction; }
const float* stanceGravity() { return kActors[g_selected].stance_gravity; }
const float* rootToGyro() { return kActors[g_selected].root_to_gyro; }

void run(const float* obs, float* action) {
    const Actor& a = kActors[g_selected];
    for (size_t i = 0; i < POLICY_OMNI_OBS_DIM; i++) {
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

    for (size_t i = 0; i < POLICY_OMNI_ACT_DIM; i++) action[i] = in[i];
}

}  // namespace policy
