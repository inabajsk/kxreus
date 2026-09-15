#!/usr/bin/env python3
"""Quantize a trained actor into the M5StickC's runtime upload format.

``export_policy.py`` bakes an actor into ``.rodata`` at build time -- fine
for the actor(s) this firmware ships with, but reflashing is a poor way to
try a different trained checkpoint of the SAME actor just to compare gaits.
This script instead writes a small binary file for the phone's own upload
form (POST /policy, see net.cpp) to hand to ``policy::beginUpload()`` /
``appendUpload()`` / ``finishUpload()`` at runtime -- no reflash, and the
compiled-in actor(s) are left untouched.

It is NOT a way to load a differently shaped network: this device's own
build already fixes the layer sizes, the servo ids, the action scale, the
joint limits and the home pose (all still read from whichever compiled-in
actor policy.cpp names ``shape`` -- see finishUpload()'s own comment).
Only mean/inv_std and every weight/bias are read from ``--onnx`` here; the
rest of the actor an upload becomes is exactly what is already on the
device.

Wire format (see policy.h's own beginUpload() comment -- this MUST match
it exactly, byte for byte):

    mean[obs_dim]           float32
    inv_std[obs_dim]        float32
    weight_scale[layers]    float32  (one per layer)
    bias_scale[layers]      float32  (one per layer)
    then per layer:
        weight[out * in]   int16  (row major, out x in)
        bias[out]           int16

Weights and biases are fixed-point rather than float32: halving every one
of them from 4 bytes to 2 is what makes one whole extra copy of a ~52 K
parameter network affordable to hold in RAM on a chip already sharing its
~320 KiB with Wi-Fi/BT (see policy.cpp's own comment on run()'s quantized
path, which reads these back directly -- nothing is ever re-expanded into
a second, float32-sized buffer on the device). mean/inv_std stay float32:
82 numbers is noise next to the ~52 K weights+biases below, and a bad
scale there would corrupt the very first thing every observation goes
through.

Quantization is symmetric per-tensor, one scale each for a layer's weight
matrix and its bias vector: ``scale = max(abs(values)) / 32767`` and
``quantized = round(value / scale)``, clipped to int16's range (32767, not
32768, so the largest-magnitude element never needs -32768's extra step
and the scheme stays exactly symmetric). All rounding happens once, here;
the device only ever multiplies back, in run()'s own inner loop.

The export is checked against onnxruntime, the same way export_policy.py
checks its own float32 export, and ALSO against export_policy.py's plain
float32 reference -- the second number isolates what quantization alone
cost, separate from the float32 path's own tiny summation-order noise.

Usage
-----
    export_policy_upload.py --onnx .../real_robot/policies/walk.onnx \\
        --out walk_v2.bin

Then, from the phone: open this robot's control page, pick ``walk_v2.bin``
in the policy-upload file field, upload, select "uploaded" from the actor
list, and (with the robot stopped -- see net::takeActorSelect()'s own
comment on why it must be) run it.
"""

import argparse
import pathlib
import sys

import numpy as np

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from export_policy import forward, load_actor  # noqa: E402  (path insert above)

INT16_MAX = 32767


def quantize_layer(weight, bias):
    """Symmetric per-tensor int16 quantization for one Gemm layer.

    Returns
    -------
    weight_q : numpy.ndarray[int16], shape (out, in)
    bias_q   : numpy.ndarray[int16], shape (out,)
    weight_scale, bias_scale : float
        ``weight ~= weight_q * weight_scale`` (and the same for bias).
    """
    w_abs_max = float(np.max(np.abs(weight))) if weight.size else 0.0
    b_abs_max = float(np.max(np.abs(bias))) if bias.size else 0.0
    # An all-zero tensor (a bias vector is a real candidate) has nothing to
    # scale against; the scale is then unused (every quantized value is
    # already 0) but must stay a normal, non-zero float -- 1.0 divides
    # cleanly and is never read back as anything but 0 * 1.0.
    weight_scale = w_abs_max / INT16_MAX if w_abs_max > 0 else 1.0
    bias_scale = b_abs_max / INT16_MAX if b_abs_max > 0 else 1.0
    weight_q = np.clip(np.round(weight / weight_scale), -INT16_MAX, INT16_MAX)
    bias_q = np.clip(np.round(bias / bias_scale), -INT16_MAX, INT16_MAX)
    return (weight_q.astype(np.int16), bias_q.astype(np.int16),
            weight_scale, bias_scale)


def dequantized_forward(mean, inv_std, layers_q, obs):
    """The same computation run()'s own quantized path performs on-device.

    Mirrors ``export_policy.forward()`` exactly except that each layer's
    weight/bias is expanded from (int16, scale) right before use, the same
    per-element ``raw * scale`` policy.cpp's run() does -- never a
    separate, fully-dequantized float32 copy of a whole layer.
    """
    x = (obs.astype(np.float32) - mean.astype(np.float32)) * inv_std.astype(np.float32)
    n = len(layers_q)
    for i, (weight_q, bias_q, weight_scale, bias_scale) in enumerate(layers_q):
        weight = weight_q.astype(np.float32) * np.float32(weight_scale)
        bias = bias_q.astype(np.float32) * np.float32(bias_scale)
        x = (weight @ x + bias).astype(np.float32)
        if i < n - 1:
            x = np.where(x > 0, x, np.expm1(np.minimum(x, np.float32(0.0))))
            x = x.astype(np.float32)
    return x


