#!/bin/sh
# qptest (GMR と GMR + 全身 QP を比べる Mac のコマンド) をビルドする.  使い方: tools/build-qptest.sh [出力先]
#   アプリの BVHData.swift / BVHRetarget.swift / RobotModel.swift / PhysicsSim.swift / WholeBodyQP.swift と
#   odesim.cpp (ODE) / wbqp.cpp をそのまま使う
set -e
cd "$(dirname "$0")/.."
OUT=${1:-build/qptest}
mkdir -p "$OUT"
ODE=third_party/ODE.xcframework/macos-x86_64
clang++ -std=c++17 -O2 -c -I $ODE/Headers EusView/Physics/odesim.cpp -o "$OUT/odesim.o"
clang++ -std=c++17 -O2 -c EusView/QP/wbqp.cpp -o "$OUT/wbqp.o"
cp tools/qptest.swift "$OUT/main.swift"
swiftc -O -swift-version 5 -import-objc-header EusView/Physics/Bridging.h -I EusView/Physics -I $ODE/Headers \
  "$OUT/main.swift" EusView/App/BVHData.swift EusView/App/BVHRetarget.swift EusView/App/RobotModel.swift \
  EusView/Physics/PhysicsSim.swift EusView/QP/WholeBodyQP.swift "$OUT/odesim.o" "$OUT/wbqp.o" $ODE/libode.a -lc++ \
  -o "$OUT/qptest"
echo "built $OUT/qptest"
