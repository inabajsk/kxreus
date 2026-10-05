#!/bin/sh
# rendervideo (動画を作る Mac のコマンド) をビルドする.  使い方: tools/build-rendervideo.sh [出力先のフォルダ]
#   アプリの RobotModel.swift / PhysicsSim.swift / odesim.cpp をそのまま使う.
#   PhysicsSim.swift は写しを作り, 関節の CFM の上限 (1e-5) を比較用に上書きできるようにする (gWorldCFMOverride)
set -e
cd "$(dirname "$0")/.."
OUT=${1:-build/rendervideo}
mkdir -p "$OUT"
ODE=third_party/ODE.xcframework/macos-x86_64
clang++ -std=c++17 -O2 -c -I $ODE/Headers EusView/Physics/odesim.cpp -o "$OUT/odesim.o"
cp tools/rendervideo.swift "$OUT/main.swift"    # トップレベルのコードは main.swift にしか書けない
sed 's/min(ph?.world?.cfm ?? 1e-5, 1e-5)/(gWorldCFMOverride ?? min(ph?.world?.cfm ?? 1e-5, 1e-5))/' EusView/Physics/PhysicsSim.swift > "$OUT/PhysicsSim.swift"
grep -q gWorldCFMOverride "$OUT/PhysicsSim.swift" || { echo "PhysicsSim.swift: CFM の行が見つからない"; exit 1; }
swiftc -O -swift-version 5 -import-objc-header EusView/Physics/Bridging.h -I EusView/Physics -I $ODE/Headers \
  "$OUT/main.swift" EusView/App/RobotModel.swift "$OUT/PhysicsSim.swift" "$OUT/odesim.o" $ODE/libode.a -lc++ \
  -o "$OUT/rendervideo"
echo "built $OUT/rendervideo"
