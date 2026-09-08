#!/usr/bin/env python3
"""Turn a trained actor into a C header the AtomS3 can run.

The AtomS3 has no ONNX runtime and no room for one, but the actor is only a
four-layer MLP behind an input normaliser, so the weights are baked into
``.rodata`` and the forward pass is written out by hand.  That is the same
route ``feetech-cli/arduino/arduino_quad`` took, for the same reason.

Two headers come out, and they are split by size rather than by topic:

``policy_spec.h`` is small -- the dimensions, the control-loop constants from
``deploy_spec.json`` and ``calibration.yaml``, the home pose, the joint limits
and the servo ids. Anything that wants to know the shape of the problem
includes this.

``policy_weights.h`` is the 235 KiB of normaliser and layer weights, and is
included by exactly one translation unit. Keeping it out of ``policy.h`` is
what stops every file that mentions the policy from recompiling a megabyte of
float literals.

Weight matrices are written ROW MAJOR as ``out x in`` so that each output
neuron is one contiguous sweep, and the normaliser's standard deviation is
written as its reciprocal so the device multiplies rather than divides.

Usage
-----
    export_policy.py \\
        --onnx  .../real_robot/policies/walk.onnx \\
        --spec  .../real_robot/deploy_spec.json \\
        --calib .../real_robot/calibration.yaml \\
        --outdir lib/policy

The export is checked against onnxruntime on random observations before it is
written, so a header that disagrees with the ONNX never reaches the device.
"""

import argparse
import json
import pathlib
import re
import sys

import numpy as np
import onnx
import yaml
from onnx import numpy_helper

# The one architecture this exporter understands.  Anything else -- a different
# activation, a recurrent core, a different normaliser -- has to be handled
# deliberately rather than silently mis-exported, so the shape is asserted.
EXPECTED_OPS = ["Sub", "Div", "Gemm", "Elu", "Gemm", "Elu", "Gemm", "Elu", "Gemm"]


def load_actor(path):
    """Read the MLP and its input normaliser out of an ONNX actor.

    Parameters
    ----------
    path : str
        Path to the exported actor.

    Returns
    -------
    mean : numpy.ndarray, shape (obs_dim,)
        The normaliser's mean.
    inv_std : numpy.ndarray, shape (obs_dim,)
        Reciprocal of the normaliser's standard deviation.
    layers : list of tuple
        ``(weight, bias)`` per layer, weight shaped ``(out, in)``.

    Raises
    ------
    ValueError
        If the graph is not the normaliser-plus-ELU-MLP this understands.
    """
    model = onnx.load(path)
    ops = [n.op_type for n in model.graph.node]
    if ops != EXPECTED_OPS:
        raise ValueError(
            f"{path}: expected the graph {EXPECTED_OPS}, got {ops}. This"
            + " exporter only writes out an ELU MLP behind a mean/std"
            + " normaliser; anything else needs new code, not a new flag."
        )
    tensors = {i.name: numpy_helper.to_array(i) for i in model.graph.initializer}

    sub, div = model.graph.node[0], model.graph.node[1]
    mean = tensors[sub.input[1]].reshape(-1).astype(np.float64)
    std = tensors[div.input[1]].reshape(-1).astype(np.float64)
    if np.any(std <= 0):
        raise ValueError(f"{path}: the normaliser has a non-positive std")

    layers = []
    for node in model.graph.node:
        if node.op_type != "Gemm":
            continue
        weight = tensors[node.input[1]].astype(np.float64)
        bias = tensors[node.input[2]].astype(np.float64)
        layers.append((weight, bias))
    return mean, 1.0 / std, layers


