"""Generic per-robot EntityCfg builder for any KXR leg-type robot.

One function, ``get_robot_cfg(name)``, replaces what walking-hand-rl needed a
whole bespoke module for: every KXR body shares one real servo spec and the
same URDF naming convention (see ``robots.py``), so contacts, actuators and the
home keyframe can all be derived from the parsed ``RobotSpec`` instead of
hand-written per robot.

Ground contact: every collision geom on the robot -- not just the feet -- is
enabled against the floor (``contype=0, conaffinity=1``, self-collision stays
off from the MJCF conversion). This is required for the GET-UP task: a robot
lying flat pushes off the ground with its torso, arms and head, not just its
feet. Foot geoms get a higher friction (a rubber sole) than the rest of the
body (bare plastic sliding); everything is condim=3 so both can generate
tangential (grip) force, exactly the two-cfg-into-one-CollisionCfg pattern
walking-hand-rl's robot_cfg.py documents the footgun for (``disable_other_geoms``
defaults True, so a second CollisionCfg silently switches off the first one's
geoms) -- there is exactly ONE CollisionCfg here for the same reason.
"""

from __future__ import annotations

import json
import os
import re
from pathlib import Path

import mujoco

from mjlab.actuator import BuiltinPositionActuatorCfg
from mjlab.entity import EntityArticulationInfoCfg, EntityCfg
from mjlab.utils.spec_config import CollisionCfg

from .robots import JOINT_EFFORT_NM, JOINT_VELOCITY_RAD_S, RobotSpec, load_robot_spec

_REPO_ROOT = Path(os.environ.get("WALKING_KXR_ROOT", Path(__file__).resolve().parent.parent))
MJCF_ROOT = _REPO_ROOT / "robot" / "mjcf"

# Bare plastic body sliding on a hard floor vs. a rubber-soled foot -- the same
# grippy-foot / slippery-body split walking-hand-rl's hand uses between its
# fingertips (0.8) and palm (0.5), just less extreme here since a biped's torso
# is not meant to be a propulsion surface, only a get-up contact.
FOOT_FRICTION = 0.8
BODY_FRICTION = 0.6

_KP = float(os.environ.get("KXR_KP", "25.0"))
_KD = float(os.environ.get("KXR_KD", "1.0"))
_ARMATURE = 0.005


def mjcf_path(name: str) -> Path:
  return MJCF_ROOT / name / "{}.xml".format(name)


def home_path(name: str) -> Path:
  return MJCF_ROOT / name / "home.json"


def foot_site_name(leg_key: str) -> str:
  return "{}_foot".format(leg_key)


