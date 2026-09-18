"""Generic velocity-task env cfg for any KXR leg-type robot.

Unlike walking-hand-rl (which had to override nearly everything -- the hand
crawls on its fingertips, not legs), a KXR biped IS the morphology
``make_velocity_env_cfg()`` was built for. This module mostly just PARAMETERIZES
the stock recipe from the parsed ``RobotSpec`` (torso link, foot links, leg
DOF roles) instead of hand-writing it per robot, and adds exactly one new
task mode -- ``getup`` -- for which upstream has no equivalent (its robots
never start lying down).
"""

from __future__ import annotations

import json
import math
import os
import re

from mjlab.envs import ManagerBasedRlEnvCfg
from mjlab.envs import mdp as envs_mdp
from mjlab.envs.mdp.actions import JointPositionActionCfg
from mjlab.managers.event_manager import EventTermCfg
from mjlab.managers.reward_manager import RewardTermCfg
from mjlab.managers.scene_entity_config import SceneEntityCfg
from mjlab.managers.termination_manager import TerminationTermCfg
from mjlab.sensor import ContactMatch, ContactSensorCfg, RayCastSensorCfg
from mjlab.tasks.velocity.mdp import UniformVelocityCommandCfg
from src.tasks.velocity.velocity_env_cfg import make_velocity_env_cfg

from . import _mdp as mdp
from .robot_cfg import foot_site_name, get_robot_cfg, home_path
from .robots import load_robot_spec

# Per-support-DOF-role posture looseness. Hips/knees need room to stride; ankle
# roll (balance) and the mid-hip roll/yaw stay tighter. Anything not in this
# table (a limb the robot does NOT stand on -- a free arm, the head, a gripper
# -- or an unusual DOF name) gets a loose default: those joints do not affect
# locomotion directly, they just should not be rigid statues.
_ROLE_STD = {
  "hip_pitch": 0.5, "hip_roll": 0.2, "hip_yaw": 0.2,
  "knee": 0.5,
  "ankle_pitch": 0.2, "ankle_roll": 0.1, "ankle_yaw": 0.2,
}
_DEFAULT_STD = 0.3

GAIT_PERIOD = float(os.environ.get("KXR_GAIT_PERIOD", "0.6"))

# Fraction of its mechanical stride a real gait actually uses -- no gait sweeps
# a joint end to end. Calibrated against tools/openloop_gait.py on kxrl4t: a
# 0.0814 m stride delivered once per 0.3 s stance predicts 0.190 m/s, and the
# hand-written open-loop trot measured 0.195 m/s.
STRIDE_UTILIZATION = 0.7
# A support-limb joint counts as a gait joint -- one the posture term must let
# swing -- if it carries this share of the stride, or lifts the tip clear.
GAIT_JOINT_SHARE = 0.5

_PRESETS: dict[str, dict[str, str]] = {
  "walk": {},
  "getup": {"KXR_GETUP": "1", "KXR_GETUP_DR": "1"},
}


class _Opts:
  """Option lookup: explicit environment first, then the task preset."""

  def __init__(self, preset: str) -> None:
    if preset not in _PRESETS:
      raise KeyError("unknown preset {!r} (have {})".format(preset, sorted(_PRESETS)))
    self._values = _PRESETS[preset]

  def raw(self, name: str, default: str = "") -> str:
    value = os.environ.get(name)
    # An env var set to the empty string means "not set" -- otherwise
    # `KXR_IMPRATIO= uv run ...` (the natural way to write "use the default"
    # in a shell loop) reaches float("") and raises.
    if value is None or not value.strip():
      return self._values.get(name, default)
    return value

  def flag(self, name: str) -> bool:
    return self.raw(name).strip().lower() not in ("", "0", "false", "no", "off")

  def num(self, name: str, default: float) -> float:
    return float(self.raw(name, str(default)))


def _home(name: str) -> dict:
  with home_path(name).open() as f:
    return json.load(f)