def check_quantized(path, mean, inv_std, layers_q, layers_f32, obs_dim, trials=64):
    """Compare the quantized export against onnxruntime AND against the
    plain float32 export, on the same random observations.

    Returns
    -------
    worst_vs_onnx : float
        Largest |quantized - onnxruntime| seen -- includes both
        quantization error and the float32 path's own tiny
        summation-order noise (see export_policy.check_against_onnx).
    worst_vs_float32 : float
        Largest |quantized - float32 reference| seen -- isolates what
        quantization alone changed, with the summation-order noise above
        cancelled out (both sides are computed the same way in Python).
    """
    import onnxruntime

    session = onnxruntime.InferenceSession(path, providers=["CPUExecutionProvider"])
    rng = np.random.default_rng(0)
    worst_vs_onnx = 0.0
    worst_vs_float32 = 0.0
    for _ in range(trials):
        obs = rng.normal(size=obs_dim).astype(np.float32)
        want = session.run(None, {"obs": obs.reshape(1, -1)})[0].reshape(-1)
        got_q = dequantized_forward(mean, inv_std, layers_q, obs.astype(np.float64))
        got_f32 = forward(mean, inv_std, layers_f32, obs.astype(np.float64))
        worst_vs_onnx = max(worst_vs_onnx, float(np.max(np.abs(want - got_q))))
        worst_vs_float32 = max(worst_vs_float32, float(np.max(np.abs(got_f32 - got_q))))
    return worst_vs_onnx, worst_vs_float32


def pack_upload(mean, inv_std, layers_q):
    """Byte-for-byte the layout policy.h's own beginUpload() documents."""
    parts = [
        np.asarray(mean, dtype="<f4").tobytes(),
        np.asarray(inv_std, dtype="<f4").tobytes(),
        np.asarray([s for _, _, s, _ in layers_q], dtype="<f4").tobytes(),
        np.asarray([s for _, _, _, s in layers_q], dtype="<f4").tobytes(),
    ]
    for weight_q, bias_q, _, _ in layers_q:
        # Row major (out x in), matching export_policy.py's own c_array()
        # of the same weight matrix -- numpy's default row-major layout
        # already is this, so a plain astype+tobytes needs no transpose.
        parts.append(np.asarray(weight_q, dtype="<i2").tobytes())
        parts.append(np.asarray(bias_q, dtype="<i2").tobytes())
    return b"".join(parts)


def parse_args():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--onnx", required=True, help="trained actor")
    parser.add_argument("--out", required=True, help="output .bin path")
    parser.add_argument(
        "--tolerance",
        type=float,
        default=2e-2,
        help="largest |quantized - onnxruntime| action-space difference to"
             " accept (default 2e-2). Wider than export_policy.py's own"
             " 1e-4: that tolerance is for a lossless float32 re-encoding,"
             " while quantizing to int16 is deliberately lossy. 2e-2 of"
             " action, scaled by POLICY_KXRL4TWALK_ACTION_SCALE (0.25), is"
             " 5e-3 rad -- about one servo step (0.3 deg) -- which is"
             " already the resolution the hardware itself is limited to.",
    )
    parser.add_argument(
        "--trials", type=int, default=64,
        help="random observations to check the export against (default 64)",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    mean, inv_std, layers_f32 = load_actor(args.onnx)
    obs_dim = mean.size

    layers_q = [quantize_layer(w, b) for w, b in layers_f32]

    worst_vs_onnx, worst_vs_float32 = check_quantized(
        args.onnx, mean, inv_std, layers_q, layers_f32, obs_dim, args.trials)
    print(f"max |quantized - onnxruntime|   over {args.trials} random obs: "
          f"{worst_vs_onnx:.3g}")
    print(f"max |quantized - float32 export| over {args.trials} random obs: "
          f"{worst_vs_float32:.3g}  (quantization's own contribution)")
    if worst_vs_onnx > args.tolerance:
        raise SystemExit(
            f"the quantized export disagrees with onnxruntime by "
            f"{worst_vs_onnx:.3g}, over the {args.tolerance:g} tolerance."
            " Not writing the file."
        )

    sizes = [layers_f32[0][0].shape[1]] + [w.shape[0] for w, _ in layers_f32]
    print(f"layers {' -> '.join(str(s) for s in sizes)} (ELU)")

    payload = pack_upload(mean, inv_std, layers_q)
    out_path = pathlib.Path(args.out)
    out_path.write_bytes(payload)
    print(f"wrote {out_path} ({len(payload)} bytes, {len(payload) / 1024:.1f} KiB)")
    print("upload it from this robot's control page (policy section) with"
          " the robot stopped, then pick \"uploaded\" and run.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