def get_spec(name: str) -> mujoco.MjSpec:
  """Compile one robot's spec: ground contact on every geom, IMU, foot sites."""
  xml = mjcf_path(name)
  if not xml.exists():
    raise FileNotFoundError(
      "{} missing -- build it with `uv run robot/build_mjcf.py {}`".format(xml, name))
  spec = mujoco.MjSpec.from_file(str(xml))
  robot = load_robot_spec(name)
  foot_links = set(robot.foot_links)

  kept = 0
  for geom in spec.geoms:
    if "_collision" not in geom.name:
      geom.contype = 0
      geom.conaffinity = 0
      continue
    link = geom.name.rsplit("_collision", 1)[0]
    geom.contype = 0
    geom.conaffinity = 1
    geom.condim = 3
    geom.priority = 1
    geom.friction = [FOOT_FRICTION if link in foot_links else BODY_FRICTION, 0.005, 0.0001]
    kept += 1
  assert kept > 0, "{}: no *_collision geoms found -- conversion produced none?".format(name)

  # One site per foot (gait rewards read foot height/slip from here), placed at
  # the foot link's own origin -- close enough to the sole for a height/slip
  # reference; exact sole offset is not needed for these rewards' purpose.
  for leg_key, limb in robot.legs.items():
    body = spec.body(limb.foot_link)
    body.add_site(name=foot_site_name(leg_key), pos=[0.0, 0.0, 0.0])

  # IMU + root angular momentum, mounted on the torso -- same convention as
  # walking-hand-rl (the stock actor observations read these sensor names).
  torso = spec.body(robot.torso_link)
  torso.add_site(name="imu_in_body", pos=[0.0, 0.0, 0.0], size=[0.005, 0.005, 0.005])
  spec.add_sensor(name="imu_ang_vel", type=mujoco.mjtSensor.mjSENS_GYRO,
                   objtype=mujoco.mjtObj.mjOBJ_SITE, objname="imu_in_body")
  spec.add_sensor(name="imu_lin_vel", type=mujoco.mjtSensor.mjSENS_VELOCIMETER,
                   objtype=mujoco.mjtObj.mjOBJ_SITE, objname="imu_in_body")
  spec.add_sensor(name="imu_lin_acc", type=mujoco.mjtSensor.mjSENS_ACCELEROMETER,
                   objtype=mujoco.mjtObj.mjOBJ_SITE, objname="imu_in_body")
  spec.add_sensor(name="root_angmom", type=mujoco.mjtSensor.mjSENS_SUBTREEANGMOM,
                   objtype=mujoco.mjtObj.mjOBJ_BODY, objname=robot.torso_link)

  return spec


def get_articulation(name: str) -> EntityArticulationInfoCfg:
  robot = load_robot_spec(name)
  actuator = BuiltinPositionActuatorCfg(
    target_names_expr=tuple(re.escape(j) for j in robot.all_joints),
    stiffness=_KP,
    damping=_KD,
    effort_limit=JOINT_EFFORT_NM,
    armature=_ARMATURE,
  )
  return EntityArticulationInfoCfg(actuators=(actuator,), soft_joint_pos_limit_factor=0.9)


def get_home_keyframe(name: str) -> EntityCfg.InitialStateCfg:
  path = home_path(name)
  if not path.exists():
    raise FileNotFoundError(
      "{} missing -- measure it with `uv run robot/measure_home.py {}`".format(path, name))
  with path.open() as f:
    home = json.load(f)
  return EntityCfg.InitialStateCfg(
    pos=(0.0, 0.0, home["base_height"]),
    rot=tuple(home["base_quat"]),
    joint_pos=dict(home["joint_pos"]),
    joint_vel={".*": 0.0},
  )


def get_collision_cfg(name: str) -> CollisionCfg:
  robot = load_robot_spec(name)
  foot_pattern = r"^({})_collision\d+$".format(
    "|".join(re.escape(link) for link in robot.foot_links))
  body_pattern = r".*_collision\d+$"
  return CollisionCfg(
    geom_names_expr=(body_pattern,),
    contype=0,
    conaffinity=1,
    condim=3,
    priority=1,
    friction={foot_pattern: (FOOT_FRICTION,), body_pattern: (BODY_FRICTION,)},
  )


def get_robot_cfg(
  name: str, init_state: EntityCfg.InitialStateCfg | None = None
) -> EntityCfg:
  """EntityCfg for one KXR robot, ready to drop into a scene.

  ``init_state`` defaults to the measured home keyframe; ``measure_home.py``
  passes a placeholder here since producing that keyframe is its own job.
  """
  return EntityCfg(
    init_state=init_state if init_state is not None else get_home_keyframe(name),
    spec_fn=lambda: get_spec(name),
    articulation=get_articulation(name),
    collisions=(get_collision_cfg(name),),
  )


if __name__ == "__main__":
  import sys

  from mjlab.entity.entity import Entity

  names = sys.argv[1:] or ["kxrl4d"]
  for name in names:
    robot = Entity(get_robot_cfg(name))
    model = robot.spec.compile()
    print("{}: nq={} nu={} nsite={}".format(name, model.nq, model.nu, model.nsite))
