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
// How much SRAM the weights may take. All 235 KiB of them will not fit
// alongside the Wi-Fi stack -- the link fails by 2 KiB -- so this is a budget
// rather than the whole set, and begin() spends it on the largest layers
// first, where the reads are.
#ifndef POLICY_RAM_WEIGHT_BYTES
#define POLICY_RAM_WEIGHT_BYTES (POLICY_WEIGHT_FLOATS * 4)
#endif
constexpr size_t kRamFloats = POLICY_RAM_WEIGHT_BYTES / sizeof(float);
float g_ram[kRamFloats];
size_t g_layers_in_ram = 0;
#endif

/// ELU with alpha = 1, which is what the ONNX Elu node defaults to.
inline float elu(float x) { return x > 0.0f ? x : expm1f(x); }

}  // namespace

namespace policy {

bool begin() {
#ifdef POLICY_WEIGHTS_IN_RAM
    // Largest layer first. The cost being avoided is cache line fills, which
    // is proportional to bytes read, so a partial budget buys the most by
    // taking the biggest matrices -- and a layer left in flash still works,
    // just slower.
    size_t order[POLICY_LAYERS];
    for (size_t i = 0; i < POLICY_LAYERS; i++) order[i] = i;
    for (size_t i = 1; i < POLICY_LAYERS; i++) {
        const size_t key = order[i];
        const size_t key_size = static_cast<size_t>(kPolicyLayerIn[key]) *
                                kPolicyLayerOut[key];
        size_t j = i;
        while (j > 0 && static_cast<size_t>(kPolicyLayerIn[order[j - 1]]) *
                                        kPolicyLayerOut[order[j - 1]] <
                                key_size) {
            order[j] = order[j - 1];
            j--;
        }
        order[j] = key;
    }

    size_t at = 0;
    g_layers_in_ram = 0;
    for (size_t i = 0; i < POLICY_LAYERS; i++) {
        const size_t layer = order[i];
        const size_t n_in = kPolicyLayerIn[layer];
        const size_t n_out = kPolicyLayerOut[layer];
        const size_t need = n_in * n_out + n_out;
        if (at + need > kRamFloats) continue;  // stays in flash
        memcpy(g_ram + at, kFlashWeights[layer], n_in * n_out * sizeof(float));
        g_weights[layer] = g_ram + at;
        at += n_in * n_out;
        memcpy(g_ram + at, kFlashBiases[layer], n_out * sizeof(float));
        g_biases[layer] = g_ram + at;
        at += n_out;
        g_layers_in_ram++;
    }
    g_in_ram = g_layers_in_ram > 0;
#endif
    return g_in_ram;
}

size_t layersInRam() {
#ifdef POLICY_WEIGHTS_IN_RAM
    return g_layers_in_ram;
#else
    return 0;
#endif
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
