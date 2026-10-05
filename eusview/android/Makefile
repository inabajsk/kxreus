# EusView (Android アプリ)
#   make build     デバッグ版の APK をビルド (app/build/outputs/apk/debug/app-debug.apk)
#   make install   USB でつないだ端末に入れる (adb install -r)
#   make run       入れて起動する
#   make release   リリース版 (debug の鍵で署名, app/build/outputs/apk/release/app-release.apk. make install-release で入れる)
#   make log       アプリのエラーのログ, make shot  画面を shot.png に保存
#   make sync-odesim   iOS 版の odesim.{h,cpp} をコピーし直す,  make sync-wbqp  iOS 版の wbqp.{h,cpp} (全身の QP) をコピーし直す
#   make sync  両方,  make ode  ODE の静的ライブラリを作り直す
#   make test-retarget / make test-json   JVM の単体テスト (BVH の移し替え / 共通の JSON の読み手)
#   make test-qp   GMR + QP の JVM の単体テスト (デスクトップ版の JNI ライブラリ ../desktop/build/native/<os>-<arch> を使う. 先に make -C ../desktop native)
#   共通のコード (デスクトップ版と同じ) は ../shared/kotlin
JAVA_HOME ?= $(firstword $(wildcard $(HOME)/Library/Java/jdk-17*/Contents/Home))
ANDROID_HOME ?= $(HOME)/Library/Android/sdk
ADB ?= $(ANDROID_HOME)/platform-tools/adb
export JAVA_HOME ANDROID_HOME
APK = app/build/outputs/apk/debug/app-debug.apk

build: local.properties
	./gradlew assembleDebug
release: local.properties
	./gradlew assembleRelease
local.properties:
	echo "sdk.dir=$(ANDROID_HOME)" > $@
install: build
	$(ADB) install -r $(APK)
install-release: release
	$(ADB) install -r app/build/outputs/apk/release/app-release.apk
run: install
	$(ADB) shell am start -n jp.jsk.eusview/.MainActivity
log:
	$(ADB) logcat -d --pid=$$($(ADB) shell pidof jp.jsk.eusview) '*:W'
shot:
	$(ADB) exec-out screencap -p > shot.png
sync-odesim:
	cp ../ios/EusView/Physics/odesim.h ../ios/EusView/Physics/odesim.cpp app/src/main/cpp/
sync-wbqp:
	cp ../ios/EusView/QP/wbqp.h ../ios/EusView/QP/wbqp.cpp app/src/main/cpp/
sync: sync-odesim sync-wbqp
ode:
	third_party/build-ode-android.sh
test-retarget: local.properties
	./gradlew testDebugUnitTest --tests jp.jsk.eusview.RetargetTest --rerun-tasks -q
test-qp: local.properties
	./gradlew testDebugUnitTest --tests jp.jsk.eusview.QpTest --rerun-tasks -q
test-json: local.properties
	./gradlew testDebugUnitTest --tests jp.jsk.eusview.JsonReaderTest --rerun-tasks -q
clean:
	./gradlew clean
.PHONY: test-retarget test-json test-qp build release install install-release run log shot sync-odesim sync-wbqp sync ode clean