def forward(mean, inv_std, layers, obs):
    """Run the exported network the way the firmware will run it.

    Kept deliberately naive -- no batching, no fused ops -- because its job is
    to be the reference the C is checked against.  Everything is float32 for
    the same reason: the device has no float64, so a float64 reference would
    report its own extra precision as an export error.  Against onnxruntime,
    which is also float32, this agrees to a few times the float32 epsilon.
    """
    x = (obs.astype(np.float32) - mean.astype(np.float32)) * inv_std.astype(np.float32)
    for i, (weight, bias) in enumerate(layers):
        x = (weight.astype(np.float32) @ x + bias.astype(np.float32)).astype(np.float32)
        if i < len(layers) - 1:
            x = np.where(x > 0, x, np.expm1(np.minimum(x, np.float32(0.0))))
            x = x.astype(np.float32)
    return x


def c_float(value):
    """Render one float as a C++ ``float`` literal.

    ``%.9g`` alone is not enough: it prints 0.0 as ``0``, and ``0f`` is not a
    float literal in C++ -- the compiler reads it as the integer 0 with an
    unknown user-defined suffix and refuses it. A decimal point is forced in
    whenever the formatted number has neither one nor an exponent.
    """
    text = f"{value:.9g}"
    if not any(c in text for c in ".eEnN"):
        text += ".0"
    return text + "f"


def c_array(name, values, per_line=8):
    """Format a float array as a C initialiser in ``.rodata``."""
    values = np.asarray(values, dtype=np.float64).reshape(-1)
    out = [f"static const float {name}[{values.size}] = {{"]
    for start in range(0, values.size, per_line):
        chunk = values[start:start + per_line]
        out.append("    " + " ".join(c_float(v) + "," for v in chunk))
    out.append("};")
    return "\n".join(out)


def c_int_array(name, values, ctype="uint8_t", per_line=16):
    values = list(values)
    out = [f"static const {ctype} {name}[{len(values)}] = {{"]
    for start in range(0, len(values), per_line):
        chunk = values[start:start + per_line]
        out.append("    " + " ".join(f"{v}," for v in chunk))
    out.append("};")
    return "\n".join(out)


def check_against_onnx(path, mean, inv_std, layers, obs_dim, trials=64):
    """Compare the exported weights against onnxruntime on random inputs.

    Returns
    -------
    float
        The largest absolute difference seen over ``trials`` observations.
    """
    import onnxruntime

    session = onnxruntime.InferenceSession(path, providers=["CPUExecutionProvider"])
    rng = np.random.default_rng(0)
    worst = 0.0
    for _ in range(trials):
        obs = rng.normal(size=obs_dim).astype(np.float32)
        want = session.run(None, {"obs": obs.reshape(1, -1)})[0].reshape(-1)
        got = forward(mean, inv_std, layers, obs.astype(np.float64))
        worst = max(worst, float(np.max(np.abs(want - got))))
    return worst


