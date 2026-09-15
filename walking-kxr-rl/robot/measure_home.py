#!/usr/bin/env python3
"""Measure a KXR robot's standing home keyframe by settling it in physics.

    uv run robot/measure_home.py kxrl4d kxrl4t kxrl2g kxrl6

Unlike the walking-hand hand (which needs a hand-designed fingertip stance --
no pose is a natural "rest" pose for that morphology), every KXR body's
``kxreus`` limb-map yaml defines a ``reset-pose`` of all zeros -- i.e. straight
legs is the intended neutral stance for the real hardware. So this tries ALL
ZERO first; only if that settles unstable (falls over / collapses) does it
fall back to a small grid of hip/knee/ankle crouch biases and keeps whichever
settles tallest and stillest. Either way the result is *measured*, not
guessed: dropped from just above the floor, held by the position PD, and
recorded once velocities die out -- exactly walking-hand-rl's
robot/measure_home.py, generalized over robots instead of finger stances.
"""

import argparse
import itertools
import json
import os
import sys

import mujoco
import numpy as np

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, _REPO_ROOT)

import kxr_rl  # noqa: F401  (bootstraps upstream on sys.path; unused directly)
from kxr_rl import robot_cfg
from kxr_rl.robots import load_robot_spec

MAX_TILT_DEG = 25.0  # more tilted than this at rest = not a usable standing home
MIN_HEIGHT_FRAC = 0.5  # base must end up above this fraction of its start guess


def build(name):
  from mjlab.entity.entity import Entity
  from mjlab.entity import EntityCfg

  # A placeholder init_state: measure_home.py's whole job is to produce the
  # real one, and Entity() needs *some* InitialStateCfg to construct at all.
  placeholder = EntityCfg.InitialStateCfg(
    pos=(0.0, 0.0, 0.3), rot=(1.0, 0.0, 0.0, 0.0), joint_pos={}, joint_vel={})
  entity = Entity(robot_cfg.get_robot_cfg(name, init_state=placeholder))
  spec = entity.spec
  spec.worldbody.add_geom(
    name="floor", type=mujoco.mjtGeom.mjGEOM_PLANE, size=[5.0, 5.0, 0.1],
    contype=1, conaffinity=1,
  )
  robot = load_robot_spec(name)
  model = spec.compile()
  return model, robot


def lowest_point(model, data):
  """World-frame lowest vertex over every enabled collision geom."""
  lo = np.inf
  for gid in range(model.ngeom):
    if model.geom_contype[gid] == 0 and model.geom_conaffinity[gid] == 0:
      continue
    if model.geom_dataid[gid] < 0:
      continue  # not a mesh (e.g. the floor plane itself)
    mesh_id = model.geom_dataid[gid]
    adr, num = model.mesh_vertadr[mesh_id], model.mesh_vertnum[mesh_id]
    verts = model.mesh_vert[adr:adr + num]
    rot = data.geom_xmat[gid].reshape(3, 3)
    lo = min(lo, float((verts @ rot.T + data.geom_xpos[gid])[:, 2].min()))
  return lo


def _kinematic_height(model, bias, base_z_guess):
  """Torso height for one joint-bias pose, feet (or whatever is lowest)
  resting on the floor. Purely kinematic: one ``mj_forward``, no gravity, no
  settling -- unlike ``settle()`` below, unaffected by whether the pose is
  actually stable to hold unassisted."""
  data = mujoco.MjData(model)
  data.qpos[2] = base_z_guess
  data.qpos[3:7] = [1.0, 0.0, 0.0, 0.0]
  qadr = {
    mujoco.mj_id2name(model, mujoco.mjtObj.mjOBJ_JOINT, j): model.jnt_qposadr[j]
    for j in range(model.njnt)
  }
  for jname, val in bias.items():
    if jname in qadr:
      data.qpos[qadr[jname]] = val
  mujoco.mj_forward(model, data)
  return base_z_guess - lowest_point(model, data) + 0.001


