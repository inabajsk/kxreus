#!/bin/sh
# retargettest (BVH → ロボットの移し替えを確かめる Mac のコマンド) をビルドする.  使い方: tools/build-retargettest.sh [出力先]
#   アプリの BVHData.swift / BVHRetarget.swift / RobotModel.swift をそのまま使う (ODE は使わない)
set -e
cd "$(dirname "$0")/.."
OUT=${1:-build/retargettest}
mkdir -p "$OUT"
cp tools/retargettest.swift "$OUT/main.swift"
swiftc -O -swift-version 5 "$OUT/main.swift" tools/retarget-stubs.swift EusView/App/BVHData.swift EusView/App/BVHRetarget.swift \
  EusView/App/RobotModel.swift -o "$OUT/retargettest"
echo "built $OUT/retargettest"
