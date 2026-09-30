#!/bin/bash
# view_mjcf.sh <robot.xml>
#
# eus2mujoco.l(native-robot-to-mujoco-file)やmujoco2eus.l検証用に生成
# したMJCFファイルを、地面(平面)+照明を追加した状態でMuJoCoの
# simulateビューアで開く。ロボット自身のxmlは地面を持たない(root
# linkにfreejointが付くだけ)ため、これが無いとロボットが永遠に
# 落下し続けてしまう。
#
# 使い方:
#   ./view_mjcf.sh RHP9.xml
#   ./view_mjcf.sh /home/inaba/kxreus/eusmjcf/RHP9.xml
#
# 仕組み: ground_scene.xml.tmpl(地面+空+照明のみの雛形)に、
# <include file="..."/>で指定されたロボットxmlを差し込んだ一時
# シーンファイルを、ロボットxmlと同じディレクトリに生成してから
# simulateに渡す(相対パスのメッシュ参照がそのまま解決できるよう、
# 一時ファイルは/tmpではなくロボットxmlと同じ場所に置く)。終了後に
# 一時ファイルは削除する。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIMULATE_BIN="${SIMULATE_BIN:-$HOME/mujoco/mujoco-3.1.6/bin/simulate}"
TEMPLATE="$SCRIPT_DIR/ground_scene.xml.tmpl"

if [ $# -ne 1 ]; then
  echo "usage: $0 <robot.xml>" >&2
  exit 1
fi

ROBOT_XML="$(readlink -f "$1")"
if [ ! -f "$ROBOT_XML" ]; then
  echo "error: file not found: $1" >&2
  exit 1
fi
if [ ! -f "$TEMPLATE" ]; then
  echo "error: ground scene template not found: $TEMPLATE" >&2
  exit 1
fi
if [ ! -x "$SIMULATE_BIN" ]; then
  echo "error: simulate binary not found/executable: $SIMULATE_BIN (set SIMULATE_BIN to override)" >&2
  exit 1
fi

ROBOT_DIR="$(dirname "$ROBOT_XML")"
ROBOT_BASENAME="$(basename "$ROBOT_XML")"
SCENE_FILE="$(mktemp "$ROBOT_DIR/.view_scene_XXXXXX.xml")"

cleanup() { rm -f "$SCENE_FILE"; }
trap cleanup EXIT

sed "s#<mujoco model=\"ground_scene\">#<mujoco model=\"ground_scene\">\n  <include file=\"${ROBOT_BASENAME}\"/>#" \
    "$TEMPLATE" > "$SCENE_FILE"

echo "generated scene: $SCENE_FILE (includes $ROBOT_BASENAME + ground plane)"
"$SIMULATE_BIN" "$SCENE_FILE"