def _task_overrides(name: str) -> dict:
  """Per-robot task settings that the measurement-based derivation gets wrong.

  ``robot/mjcf/<name>/task.json``, written by hand and carrying its own
  ``why``. This is deliberately NOT part of home.json (which holds measured
  facts) and NOT an environment variable (which play.py would need every time):
  a shipped policy has to replay under exactly the command it was trained on,
  with nothing to remember. Env vars still win over this file, for experiments.

  Only kxrl6 has one so far -- see the file for the two numbers and the
  measurements behind each.
  """
  path = home_path(name).with_name("task.json")
  if not path.exists():
    return {}
  with path.open() as f:
    return json.load(f)


class _SpeedScale:
  """What "moving" means, in this robot's own units.

  Every speed number in the stock recipe is sized for a 1 m/s humanoid: the
  velocity-tracking kernel's std (0.5), and a family of ``command_threshold``
  gates at 0.05-0.1 m/s that switch the gait rewards on only once the robot is
  asked to move "fast enough". Scaling the command down to a 13 cm robot
  without scaling those leaves a task that cannot be solved:

  * tracking. ``exp(-||cmd - v||^2 / std^2)`` with std=0.5 and a 0.1 m/s
    command pays a motionless robot ``exp(-0.01/0.25) = 0.99`` of the maximum.
    Moving is worth 0.01 reward; the action-rate penalty for moving is worth
    more. kxrl4t duly learned to march in place at 0.0014 m/s -- with mean
    reward 63 and a full 1000-step episode, which is why this needs measuring
    rather than reading off the training log.
  * gates. kxrl4t's whole usable speed range tops out at 0.19 m/s, so
    foot_clearance, foot_slip and soft_landing (threshold 0.1) barely switch
    on, while ``stand_still`` -- which penalizes any deviation from the home
    pose -- barely switches OFF.

  So the scale comes from the robot: ``stride_span_m`` (measured by
  measure_home.py: the furthest one support limb can carry its own tip
  fore-aft) delivered once per stance phase gives the top speed it can
  physically hold. The kernel width is half of that, in the legged-gym
  proportion where standing still under a top-speed command scores
  ``exp(-4)``. The commanded band never includes zero -- a target of "don't
  move" is the standing-still basin the playbook warns about.

  ``tools/openloop_gait.py`` checks the result against a hand-written gait:
  the derived ceiling should land near what the morphology can actually do.

  Robots whose home.json predates the stride measurement keep the previous
  hard-coded ladder untouched.
  """

  def __init__(self, stride_span_m: float, gait_period: float,
               v_max_override: float = 0.0) -> None:
    # One stride is delivered per STANCE phase, which is half the gait cycle --
    # dividing by the whole period undercounts the robot by 2x. (It did: the
    # first cut of this put kxrl4t's ceiling at 0.067 m/s when an open-loop
    # trot walks it at 0.194.)
    self.v_max = STRIDE_UTILIZATION * stride_span_m / (0.5 * gait_period)
    # $KXR_VMAX pins the top speed explicitly. The stride-based derivation is
    # calibrated on kxrl4t; on kxrl6's six-limb stance, where every limb lies
    # nearly flat, a single yaw sweep carries the contact point 0.35 m and the
    # derivation claims 0.81 m/s for an 8.6 cm tall body -- seven times what
    # an open-loop tripod actually manages. This is the knob for testing that.
    if v_max_override > 0.0:
      self.v_max = v_max_override
    self.v_min = 0.5 * self.v_max
    self.std = 0.5 * self.v_max
    # The ANGULAR kernel is deliberately left at upstream's 0.7071, even though
    # the same argument that rescales the linear one applies to it on paper: a
    # kxrl4t drifting 0.16 rad/s (90 deg off heading over ten seconds, while
    # commanded straight) scores exp(-0.05) = 0.95, so curving away is nearly
    # free. Rescaling it by the same factor was tried and measured, and it made
    # the robot much worse: heading held (drift 62 -> 17 deg peak) but mean
    # speed fell 0.133 -> 0.027 m/s, with four of six seeds back to standing
    # still. This robot turns as a SIDE EFFECT of walking -- its limbs load
    # asymmetrically -- so pricing yaw error near the task reward just restores
    # the standing-still basin from the other direction. Left as is.

    # "Is it being asked to move?" -- true everywhere in the commanded band.
    self.move_gate = 0.5 * self.v_min