def max_kinematic_height(model, robot, base_z_guess):
  """Upper bound on torso height, found by sweeping the SAME per-robot
  joint-bias grid ``measure()`` uses to search for a stable settled pose
  (``_bias_candidates``) -- except scored by plain forward-kinematics height
  instead of a physics settle, and keeping the tallest regardless of whether
  that pose could actually stand there unassisted.

  Zero (every joint at its kxreus reset-pose value) is NOT reliably "limbs
  extended downward" -- on a multi-limb sprawler like kxrl6 it is closer to
  "limbs splayed out sideways", shorter than a bent-knee pose, not taller.
  So this can't just measure the zero pose; it has to search the same
  hip/knee/ankle axes ``measure()`` already searches, which is exactly the
  lever that raises or lowers this robot's torso. The result is a ceiling
  common to every robot's own joint grid -- how high ANY policy could
  conceivably lift this robot's torso by rearranging its own limbs -- with
  no per-robot tuning: ``getup_hold``'s target (see rewards.py and
  ``env_cfgs.py:_stand_height``).
  """
  return max(_kinematic_height(model, bias, base_z_guess)
             for bias in _bias_candidates(robot))


def settle(model, robot, bias, base_z_guess, seconds):
  data = mujoco.MjData(model)
  qadr = {
    mujoco.mj_id2name(model, mujoco.mjtObj.mjOBJ_JOINT, j): model.jnt_qposadr[j]
    for j in range(model.njnt)
  }
  mujoco.mj_resetData(model, data)
  data.qpos[2] = base_z_guess
  data.qpos[3:7] = [1.0, 0.0, 0.0, 0.0]
  for jname, val in bias.items():
    if jname in qadr:
      data.qpos[qadr[jname]] = val
  mujoco.mj_forward(model, data)

  lowest = lowest_point(model, data)
  data.qpos[2] += -lowest + 0.001
  mujoco.mj_forward(model, data)

  # Hold the bias pose via PD (ctrl = current joint angle for every actuator).
  data.ctrl[:] = [
    data.qpos[model.jnt_qposadr[model.actuator_trnid[a, 0]]]
    for a in range(model.nu)
  ]
  for _ in range(int(seconds / model.opt.timestep)):
    mujoco.mj_step(model, data)
    if not np.all(np.isfinite(data.qpos)):
      break
  return data, qadr


def tilt_deg(quat):
  w, x, y, z = quat
  # angle between the body +Z axis and world +Z.
  cos_tilt = 1.0 - 2.0 * (x * x + y * y)
  return float(np.degrees(np.arccos(np.clip(cos_tilt, -1.0, 1.0))))


def _bias_candidates(robot):
  """All-zero first (the hardware's own neutral pose), then a crouch grid.

  Legs with a hip pitch + knee (most KXR bodies) search THOSE -- the usual
  crouch lever. Legs with only hip yaw/roll (e.g. kxrl4t: no pitch, no knee,
  no ankle at all) cannot bend fore-aft, so the only lever that can change
  standing height at all is roll/yaw; the grid searches those instead.
  """
  roles = robot.leg_dof_names
  present = set(roles.values())
  axis_choices = {
    "hip_pitch": (-0.5, -0.25, 0.0, 0.25, 0.5),
    "knee": (0.0, 0.4, 0.7, -0.4, -0.7),
    "ankle_pitch": (0.0, -0.35, 0.35),
  }
  if not ({"hip_pitch", "knee"} & present):
    axis_choices = {
      "hip_roll": (0.0, 0.3, 0.5, -0.3, -0.5),
      "hip_yaw": (0.0, 0.3, -0.3),
    }
  used_roles = [r for r in axis_choices if r in present]
  yield {}
  if not used_roles:
    return
  for combo in itertools.product(*(axis_choices[r] for r in used_roles)):
    bias = {j: combo[used_roles.index(role)]
            for j, role in roles.items() if role in used_roles}
    if any(v != 0.0 for v in bias.values()):
      yield bias