def parse_args():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--onnx", required=True, help="trained actor")
    parser.add_argument(
        "--name",
        default="",
        help="short name for this policy, e.g. `omni`. Several policies can"
             " live on the device at once -- flash has room for many, and only"
             " the selected one is copied into RAM -- so their symbols and"
             " header files are given this suffix to keep them apart. Empty"
             " means the single-policy layout.",
    )
    parser.add_argument("--spec", required=True, help="deploy_spec.json")
    parser.add_argument("--calib", required=True, help="calibration.yaml")
    parser.add_argument(
        "--outdir",
        required=True,
        help="directory to write policy_spec.h and policy_weights.h into",
    )
    parser.add_argument(
        "--control-hz",
        type=float,
        default=None,
        help="override calibration.yaml's control_hz for this export."
             + " The device and the PC do not run the loop at the same rate,"
             + " and cannot: the PC pays USB latency the device does not,"
             + " while the device pays for reading joint positions one servo"
             + " at a time. Everything downstream is expressed in seconds"
             + " rather than in steps -- the gait phase is step/control_hz,"
             + " the joint_vel window is a duration -- so the rate is safe to"
             + " differ. Measure before choosing one.",
    )
    parser.add_argument(
        "--command-range",
        nargs=3,
        type=float,
        metavar=("VX_MIN", "VX_MAX", "WZ_MAX"),
        default=None,
        help="the command band to clamp to, when the spec does not record"
             " one. Older specs predate command_ranges_trained, and without"
             " it the firmware clamps to +-1 -- which is not a limit at all"
             " for a policy whose operator drove it between -0.3 and +0.5.",
    )
    parser.add_argument(
        "--tolerance",
        type=float,
        default=1e-4,
        help="largest absolute action difference from onnxruntime to accept."
             + " The floor here is float32 summation order, not correctness:"
             + " numpy and onnxruntime add a 256-wide dot product in different"
             + " orders and land about 1e-5 apart. What makes 1e-4 safe is"
             + " where it ends up -- an action is multiplied by"
             + " action_scale (0.25) to become a joint target, and the servo"
             + " reports and accepts angles quantised to about 0.3 deg"
             + " (5e-3 rad), so 1e-4 of action is 200x below anything the"
             + " hardware can express. A real export bug -- a transposed"
             + " weight, a permuted layer, a wrong activation -- misses by"
             + " order 1, not by 1e-5.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    spec = json.loads(pathlib.Path(args.spec).read_text())
    calib = yaml.safe_load(pathlib.Path(args.calib).read_text())

    mean, inv_std, layers = load_actor(args.onnx)
    obs_dim, act_dim = spec["obs_dim"], spec["action_dim"]
    if mean.size != obs_dim:
        raise SystemExit(
            f"the normaliser is {mean.size} wide but deploy_spec says"
            + f" obs_dim={obs_dim}; they describe different policies"
        )
    if layers[-1][1].size != act_dim:
        raise SystemExit(
            f"the actor emits {layers[-1][1].size} actions but deploy_spec"
            + f" says action_dim={act_dim}"
        )

    worst = check_against_onnx(args.onnx, mean, inv_std, layers, obs_dim)
    servo_quantum_rad = np.deg2rad(0.3)
    print(
        f"max |exported - onnxruntime| over 64 random obs: {worst:.3g}"
        + f" ({worst * spec['action_scale'] / servo_quantum_rad:.1e} of a"
        + " servo step once scaled to a joint target)"
    )
    if worst > args.tolerance:
        raise SystemExit(
            f"the export disagrees with onnxruntime by {worst:.3g}, over the"
            + f" {args.tolerance:g} tolerance. Not writing the header."
        )

    # The calibration's servo direction/offset are an identity on this board
    # (the kxr bridge already applies them), and the firmware assumes that
    # rather than carrying a second copy of the transform. Refuse to export
    # for a board where it is not, instead of shipping a wrong mapping.
    direction = np.asarray(calib["servo_direction"])
    offset = np.asarray(calib["servo_offset_deg"], dtype=float)
    if not (np.all(direction == 1) and np.allclose(offset, 0.0)):
        raise SystemExit(
            "calibration.yaml has a non-identity servo direction/offset. The"
            + " firmware reads URDF degrees straight off the board, so that"
            + " transform would have to be added to policy_mode before this"
            + " policy could be exported."
        )

    limits = np.asarray(spec["joint_limits_rad"], dtype=float)
    sizes = [layers[0][0].shape[1]] + [w.shape[0] for w, _ in layers]
    # Suffix on every generated symbol and file, so two policies can be
    # compiled into one image without colliding.
    tag = re.sub(r"[^A-Za-z0-9]", "", args.name.title())
    suffix = f"_{args.name}" if args.name else ""
    control_hz = float(args.control_hz if args.control_hz is not None
                       else calib["control_hz"])

    # Older specs predate command_ranges_trained. Falling back to the stick's
    # own limits would silently reintroduce the extrapolation this exists to
    # stop, so the absence is recorded rather than papered over.
    ranges = spec.get("command_ranges_trained")
    if ranges is None and args.command_range is not None:
        vx_lo, vx_hi, wz_max = args.command_range
        ranges_known = False   # given by hand, not read from training
        standing = None
    elif ranges is None:
        vx_lo, vx_hi = -1.0, 1.0
        wz_max = 1.0
        ranges_known = False
        standing = None
    else:
        vx_lo, vx_hi = ranges["lin_vel_x"]
        wz_max = max(abs(v) for v in ranges["ang_vel_z"])
        ranges_known = True
        standing = ranges.get("standing_env_fraction")
    quat = (spec.get("home_base") or {}).get("quat_wxyz")
    if quat is None:
        stance_gravity = np.array([0.0, 0.0, -1.0])
    else:
        w, x, y, z = (float(v) for v in quat)
        stance_gravity = -np.array([2.0 * (x * z - w * y),
                                    2.0 * (y * z + w * x),
                                    1.0 - 2.0 * (x * x + y * y)])
    root_to_gyro = np.asarray(
        (spec.get("frames") or {}).get("R_root_to_gyro", np.eye(3)), dtype=float)

    provenance = [
        "// Generated by tools/export_policy.py -- do not edit.",
        f"//   actor  {pathlib.Path(args.onnx).name}",
        f"//   task   {spec['task']}",
        f"//   layers {' -> '.join(str(s) for s in sizes)} (ELU)",
        f"//   checked against onnxruntime to {worst:.3g}",
        f"//   control  {control_hz:g} Hz"
        + ("" if args.control_hz is None
           else f" (overridden; calibration.yaml says {calib['control_hz']:g})"),
        "",
        "#pragma once",
        "",
    ]

    macro = f"_{tag.upper()}" if tag else ""
    spec_h = provenance + [
        "#include <stdint.h>",
        "",
        "// Shape of the network.",
        f"#define POLICY{macro}_OBS_DIM {obs_dim}",
        f"#define POLICY{macro}_ACT_DIM {act_dim}",
        f"#define POLICY{macro}_LAYERS {len(layers)}",
        f"#define POLICY{macro}_WIDEST_LAYER {max(sizes)}",
        "// Floats in the weight matrices and biases together, so a build that",
        "// copies them into RAM can size its buffer without a number typed in",
        "// by hand that a retrain could make stale.",
        f"#define POLICY{macro}_WEIGHT_FLOATS {sum(int(w.size + b.size) for w, b in layers)}",
        "",
        "// Control loop constants, taken from deploy_spec.json and",
        "// calibration.yaml so the firmware cannot drift from the host tools.",
        f"#define POLICY{macro}_ACTION_SCALE {c_float(spec['action_scale'])}",
        f"#define POLICY{macro}_PHASE_PERIOD_S {c_float(spec['phase_period_s'])}",
        f"#define POLICY{macro}_PHASE_STAND_THRESHOLD {c_float(spec['phase_stand_threshold'])}",
        "",
        "// The command band the actor was actually trained on. Outside it the",
        "// policy is extrapolating, and nothing in the observation tells it so",
        "// -- it simply produces a target for a speed it has never had to",
        "// achieve. The firmware clamps to these rather than to whatever the",
        "// operator's stick can reach, which for one policy here was three",
        "// times the trained speed.",
        f"#define POLICY{macro}_COMMAND_VX_MIN {c_float(vx_lo)}",
        f"#define POLICY{macro}_COMMAND_VX_MAX {c_float(vx_hi)}",
        f"#define POLICY{macro}_COMMAND_WZ_MAX {c_float(wz_max)}",
        f"#define POLICY{macro}_COMMAND_RANGES_KNOWN {1 if ranges_known else 0}",
        "// Fraction of training environments that were given a zero command.",
        "// Zero here means the actor has never been asked to stand still, so a",
        "// stick at rest is outside what it was trained on.",
        f"#define POLICY{macro}_STANDING_FRACTION {c_float(0.0 if standing is None else standing)}",
        "",
        f"#define POLICY{macro}_CONTROL_HZ {c_float(control_hz)}",
        f"#define POLICY{macro}_SERVO_FRAME_COUNT {int(calib['servo_frame_count'])}",
        "// Getting to the home stance before the policy starts: slow, because",
        "// nothing about it is time-critical and the hand may be starting from",
        "// a collapsed pose.",
        f"#define POLICY{macro}_HOME_FRAME_COUNT {int(calib['home_frame_count'])}",
        "// Holding stiffness written into every servo before running. The",
        "// board comes set to 127, which buzzed on this hand.",
        f"#define POLICY{macro}_SERVO_STRETCH {int(calib['servo_stretch'])}",
        f"#define POLICY{macro}_JOINT_VEL_WINDOW_S {c_float(float(calib['joint_vel_window_s']))}",
        "",
        "// Where each observation term starts, so the firmware assembles the",
        "// vector in the order the actor was trained on rather than in the",
        "// order it happens to compute the terms.",
    ]
    for term in spec["obs_layout"]:
        name = term["name"].upper()
        spec_h += [
            f"#define POLICY{macro}_OBS_{name}_START {term['start']}",
            f"#define POLICY{macro}_OBS_{name}_DIM {term['dim']}",
        ]
    spec_h += [
        "",
        "// Home pose in URDF radians: the action is an offset from this, and",
        "// joint_pos is reported relative to it.",
        c_array(f"kPolicyHomeRad{tag}", spec["home_joint_pos_rad"]),
        "",
        c_array(f"kPolicyJointLowRad{tag}", limits[:, 0]),
        "",
        c_array(f"kPolicyJointHighRad{tag}", limits[:, 1]),
        "",
        "// RCB-4 servo id per joint, in joint_order. NOT sorted: this is the",
        "// policy's own order, and the board wants ids ascending, so a caller",
        "// writing a servo command has to reorder.",
        c_int_array(f"kPolicyServoIds{tag}", spec["servo_ids"], "uint8_t"),
        "",
        "// Gravity in the root frame for this policy's own stance, from",
        "// home_base.quat_wxyz. Used only when there is no IMU; a transition",
        "// changes the attitude and cannot be represented by it at all.",
        c_array(f"kPolicyStanceGravity{tag}", stance_gravity),
        "",
        "// v_gyro = R_root_to_gyro @ v_root. base_ang_vel is observed in the",
        "// URDF base link frame while projected_gravity is in root, and the",
        "// two are not the same frame -- getting this wrong is silent.",
        c_array(f"kPolicyRootToGyro{tag}", root_to_gyro.reshape(-1)),
        "",
    ]

    weights_h = provenance + [
        f'#include "policy_spec{suffix}.h"',
        "",
        c_int_array(f"kPolicyLayerIn{tag}", sizes[:-1], "uint16_t"),
        "",
        c_int_array(f"kPolicyLayerOut{tag}", sizes[1:], "uint16_t"),
        "",
        c_array(f"kPolicyObsMean{tag}", mean),
        "",
        c_array(f"kPolicyObsInvStd{tag}", inv_std),
    ]
    for i, (weight, bias) in enumerate(layers):
        weights_h += ["", c_array(f"kPolicyW{tag}{i}", weight), "",
                      c_array(f"kPolicyB{tag}{i}", bias)]
    weights_h.append("")

    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    for name, lines in ((f"policy_spec{suffix}.h", spec_h),
                        (f"policy_weights{suffix}.h", weights_h)):
        text = "\n".join(lines)
        (outdir / name).write_text(text)
        print(f"wrote {outdir / name} ({len(text) / 1024:.0f} KiB)")
    print(f"weights: {sum(w.size + b.size for w, b in layers) * 4 / 1024:.0f}"
          " KiB of float32 in .rodata")
    return 0


if __name__ == "__main__":
    sys.exit(main())
