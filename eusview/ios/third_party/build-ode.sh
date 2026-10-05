#!/bin/bash
# ODE (Open Dynamics Engine) 0.16.5 を iPhone / シミュレータ / Mac 用にビルドして ODE.xcframework を作る
#   eusview/ios/third_party/build-ode.sh   (cmake と ninja が必要)
set -e
D="$(cd "$(dirname "$0")" && pwd)"; W=$(mktemp -d)
cd $W && curl -sL https://bitbucket.org/odedevs/ode/downloads/ode-0.16.5.tar.gz | tar xz && cd ode-0.16.5
for P in iphoneos iphonesimulator macosx catalyst; do
  case $P in
    iphoneos) A="-DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0";;
    iphonesimulator) A="-DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_ARCHITECTURES=x86_64;arm64 -DCMAKE_OSX_SYSROOT=iphonesimulator -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0";;
    macosx) A="-DCMAKE_OSX_ARCHITECTURES=x86_64;arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0";;
    catalyst) A="-DCMAKE_OSX_ARCHITECTURES=x86_64 -DCMAKE_C_FLAGS=-target\ x86_64-apple-ios17.0-macabi -DCMAKE_CXX_FLAGS=-target\ x86_64-apple-ios17.0-macabi";;  # Mac Catalyst (Intel Mac)
  esac
  cmake -S . -B b-$P -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DODE_WITH_DEMOS=OFF -DODE_WITH_TESTS=OFF \
    -DODE_NO_BUILTIN_THREADING_IMPL=ON -DODE_WITH_LIBCCD=ON $A
  ninja -C b-$P
done
mkdir -p hdr && cp -R include/ode hdr/ && cp b-iphoneos/include/ode/precision.h hdr/ode/
find hdr \( -name "*.in" -o -name "Makefile*" \) -delete
rm -rf "$D/ODE.xcframework"
xcodebuild -create-xcframework -library b-iphoneos/libode.a -headers hdr -library b-iphonesimulator/libode.a -headers hdr \
  -library b-macosx/libode.a -headers hdr -library b-catalyst/libode.a -headers hdr -output "$D/ODE.xcframework"
cp LICENSE-BSD.TXT "$D/ODE-LICENSE-BSD.TXT"
