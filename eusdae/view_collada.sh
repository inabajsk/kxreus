#!/bin/bash
# view_collada.sh <robot.dae>
#
# collada2eus.l/eus2collada.l検証用のCOLLADA(.dae)ファイルを、
# MeshLabで直接開いて見た目を確認する。COLLADAを直接読める(材質/色も
# 含めて)、この機材で確認済みの数少ないビューアの1つ(blender/
# osgviewer/g3dviewerは未インストール、MuJoCoのsimulateはURDFは直接
# 読めるがCOLLADAシーングラフは読めない)。
#
# 使い方:
#   ./view_collada.sh RHP9.dae
#   ./view_collada.sh /home/inaba/kxreus/eusdae/RHP9.dae

set -euo pipefail

MESHLAB_BIN="${MESHLAB_BIN:-$(command -v meshlab || true)}"

if [ $# -ne 1 ]; then
  echo "usage: $0 <robot.dae>" >&2
  exit 1
fi

ROBOT_DAE="$(readlink -f "$1")"
if [ ! -f "$ROBOT_DAE" ]; then
  echo "error: file not found: $1" >&2
  exit 1
fi
if [ -z "$MESHLAB_BIN" ]; then
  echo "error: meshlab not found in PATH (set MESHLAB_BIN to override)" >&2
  exit 1
fi

"$MESHLAB_BIN" "$ROBOT_DAE"
