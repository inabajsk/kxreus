#include "policy.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#include <Arduino.h>  // ESP.getFreeHeap(), for beginUpload()'s own budget check

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
    // See kxreus/rcb4robotconfig.l's own per-servo direction annotation
    // (next to each joint name there) -- hand-transcribed, same order as
    // servo_ids. Multiplied into a joint's own clamped target angle right
    // before the RCB-4 pulse conversion (see PolicyMode::
    // writeJointTargets()).
    const int8_t* servo_direction;

    // Only ever set for the "uploaded" actor (see finishUpload()) -- every
    // compiled-in actor below passes false/nullptr explicitly (this struct
    // stays a plain aggregate, no default member initializers, since this
    // toolchain's default C++ standard predates aggregates being allowed
    // to have those). weights/biases above are unused when this is true;
    // qweights/qbiases (same per-layer shape) are used instead, each entry
    // read back as `raw * scale[layer]` -- see policy.h's own
    // beginUpload() comment for why fixed-point at all.
    bool quantized;
    const int16_t* const* qweights;
    const int16_t* const* qbiases;
    const float* weight_scale;  // one per layer
    const float* bias_scale;    // one per layer
};

const float* const kWalkW[POLICY_KXRL2GWALK_LAYERS] = {
        kPolicyWKxrl2Gwalk0, kPolicyWKxrl2Gwalk1, kPolicyWKxrl2Gwalk2,
        kPolicyWKxrl2Gwalk3};
const float* const kWalkB[POLICY_KXRL2GWALK_LAYERS] = {
        kPolicyBKxrl2Gwalk0, kPolicyBKxrl2Gwalk1, kPolicyBKxrl2Gwalk2,
        kPolicyBKxrl2Gwalk3};

// See kxreus/rcb4robotconfig.l's own per-servo direction annotation (next
// to each joint name there) -- hand-transcribed, same order as
// kPolicyServoIdsKxrl2Gwalk. Multiplied into a joint's own clamped target
// angle right before the RCB-4 pulse conversion (see
// PolicyMode::writeJointTargets()). Entries for ids the policy carries but
// this robot has no real servo at (255 in kPolicyServoIdsKxrl2Gwalk) are
// left at 1 -- never read.
const int8_t kServoDirectionKxrl2Gwalk[22] = {
    1, 1, -1, 1, 1, 1, 1, 1, -1, 1, -1, -1, 1, -1, 1, 1, 1, 1, -1, 1, -1, -1,
};

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
         kPolicyStanceGravityKxrl2Gwalk, kPolicyRootToGyroKxrl2Gwalk,
         kServoDirectionKxrl2Gwalk,
         /*quantized=*/false, nullptr, nullptr, nullptr, nullptr},
};
constexpr size_t kActorCount = sizeof(kActors) / sizeof(kActors[0]);

size_t g_selected = 0;

// ---------------------------------------------------------------------
// The "uploaded" actor -- see policy.h's own beginUpload()/appendUpload()/
// finishUpload() comments. Unlike kActors[] above, whose weights are
// `.rodata` that costs nothing to keep around, this one exists only
// because a phone fetched it, so its data has to live somewhere: one
// ~103 KiB buffer (kUploadTotalBytes below).
//
// Allocated ONCE, in begin() -- called at boot, before Wi-Fi/BT/ESP-NOW
// have made a single allocation of their own -- and never freed, rather
// than malloc'd fresh on every beginUpload(). See the m5stickc trees'
// own comment on why: a fragmented heap can refuse a single allocation
// this size even with plenty of TOTAL free heap left, and it only gets
// worse the longer the device runs.
constexpr size_t kUploadTotalBytes =
        2 * POLICY_KXRL2GWALK_OBS_DIM * sizeof(float) +
        POLICY_KXRL2GWALK_LAYERS * 2 * sizeof(float) +
        POLICY_KXRL2GWALK_WEIGHT_FLOATS * sizeof(int16_t);

uint8_t* g_upload_buf = nullptr;  // null only if the early malloc failed
size_t g_upload_received = 0;
bool g_upload_active = false;

const int16_t* g_uploaded_weights[POLICY_MAX_LAYERS];
const int16_t* g_uploaded_biases[POLICY_MAX_LAYERS];
float g_uploaded_weight_scale[POLICY_MAX_LAYERS];
float g_uploaded_bias_scale[POLICY_MAX_LAYERS];
Actor g_uploaded_actor;                 // valid only once g_uploaded_ready
bool g_uploaded_ready = false;

/// Actors, compiled-in and uploaded, indexed as one contiguous range --
/// count()'s own extra slot when g_uploaded_ready is what makes index
/// kActorCount valid. Every *Of() accessor and select() itself goes
/// through this rather than kActors[] directly, so neither has to know
/// which kind of actor it was handed.
const Actor& actorAt(size_t index) {
    return index < kActorCount ? kActors[index] : g_uploaded_actor;
}

/// index if it is currently valid, else whatever is selected -- the same
/// fallback homeRadOf()/commandVxMinOf() et al. already gave a
/// too-large index before the uploaded actor existed, just now also
/// covering "the uploaded actor that finishUpload() has not run yet".
size_t effectiveIndex(size_t index) {
    return index < kActorCount + (g_uploaded_ready ? 1 : 0) ? index
                                                             : g_selected;
}

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

