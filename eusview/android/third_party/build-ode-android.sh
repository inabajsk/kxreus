#!/bin/bash
# ODE (Open Dynamics Engine) 0.16.5 を Android (arm64-v8a, x86_64) 用の静的ライブラリにする
#   eusview/android/third_party/build-ode-android.sh
#   → third_party/ode/include/ode/*.h, third_party/ode/lib/<ABI>/libode.a  (リポジトリに入れる)
#   オプションは ios/third_party/build-ode.sh と同じ (倍精度, 静的, スレッドなし, libccd あり)
#   必要: ANDROID_HOME (ndk;27.2.12479018, cmake;3.22.1)
set -e
D="$(cd "$(dirname "$0")" && pwd)"; W=$(mktemp -d)
ANDROID_HOME=${ANDROID_HOME:-$HOME/Library/Android/sdk}
NDK=${ANDROID_NDK:-$ANDROID_HOME/ndk/27.2.12479018}
CMAKE_DIR=$ANDROID_HOME/cmake/3.22.1/bin
export PATH=$CMAKE_DIR:$PATH
cd $W && curl -sL https://bitbucket.org/odedevs/ode/downloads/ode-0.16.5.tar.gz | tar xz && cd ode-0.16.5
for ABI in arm64-v8a x86_64; do
  cmake -S . -B b-$ABI -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake -DANDROID_ABI=$ABI -DANDROID_PLATFORM=android-26 \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DBUILD_SHARED_LIBS=OFF -DODE_WITH_DEMOS=OFF -DODE_WITH_TESTS=OFF \
    -DODE_NO_BUILTIN_THREADING_IMPL=ON -DODE_WITH_LIBCCD=ON -DODE_DOUBLE_PRECISION=ON
  ninja -C b-$ABI ODE
  mkdir -p "$D/ode/lib/$ABI"
  cp b-$ABI/libode.a "$D/ode/lib/$ABI/"
  $NDK/toolchains/llvm/prebuilt/*/bin/llvm-strip --strip-debug "$D/ode/lib/$ABI/libode.a"
done
rm -rf "$D/ode/include" && mkdir -p "$D/ode/include"
cp -R include/ode "$D/ode/include/" && cp b-arm64-v8a/include/ode/precision.h "$D/ode/include/ode/"
find "$D/ode/include" \( -name "*.in" -o -name "Makefile*" \) -delete
cp LICENSE-BSD.TXT "$D/ode/LICENSE-BSD.TXT"
rm -rf $W
echo "done: $D/ode"
