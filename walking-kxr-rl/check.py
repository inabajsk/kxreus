#!/usr/bin/env python3
"""Pre-training sanity gate: does each KXR robot STAND under zero action?

    uv run check.py                       # all of kxr_rl.robots.DEFAULT_ROBOTS
    uv run check.py kxrl4d kxrl6          # just these
    uv run check.py --gait kxrl4d policies/kxrl4d_walk.pt   # trained-policy travel

Holds the measured home keyframe with the position PD (zero policy action) for
a few seconds and checks it does not drift, tip over, or sink -- exactly what
would happen if the home pose were not actually a stable equilibrium (a wrong
default pose / actuator sign is the single most common way a training run
wastes a day). Thresholds are FIXED; if a gate fails, fix the model, don't
loosen the gate.
"""

import argparse
import os
import sys

import mujoco
import numpy as np

os.environ.setdefault("MUJOCO_GL", "egl")

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import kxr_rl  # noqa: E402,F401
from kxr_rl import robot_cfg  # noqa: E402
from kxr_rl.robots import DEFAULT_ROBOTS  # noqa: E402

MAX_DRIFT_M = 0.03
MAX_TILT_DEG = 15.0
MAX_HEIGHT_DROP_FRAC = 0.15


def zero_action_hold(name: str, seconds: float = 3.0) -> bool:
  from mjlab.entity.entity import Entity

  home = robot_cfg.get_home_keyframe(name)
  entity = Entity(robot_cfg.get_robot_cfg(name))
  spec = entity.spec
  spec.worldbody.add_geom(
    name="floor", type=mujoco.mjtGeom.mjGEOM_PLANE, size=[5.0, 5.0, 0.1],
    contype=1, conaffinity=1,
  )
  model = spec.compile()
  data = mujoco.MjData(model)

  qadr = {
    mujoco.mj_id2name(model, mujoco.mjtObj.mjOBJ_JOINT, j): model.jnt_qposadr[j]
    for j in range(model.njnt)
  }
  mujoco.mj_resetData(model, data)
  data.qpos[0:3] = home.pos
  data.qpos[3:7] = home.rot
  for jname, val in home.joint_pos.items():
    if jname in qadr:
      data.qpos[qadr[jname]] = val
  mujoco.mj_forward(model, data)
  data.ctrl[:] = [
    data.qpos[model.jnt_qposadr[model.actuator_trnid[a, 0]]] for a in range(model.nu)
  ]

  start_xy = data.qpos[0:2].copy()
  start_z = float(data.qpos[2])
  peak_torque_frac = 0.0
  for _ in range(int(seconds / model.opt.timestep)):
    mujoco.mj_step(model, data)
    peak_torque_frac = max(
      peak_torque_frac,
      float(np.max(np.abs(data.actuator_force) / robot_cfg.JOINT_EFFORT_NM)))
    if not np.all(np.isfinite(data.qpos)):
      print("  {}: DIVERGED (NaN in qpos)".format(name))
      return False

  drift = float(np.linalg.norm(data.qpos[0:2] - start_xy))
  end_z = float(data.qpos[2])
  drop_frac = (start_z - end_z) / start_z if start_z > 1e-6 else 0.0
  w, x, y, z = data.qpos[3:7]
  tilt_deg = float(np.degrees(np.arccos(np.clip(1.0 - 2.0 * (x * x + y * y), -1.0, 1.0))))

  ok = (drift <= MAX_DRIFT_M and tilt_deg <= MAX_TILT_DEG
        and drop_frac <= MAX_HEIGHT_DROP_FRAC)
  print("  {}: drift={:.4f}m tilt={:.2f}deg height_drop={:.1%} peak_torque={:.0%} "
        "-> {}".format(name, drift, tilt_deg, drop_frac, peak_torque_frac,
                       "PASS" if ok else "FAIL"))
  return ok


def gait_eval(robot: str, checkpoint: str, seconds: float) -> int:
  import subprocess

  out_prefix = os.path.join(HERE, "out", "_check_{}".format(robot))
  return subprocess.call([
    sys.executable, os.path.join(HERE, "tools", "render_robot.py"),
    "--robot", robot, "--mode", "walk", "--checkpoint", os.path.abspath(checkpoint),
    "--out-prefix", out_prefix, "--seconds", str(seconds),
  ], cwd=HERE)


def main() -> None:
  parser = argparse.ArgumentParser(
    description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
  parser.add_argument("robots", nargs="*", default=None)
  parser.add_argument("--gait", nargs=2, metavar=("ROBOT", "CHECKPOINT"), default=None)
  parser.add_argument("--seconds", type=float, default=8.0)
  args = parser.parse_args()

  if args.gait:
    sys.exit(gait_eval(args.gait[0], args.gait[1], args.seconds))

  names = args.robots or list(DEFAULT_ROBOTS)
  print("===== zero-action home stability =====")
  failures = [name for name in names if not zero_action_hold(name)]

  print()
  if failures:
    print("FAILED gates: {}".format(", ".join(failures)))
    sys.exit(1)
  print("all sanity gates passed")


if __name__ == "__main__":
  main()
