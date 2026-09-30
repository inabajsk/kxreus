"""Registers ``<Robot>-Walk`` and ``<Robot>-Getup`` for every KXR robot.

This is the payoff of parsing robot structure instead of hand-writing it: the
same two-line registration loop covers kxrl4d (19 joints, a 4-DOF leg with a
full hip+knee+ankle), kxrl4t (10 joints, a 2-DOF hip-only leg with no ankle
or knee at all), kxrl2g (22 joints, a 5-DOF leg with ankle roll) and kxrl6
(18 joints, a 3-DOF leg and four arms) alike. Adding a new KXR robot to this
repo is: (1) point ``kxr_rl.robots.DEFAULT_ROBOTS`` at its name, (2)
``uv run robot/build_mjcf.py <name>``, (3) ``uv run robot/measure_home.py
<name>`` -- and it has a Walk and a Getup task, zero new code.

Kept OUT of ``kxr_rl/__init__.py`` on purpose, same reason as
walking-hand-rl/tasks.py: registration BUILDS the env configs, which read
KXR_* environment options as they are built, so a caller that sets one must
import this module AFTER setting it.
"""

from mjlab.tasks.registry import register_mjlab_task  # noqa: E402
from src.tasks.velocity.rl.runner import VelocityOnPolicyRunner  # noqa: E402

from .env_cfgs import kxr_env_cfg  # noqa: E402
from .rl_cfg import kxr_ppo_runner_cfg  # noqa: E402
from .robots import DEFAULT_ROBOTS  # noqa: E402


def task_id(robot_name: str, mode: str) -> str:
  """e.g. ("kxrl4d", "walk") -> "Kxrl4d-Walk"."""
  return "{}-{}".format(robot_name.capitalize(), mode.capitalize())


REGISTERED_ROBOTS = tuple(DEFAULT_ROBOTS)

for _robot in REGISTERED_ROBOTS:
  register_mjlab_task(
    task_id=task_id(_robot, "walk"),
    env_cfg=kxr_env_cfg(_robot, preset="walk"),
    play_env_cfg=kxr_env_cfg(_robot, preset="walk", play=True),
    rl_cfg=kxr_ppo_runner_cfg(experiment_name="{}_walk".format(_robot)),
    runner_cls=VelocityOnPolicyRunner,
  )
  register_mjlab_task(
    task_id=task_id(_robot, "getup"),
    env_cfg=kxr_env_cfg(_robot, preset="getup"),
    play_env_cfg=kxr_env_cfg(_robot, preset="getup", play=True),
    rl_cfg=kxr_ppo_runner_cfg(experiment_name="{}_getup".format(_robot), max_iterations=2001),
    runner_cls=VelocityOnPolicyRunner,
  )
