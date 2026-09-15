#!/usr/bin/env bash
# Thin wrapper -- the actual adaptive-iteration logic lives in train_all.py
# (chunked + resumed, extends a robot/task's budget past the old fixed
# 700/900 only while its own Mean reward is still climbing). Kept as a
# script for muscle memory; pass through any train_all.py flag, e.g.
# `tools/train_all.sh kxrl6 --mode getup --chunk-iters 200`.
set -uo pipefail
cd "$(dirname "$0")/.."
exec uv run tools/train_all.py "$@"
