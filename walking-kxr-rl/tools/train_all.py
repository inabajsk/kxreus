#!/usr/bin/env python3
"""Train Walk then Getup for every robot in kxr_rl.robots.DEFAULT_ROBOTS,
sequentially (one GPU, avoid contention) -- like the old train_all.sh, except
each (robot, mode)'s own iteration budget now adapts to how ITS training is
actually going, instead of every robot getting the same fixed 700/900.

Chunked + resumed: run a BASE-sized chunk (the old fixed count, so a robot
that was already fine keeps costing exactly what it used to), then look at
whether Mean reward is still climbing within that chunk. If it is, resume
for another CHUNK-sized extension and check again; if it has flattened out,
stop. A per-task ceiling keeps a robot that never plateaus (or never learns
the task at all) from running forever.

    uv run tools/train_all.py                    # every robot, walk + getup
    uv run tools/train_all.py kxrl6               # just this robot
    uv run tools/train_all.py kxrl6 --mode getup  # just this robot+mode
    uv run tools/train_all.py --chunk-iters 200 --improve-threshold 0.05

Progress is read straight off the SAME "Mean reward: <x>" line already
printed once per iteration for every robot/task -- no per-robot metric, so
the extend/stop decision needs no per-robot tuning either.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT))

from kxr_rl.robots import DEFAULT_ROBOTS  # noqa: E402

BASE_ITERS = {"walk": 700, "getup": 900}
_ITER_RE = re.compile(r"Learning iteration (\d+)/(\d+)")
_REWARD_RE = re.compile(r"Mean reward:\s*([-\d.]+)")


@dataclass
class ChunkResult:
  ok: bool
  start_it: int
  end_it: int
  rewards: list[float]  # one per learning iteration actually seen, in order


def parse_chunk(text: str) -> ChunkResult:
  """Pull (iteration, Mean reward) pairs out of one chunk's own stdout.

  Each "Learning iteration N/M" line is followed (later in the block) by its
  "Mean reward: x" line -- pairing them positionally by order of appearance
  is robust to everything else in the block varying by robot/task.
  """
  its = [int(m.group(1)) for m in _ITER_RE.finditer(text)]
  rewards = [float(m.group(1)) for m in _REWARD_RE.finditer(text)]
  n = min(len(its), len(rewards))
  if n == 0:
    return ChunkResult(ok=False, start_it=-1, end_it=-1, rewards=[])
  return ChunkResult(ok=True, start_it=its[0], end_it=its[n - 1], rewards=rewards[:n])


def still_improving(rewards: list[float], threshold: float) -> tuple[bool, float]:
  """Mean reward, third quarter of the chunk vs its last quarter, relative change.

  Deliberately NOT first-quarter-vs-last: every run rises fast off its own
  starting point (reward ~0), so a first-vs-last comparison reads "still
  improving" for the WHOLE chunk even once it flattened out long ago --
  exactly the base 700/900-iteration chunk's own early climb would otherwise
  mask. Comparing the two most RECENT quarters instead asks the question
  that actually matters for extending: is it still climbing right now, at
  the point training is about to stop? Quarters (not single points) so one
  noisy iteration can't flip the call -- PPO's per-iteration reward stays
  noisy even once a policy has essentially converged.
  """
  if len(rewards) < 8:
    return True, float("inf")  # too short a chunk to judge; assume yes, keep going
  q = max(1, len(rewards) // 4)
  mid = sum(rewards[-2 * q:-q]) / q
  late = sum(rewards[-q:]) / q
  denom = max(abs(mid), 1e-3)
  rel = (late - mid) / denom
  return rel > threshold, rel


def run_chunk(
  robot: str, mode: str, iterations: int, run_name: str, resume: bool, log_path: Path,
) -> tuple[int, str]:
  cmd = [
    "uv", "run", "train.py", robot, mode,
    "--num-envs", "4096", "--iterations", str(iterations), "--run-name", run_name,
  ]
  if resume:
    cmd += ["--agent.resume", "True"]
  banner = "\n{}\n=== {} training {} {}: {} (run_name={}, resume={}) ===\n".format(
    "#" * 80, time.strftime("%H:%M:%S"), robot, mode, iterations, run_name, resume)
  print(banner, end="", flush=True)
  with log_path.open("a") as f:
    f.write(banner)
    f.flush()
    proc = subprocess.run(
      cmd, cwd=REPO_ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    f.write(proc.stdout)
  tail = "\n".join(proc.stdout.splitlines()[-25:])
  print(tail, flush=True)
  return proc.returncode, proc.stdout


def train_one(
  robot: str, mode: str, args: argparse.Namespace, log_path: Path,
) -> None:
  base = BASE_ITERS[mode]
  cap = base + args.max_extra_chunks * args.chunk_iters
  total_target = base
  chunk_index = 0
  resume = False
  consecutive_failures = 0

  while True:
    run_name = "{}-{}".format(robot, mode) if chunk_index == 0 else \
      "{}-{}-c{}".format(robot, mode, chunk_index + 1)
    chunk_iters = base if chunk_index == 0 else min(args.chunk_iters, cap - total_target)
    code, stdout = run_chunk(robot, mode, chunk_iters, run_name, resume, log_path)

    result = parse_chunk(stdout)
    if code != 0 or not result.ok:
      consecutive_failures += 1
      msg = "{} {}: chunk {} FAILED (exit={}, parsed_ok={}), {}".format(
        robot, mode, chunk_index, code, result.ok,
        "retrying once" if consecutive_failures == 1 else "giving up after retry")
      print(msg, flush=True)
      with log_path.open("a") as f:
        f.write(msg + "\n")
      if consecutive_failures >= 2:
        return
      # Retry the SAME chunk without advancing total_target -- transient
      # failures (this machine is shared; a run can get killed or OOM'd by
      # something else entirely, see kxrl6-getup's unexplained 87/900 stop)
      # deserve one clean retry, not a permanent write-off.
      resume = chunk_index > 0
      continue
    consecutive_failures = 0

    total_target += chunk_iters
    chunk_index += 1
    keep_going, rel = still_improving(result.rewards, args.improve_threshold)
    verdict = "{} {}: after {} iters, last-quarter reward {:+.1%} vs prior quarter -> {}".format(
      robot, mode, result.end_it + 1, rel,
      "still improving, extending" if keep_going and total_target < cap
      else ("plateaued, stopping" if not keep_going else "hit the iteration cap, stopping"))
    print(verdict, flush=True)
    with log_path.open("a") as f:
      f.write(verdict + "\n")

    if not keep_going or total_target >= cap:
      return
    resume = True


def main() -> None:
  parser = argparse.ArgumentParser(
    description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
  parser.add_argument("robots", nargs="*", default=None,
                       help="defaults to every robot in DEFAULT_ROBOTS")
  parser.add_argument("--mode", choices=("walk", "getup"), default=None,
                       help="defaults to both walk and getup")
  parser.add_argument("--chunk-iters", type=int, default=300,
                       help="extension chunk size once the base budget is used up")
  parser.add_argument("--max-extra-chunks", type=int, default=4,
                       help="hard ceiling: base + this many extension chunks, per task")
  parser.add_argument("--improve-threshold", type=float, default=0.03,
                       help="relative Mean-reward gain (last quarter vs the quarter "
                            "before it) below which a task is called plateaued. 0.03 "
                            "was picked against this repo's own already-finished runs: "
                            "every converged walk/getup log's tail sits at +0.3%%..+1.9%%, "
                            "its still-climbing early phase at +6%%+, so 3%% clears normal "
                            "PPO noise without needing the still-climbing case to be huge. "
                            "A false 'still improving' just costs one confirmatory "
                            "extension chunk, since the check re-runs every chunk boundary")
  args = parser.parse_args()

  robots = args.robots or list(DEFAULT_ROBOTS)
  modes = [args.mode] if args.mode else ["walk", "getup"]

  log_dir = REPO_ROOT / "logs" / "train_all"
  log_dir.mkdir(parents=True, exist_ok=True)

  os.environ.setdefault("WANDB_MODE", "disabled")
  os.environ.setdefault("MUJOCO_GL", "egl")

  for robot in robots:
    for mode in modes:
      train_one(robot, mode, args, log_dir / "{}_{}.log".format(robot, mode))

  print("\n=== all training runs finished ===")


if __name__ == "__main__":
  main()