def measure(name, seconds, base_z_guess):
  model, robot = build(name)
  best = None
  n_tried = 0
  for bias in _bias_candidates(robot):
    data, qadr = settle(model, robot, bias, base_z_guess, seconds)
    n_tried += 1
    if not np.all(np.isfinite(data.qpos)):
      continue
    quat = data.qpos[3:7]
    height = float(data.qpos[2])
    tilt = tilt_deg(quat)
    residual = float(np.abs(data.qvel).max())
    ok = tilt <= MAX_TILT_DEG and residual < 0.5
    score = height if ok else -1.0
    if best is None or score > best[0]:
      best = (score, data.qpos.copy(), qadr, tilt, residual, height, bool(bias))
  print("  ({} candidate poses tried)".format(n_tried), file=sys.stderr)
  score, qpos, qadr, tilt, residual, height, used_bias = best
  if score < 0:
    print("WARNING: {} did not settle within tilt/velocity thresholds "
          "(best tilt={:.1f} deg, residual={:.3f}, height={:.3f})".format(
            name, tilt, residual, height), file=sys.stderr)

  joint_pos = {}
  for jname in robot.all_joints:
    joint_pos[jname] = round(float(qpos[qadr[jname]]), 6)

  # Symmetrize left/right: the settle is deterministic but not perfectly
  # mirror-symmetric (contact order, tiny numerical drift), and a policy
  # trained against an asymmetric home would be penalized at t=0 for an
  # asymmetry it inherited rather than caused.
  for lj in robot.legs.get("lleg", type("", (), {"joints": ()})).joints:
    suffix = lj.split("-", 1)[1]
    rj = "rleg-" + suffix
    if rj in joint_pos:
      # Mirror joints (roll/yaw at the hip, ankle roll) are antisymmetric;
      # pitch-family joints (hip/knee/ankle pitch) are symmetric. Use the
      # DOF role table to decide which.
      role = robot.leg_dof_names.get(lj, "")
      mean_mag = (abs(joint_pos[lj]) + abs(joint_pos[rj])) / 2.0
      if role in ("hip_roll", "ankle_roll", "hip_yaw", "ankle_yaw"):
        sign_l = 1.0 if joint_pos[lj] >= 0 else -1.0
        sign_r = 1.0 if joint_pos[rj] >= 0 else -1.0
        joint_pos[lj] = round(sign_l * mean_mag, 6)
        joint_pos[rj] = round(sign_r * mean_mag, 6)
      else:
        mean = round((joint_pos[lj] + joint_pos[rj]) / 2.0, 6)
        joint_pos[lj] = mean
        joint_pos[rj] = mean

  home = {
    "base_height": round(height, 6),
    "stand_height": round(max_kinematic_height(model, robot, base_z_guess), 6),
    "base_quat": [round(float(v), 6) for v in qpos[3:7]],
    "joint_pos": joint_pos,
    "settled_seconds": seconds,
    "residual_speed": round(residual, 6),
    "tilt_deg": round(tilt, 3),
    "used_crouch_bias": used_bias,
  }
  return home


def main():
  parser = argparse.ArgumentParser(description=__doc__,
                                    formatter_class=argparse.RawDescriptionHelpFormatter)
  parser.add_argument("robots", nargs="*", default=None)
  parser.add_argument("--seconds", type=float, default=2.0)
  parser.add_argument("--base-z-guess", type=float, default=0.3)
  args = parser.parse_args()

  from kxr_rl.robots import DEFAULT_ROBOTS

  names = args.robots or list(DEFAULT_ROBOTS)
  for name in names:
    home = measure(name, args.seconds, args.base_z_guess)
    out = robot_cfg.home_path(name)
    with out.open("w") as f:
      json.dump(home, f, indent=2, sort_keys=True)
    print("{}: base_height={:.4f} stand_height={:.4f} tilt={:.2f}deg residual={:.4f} "
          "crouch_bias={} -> {}".format(
      name, home["base_height"], home["stand_height"], home["tilt_deg"],
      home["residual_speed"], home["used_crouch_bias"], out))


if __name__ == "__main__":
  main()
