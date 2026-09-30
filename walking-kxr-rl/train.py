#!/usr/bin/env python3
"""Train one KXR robot's Walk or Getup task.

    uv run train.py kxrl4d walk                          # 1500 iter, 4096 envs
    uv run train.py kxrl4d getup --iterations 2000
    uv run train.py kxrl6 walk --iterations 10 --num-envs 1024   # smoke test

Any further arguments are passed through to mjlab's trainer, e.g.
``--agent.seed 3`` or ``--video``. Checkpoints land in
``logs/rsl_rl/<robot>_<mode>/<timestamp>_<run-name>/``.
"""

import argparse
import os
import sys
from datetime import datetime


def main() -> None:
  parser = argparse.ArgumentParser(
    description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
  parser.add_argument("robot", help="e.g. kxrl4d, kxrl4t, kxrl2g, kxrl6")
  parser.add_argument("mode", nargs="?", default="walk", choices=("walk", "getup"))
  parser.add_argument("--iterations", type=int, default=None)
  parser.add_argument("--num-envs", type=int, default=4096)
  parser.add_argument("--run-name", default=None)
  args, passthrough = parser.parse_known_args()

  run_name = args.run_name or "{}-{}-{}".format(
    args.robot, args.mode, datetime.now().strftime("%H%M%S"))

  os.environ.setdefault("WANDB_MODE", "disabled")
  os.environ.setdefault("MUJOCO_GL", "egl")

  import kxr_rl.tasks as tasks
  from mjlab.scripts.train import main as mjlab_train

  task = tasks.task_id(args.robot, args.mode)
  sys.argv = [
    "train.py", task,
    "--env.scene.num-envs", str(args.num_envs),
    "--agent.run_name", run_name,
    *passthrough,
  ]
  if args.iterations is not None:
    sys.argv += ["--agent.max-iterations", str(args.iterations)]
  print("task={} num_envs={} run_name={}".format(task, args.num_envs, run_name), flush=True)
  mjlab_train()


if __name__ == "__main__":
  main()