def kxr_env_cfg(
  robot_name: str, preset: str = "walk", play: bool = False
) -> ManagerBasedRlEnvCfg:
  """Velocity task configuration for one KXR robot. ``preset`` in {"walk","getup"}."""
  opt = _Opts(preset)
  robot = load_robot_spec(robot_name)
  home = _home(robot_name)
  task = _task_overrides(robot_name)
  home_height = float(home["base_height"])
  stride_span = float(home.get("stride_span_m") or 0.0)
  v_max_override = opt.num("KXR_VMAX", float(task.get("v_max", 0.0)))
  speed = (_SpeedScale(stride_span, GAIT_PERIOD, v_max_override)
           if stride_span > 0.0 else None)
  # m/s, symmetric on x, y and yaw -- 0 (default) leaves every branch below
  # exactly as it was (forward-only, no strafing: see twist.ranges.lin_vel_y's
  # own assignment just below). Every deployed policy so far can only walk
  # forward and turn, which was a deliberate first-generation choice, not a
  # hardware limit -- this opts a run into the fuller command space instead.
  omni_range = opt.num("KXR_OMNI_RANGE", 0.0)
  # "Feet" = the tips of the limbs the measured home stance actually stands on.
  # For most KXR bodies that is the two legs; kxrl4t stands on all four of its
  # identical 2-DOF limbs, so all four are gait limbs (see robots.py).
  support_keys = list(robot.support)
  foot_links = list(robot.support_links)
  foot_sites = tuple(foot_site_name(k) for k in support_keys)

  cfg = make_velocity_env_cfg()
  cfg.scene.entities = {"robot": get_robot_cfg(robot_name)}

  # Flat plane only: no terrain generator, no height scan -- a robot this
  # small has no meaningful use for rough-terrain raycasting.
  assert cfg.scene.terrain is not None
  cfg.scene.terrain.terrain_type = "plane"
  cfg.scene.terrain.terrain_generator = None
  cfg.scene.sensors = tuple(
    s for s in (cfg.scene.sensors or ()) if not isinstance(s, RayCastSensorCfg))
  del cfg.observations["actor"].terms["height_scan"]
  del cfg.observations["critic"].terms["height_scan"]
  cfg.curriculum.pop("terrain_levels", None)
  cfg.observations["critic"].terms["foot_height"].params["asset_cfg"].site_names = foot_sites

  foot_body_pattern = r"^({})$".format("|".join(re.escape(link) for link in foot_links))
  feet_ground_cfg = ContactSensorCfg(
    name="feet_ground_contact",
    primary=ContactMatch(mode="body", pattern=foot_body_pattern, entity="robot"),
    secondary=ContactMatch(mode="body", pattern="terrain"),
    fields=("found", "force"), reduce="netforce", num_slots=1, track_air_time=True,
  )
  # Torso touching the ground while WALKING means the stance collapsed; while
  # lying down at the START of get-up it is the task's own initial condition,
  # so this termination is popped in that branch below (same "the fallen
  # posture is the task, not a failure" logic walking-hand-rl uses for its
  # palm-down termination).
  torso_ground_cfg = ContactSensorCfg(
    name="torso_ground_contact",
    primary=ContactMatch(mode="body", pattern=re.escape(robot.torso_link), entity="robot"),
    secondary=ContactMatch(mode="body", pattern="terrain"),
    fields=("found", "force"), reduce="netforce", num_slots=1,
  )
  cfg.scene.sensors = (cfg.scene.sensors or ()) + (feet_ground_cfg, torso_ground_cfg)

  # Many small contacts on a plane; no CCD needed (mirrors walking-hand-rl).
  # njmax needs real headroom here: unlike the hand (feet/palm only), EVERY
  # collision geom on a KXR body is enabled against the ground (get-up needs
  # the whole body to be able to push off the floor), so a robot that
  # tips over during WALK training can put its whole body in contact at
  # once too, not just its feet. 300 (the hand's flat-terrain value)
  # overflowed at "njmax must be >= 1212" on kxrl4d's first fall; 900 clears
  # comfortably with room to spare.
  cfg.sim.njmax = 2000
  cfg.sim.nconmax = None
  cfg.sim.mujoco.ccd_iterations = 50
  cfg.sim.contact_sensor_maxmatch = 64

  # MuJoCo's default impratio=1 makes friction "soft" relative to the normal
  # constraint: a foot starts sliding before Coulomb friction fully engages, so
  # a policy that skates along on planted feet can be physically optimal and no
  # amount of reward shaping will talk it out of that. Raising impratio with an
  # elliptic cone is the standard fix. Off by default -- it changes contact
  # physics for every robot, including the ones whose shipped policies were
  # trained under the stock value -- so it is opt-in per run via $KXR_IMPRATIO.
  # NOTE the nested path: cfg.sim.impratio is silently ignored, only
  # cfg.sim.mujoco.impratio reaches the compiled model.
  impratio = opt.num("KXR_IMPRATIO", 0.0)
  if impratio > 0.0:
    cfg.sim.mujoco.impratio = impratio
    cfg.sim.mujoco.cone = "elliptic"

  cfg.viewer.body_name = robot.torso_link
  cfg.viewer.distance = max(0.5, 6.0 * home_height)
  cfg.viewer.elevation = -15.0

  # These are small, weak-actuator (0.656 N*m) bodies, not full-size
  # humanoids -- top speed is scaled down from upstream's (-1, 2) m/s roughly
  # by leg-length ratio. Forward-only (like the hand) keeps the tracking
  # kernel's useful range concentrated rather than split across +/-.
  twist = cfg.commands["twist"]
  assert isinstance(twist, UniformVelocityCommandCfg)
  twist.ranges.lin_vel_y = (0.0, 0.0)
  twist.heading_command = False
  twist.ranges.heading = None

  if speed is not None:
    # Forward-only, never zero, inside what the morphology can hold. Turning is
    # commanded off while straight-line walking is what is being learned: a
    # yaw command the robot answers by pivoting looks like forward-speed noise
    # to the tracking term.
    twist.ranges.lin_vel_x = (speed.v_min, speed.v_max)
    twist.ranges.ang_vel_z = (0.0, 0.0)
    twist.rel_standing_envs = 0.0
    cfg.rewards["track_linear_velocity"].params["std"] = speed.std
    # The stock ladder walks the command from 0 up to a speed this robot has
    # no way to reach; the band above is already inside its means. Left in
    # place (not popped) when omni_range is on: that override, below, needs
    # cfg.curriculum["command_vel"] to still exist to set its own stages.
    if omni_range <= 0.0:
      cfg.curriculum.pop("command_vel", None)
  else:
    twist.ranges.lin_vel_x = (0.0, 0.3)
    twist.ranges.ang_vel_z = (-0.3, 0.3)
    twist.rel_standing_envs = 0.05
    cfg.curriculum["command_vel"].params["velocity_stages"] = [
      {"step": 0, "lin_vel_x": (0.0, 0.10), "lin_vel_y": (0.0, 0.0),
       "ang_vel_z": (-0.1, 0.1)},
      {"step": 800 * 24, "lin_vel_x": (0.0, 0.20), "lin_vel_y": (0.0, 0.0),
       "ang_vel_z": (-0.2, 0.2)},
      {"step": 1600 * 24, "lin_vel_x": (0.0, 0.30), "lin_vel_y": (0.0, 0.0),
       "ang_vel_z": (-0.3, 0.3)},
    ]

  if omni_range > 0.0:
    # Capped to what this ROBOT's own body can actually hold (speed.v_max,
    # already measured above from its own stride) rather than applied as
    # one flat number for all four: kxrl4d/kxrl6/kxrl2g's own v_max (0.29,
    # 0.35, 0.32 m/s) all clear a flat 0.3 comfortably, but kxrl4t's own
    # is only 0.19 -- asking it for 0.3 m/s omnidirectionally was asking
    # for 58% more than it can physically do, in every direction, for the
    # whole run. Real training data said so: alone among the four,
    # kxrl4t's own Metrics/twist/error_vel_xy never recovered (0.33 ->
    # 0.43 m/s over the run) where the other three all ended at 0.19-0.22,
    # and a policy chasing a target that can never be reached has no
    # reason to ever stop increasing its own effort trying. speed is
    # always set here (only the `speed is not None` branch above can
    # reach this one with cfg.curriculum["command_vel"] intact -- see its
    # own guard), so this is never None to cap against.
    effective_omni_range = min(omni_range, speed.v_max)
    # track_linear_velocity's own reward kernel width (std) WAS left
    # exactly as whichever branch above set it (the `speed is not None`
    # branch's own speed.std, sized for a one-sided band roughly half
    # speed.v_max wide -- 0.1-0.175 m/s across these four robots). Real
    # training data then said so: the first omni run (KXR_OMNI_RANGE=0.3,
    # this std left untouched) plateaued in well under its own extension
    # budget while Metrics/twist/error_vel_xy got WORSE between chunks
    # (kxrl4d 0.114 -> 0.136 m/s) -- a kernel this narrow next to errors
    # this large sits so close to zero everywhere in the now much bigger
    # 2D command box that there is little gradient telling "closer" from
    # "further", the exact failure mode _SpeedScale's own class
    # docstring already describes for an unscaled kernel. Set to
    # effective_omni_range itself instead: wider than the old per-robot
    # std on purpose, since the command band is now 2D and several times
    # wider per axis, not guessed independently of that -- retune again
    # from HERE if the same regression shows up.
    cfg.rewards["track_linear_velocity"].params["std"] = effective_omni_range
    twist.ranges.lin_vel_x = (-effective_omni_range, effective_omni_range)
    twist.ranges.lin_vel_y = (-effective_omni_range, effective_omni_range)
    twist.ranges.ang_vel_z = (-0.3, 0.3)
    twist.rel_standing_envs = 0.05
    cfg.curriculum["command_vel"].params["velocity_stages"] = [
      {"step": step,
       "lin_vel_x": (-effective_omni_range * frac, effective_omni_range * frac),
       "lin_vel_y": (-effective_omni_range * frac, effective_omni_range * frac),
       "ang_vel_z": (-0.3 * frac, 0.3 * frac)}
      for step, frac in ((0, 1 / 3), (800 * 24, 2 / 3), (1600 * 24, 1.0))
    ]

  cfg.events["reset_base"].params["pose_range"] = {
    "x": (-0.1, 0.1), "y": (-0.1, 0.1), "z": (0.0, 0.0), "yaw": (-3.14, 3.14),
  }
  cfg.events["push_robot"].params["velocity_range"] = {
    "x": (-0.15, 0.15), "y": (-0.15, 0.15), "z": (0.0, 0.0),
    "roll": (-0.2, 0.2), "pitch": (-0.2, 0.2), "yaw": (-0.3, 0.3),
  }
  cfg.events["foot_friction"].params["asset_cfg"].geom_names = tuple(
    r"^{}_collision\d+$".format(re.escape(link)) for link in foot_links)
  cfg.events["foot_friction"].params["ranges"] = (0.5, 1.0)
  cfg.events["base_com"].params["asset_cfg"].body_names = (robot.torso_link,)

  joint_pos_action = cfg.actions["joint_pos"]
  assert isinstance(joint_pos_action, JointPositionActionCfg)
  joint_pos_action.scale = 0.25

  ##
  # Rewards
  ##
  cfg.rewards["body_orientation_l2"].params["asset_cfg"].body_names = (robot.torso_link,)
  cfg.rewards["body_ang_vel"].params["asset_cfg"].body_names = (robot.torso_link,)
  cfg.rewards["foot_clearance"].params["asset_cfg"].site_names = foot_sites
  cfg.rewards["foot_slip"].params["asset_cfg"].site_names = foot_sites
  # Scale the swing-lift target to the robot's OWN standing height -- a robot
  # standing 0.03 m tall (kxrl4t) cannot lift its foot 0.10 m (upstream's flat
  # default, sized for a human-scale biped).
  clearance_target = max(0.01, 0.25 * home_height)
  cfg.rewards["foot_clearance"].params["target_height"] = clearance_target
  # $KXR_GAIT_WEIGHT overrides the gait-clock weight (upstream: 0.5). The
  # clock's reward is the MEAN match over support limbs, so each limb's stake
  # in it shrinks as limbs are added: 0.25 each for a biped, 0.08 for kxrl6's
  # six. A six-limbed policy trained at 0.5 lifted one arm for good and walked
  # on the other five -- dropping a limb cost it nothing the tracking term did
  # not pay back. Explicit knob for now; the per-limb stake is what should be
  # held constant, but changing the default retunes every trained robot.
  gait_weight = opt.num("KXR_GAIT_WEIGHT", float(task.get("gait_weight", 0.0)))
  if gait_weight > 0.0:
    cfg.rewards["foot_gait"].weight = gait_weight
  cfg.rewards["foot_gait"].params.update({
    "period": GAIT_PERIOD,
    # Antiphase for two legs; a diagonal trot once there are four support
    # limbs. Derived from where each limb attaches, not hard-coded per robot.
    "offset": robot.gait_offsets(),
    "threshold": 0.55,
    "command_threshold": 0.05,
  })

  posture_std = {j: _DEFAULT_STD for j in robot.all_joints}
  for j, role in robot.support_dof_names.items():
    posture_std[j] = _ROLE_STD.get(role, _DEFAULT_STD)

  # A joint that DELIVERS the stride cannot also be pinned near the home pose.
  # The role table above is written for a human-proportioned biped, where hip
  # yaw is a balance DOF worth keeping tight (std 0.2). On kxrl4t hip yaw is
  # the only propulsion DOF there is, and the gait that works sweeps it 0.9 rad
  # -- which at std 0.2 scores exp(-20), i.e. the posture term prices the only
  # available gait at the entire reward. So each support-limb joint that moves
  # its own contact point (fore-aft for a stride, or up for clearance) is given
  # a std as wide as the swing amplitude that stride needs, and the tighter
  # role value is kept only for joints that do neither.
  for joint, m in (home.get("gait_joints") or {}).items():
    if joint not in posture_std:
      continue
    drives_stride = m["span_x_m"] >= GAIT_JOINT_SHARE * stride_span
    lifts_clear = m["span_z_m"] >= clearance_target
    if drives_stride or lifts_clear:
      amplitude = 0.5 * STRIDE_UTILIZATION * m["range_rad"]
      posture_std[joint] = max(posture_std[joint], amplitude)
  cfg.rewards["pose"].params["std_standing"] = dict(posture_std)
  cfg.rewards["pose"].params["std_walking"] = dict(posture_std)
  cfg.rewards["pose"].params["std_running"] = dict(posture_std)
  cfg.rewards["pose"].params["walking_threshold"] = 0.03
  cfg.rewards["pose"].params["running_threshold"] = 1.0

  if speed is not None:
    # Put every "is it moving?" gate below the commanded band, so the gait
    # terms are live for the whole band and stand_still (which penalizes
    # leaving the home pose) is not.
    for term in ("foot_gait", "foot_clearance", "foot_slip", "soft_landing",
                 "stand_still"):
      cfg.rewards[term].params["command_threshold"] = speed.move_gate
    cfg.rewards["pose"].params["walking_threshold"] = speed.move_gate
    cfg.rewards["pose"].params["running_threshold"] = speed.v_max

  ##
  # Terminations
  ##
  cfg.terminations["fell_over"].params["limit_angle"] = math.radians(55.0)
  cfg.terminations["torso_down"] = TerminationTermCfg(
    func=mdp.illegal_contact,
    params={"sensor_name": torso_ground_cfg.name, "force_threshold": 3.0},
  )

  # ---- GET-UP task ($KXR_GETUP=1) ----------------------------------------
  # Instead of STARTING in the standing home pose, can the robot RISE into it
  # from lying flat? Locomotion terms are zeroed (scale=0, never deleted --
  # see walking-hand-rl README section 6 for why), reset drops the base to
  # the floor, and the fallen posture becomes the task's start condition
  # rather than a termination.
  if opt.flag("KXR_GETUP"):
    flat_clearance = min(0.02, 0.3 * home_height)
    flat_z = -(home_height - flat_clearance)
    cfg.events["reset_base"].params["pose_range"]["z"] = (flat_z, flat_z)
    twist.ranges.lin_vel_x = (0.0, 0.0)
    twist.ranges.lin_vel_y = (0.0, 0.0)
    twist.ranges.ang_vel_z = (0.0, 0.0)
    for term in ("foot_gait", "foot_clearance", "foot_slip",
                 "track_linear_velocity", "track_angular_velocity", "stand_still"):
      if term in cfg.rewards:
        cfg.rewards[term].weight = 0.0
    cfg.rewards["getup_hold"] = RewardTermCfg(
      func=mdp.getup_hold, weight=20.0,
      params={"target_height": home_height, "asset_cfg": SceneEntityCfg("robot")},
    )
    # The robot starts ON the floor; that termination would end every episode
    # at step 0.
    cfg.terminations.pop("torso_down", None)
    # Lying flat puts every link in contact with the floor simultaneously --
    # even more contacts than a mid-walk fall, so this needs MORE headroom
    # than the walk preset's 900, not less. contact_sensor_maxmatch needs the
    # same bump: the stock 64 silently prints "contact match overflow" during
    # training (harmless there) but makes the CUDA graph capture used by
    # play-mode / eval tooling fail outright ("Graph launch error") the first
    # time a flat-on-the-floor reset actually exceeds it.
    cfg.sim.njmax = 2600
    cfg.sim.contact_sensor_maxmatch = 256

    # ---- POSTURE-ROBUST get-up ($KXR_GETUP_DR=1, stacks on KXR_GETUP) -----
    # Rise from a VARIETY of fallen postures (tilted, rotated), not just flat
    # on the back. Requires dropping the tilt-based fell_over termination
    # (fired the instant the body starts tilted, which here is the START
    # condition, not a failure).
    if opt.flag("KXR_GETUP_DR"):
      tilt = opt.num("KXR_DR_TILT", 0.6)
      dz = opt.num("KXR_DR_DZ", 0.01)
      cfg.events["reset_base"].params["pose_range"].update({
        "z": (flat_z - dz, flat_z + dz),
        "roll": (-tilt, tilt), "pitch": (-tilt, tilt), "yaw": (-math.pi, math.pi),
      })
      cfg.terminations.pop("fell_over", None)

  if play:
    cfg.episode_length_s = int(1e9)
    cfg.observations["actor"].enable_corruption = False
    cfg.events.pop("push_robot", None)
    cfg.curriculum = {}
    cfg.events["randomize_terrain"] = EventTermCfg(
      func=envs_mdp.randomize_terrain, mode="reset", params={})
    if not opt.flag("KXR_GETUP"):
      # Hold the top of the band this robot was TRAINED on. A fixed 0.2 m/s
      # (the old, unscaled value) asks kxrl4t for three times its mechanical
      # top speed -- an out-of-distribution command, so the clip measures
      # something the policy was never trained to do.
      play_speed = speed.v_max if speed is not None else 0.2
      twist.ranges.lin_vel_x = (play_speed, play_speed)
      twist.ranges.ang_vel_z = (0.0, 0.0)
    twist.debug_vis = False
    _z = cfg.events["reset_base"].params["pose_range"].get("z", (0.0, 0.0))
    cfg.events["reset_base"].params["pose_range"] = {
      "x": (0.0, 0.0), "y": (0.0, 0.0), "z": _z, "yaw": (0.0, 0.0),
    }

  return cfg
