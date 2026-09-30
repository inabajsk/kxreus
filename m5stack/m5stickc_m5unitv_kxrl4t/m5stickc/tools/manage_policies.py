#!/usr/bin/env python3
"""Keep a dated history of trained checkpoints next to the firmware they feed.

~/kxreus/walking-kxr-rl (see that repo's own README) is where training
actually happens; its policies/<robot>_<actor>.pt is overwritten in place
every time train.py finishes, the same file each run. That is fine for the
training repo's own use (play.py always wants the latest), but it is the
wrong shape for two things this atom/ tree needs:

  * a record of WHICH checkpoint a given firmware build was flashed from,
    so "the robot got worse after some retrain" has evidence rather than
    just a hunch -- see the field-logging pipeline (log_server.py) this is
    meant to eventually close a loop with.
  * export_policy.py taking a stable, deliberately-updated path rather than
    a file that changes size and content out from under it mid-export.

So this tool copies (never moves, never edits in place) a checkpoint from
the training repo into

    ~/kxreus/atom_phone/policies/<robot>/<actor>/<robot>_<actor>_<YYYYMMDD_HHMMSS>.pt
    ~/kxreus/atom_phone/policies/<robot>/<actor>/policy.pt   (symlink -> latest)

The timestamp is the SOURCE FILE's own mtime (when training actually wrote
it), not the time this tool happens to run -- so importing the same
checkpoint twice, or importing something trained days ago, still files it
under the date that matters.

Usage
-----
    manage_policies.py import kxrl4d walk
    manage_policies.py import kxrl4d walk --src /path/to/some.pt
    manage_policies.py import-all      # every <robot>_<actor>.pt currently
                                        # in walking-kxr-rl/policies/
    manage_policies.py list kxrl4d walk

No third-party dependencies -- this only ever copies files and reads mtimes.
"""
import argparse
import datetime
import pathlib
import shutil
import sys

ATOM_POLICIES = pathlib.Path(__file__).resolve().parents[2] / "policies"
TRAINING_REPO = pathlib.Path.home() / "kxreus" / "walking-kxr-rl"
TRAINING_POLICIES = TRAINING_REPO / "policies"


def _dated_name(robot, actor, src):
    stamp = datetime.datetime.fromtimestamp(src.stat().st_mtime)
    return f"{robot}_{actor}_{stamp:%Y%m%d_%H%M%S}.pt"


def import_one(robot, actor, src=None):
    src = pathlib.Path(src) if src else TRAINING_POLICIES / f"{robot}_{actor}.pt"
    if not src.is_file():
        print(f"no such checkpoint: {src}", file=sys.stderr)
        return False

    dest_dir = ATOM_POLICIES / robot / actor
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / _dated_name(robot, actor, src)

    if dest.exists() and dest.stat().st_size == src.stat().st_size:
        # Same mtime-derived name AND same size: almost certainly the same
        # checkpoint re-imported (e.g. import-all run twice with no new
        # training in between). Re-copying would be harmless but pointless.
        print(f"{robot}/{actor}: {dest.name} already stored, skipping copy")
    else:
        shutil.copy2(src, dest)
        print(f"{robot}/{actor}: stored {dest.name}")

    link = dest_dir / "policy.pt"
    if link.is_symlink() or link.exists():
        link.unlink()
    link.symlink_to(dest.name)
    print(f"{robot}/{actor}: policy.pt -> {dest.name}")
    return True


def import_all():
    if not TRAINING_POLICIES.is_dir():
        print(f"no training policies dir: {TRAINING_POLICIES}", file=sys.stderr)
        return 1
    ok = True
    for src in sorted(TRAINING_POLICIES.glob("*.pt")):
        robot, _, actor = src.stem.partition("_")
        if not actor:
            print(f"skipping {src.name}: not a <robot>_<actor>.pt name")
            continue
        ok = import_one(robot, actor) and ok
    return 0 if ok else 1


def list_history(robot, actor):
    dest_dir = ATOM_POLICIES / robot / actor
    if not dest_dir.is_dir():
        print(f"no history for {robot}/{actor} yet")
        return 0
    current = (dest_dir / "policy.pt").resolve().name if (dest_dir / "policy.pt").exists() else None
    for f in sorted(dest_dir.glob(f"{robot}_{actor}_*.pt")):
        marker = " <- policy.pt" if f.name == current else ""
        print(f"{f.name}{marker}")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_import = sub.add_parser("import", help="import one <robot> <actor> checkpoint")
    p_import.add_argument("robot")
    p_import.add_argument("actor")
    p_import.add_argument("--src", help="override source .pt "
                           "(default: walking-kxr-rl/policies/<robot>_<actor>.pt)")

    sub.add_parser("import-all", help="import every checkpoint currently in "
                    "walking-kxr-rl/policies/")

    p_list = sub.add_parser("list", help="show a robot/actor's dated history")
    p_list.add_argument("robot")
    p_list.add_argument("actor")

    args = ap.parse_args()
    if args.cmd == "import":
        sys.exit(0 if import_one(args.robot, args.actor, args.src) else 1)
    elif args.cmd == "import-all":
        sys.exit(import_all())
    elif args.cmd == "list":
        sys.exit(list_history(args.robot, args.actor))


if __name__ == "__main__":
    main()
