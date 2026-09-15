"""Make the upstream unitree_rl_mjlab checkout importable.

Identical strategy to walking-hand-rl/_bootstrap.py (see that file for the full
rationale): upstream's setup.py does not ship ``src.tasks``, so this fetches a
pinned commit into ``.upstream/`` and puts it on ``sys.path`` on first import.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

UPSTREAM_URL = "https://github.com/unitreerobotics/unitree_rl_mjlab"
UPSTREAM_SHA = "1425b15f73bd4095f0df53709d7c389c3eb9e790"

_READY = False


def repo_root() -> Path:
  return Path(__file__).resolve().parent.parent


def upstream_dir() -> Path:
  override = os.environ.get("UNITREE_RL_MJLAB")
  if override:
    return Path(override).expanduser().resolve()
  return repo_root() / ".upstream" / "unitree_rl_mjlab"


def _git(*args: str, cwd: Path | None = None) -> str:
  return subprocess.run(
    ["git", *args], cwd=None if cwd is None else str(cwd),
    check=True, capture_output=True, text=True,
  ).stdout.strip()


def _fetch(dest: Path) -> None:
  if not (dest / ".git").is_dir():
    print(
      "[walking-kxr-rl] fetching upstream unitree_rl_mjlab into {} "
      "(one time, ~40 MB)".format(dest), flush=True)
    dest.parent.mkdir(parents=True, exist_ok=True)
    _git("clone", "--quiet", UPSTREAM_URL, str(dest))
  if _git("rev-parse", "HEAD", cwd=dest) != UPSTREAM_SHA:
    try:
      _git("checkout", "--quiet", UPSTREAM_SHA, cwd=dest)
    except subprocess.CalledProcessError:
      _git("fetch", "--quiet", "origin", cwd=dest)
      _git("checkout", "--quiet", UPSTREAM_SHA, cwd=dest)


def ensure_upstream() -> Path:
  global _READY
  dest = upstream_dir()
  if _READY:
    return dest

  if not (dest / "src" / "tasks").is_dir():
    if os.environ.get("UNITREE_RL_MJLAB"):
      raise FileNotFoundError(
        "$UNITREE_RL_MJLAB is set to {} but there is no src/tasks there".format(dest))
    _fetch(dest)
    if not (dest / "src" / "tasks").is_dir():
      raise FileNotFoundError(
        "upstream checkout at {} has no src/tasks -- fetch failed".format(dest))

  # A stale task-package copy inside the upstream tree would double-register.
  stale = dest / "src" / "tasks" / "velocity" / "config" / "kxr"
  if stale.is_dir():
    shutil.rmtree(stale)

  if str(dest) not in sys.path:
    sys.path.insert(0, str(dest))

  os.environ.setdefault("WALKING_KXR_ROOT", str(repo_root()))
  _READY = True
  return dest