// What run() actually reads. Points into flash until select() moves it.
const float* g_weights[POLICY_MAX_LAYERS];
const float* g_biases[POLICY_MAX_LAYERS];
bool g_in_ram = false;

// What run() reads instead, for a quantized (see Actor::quantized) actor
// -- currently only ever the "uploaded" one. Kept fully separate from
// g_weights/g_biases above rather than reusing POLICY_WEIGHTS_IN_RAM's
// own g_ram cache: that cache is an OPTIONAL speed-up over flash a
// compiled-in actor can always fall back from, while this is the
// uploaded actor's only copy of its own data, period.
const int16_t* g_qweights[POLICY_MAX_LAYERS];
const int16_t* g_qbiases[POLICY_MAX_LAYERS];
float g_weight_scale[POLICY_MAX_LAYERS];
float g_bias_scale[POLICY_MAX_LAYERS];

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

size_t count() { return kActorCount + (g_uploaded_ready ? 1 : 0); }

const char* name(size_t index) {
    if (index < kActorCount) return kActors[index].name;
    return index == kActorCount && g_uploaded_ready ? g_uploaded_actor.name
                                                      : "";
}

size_t selected() { return g_selected; }

bool select(size_t index) {
    if (index >= count()) return false;
    g_selected = index;
    const Actor& a = actorAt(index);

    if (a.quantized) {
        // The "uploaded" actor's own data already lives in RAM -- the
        // upload buffer itself, malloc'd whole in finishUpload() -- so
        // there is no flash-vs-RAM choice for the block below to make,
        // and nothing to do with g_weights/g_biases: run() reads
        // g_qweights/g_qbiases instead whenever a.quantized is set.
        for (size_t i = 0; i < a.layers; i++) {
            g_qweights[i] = a.qweights[i];
            g_qbiases[i] = a.qbiases[i];
            g_weight_scale[i] = a.weight_scale[i];
            g_bias_scale[i] = a.bias_scale[i];
        }
        g_in_ram = true;
#ifdef POLICY_WEIGHTS_IN_RAM
        g_layers_in_ram = a.layers;
#endif
        return true;
    }

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

bool begin() {
    // Before select() copies anything into g_ram, and long before
    // net::begin()/EspNowLink::begin() -- see kUploadTotalBytes' own
    // comment on why the timing matters, not just the size.
    if (g_upload_buf == nullptr) {
        g_upload_buf = static_cast<uint8_t*>(malloc(kUploadTotalBytes));
    }
    return select(g_selected);
}

size_t layers() { return actorAt(g_selected).layers; }

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

const float* homeRad() { return actorAt(g_selected).home_rad; }

const float* homeRadOf(size_t index) {
    return actorAt(effectiveIndex(index)).home_rad;
}
const float* jointLowRad() { return actorAt(g_selected).joint_low; }
const float* jointHighRad() { return actorAt(g_selected).joint_high; }
const uint8_t* servoIds() { return actorAt(g_selected).servo_ids; }
const int8_t* servoDirection() { return actorAt(g_selected).servo_direction; }
float actionScale() { return actorAt(g_selected).action_scale; }
float phasePeriodS() { return actorAt(g_selected).phase_period_s; }
float phaseStandThreshold() {
    return actorAt(g_selected).phase_stand_threshold;
}
float commandVxMin() { return actorAt(g_selected).command_vx_min; }
float commandVxMax() { return actorAt(g_selected).command_vx_max; }
float commandWzMax() { return actorAt(g_selected).command_wz_max; }

float commandVxMinOf(size_t index) {
    return actorAt(effectiveIndex(index)).command_vx_min;
}
float commandVxMaxOf(size_t index) {
    return actorAt(effectiveIndex(index)).command_vx_max;
}
float commandWzMaxOf(size_t index) {
    return actorAt(effectiveIndex(index)).command_wz_max;
}
float standingFraction() { return actorAt(g_selected).standing_fraction; }
const float* stanceGravity() { return actorAt(g_selected).stance_gravity; }
const float* rootToGyro() { return actorAt(g_selected).root_to_gyro; }

void run(const float* obs, float* action) {
    const Actor& a = actorAt(g_selected);
    for (size_t i = 0; i < POLICY_KXRL2GWALK_OBS_DIM; i++) {
        g_a[i] = (obs[i] - a.mean[i]) * a.inv_std[i];
    }

    const float* in = g_a;
    float* out = g_b;
    for (size_t layer = 0; layer < a.layers; layer++) {
        const size_t n_in = a.layer_in[layer];
        const size_t n_out = a.layer_out[layer];
        const bool last = layer + 1 == a.layers;
        if (a.quantized) {
            // The uploaded actor's own weights/biases (see policy.h's own
            // beginUpload() comment): int16 fixed-point, one scale per
            // layer for each of the two. Dequantized right here, one
            // element at a time, rather than ever expanding a whole
            // layer back into a second float32 buffer -- that buffer is
            // exactly the RAM this format exists to avoid holding twice.
            const int16_t* w = g_qweights[layer];
            const int16_t* bias = g_qbiases[layer];
            const float wscale = g_weight_scale[layer];
            const float bscale = g_bias_scale[layer];
            for (size_t o = 0; o < n_out; o++) {
                const int16_t* row = w + o * n_in;
                float sum = bias[o] * bscale;
                for (size_t i = 0; i < n_in; i++) {
                    sum += row[i] * wscale * in[i];
                }
                out[o] = last ? sum : elu(sum);
            }
        } else {
            const float* w = g_weights[layer];
            const float* bias = g_biases[layer];
            // The weight matrix is row major as (out x in), so each
            // output is one contiguous sweep -- which is what keeps the
            // flash cache useful.
            for (size_t o = 0; o < n_out; o++) {
                const float* row = w + o * n_in;
                float sum = bias[o];
                for (size_t i = 0; i < n_in; i++) sum += row[i] * in[i];
                out[o] = last ? sum : elu(sum);
            }
        }
        in = out;
        out = (out == g_b) ? g_a : g_b;
    }

    for (size_t i = 0; i < POLICY_KXRL2GWALK_ACT_DIM; i++) action[i] = in[i];
}

size_t uploadExpectedBytes() { return kUploadTotalBytes; }

bool beginUpload() {
    g_upload_active = false;
    g_upload_received = 0;

    // Either the early malloc in begin() failed (see kUploadTotalBytes'
    // own comment -- this device genuinely does not have ~103 KiB to
    // spare right now) or the buffer this would write into is the one
    // run() is reading from on every control step right now (the
    // uploaded actor is the one currently selected). Either way, a
    // caller sees this the same way an out-of-RAM failure already looks:
    // select a different (compiled-in) actor first, then retry.
    if (g_upload_buf == nullptr) return false;
    if (g_uploaded_ready && g_selected == kActorCount) return false;

    g_upload_active = true;
    return true;
}

bool appendUpload(const uint8_t* data, size_t len) {
    if (!g_upload_active) return false;
    if (g_upload_received + len > kUploadTotalBytes) {
        // More bytes than expected: caller and firmware disagree about
        // what is being sent (wrong file, stale build) -- abort outright
        // rather than accept a truncated, silently-wrong mix of old and
        // new data.
        g_upload_active = false;
        g_upload_received = 0;
        return false;
    }
    memcpy(g_upload_buf + g_upload_received, data, len);
    g_upload_received += len;
    return true;
}

size_t uploadBytesReceived() { return g_upload_active ? g_upload_received : 0; }

bool finishUpload() {
    if (!g_upload_active || g_upload_received != kUploadTotalBytes) {
        g_upload_active = false;
        g_upload_received = 0;
        return false;
    }
    g_upload_active = false;
    g_upload_received = 0;

    // Same per-layer shapes as the compiled-in "walk" actor -- an upload is
    // a different trained checkpoint of it, not a different network (see
    // policy.h's own comment on beginUpload()).
    const Actor& shape = kActors[0];

    // The whole float region -- mean, inv_std, then every layer's two
    // scales -- sits first and is 4-byte aligned from g_upload_buf
    // (malloc's own return address) onward, so it is safe to read
    // straight through as one float array.
    const float* floats = reinterpret_cast<const float*>(g_upload_buf);
    const float* mean = floats;
    const float* inv_std = floats + POLICY_KXRL2GWALK_OBS_DIM;
    const float* wscale = inv_std + POLICY_KXRL2GWALK_OBS_DIM;
    const float* bscale = wscale + shape.layers;
    for (size_t i = 0; i < shape.layers; i++) {
        g_uploaded_weight_scale[i] = wscale[i];
        g_uploaded_bias_scale[i] = bscale[i];
    }

    // The int16 region starts right after (a multiple of 4 bytes in, so
    // also 2-byte aligned) and is weight/bias per layer, back to back, in
    // layer order.
    const int16_t* ints =
            reinterpret_cast<const int16_t*>(bscale + shape.layers);
    size_t at = 0;
    for (size_t i = 0; i < shape.layers; i++) {
        const size_t n_in = shape.layer_in[i];
        const size_t n_out = shape.layer_out[i];
        g_uploaded_weights[i] = ints + at;
        at += n_in * n_out;
        g_uploaded_biases[i] = ints + at;
        at += n_out;
    }

    g_uploaded_actor = Actor{
            "uploaded",        mean,
            inv_std,           nullptr,
            nullptr,           shape.layer_in,
            shape.layer_out,   shape.layers,
            shape.home_rad,    shape.joint_low,
            shape.joint_high,  shape.servo_ids,
            shape.action_scale, shape.phase_period_s,
            shape.phase_stand_threshold, shape.command_vx_min,
            shape.command_vx_max, shape.command_wz_max,
            shape.standing_fraction, shape.stance_gravity,
            shape.root_to_gyro, shape.servo_direction,
            /*quantized=*/true, g_uploaded_weights, g_uploaded_biases,
            g_uploaded_weight_scale, g_uploaded_bias_scale};
    g_uploaded_ready = true;
    return true;
}

}  // namespace policy
