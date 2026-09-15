#!/usr/bin/env python3
"""Convert a KXR robot's URDF to the MJCF mjlab trains against.

    uv run robot/build_mjcf.py kxrl4d kxrl4t kxrl2g kxrl6
    uv run robot/build_mjcf.py --all            # everything kxr_rl.robots can parse

Unlike walking-hand-rl's build_mjcf.py, no Z-up rotation hack is needed: every
KXR URDF already has its root's +Z pointing up and legs extending in -Z (they
come out of a ROS/rviz-oriented toolchain), so the source URDF is converted
as-is. The two things that DO carry over from the hand:

1. **No actuators are emitted.** mjlab attaches its own from robot_cfg.py;
   letting the converter also emit ``<position>`` actuators would drive every
   joint twice (the ideal-actuator exploit).
2. **Self-collision stays off** at conversion time (scikit-robot's default),
   same as the hand -- ground contact is enabled per-robot in robot_cfg.py.

Mesh ``package://<name>/meshes/...`` URIs resolve on their own: scikit-robot's
URDF loader walks UP from the URDF's directory looking for a
``<name>/meshes/...`` match, and ``kxreus/urdfs/<name>/urdf/<name>.urdf`` sits
exactly two levels below ``kxreus/urdfs/<name>/meshes/`` -- no ROS_PACKAGE_PATH
needed.
"""

import argparse
import os
import sys

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, _REPO_ROOT)

from kxr_rl.robots import DEFAULT_ROBOTS, discover_robots, load_robot_spec  # noqa: E402

OUT_ROOT = os.path.join(_REPO_ROOT, "robot", "mjcf")


def build_one(name: str) -> str:
  spec = load_robot_spec(name)
  out_dir = os.path.join(OUT_ROOT, name)
  os.makedirs(out_dir, exist_ok=True)
  out_path = os.path.join(out_dir, "{}.xml".format(name))

  from skrobot.utils.mjcf_converter import urdf_to_mjcf

  urdf_to_mjcf(
    str(spec.urdf_path),
    out_path,
    mesh_dir=os.path.join(out_dir, "assets"),
    floating_base=True,
    self_collision=False,
    add_position_actuators=False,  # kxr_rl.robot_cfg owns the actuators
    add_ground=False,  # mjlab's scene provides the terrain
  )
  print("{}: wrote {} ({} joints, legs {})".format(
    name, out_path, len(spec.all_joints), sorted(spec.legs)))
  return out_path


def main() -> None:
  parser = argparse.ArgumentParser(description=__doc__,
                                    formatter_class=argparse.RawDescriptionHelpFormatter)
  parser.add_argument("robots", nargs="*", help="robot names, e.g. kxrl4d")
  parser.add_argument("--all", action="store_true",
                       help="build every robot kxr_rl.robots.discover_robots() finds")
  args = parser.parse_args()

  names = list(discover_robots()) if args.all else (args.robots or list(DEFAULT_ROBOTS))
  for name in names:
    build_one(name)


if __name__ == "__main__":
  main()
