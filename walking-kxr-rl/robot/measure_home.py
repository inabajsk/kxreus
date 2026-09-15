#!/usr/bin/env python3
"""Measure a KXR robot's standing home keyframe by settling it in physics.

    uv run robot/measure_home.py kxrl4d kxrl4t kxrl2g kxrl6

Unlike the walking-hand hand (which needs a hand-designed fingertip stance --
no pose is a natural "rest" pose for that morphology), every KXR body's
``kxreus`` limb-map yaml defines a ``reset-pose`` of all zeros -- i.e. straight
legs is the intended neutral stance for the real hardware. So this tries ALL
ZERO first; only if that does not STAND does it fall back to a grid of crouch
biases, first over the legs and then over every weight-bearing limb, keeping
whichever settles tallest and stillest. Either way the result is *measured*,
not guessed: dropped from just above the floor, held by the position PD, and
recorded once velocities die out -- exactly walking-hand-rl's
robot/measure_home.py, generalized over robots instead of finger stances.

Two things the measurement records that a pose alone does not:

* **Standing means the torso is off the floor.** A pose that settles level and
  still while resting on its belly is not a stance -- it is lying down, and
  every walk reward downstream is meaningless from there. kxrl4t's shipped
  home was exactly that (98% of its weight on the torso).
* **Which limbs it stands ON.** Three of the four KXR bodies here put weight on
  their arms as well as their legs, and kxrl4t stands on nothing but its four
  identical 2-DOF limbs. The loaded limb tips are written to home.json as
  ``support_limbs``, and that is what the gait rewards treat as feet.
* **What each support-limb joint contributes to a step.** How far one joint
  can sweep its own tip fore-aft, how far it can lift it, and over how many
  radians. Written as ``gait_joints``. env_cfgs.py sizes three things from it
  that upstream hard-codes for a 1 m/s humanoid: the commanded speed, the
  velocity-tracking kernel, and -- the one that actually stopped kxrl4t --
  how far the posture regularizer lets a joint leave the home pose. A stride
  this robot can only take with a 0.9 rad hip-yaw sweep is a stride the stock
  0.2 rad posture std scores at ``exp(-20)``, so the posture term forbids the
  only gait the morphology has.
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
from kxr_rl.geometry import baseline_overlaps, self_penetration
from kxr_rl.robot_cfg import SOFT_JOINT_POS_LIMIT_FACTOR
from kxr_rl.robots import RobotSpec, dof_role, load_robot_spec, support_candidates

MAX_TILT_DEG = 25.0  # more tilted than this at rest = not a usable standing home
MAX_RESIDUAL_SPEED = 0.5  # still drifting at the end = not settled
# A stance carries its weight on limb tips. Anything the torso is still taking
# at rest means it is (partly) lying down, not standing.
MAX_TORSO_LOAD_FRAC = 0.05
# A limb tip carrying at least this much of the robot's weight is a support
# limb -- the threshold only has to separate "holding the body up" from the
# grazing contact of a limb that happens to touch.
MIN_SUPPORT_LOAD_FRAC = 0.05
# How far a tip may rise off its lowest point and still count as loadable --
# i.e. as travel that can actually carry the body rather than swing in the air.
STANCE_BAND_FRAC = 0.1

# Roll and yaw joints mirror with OPPOSITE sign: the left and right copies of
# a KXR limb share one world axis, so the mirror of a left bias +v is a right
# bias -v. Feeding both sides the same signed value (which is what the crouch
# grid used to do) swings one limb down and the other UP -- the search then
# never even tries the symmetric stance it is looking for.
_ANTISYMMETRIC_ROLES = ("hip_roll", "hip_yaw", "ankle_roll", "ankle_yaw")

# Crouch grids. Legs with a hip pitch + knee (most KXR bodies) search THOSE --
# the usual crouch lever. Limbs with only yaw/roll (kxrl4t: no pitch, no knee,
# no ankle at all) can only change standing height by rolling the limb under
# the body, so that grid has to reach the far end of the joint range, not just
# nudge it: kxrl4t stands at roll -1.2 rad and the old grid stopped at 0.5.
_PITCH_GRID = {
  "hip_pitch": (-0.5, -0.25, 0.0, 0.25, 0.5),
  "knee": (0.0, 0.4, 0.7, -0.4, -0.7),
  "ankle_pitch": (0.0, -0.35, 0.35),
}
_ROLL_GRID = {
  "hip_roll": (0.0, 0.3, 0.6, 0.9, 1.2, 1.5, -0.3, -0.6, -0.9, -1.2, -1.5),
  "hip_yaw": (0.0, 0.3, -0.3),
}


def build(name):
  from mjlab.entity import EntityCfg
  from mjlab.entity.entity import Entity

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


def ground_load(model, data):
  """Normal force each body exchanges with the floor, keyed by body name."""
  loads: dict[str, float] = {}
  force = np.zeros(6)
  for i in range(data.ncon):
    contact = data.contact[i]
    mujoco.mj_contactForce(model, data, i, force)
    for gid in (contact.geom1, contact.geom2):
      name = mujoco.mj_id2name(model, mujoco.mjtObj.mjOBJ_BODY, model.geom_bodyid[gid])
      if name and name != "world":
        loads[name] = loads.get(name, 0.0) + abs(float(force[0]))
  return loads


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


def _is_left(joint: str) -> bool:
  return joint.startswith("l")


def _mirror_joint(joint: str) -> str:
  """``lleg-crotch-r`` -> ``rleg-crotch-r`` (also lmarm -> rmarm)."""
  return "r" + joint[1:]


def _grid_for(roles: dict[str, str]) -> dict[str, tuple[float, ...]]:
  present = set(roles.values())
  return _PITCH_GRID if ({"hip_pitch", "knee"} & present) else _ROLL_GRID


def _biases_over(roles: dict[str, str]):
  """Crouch poses over one set of limbs, mirrored left/right."""
  grid = _grid_for(roles)
  used = [role for role in grid if role in set(roles.values())]
  if not used:
    return
  for combo in itertools.product(*(grid[role] for role in used)):
    bias = {}
    for joint, role in roles.items():
      if role not in used:
        continue
      value = combo[used.index(role)]
      if role in _ANTISYMMETRIC_ROLES and not _is_left(joint):
        value = -value
      bias[joint] = value
    if any(v != 0.0 for v in bias.values()):
      yield bias


# Clearances tried for the stance solve, metres. Spans 1-20 cm, which covers
# every KXR body here; the tallest one that still puts the tips on the floor
# wins.
_STANCE_CLEARANCES = (0.01, 0.02, 0.03, 0.04, 0.06, 0.08, 0.10, 0.12, 0.15, 0.20)
# Vertices kept per link for the solve. A seed pose does not need the full mesh.
_CLOUD_POINTS = 64


def _link_cloud(model, body_id):
  """Collision vertices of one link, in that link's own frame (subsampled)."""
  chunks = []
  for gid in _body_geom_ids(model, body_id):
    mesh = model.geom_dataid[gid]
    adr, num = model.mesh_vertadr[mesh], model.mesh_vertnum[mesh]
    verts = model.mesh_vert[adr:adr + num]
    mat = np.zeros(9)
    mujoco.mju_quat2Mat(mat, model.geom_quat[gid])
    chunks.append(verts @ mat.reshape(3, 3).T + model.geom_pos[gid])
  if not chunks:
    return None
  cloud = np.concatenate(chunks)
  if len(cloud) > _CLOUD_POINTS:
    cloud = cloud[:: max(1, len(cloud) // _CLOUD_POINTS)]
  return cloud


# Share of the robot's weight that has to come down through limb TIPS before a
# settled pose counts as standing on its feet rather than leaning on something.
WELL_FOOTED_FRAC = 0.9
# Overlap between two links that the pose is allowed to introduce, metres.
MAX_SELF_PENETRATION_M = 0.001
# A limb that reaches at least this fraction as far below a level torso as the
# shortest leg does is expected to CARRY WEIGHT in the home stance. This is what
# decides whether a body stands on everything it has or only on its "legs":
# kxrl6's mid-arms reach exactly as far as its legs (all six: 0.151 m) and are
# legs in every sense but the name; kxrl2g's arms are much shorter than its
# legs and stay off the floor.
LEG_LIKE_REACH_FRAC = 0.9


def limb_reach(model, robot: RobotSpec) -> dict[str, float]:
  """How far below a LEVEL torso each weight-bearing candidate limb's tip can
  reach, metres (positive = down). Pure kinematics over the soft joint range."""
  from scipy.optimize import minimize

  data = mujoco.MjData(model)
  out: dict[str, float] = {}
  for key, limb in support_candidates({**robot.legs, **robot.upper}).items():
    tip = mujoco.mj_name2id(model, mujoco.mjtObj.mjOBJ_BODY, limb.foot_link)
    cloud = _link_cloud(model, tip)
    jid = [mujoco.mj_name2id(model, mujoco.mjtObj.mjOBJ_JOINT, j) for j in limb.joints]
    if cloud is None or any(i < 0 for i in jid):
      continue
    lo = np.array([model.jnt_range[i][0] for i in jid]) * SOFT_JOINT_POS_LIMIT_FACTOR
    hi = np.array([model.jnt_range[i][1] for i in jid]) * SOFT_JOINT_POS_LIMIT_FACTOR

    def lowest(x):
      data.qpos[:] = 0.0
      data.qpos[3] = 1.0
      for i, value in zip(jid, x):
        data.qpos[model.jnt_qposadr[i]] = value
      mujoco.mj_kinematics(model, data)
      return float((cloud @ data.xmat[tip].reshape(3, 3).T + data.xpos[tip])[:, 2].min())

    starts = (np.zeros(len(jid)), (lo + hi) / 2.0, 0.5 * lo, 0.5 * hi)
    out[key] = -min(minimize(lowest, g, bounds=list(zip(lo, hi)),
                             method="L-BFGS-B").fun for g in starts)
  return out


def expected_support(robot: RobotSpec, reach: dict[str, float]) -> list[str]:
  """Limbs that must carry weight in a home stance: the legs, plus any other
  limb that reaches (nearly) as far below the torso as the legs do."""
  leg_reach = min(reach[k] for k in robot.legs if k in reach)
  return sorted(k for k, r in reach.items() if r >= LEG_LIKE_REACH_FRAC * leg_reach)


def solved_stances(model, robot: RobotSpec):
  """Seed pose: torso LEVEL, every weight-bearing limb tip on the floor, and
  left/right symmetric by construction.

  The crouch grid cannot produce this. It moves whole DOF ROLES in lockstep, so
  on a body whose arms are as long and as jointed as its legs the best it finds
  is a lean: kxrl6's measured home put 56% of the robot's weight through its
  ELBOWS -- mid-chain links, not tips -- with the torso pitched 11 deg, the arm
  tips carrying nothing at all, and only the legs actually standing. A stance
  where all four tips share the load has to be solved for, not sampled.

  So: hold the torso level, solve the left limbs' joint angles (mirrored to the
  right, roll/yaw flipping sign) that put every tip on z=0 with the body clear
  above them, and hand the results to the same physics settle as every other
  candidate -- they are seeds, not answers, and one only wins if it settles
  better than the alternatives.

  One seed per clearance is returned rather than "the tallest feasible" one.
  A least-squares solve balances the tip and clearance terms against each
  other, so it lands near the constraints rather than exactly on them; judging
  those near misses by an exact feasibility test threw away every usable seed
  on three of the four robots. The physics settle is the honest judge anyway.
  """
  from scipy.optimize import least_squares

  limbs = support_candidates({**robot.legs, **robot.upper})
  left = {k: v for k, v in limbs.items() if _is_left(k)}
  if not left or len(left) * 2 != len(limbs):
    return None  # no clean left/right pairing to mirror across

  data = mujoco.MjData(model)
  joints = [j for limb in left.values() for j in limb.joints]
  jid = {j: mujoco.mj_name2id(model, mujoco.mjtObj.mjOBJ_JOINT, j) for j in joints}
  if any(i < 0 for i in jid.values()):
    return None
  adr = {j: model.jnt_qposadr[jid[j]] for j in joints}
  lo = np.array([model.jnt_range[jid[j]][0] for j in joints]) * SOFT_JOINT_POS_LIMIT_FACTOR
  hi = np.array([model.jnt_range[jid[j]][1] for j in joints]) * SOFT_JOINT_POS_LIMIT_FACTOR

  tips = {}
  for key, limb in limbs.items():
    body = mujoco.mj_name2id(model, mujoco.mjtObj.mjOBJ_BODY, limb.foot_link)
    tips[key] = (body, _link_cloud(model, body))
  tip_bodies = {body for body, _ in tips.values()}
  # The body (torso, head, anything not part of a weight-bearing limb) has to
  # stand CLEAR of the floor. Without that the solve has a trivial answer --
  # leave every joint at zero and drop the base until the tips reach z=0, which
  # on kxrl6 buries the torso and puts 9.4 N of its 10.1 N weight on the belly.
  #
  # Links INSIDE a limb are held to a weaker rule: not below their own tip.
  # Demanding the same clearance of them asks a shin to float a centimetre
  # above the knee it ends in, which is infeasible for every KXR body -- the
  # first cut of this did exactly that and solved for none of them.
  limb_bodies = set()
  for limb in limbs.values():
    for joint in limb.joints:
      body = mujoco.mj_name2id(model, mujoco.mjtObj.mjOBJ_BODY, joint)
      if body >= 0:
        limb_bodies.add(body)
  clouds = {body: _link_cloud(model, body) for body in range(model.nbody)}
  body_links = [(b, c) for b, c in clouds.items()
                if c is not None and b not in limb_bodies]
  limb_links = [(b, c) for b, c in clouds.items()
                if c is not None and b in limb_bodies and b not in tip_bodies]

  def pose_of(x):
    angles = dict(zip(joints, x[:-1]))
    full = {}
    for j, value in angles.items():
      full[j] = value
      mirror = _mirror_joint(j)
      if mirror in {m for limb in limbs.values() for m in limb.joints}:
        full[mirror] = -value if dof_role(j) in _ANTISYMMETRIC_ROLES else value
    return full, x[-1]

  def lowest(x):
    full, height = pose_of(x)
    data.qpos[:] = 0.0
    data.qpos[2] = height
    data.qpos[3] = 1.0
    for j, value in full.items():
      body_jid = mujoco.mj_name2id(model, mujoco.mjtObj.mjOBJ_JOINT, j)
      if body_jid >= 0:
        data.qpos[model.jnt_qposadr[body_jid]] = value
    mujoco.mj_kinematics(model, data)
    mujoco.mj_comPos(model, data)

    def contact(body, cloud):
      world = cloud @ data.xmat[body].reshape(3, 3).T + data.xpos[body]
      lowest = world[world[:, 2].argmin()]
      return float(lowest[2]), float(lowest[0])

    tip_z, tip_x = [], []
    for body, cloud in tips.values():
      z, x = contact(body, cloud)
      tip_z.append(z)
      tip_x.append(x)
    balance = float(np.mean(tip_x) - data.subtree_com[0][0])
    return (tip_z,
            [contact(body, cloud)[0] for body, cloud in body_links],
            [contact(body, cloud)[0] for body, cloud in limb_links],
            balance)

  def make_residuals(clearance):
    def residuals(x):
      tip_z, body_z, mid_z, balance = lowest(x)
      # Tips reaching the floor matters most; the clearance term is what pushes
      # the stance taller, and the two pull against each other.
      out = [5.0 * z for z in tip_z]
      out.extend(max(0.0, clearance - z) for z in body_z)
      out.extend(max(0.0, -z) for z in mid_z)
      # Put the contact patch UNDER the centre of mass. Without this the solve
      # is free to sweep the legs back and tuck the arms in, which is what it
      # did on kxrl6: four tips level at the same height, but spanning
      # x = -0.175..0.0 with the COM at +0.018 -- in front of every contact, so
      # the robot tips onto its arms the instant physics starts.
      out.append(5.0 * balance)
      # A light pull toward the neutral pose, enough to break ties between
      # equivalent stances without overriding the clearance term -- at 0.05 it
      # dominated, and kxrl6 (whose limbs all reach 0.151 m below a level
      # torso) was held down at 0.06 m in a permanent 11 deg lean.
      out.extend(0.005 * x[:-1])
      return out
    return residuals

  bounds = (np.append(lo, 0.005), np.append(hi, 1.0))
  guess = np.concatenate([np.zeros(len(joints)), [0.15]])
  out = []
  for clearance in _STANCE_CLEARANCES:
    try:
      fit = least_squares(make_residuals(clearance), guess, bounds=bounds,
                          max_nfev=1500)
    except Exception:
      continue
    full, _ = pose_of(fit.x)
    out.append({j: float(v) for j, v in full.items()})
    guess = fit.x.copy()  # warm start the next, taller, attempt
  return out


def _bias_candidates(model, robot: RobotSpec):
  """All-zero (the hardware's own neutral pose), then crouch grids.

  Two grids, in order: the legs alone, then every weight-bearing limb. A body
  whose legs cannot lift its torso on their own may still stand on all four of
  its limbs -- three of the four KXR bodies here do -- and the leg-only search
  can never find that stance.
  """
  yield {}
  for solved in solved_stances(model, robot):
    yield solved
  seen = set()
  for limbs in (robot.legs, support_candidates({**robot.legs, **robot.upper})):
    roles = {j: dof_role(j) for limb in limbs.values() for j in limb.joints}
    for bias in _biases_over(roles):
      key = tuple(sorted(bias.items()))
      if key in seen:
        continue
      seen.add(key)
      yield bias


def _symmetrize(robot: RobotSpec, joint_pos: dict[str, float]) -> dict[str, float]:
  """Mirror every left/right limb pair, respecting each role's parity.

  The settle is deterministic but not perfectly mirror-symmetric (contact
  order, tiny numerical drift), and a policy trained against an asymmetric
  home would be penalized at t=0 for an asymmetry it inherited rather than
  caused. Roll/yaw pairs mirror with opposite signs; pitch pairs with the
  same sign. The caller re-settles the result and keeps it only if it still
  stands, so an unlucky mirror cannot make the home worse.
  """
  out = dict(joint_pos)
  for lj in joint_pos:
    if not _is_left(lj):
      continue
    rj = _mirror_joint(lj)
    if rj not in joint_pos:
      continue
    mean_mag = (abs(joint_pos[lj]) + abs(joint_pos[rj])) / 2.0
    if dof_role(lj) in _ANTISYMMETRIC_ROLES:
      sign = 1.0 if joint_pos[lj] >= 0 else -1.0
      out[lj] = round(sign * mean_mag, 6)
      out[rj] = round(-sign * mean_mag, 6)
    else:
      mean = round((joint_pos[lj] + joint_pos[rj]) / 2.0, 6)
      out[lj] = mean
      out[rj] = mean
  return out


def _tip_load_frac(robot, loads, weight):
  """Share of the robot's weight coming down through weight-bearing limb TIPS.

  kxrl6's measured home scored 0.44: its legs stood on their knees while 56% of
  the robot went through its ELBOWS, mid-chain links that no gait reward can
  see, with the torso pitched 11 deg. Standing on the torso is caught by the
  torso gate; standing on an elbow needs this one.
  """
  candidates = support_candidates({**robot.legs, **robot.upper})
  tips = sum(loads.get(limb.foot_link, 0.0) for limb in candidates.values())
  return tips / weight if weight > 0 else 0.0


def _evaluate(model, robot, data, weight, baseline, required):
  """(clean, fully_footed, well_footed, stands, settled, height, tilt, residual,
  loads, penetration, pair)."""
  if not np.all(np.isfinite(data.qpos)):
    return None
  height = float(data.qpos[2])
  tilt = tilt_deg(data.qpos[3:7])
  residual = float(np.abs(data.qvel).max())
  loads = ground_load(model, data)
  torso_load = loads.get(robot.torso_link, 0.0)
  penetration, pair = self_penetration(model, data, baseline)
  settled = tilt <= MAX_TILT_DEG and residual < MAX_RESIDUAL_SPEED
  stands = settled and torso_load <= MAX_TORSO_LOAD_FRAC * weight
  well_footed = stands and _tip_load_frac(robot, loads, weight) >= WELL_FOOTED_FRAC
  clean = stands and penetration <= MAX_SELF_PENETRATION_M
  # Every limb that is a leg by reach is actually standing. Without this tier
  # the tallest clean stance wins, and on kxrl6 that is the one that lifts the
  # two mid-arms clear of the floor and stands on four of its six legs.
  loaded = set(_support_limbs(robot, loads, weight))
  fully_footed = stands and all(k in loaded for k in required)
  return (clean, fully_footed, well_footed, stands, settled, height, tilt,
          residual, loads, penetration, pair)


def _body_geom_ids(model, body_id):
  return [g for g in range(model.ngeom)
          if model.geom_bodyid[g] == body_id
          and (model.geom_contype[g] or model.geom_conaffinity[g])
          and model.geom_dataid[g] >= 0]


def measure_foot_offsets(model, robot: RobotSpec, qpos, support_keys):
  """Where a support limb actually touches the floor, in its tip link's frame.

  The tip LINK ORIGIN is not the contact point. On kxrl4t it is the roll joint
  itself, 3 cm inboard of the rubber that meets the floor -- so a site placed
  at the origin cannot change height when the roll joint moves, and every
  reward reading foot height or foot slip off that site reads a point that
  never lifts. Measured instead: the lowest collision vertex of the tip link
  in the settled home stance, expressed in the link's own frame.
  """
  data = mujoco.MjData(model)
  data.qpos[:] = qpos
  mujoco.mj_forward(model, data)
  limbs = {**robot.legs, **robot.upper}
  offsets: dict[str, list[float]] = {}
  for key in support_keys:
    body = mujoco.mj_name2id(
      model, mujoco.mjtObj.mjOBJ_BODY, limbs[key].foot_link)
    lowest, point = np.inf, None
    for gid in _body_geom_ids(model, body):
      mesh = model.geom_dataid[gid]
      adr, num = model.mesh_vertadr[mesh], model.mesh_vertnum[mesh]
      rot = data.geom_xmat[gid].reshape(3, 3)
      world = model.mesh_vert[adr:adr + num] @ rot.T + data.geom_xpos[gid]
      idx = int(world[:, 2].argmin())
      if world[idx, 2] < lowest:
        lowest, point = float(world[idx, 2]), world[idx]
    if point is None:
      offsets[key] = [0.0, 0.0, 0.0]
      continue
    body_rot = data.xmat[body].reshape(3, 3)
    local = body_rot.T @ (point - data.xpos[body])
    offsets[key] = [round(float(v), 6) for v in local]
  return offsets


def measure_gait_joints(model, robot: RobotSpec, qpos, support_keys, foot_offsets,
                        stance_band):
  """Per support-limb joint: how far it moves its own tip, and over what range.

  Swept from the settled home stance, one joint at a time over the range the
  policy is actually allowed to command, reading the tip BODY (not its site --
  the sites are built from the PREVIOUS measurement's support set, which is
  exactly what this run is replacing).

  ``span_x_m`` is the tip's total fore-aft travel and ``span_z_m`` how far it
  can lift clear of the floor, both over ``range_rad`` of joint travel.

  ``stride_m`` is the part that matters: fore-aft travel restricted to the
  portion of the sweep where the tip is still low enough to be IN STANCE. A
  hip pitch swings its foot through a long arc, but most of that arc is in the
  air and carries the body nowhere -- measuring the whole arc credits kxrl2g
  with a 0.31 m stride and a 0.72 m/s top speed, for a robot 0.17 m tall.
  kxrl4t is the case where the two agree: its yaw sweep moves the tip level,
  so all of it is stance.
  """
  data = mujoco.MjData(model)
  limbs = {**robot.legs, **robot.upper}
  out: dict[str, dict[str, float]] = {}
  for key in support_keys:
    limb = limbs[key]
    tip = mujoco.mj_name2id(model, mujoco.mjtObj.mjOBJ_BODY, limb.foot_link)
    sole = np.array(foot_offsets[key])
    for joint in limb.joints:
      jid = mujoco.mj_name2id(model, mujoco.mjtObj.mjOBJ_JOINT, joint)
      if jid < 0:
        continue
      adr = model.jnt_qposadr[jid]
      lo, hi = model.jnt_range[jid] * SOFT_JOINT_POS_LIMIT_FACTOR
      samples = np.linspace(lo, hi, 81)
      xs, zs = [], []
      for value in samples:
        data.qpos[:] = qpos
        data.qpos[adr] = value
        mujoco.mj_forward(model, data)
        contact = data.xpos[tip] + data.xmat[tip].reshape(3, 3) @ sole
        xs.append(float(contact[0]))
        zs.append(float(contact[2]))
      xs, zs = np.array(xs), np.array(zs)
      grounded = zs <= zs.min() + stance_band
      out[joint] = {
        "span_x_m": round(float(xs.max() - xs.min()), 6),
        "span_z_m": round(float(zs.max() - zs.min()), 6),
        "stride_m": round(
          float(xs[grounded].max() - xs[grounded].min()) if grounded.any() else 0.0, 6),
        "range_rad": round(float(hi - lo), 6),
      }
  return out


def _support_limbs(robot: RobotSpec, loads: dict[str, float], weight: float):
  candidates = support_candidates({**robot.legs, **robot.upper})
  return sorted(
    key for key, limb in candidates.items()
    if loads.get(limb.foot_link, 0.0) >= MIN_SUPPORT_LOAD_FRAC * weight
  )


def measure(name, seconds, base_z_guess):
  model, robot = build(name)
  baseline = baseline_overlaps(model)
  reach = limb_reach(model, robot)
  required = expected_support(robot, reach)
  print("  (reach below torso: {}; must stand on {})".format(
    {k: round(v, 3) for k, v in sorted(reach.items())}, required), file=sys.stderr)
  weight = float(model.body_mass.sum()) * 9.81
  best = None
  n_tried = 0
  for bias in _bias_candidates(model, robot):
    data, qadr = settle(model, robot, bias, base_z_guess, seconds)
    n_tried += 1
    verdict = _evaluate(model, robot, data, weight, baseline, required)
    if verdict is None:
      continue
    clean, fully_footed, well_footed, stands, settled, height = verdict[:6]
    # In order: a pose the hardware could actually adopt (no link driven
    # through another -- self-collision is off here, so physics will hold an
    # arm inside a torso without complaint); standing on EVERY leg-length
    # limb; standing on the limb TIPS rather than on an elbow or a shin;
    # standing at all rather than lying on the belly; settled rather than
    # diverged; and only then, taller.
    score = (clean, fully_footed, well_footed, stands, settled, height)
    if best is None or score > best[0]:
      best = (score, data.qpos.copy(), qadr, verdict)
  print("  ({} candidate poses tried)".format(n_tried), file=sys.stderr)

  score, qpos, qadr, verdict = best
  joint_pos = {j: round(float(qpos[qadr[j]]), 6) for j in robot.all_joints}

  # Symmetrize, then VERIFY: keep the mirrored pose only if it still stands at
  # least as well. Measured, not assumed.
  sym = _symmetrize(robot, joint_pos)
  if sym != joint_pos:
    data_s, qadr_s = settle(model, robot, sym, base_z_guess, seconds)
    verdict_s = _evaluate(model, robot, data_s, weight, baseline, required)
    if verdict_s is not None:
      score_s = tuple(verdict_s[:6])
      # Height may legitimately dip a hair when mirroring; only reject a
      # mirror that loses standing or drops more than 2 mm.
      if score_s[:5] >= score[:5] and score_s[5] >= score[5] - 0.002:
        qpos, qadr, verdict, score = data_s.qpos.copy(), qadr_s, verdict_s, score_s
        joint_pos = {j: round(float(qpos[qadr[j]]), 6) for j in robot.all_joints}

  (clean, fully_footed, well_footed, stands, settled, height, tilt, residual,
   loads, penetration, pen_pair) = verdict
  if not fully_footed:
    print("WARNING: {} best pose does not stand on every leg-length limb "
          "(required {}, loaded {})".format(
            name, required, _support_limbs(robot, loads, weight)), file=sys.stderr)
  if not clean:
    print("WARNING: {} best pose drives {} through {} by {:.1f} mm -- "
          "self-collision is disabled, so nothing in the physics stops it, but "
          "the real robot cannot hold this stance".format(
            name, *(pen_pair or ("?", "?")), 1000.0 * penetration),
          file=sys.stderr)
  if not stands:
    print("WARNING: {} never settled into a STANDING pose (best: tilt={:.1f} deg, "
          "residual={:.3f}, height={:.3f}, torso carries {:.0f}% of its weight). "
          "The walk task needs the torso off the floor; check the MJCF."
          .format(name, tilt, residual, height,
                  100.0 * loads.get(robot.torso_link, 0.0) / weight),
          file=sys.stderr)

  support = _support_limbs(robot, loads, weight)
  if stands and not support:
    raise AssertionError(
      "{}: stands with the torso clear but no limb tip carries load -- "
      "the contact measurement disagrees with itself".format(name))

  foot_offsets = measure_foot_offsets(model, robot, qpos, support)
  # A tip within this much of its lowest point still counts as in stance.
  stance_band = max(0.005, STANCE_BAND_FRAC * height)
  gait_joints = measure_gait_joints(
    model, robot, qpos, support, foot_offsets, stance_band)
  return {
    "base_height": round(height, 6),
    "foot_offsets": foot_offsets,
    "gait_joints": gait_joints,
    "stance_band_m": round(stance_band, 6),
    "stride_span_m": round(
      max((m["stride_m"] for m in gait_joints.values()), default=0.0), 6),
    "base_quat": [round(float(v), 6) for v in qpos[3:7]],
    "joint_pos": joint_pos,
    "settled_seconds": seconds,
    "residual_speed": round(residual, 6),
    "tilt_deg": round(tilt, 3),
    "stands": bool(stands),
    "well_footed": bool(well_footed),
    "fully_footed": bool(fully_footed),
    "limb_reach_m": {k: round(v, 6) for k, v in sorted(reach.items())},
    "expected_support": required,
    "self_penetration_mm": round(1000.0 * penetration, 3),
    "tip_load_frac": round(_tip_load_frac(robot, loads, weight), 4),
    "torso_load_frac": round(loads.get(robot.torso_link, 0.0) / weight, 4),
    "support_limbs": support,
    "support_load_n": {k: round(loads.get(v.foot_link, 0.0), 4)
                       for k, v in support_candidates(
                         {**robot.legs, **robot.upper}).items()},
  }


def main():
  parser = argparse.ArgumentParser(description=__doc__,
                                    formatter_class=argparse.RawDescriptionHelpFormatter)
  parser.add_argument("robots", nargs="*", default=None)
  parser.add_argument("--seconds", type=float, default=2.0)
  parser.add_argument("--base-z-guess", type=float, default=0.3)
  parser.add_argument("--dry-run", action="store_true",
                      help="measure and print, do not overwrite home.json")
  args = parser.parse_args()

  from kxr_rl.robots import DEFAULT_ROBOTS

  names = args.robots or list(DEFAULT_ROBOTS)
  for name in names:
    home = measure(name, args.seconds, args.base_z_guess)
    out = robot_cfg.home_path(name)
    if not args.dry_run:
      with out.open("w") as f:
        json.dump(home, f, indent=2, sort_keys=True)
    print("{}: base_height={:.4f} tilt={:.2f}deg stands={} tip_load={:.0%} "
          "selfpen={:.1f}mm support={} stride={:.4f}m -> {}".format(
            name, home["base_height"], home["tilt_deg"], home["stands"],
            home["tip_load_frac"], home["self_penetration_mm"],
            home["support_limbs"], home["stride_span_m"],
            "(dry run)" if args.dry_run else out))


if __name__ == "__main__":
  main()
