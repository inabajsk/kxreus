# EusView デスクトップ版 (Ubuntu / Mac)
#   make native   物理 (ODE) の JNI ライブラリをこの PC 用に作る → build/native/<os>-<arch>/libeusviewode.{so,dylib}
#                 ODE: third_party/ode-<os>-<arch> (make ode で作ったもの) があればそれ (静的),
#                      なければ Linux は pkg-config ode (libode-dev), Mac は ../ios/third_party/ODE.xcframework
#   make ode      ODE 0.16.5 をソースから静的ライブラリにする (third_party/ode-<os>-<arch>, 配布物を libode に頼らないため)
#   make run      起動 (ARGS="-open kxrl2l6a6h2 -physics 1" のように起動の引数を渡せる)
#   make deb      Ubuntu の .deb (build/compose/binaries/main/deb/eusview_1.0.0-1_<arch>.deb, ODE は静的に入れる: なければ make ode)
#   make dist     この PC 用のアプリのフォルダ (build/compose/binaries/main/app/eusview)
#   make jar      全部入りの jar (build/compose/jars/eusview-<os>-<arch>-1.0.0.jar)
#   make clean
UNAME := $(shell uname)
ARCH := $(shell uname -m)
ifeq ($(UNAME),Darwin)
  OS := macos
  JAVA_HOME ?= $(firstword $(wildcard $(HOME)/Library/Java/jdk-17*/Contents/Home) $(shell /usr/libexec/java_home -v 17 2>/dev/null))
else
  OS := linux
  JAVA_HOME ?= $(firstword $(wildcard /usr/lib/jvm/java-17-openjdk-*) $(wildcard /usr/lib/jvm/java-21-openjdk-*))
endif
ifneq ($(filter $(ARCH),arm64 aarch64),)
  TARGET := $(OS)-arm64
else
  TARGET := $(OS)-x64
endif
export JAVA_HOME
ODE_LOCAL := third_party/ode-$(TARGET)
NATIVE := build/native/$(TARGET)
CMAKE_ODE := $(if $(wildcard $(ODE_LOCAL)/lib/libode.a),-DODE_ROOT=$(abspath $(ODE_LOCAL)),)
ARGS ?=

run: native
	./gradlew run $(if $(ARGS),--args="$(ARGS)",)

# ロボットの一覧の画像 (../robots/<グループ>/<名前>.png). ONLY=名前の一部 で 1 つだけ
thumbs:
	./gradlew run --args="-thumbs $(abspath ../robots)$(if $(ONLY), -only $(ONLY),)"

native:
	cmake -S native -B build/native-build -DCMAKE_BUILD_TYPE=Release $(CMAKE_ODE)
	cmake --build build/native-build -j 4
	mkdir -p $(NATIVE)
	cp build/native-build/libeusviewode.* $(NATIVE)/
	@echo "JNI: $(NATIVE)/$$(ls build/native-build | grep libeusviewode)"

ode:
	native/build-ode.sh $(TARGET)
	rm -rf build/native-build
$(ODE_LOCAL)/lib/libode.a:
	$(MAKE) ode

# .deb は ODE を静的に入れる (入れる PC に libode がなくてもよいように). なければソースから作る
deb: $(ODE_LOCAL)/lib/libode.a
	$(MAKE) native
	./gradlew packageDeb
	@ls -l build/compose/binaries/main/deb/

dist: native
	./gradlew createDistributable
	@echo build/compose/binaries/main/app/

jar: native
	./gradlew packageUberJarForCurrentOS

clean:
	./gradlew clean
	rm -rf build

.PHONY: run native ode deb dist jar clean
