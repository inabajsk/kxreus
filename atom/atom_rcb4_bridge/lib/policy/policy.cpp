#include "policy.h"

#include <math.h>
#include <string.h>

#include "policy_weights.h"

namespace {

// Ping-pong buffers sized to the widest layer. Static rather than on the
// stack: the control task's stack is not large, and there is only ever one
// forward pass in flight.
constexpr size_t kWidest = POLICY_WIDEST_LAYER;
float g_a[kWidest];
float g_b[kWidest];

const float* const kFlashWeights[POLICY_LAYERS] = {
        kPolicyW0, kPolicyW1, kPolicyW2, kPolicyW3};
const float* const kFlashBiases[POLICY_LAYERS] = {
        kPolicyB0, kPolicyB1, kPolicyB2, kPolicyB3};

// What run() actually reads. Points into flash until begin() moves it.
const float* g_weights[POLICY_LAYERS] = {
        kPolicyW0, kPolicyW1, kPolicyW2, kPolicyW3};
const float* g_biases[POLICY_LAYERS] = {
        kPolicyB0, kPolicyB1, kPolicyB2, kPolicyB3};
bool g_in_ram = false;

#ifdef POLICY_WEIGHTS_IN_RAM
// Sized by the exporter rather than by a number typed in here, so it cannot
// go stale when the policy is retrained.
float g_ram[POLICY_WEIGHT_FLOATS];
#endif

/// ELU with alpha = 1, which is what the ONNX Elu node defaults to.
inline float elu(float x) { return x > 0.0f ? x : expm1f(x); }

}  // namespace

namespace policy {

bool begin() {
#ifdef POLICY_WEIGHTS_IN_RAM
    size_t at = 0;
    for (size_t layer = 0; layer < POLICY_LAYERS; layer++) {
        // Belt and braces: if a regenerated header ever outgrew the buffer,
        // the copy below would run off the end of it silently.
        const size_t need = static_cast<size_t>(kPolicyLayerIn[layer]) *
                                    kPolicyLayerOut[layer] +
                            kPolicyLayerOut[layer];
        if (at + need > POLICY_WEIGHT_FLOATS) return false;
        const size_t n_in = kPolicyLayerIn[layer];
        const size_t n_out = kPolicyLayerOut[layer];
        memcpy(g_ram + at, kFlashWeights[layer], n_in * n_out * sizeof(float));
        g_weights[layer] = g_ram + at;
        at += n_in * n_out;
        memcpy(g_ram + at, kFlashBiases[layer], n_out * sizeof(float));
        g_biases[layer] = g_ram + at;
        at += n_out;
    }
    g_in_ram = true;
#endif
    return g_in_ram;
}

bool weightsInRam() { return g_in_ram; }

size_t obsDim() { return POLICY_OBS_DIM; }
size_t actDim() { return POLICY_ACT_DIM; }

void run(const float* obs, float* action) {
    for (size_t i = 0; i < POLICY_OBS_DIM; i++) {
        g_a[i] = (obs[i] - kPolicyObsMean[i]) * kPolicyObsInvStd[i];
    }

    const float* in = g_a;
    float* out = g_b;
    for (size_t layer = 0; layer < POLICY_LAYERS; layer++) {
        const size_t n_in = kPolicyLayerIn[layer];
        const size_t n_out = kPolicyLayerOut[layer];
        const float* w = g_weights[layer];
        const float* bias = g_biases[layer];
        const bool last = layer + 1 == POLICY_LAYERS;
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

    for (size_t i = 0; i < POLICY_ACT_DIM; i++) action[i] = in[i];
}

}  // namespace policy
