#!/usr/bin/env python3
"""Render a trained (or freshly trained) KXR robot policy to mp4.

    uv run play.py kxrl4d standwalk    # fall over -> get up -> walk, one clip
    uv run play.py kxrl4d walk
    uv run play.py kxrl4d getup

    uv run play.py kxrl4d walk --out-prefix out/kxrl4d_walk --seconds 10 \
                                --checkpoint logs/rsl_rl/kxrl4d_walk/<run>/model_1500.pt

Writes <prefix>_fixed.mp4 (world-fixed camera), plus _side.mp4 and (for
walk/getup) _top.mp4.
"""

import argparse
import os
import runpy
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def main() -> None:
  parser = argparse.ArgumentParser(
    description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
  parser.add_argument("robot")
  parser.add_argument("mode", choices=("walk", "getup", "standwalk"))
  parser.add_argument("--out-prefix", default=None)
  parser.add_argument("--seconds", type=float, default=None)
  parser.add_argument("--checkpoint", default=None)
  args, passthrough = parser.parse_known_args()

  os.environ.setdefault("MUJOCO_GL", "egl")
  prefix = args.out_prefix or os.path.join(HERE, "out", "{}_{}".format(args.robot, args.mode))

  if args.mode == "standwalk":
    script = "tools/standwalk_eval.py"
    argv = [
      "--robot", args.robot,
      "--getup-checkpoint", args.checkpoint or os.path.join(
        HERE, "policies", "{}_getup.pt".format(args.robot)),
      "--walk-checkpoint", os.path.join(HERE, "policies", "{}_walk.pt".format(args.robot)),
      "--out-prefix", prefix,
      "--seconds", str(args.seconds if args.seconds is not None else 12.0),
    ]
  else:
    script = "tools/render_robot.py"
    default_ckpt = os.path.join(HERE, "policies", "{}_{}.pt".format(args.robot, args.mode))
    argv = [
      "--robot", args.robot,
      "--mode", args.mode,
      "--checkpoint", args.checkpoint or default_ckpt,
      "--out-prefix", prefix,
      "--seconds", str(args.seconds if args.seconds is not None else
                       (6.0 if args.mode == "getup" else 10.0)),
    ]

  sys.argv = [script] + argv + passthrough
  runpy.run_path(os.path.join(HERE, script), run_name="__main__")


if __name__ == "__main__":
  main()
