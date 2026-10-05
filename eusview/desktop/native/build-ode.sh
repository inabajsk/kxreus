#!/bin/bash
# ODE (Open Dynamics Engine) 0.16.5 をこの PC (Linux / macOS) 用の静的ライブラリにする (make ode)
#   → desktop/third_party/ode-<os>-<arch>/{include/ode/*.h, lib/libode.a}
#   オプションは ios/third_party/build-ode.sh, android/third_party/build-ode-android.sh と同じ (倍精度, 静的, スレッドなし, libccd あり)
#   必要: curl, cmake, c++ コンパイラ (Ubuntu: sudo apt install cmake g++ curl)
set -e
D="$(cd "$(dirname "$0")/.." && pwd)"
T=${1:?ターゲット (linux-x64 など)}
OUT="$D/third_party/ode-$T"
W=$(mktemp -d)
cd "$W" && curl -sL https://bitbucket.org/odedevs/ode/downloads/ode-0.16.5.tar.gz | tar xz && cd ode-0.16.5
EXTRA=""
if [ "$(uname)" = Darwin ]; then EXTRA="-DCMAKE_OSX_ARCHITECTURES=$(uname -m) -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0"; fi
cmake -S . -B b -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DBUILD_SHARED_LIBS=OFF -DODE_WITH_DEMOS=OFF -DODE_WITH_TESTS=OFF \
  -DODE_NO_BUILTIN_THREADING_IMPL=ON -DODE_WITH_LIBCCD=ON -DODE_DOUBLE_PRECISION=ON $EXTRA
cmake --build b --target ODE -j "$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
rm -rf "$OUT" && mkdir -p "$OUT/lib" "$OUT/include"
cp b/libode.a "$OUT/lib/"
cp -R include/ode "$OUT/include/" && cp b/include/ode/precision.h "$OUT/include/ode/"
find "$OUT/include" \( -name "*.in" -o -name "Makefile*" \) -delete
cp LICENSE-BSD.TXT "$OUT/LICENSE-BSD.TXT"
rm -rf "$W"
echo "done: $OUT"
