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

# Per-leg-DOF-role posture looseness. Hips/knees need room to stride; ankle
# roll (balance) and the mid-hip roll/yaw stay tighter. Anything not in this
# table (arms, head, grippers, or an unusual DOF name) gets a loose default --
# these joints do not affect locomotion directly, they just should not be
# rigid statues.
_ROLE_STD = {
  "hip_pitch": 0.5, "hip_roll": 0.2, "hip_yaw": 0.2,
  "knee": 0.5,
  "ankle_pitch": 0.2, "ankle_roll": 0.1, "ankle_yaw": 0.2,
}
_DEFAULT_STD = 0.3

GAIT_PERIOD = float(os.environ.get("KXR_GAIT_PERIOD", "0.6"))

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
    return self._values.get(name, default) if value is None else value

  def flag(self, name: str) -> bool:
    return self.raw(name).strip().lower() not in ("", "0", "false", "no", "off")

  def num(self, name: str, default: float) -> float:
    return float(self.raw(name, str(default)))


def _home_height(name: str) -> float:
  with home_path(name).open() as f:
    return float(json.load(f)["base_height"])


def _stand_height(name: str) -> float:
  """Robot-agnostic getup target: the tallest torso height reachable by
  sweeping the robot's own hip/knee/ankle bias grid purely kinematically
  (no gravity, no stability requirement) -- see
  ``robot/measure_home.py:max_kinematic_height``. It is the same search
  ``_home_height`` (``base_height``) runs to find a stable settled pose, just
  scored by geometry instead of "does it stay upright", so it never needs
  per-robot tuning: whichever leg axes raise THIS robot's torso are exactly
  the axes ``measure()`` already knows to search. It runs taller than
  ``_home_height`` for any robot whose settled resting pose needed a crouch
  bias to stay stable (e.g. kxrl6) -- deliberately: passive PD holding a
  fixed pose can't reach it, but an actively-balancing RL policy might, and
  the reward should keep paying for trying rather than cap out at a crouch."""
  with home_path(name).open() as f:
    return float(json.load(f)["stand_height"])


def kxr_env_cfg(
  robot_name: str, preset: str = "walk", play: bool = False
) -> ManagerBasedRlEnvCfg:
  """Velocity task configuration for one KXR robot. ``preset`` in {"walk","getup"}."""
  opt = _Opts(preset)
  robot = load_robot_spec(robot_name)
  home_height = _home_height(robot_name)
  leg_keys = sorted(robot.legs)
  foot_links = [robot.legs[k].foot_link for k in leg_keys]
  foot_sites = tuple(foot_site_name(k) for k in leg_keys)

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

  cfg.viewer.body_name = robot.torso_link
  cfg.viewer.distance = max(0.5, 6.0 * home_height)
  cfg.viewer.elevation = -15.0

  # These are small, weak-actuator (0.656 N*m) bodies, not full-size
  # humanoids -- top speed is scaled down from upstream's (-1, 2) m/s roughly
  # by leg-length ratio. Forward-only (like the hand) keeps the tracking
  # kernel's useful range concentrated rather than split across +/-.
  twist = cfg.commands["twist"]
  assert isinstance(twist, UniformVelocityCommandCfg)
  twist.ranges.lin_vel_x = (0.0, 0.3)
  twist.ranges.lin_vel_y = (0.0, 0.0)
  twist.ranges.ang_vel_z = (-0.3, 0.3)
  twist.heading_command = False
  twist.ranges.heading = None
  twist.rel_standing_envs = 0.05

  cfg.curriculum["command_vel"].params["velocity_stages"] = [
    {"step": 0, "lin_vel_x": (0.0, 0.10), "lin_vel_y": (0.0, 0.0),
     "ang_vel_z": (-0.1, 0.1)},
    {"step": 800 * 24, "lin_vel_x": (0.0, 0.20), "lin_vel_y": (0.0, 0.0),
     "ang_vel_z": (-0.2, 0.2)},
    {"step": 1600 * 24, "lin_vel_x": (0.0, 0.30), "lin_vel_y": (0.0, 0.0),
     "ang_vel_z": (-0.3, 0.3)},
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
  cfg.rewards["foot_clearance"].params["target_height"] = max(0.01, 0.25 * home_height)
  cfg.rewards["foot_gait"].params.update({
    "period": GAIT_PERIOD,
    "offset": [0.0, 0.5],  # antiphase: a biped's two legs alternate.
    "threshold": 0.55,
    "command_threshold": 0.05,
  })

  posture_std = {}
  for j, role in robot.leg_dof_names.items():
    posture_std[j] = _ROLE_STD.get(role, _DEFAULT_STD)
  for limb in robot.upper.values():
    for j in limb.joints:
      posture_std[j] = _DEFAULT_STD
  cfg.rewards["pose"].params["std_standing"] = dict(posture_std)
  cfg.rewards["pose"].params["std_walking"] = dict(posture_std)
  cfg.rewards["pose"].params["std_running"] = dict(posture_std)
  cfg.rewards["pose"].params["walking_threshold"] = 0.03
  cfg.rewards["pose"].params["running_threshold"] = 1.0

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
      params={"target_height": _stand_height(robot_name), "asset_cfg": SceneEntityCfg("robot")},
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
      twist.ranges.lin_vel_x = (0.2, 0.2)
      twist.ranges.ang_vel_z = (0.0, 0.0)
    twist.debug_vis = False
    _z = cfg.events["reset_base"].params["pose_range"].get("z", (0.0, 0.0))
    cfg.events["reset_base"].params["pose_range"] = {
      "x": (0.0, 0.0), "y": (0.0, 0.0), "z": _z, "yaw": (0.0, 0.0),
    }

  return cfg
