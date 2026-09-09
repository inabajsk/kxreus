#!/bin/bash
# view_urdf.sh <robot.urdf>
#
# eus2urdf.l(native-robot-to-urdf-file)で生成したURDFファイルを、
# MuJoCoのsimulateビューアで直接開いて見た目を確認する。MuJoCoは
# URDFを直接読み込めるので、変換等は不要(メッシュのSTL参照は
# URDFファイル自身のディレクトリ相対と想定し、cdしてから開く)。
#
# 使い方:
#   ./view_urdf.sh kxrl2l2a6h2.urdf
#   ./view_urdf.sh /home/inaba/kxreus/eusurdf/kxrl2l2a6h2.urdf
#
# 「Geom with duplicate name '' encountered in URDF」という警告が出る
# ことがあるが、これはvisualとcollisionの両方にジオメトリ名が付いて
# いないための無害な警告で、表示には影響しない。

set -euo pipefail

SIMULATE_BIN="${SIMULATE_BIN:-$HOME/mujoco/mujoco-3.1.6/bin/simulate}"

if [ $# -ne 1 ]; then
  echo "usage: $0 <robot.urdf>" >&2
  exit 1
fi

ROBOT_URDF="$(readlink -f "$1")"
if [ ! -f "$ROBOT_URDF" ]; then
  echo "error: file not found: $1" >&2
  exit 1
fi
if [ ! -x "$SIMULATE_BIN" ]; then
  echo "error: simulate binary not found/executable: $SIMULATE_BIN (set SIMULATE_BIN to override)" >&2
  exit 1
fi

ROBOT_DIR="$(dirname "$ROBOT_URDF")"
ROBOT_BASENAME="$(basename "$ROBOT_URDF")"

cd "$ROBOT_DIR"
"$SIMULATE_BIN" "$ROBOT_BASENAME"
