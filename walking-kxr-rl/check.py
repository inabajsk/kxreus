#!/usr/bin/env python3
"""Pre-training sanity gate: does each KXR robot STAND under zero action?

    uv run check.py                       # all of kxr_rl.robots.DEFAULT_ROBOTS
    uv run check.py kxrl4d kxrl6          # just these
    uv run check.py --gait kxrl4d policies/kxrl4d_walk.pt   # trained-policy travel

Holds the measured home keyframe with the position PD (zero policy action) for
a few seconds and checks it does not drift, tip over, sink, REST ON ITS TORSO,
or hold itself up with one link driven THROUGH another -- exactly what would
happen if the home pose were not actually a stable standing equilibrium the
hardware could adopt (a wrong default pose / actuator sign is the single most
common way a training run wastes a day). Thresholds are FIXED; if a gate
fails, fix the model, don't loosen the gate.

The torso gate is the one this file was missing. kxrl4t's shipped home settled
dead level and dead still -- and passed -- while lying on its belly with 98% of
its weight on the torso. Every walk episode then ended at step 1 on the
torso-contact termination, at a mean reward that never moved off -3.94, for as
many iterations as anyone cared to run. Standing means the limbs carry the
load, so that is what gets measured.

The self-penetration gate is the second one this file was missing. With
self-collision off (deliberately -- see robot_cfg.py), the physics will hold a
stance whose arm passes 15 mm through its own torso and never say a word; the
first solved stance for kxrl6 did, and it looked fine on every other gate.
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
from kxr_rl.geometry import baseline_overlaps, self_penetration  # noqa: E402
from kxr_rl.robots import DEFAULT_ROBOTS  # noqa: E402

MAX_DRIFT_M = 0.03
MAX_TILT_DEG = 15.0
MAX_HEIGHT_DROP_FRAC = 0.15
# Weight the torso may carry at rest before the pose counts as lying down
# rather than standing.
MAX_TORSO_LOAD_FRAC = 0.05
# Overlap the home pose may introduce between two links that the URDF does
# not already overlap at the zero pose.
MAX_SELF_PENETRATION_M = 0.001


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

  torso_body = mujoco.mj_name2id(
    model, mujoco.mjtObj.mjOBJ_BODY, robot_cfg.load_robot_spec(name).torso_link)
  weight = float(model.body_mass.sum()) * 9.81

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

  torso_load = 0.0
  force = np.zeros(6)
  for i in range(data.ncon):
    contact = data.contact[i]
    if torso_body in (model.geom_bodyid[contact.geom1], model.geom_bodyid[contact.geom2]):
      mujoco.mj_contactForce(model, data, i, force)
      torso_load += abs(float(force[0]))
  torso_frac = torso_load / weight
  penetration, pair = self_penetration(model, data, baseline_overlaps(model))

  ok = (drift <= MAX_DRIFT_M and tilt_deg <= MAX_TILT_DEG
        and drop_frac <= MAX_HEIGHT_DROP_FRAC
        and torso_frac <= MAX_TORSO_LOAD_FRAC
        and penetration <= MAX_SELF_PENETRATION_M)
  print("  {}: drift={:.4f}m tilt={:.2f}deg height_drop={:.1%} torso_load={:.0%} "
        "selfpen={:.1f}mm peak_torque={:.0%} -> {}".format(
          name, drift, tilt_deg, drop_frac, torso_frac, 1000.0 * penetration,
          peak_torque_frac, "PASS" if ok else "FAIL"))
  if penetration > MAX_SELF_PENETRATION_M and pair:
    print("      {} is driven {:.1f} mm into {}".format(pair[0], 1000.0 * penetration, pair[1]))
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
