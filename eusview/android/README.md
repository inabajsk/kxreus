# EusView（Android 版）

iPhone / Mac 版 `eusview/ios/EusView` と同じ機能の Android アプリ（Kotlin + Jetpack Compose + OpenGL ES 3.0 + ODE）。
Google Pixel 7 / 7a（arm64-v8a, Android 14 以降）向け。エミュレータ用に x86_64 も入れてある。

- ロボットを選ぶ（KXR / KHR / JSK, 名前で探す）→ 3D 表示（1 本指で回転, 2 本指でつまんで拡大縮小・動かして平行移動）
- タブ: 関節（スライダー）/ 姿勢（reset-pose などへ 0.6 秒で動かす, すべて 0）/ 動作（押すと止めるまで繰り返し再生, もう一度押すと止まる）/ 接続
- 物理（ODE）: 今の姿勢で床に置いて動かす。サーボのオン / オフ, 置き直す。物理モードでは姿勢・動作・スライダー・接続の関節角がサーボの目標になる。
  左上に「時間・接触点の数・1 コマの計算時間」
- 接続: `ws://<Mac の IP>:8766/`（既定 `ws://192.168.1.59:8766/`, 端末に記憶）。Mac で `eusview/live.py` を動かし、
  EusLisp から `{"angles": [...]}` / `{"pose": "reset-pose"}` / `{"root": [x y z r00..r22]}` を送る（iOS 版と同じ）

## ビルドと端末へのインストール（Mac, コマンドライン）

必要なもの: JDK 17（`~/Library/Java/jdk-17*`）、Android SDK（`~/Library/Android/sdk`: platform-tools, platforms;android-35,
build-tools;35.0.0, ndk;27.2.12479018, cmake;3.22.1）。Gradle は同梱の `gradlew`（8.10.2）が自動で取ってくる。

```
cd eusview/android
make build          # = ./gradlew assembleDebug → app/build/outputs/apk/debug/app-debug.apk（約 26 MB）
make install        # adb install -r（USB デバッグを許可した端末）
make run            # 入れて起動（adb shell am start -n jp.jsk.eusview/.MainActivity）
make install-release  # リリース版（速い, 約 19 MB, debug の鍵で署名）
make log / make shot  # エラーのログ / 画面を shot.png に保存
make test-retarget    # BVH → ロボットの移し替えを Mac の JVM で確かめる（eusview/README.md「BVH → ロボット」）
make test-qp          # GMR + 全身 QP を JVM で確かめる（デスクトップ版の JNI ライブラリを使う: 先に make -C ../desktop native）
make sync-wbqp        # iOS 版の wbqp.{h,cpp}（全身 QP）をコピーし直す（make sync で odesim と両方）
```
`make` を使わないときは `export JAVA_HOME=$(ls -d ~/Library/Java/jdk-17*)/Contents/Home` と
`local.properties`（`sdk.dir=/Users/<名前>/Library/Android/sdk`）を用意して `./gradlew assembleDebug`。

- 初めて `adb install` すると端末に Google Play プロテクトの確認（「セキュリティ診断のためにアプリを送信しますか？」）が出て、
  答えるまでインストールが止まる。
- ロボットの JSON（`eusview/robots/<グループ>/*.json`, 約 80 MB）は git に重ねて入れず、ビルドのたびに
  `app/build/generated/robotAssets/robots/` へコピー（Gradle の `copyRobots` タスク）して APK の `assets/robots/` に入れる。
  JSON を作り直したら、もう一度ビルドすれば入る。端末の `files/` に置いた `*.json` も一覧に出る（名前の先頭でグループを決める）。

## 中身

```
app/build.gradle.kts            AGP 8.7.3, Kotlin 2.0.21, Compose BOM 2024.10.01, OkHttp 4.12.0, minSdk 26, targetSdk 35
app/src/main/java/jp/jsk/eusview/   Android だけの部分
  MainActivity.kt   一覧（グループ・検索）と表示画面（物理・サーボ・置き直す, 下の欄）, AndroidStore（assets と設定） ← EusViewApp.swift, RobotView.swift
  RobotGLView.kt    GLSurfaceView: メッシュごとの VBO, タッチ（メッシュ・床・光・カメラは共通の SceneCommon.kt）
  BvhAndroid.kt     BVH の画面の移り変わり（戻るボタン）と GLSurfaceView
../shared/kotlin/jp/jsk/eusview/   デスクトップ版（eusview/desktop）と共通（android.* を使わない. app/build.gradle.kts の srcDir）
  Platform.kt       環境ごとに違うもの: AppStore（データと設定）, Launch（起動の引数）, SceneView（カメラの操作）
  Json.kt           JSON をストリームで読む（android.util.JsonReader と同じ使い方, 数を速く読む）
  RobotModel.kt     JSON の読み込み, 4x4 行列（android.opengl.Matrix と同じ式）, 順運動学                 ← RobotModel.swift
  RobotScene.kt     リンクの木: rest · R(axis, 角度), setAngles / setFrame / setWorldPoses                   ← RobotScene.swift
  RobotState.kt     関節角・姿勢へ動かす・動作の繰り返し再生・物理モードの実時間ループ                       ← RobotView.swift の RobotState
  RobotPanels.kt    下の欄（関節 / 姿勢 / 動作 / 接続）と BVH の動作を選ぶ画面                                ← RobotView.swift
  SceneCommon.kt    3D 表示の共通部分: カメラ, 面の法線のメッシュ, 床と格子, 光, 色
  PhysicsSim.kt     ODE の物理モデル（質量の見積もり, 床に置く, 可動範囲, 車輪, 目標の範囲, dt の持ち越し）   ← PhysicsSim.swift
  LiveLink.kt       WebSocket（OkHttp）                                                                       ← LiveLink.swift
  BvhData.kt        BVH（.ebvh）の読み込みと順運動学                                                         ← BVHData.swift
  BvhPlayer.kt      BVH の再生の状態（骨格を RobotModel のメッシュに, ロボットに移して並べる）              ← BVHView.swift
  BvhScreens.kt     BVH の種類 / ファイルの一覧, 再生の画面                                                   ← BVHView.swift
  BvhRetarget.kt    BVH → ロボット（方法 1 関節名 = kxreus :names, 方法 2 GMR）                              ← BVHRetarget.swift
  WholeBodyQp.kt    GMR + 全身 QP（wbqp の JNI, runGmrQp, makeGmrQpMotion）                                  ← WholeBodyQP.swift
app/src/test/java/jp/jsk/eusview/RetargetTest.kt   BvhRetarget.kt を JVM で kxreus の書き出しと照合（make test-retarget）
app/src/test/java/jp/jsk/eusview/JsonReaderTest.kt 共通の JsonReader で読んだ全部のロボットを org.json で読んだものと比べる（make test-json）
app/src/test/java/jp/jsk/eusview/QpTest.kt   GMR + QP を JVM で（qptest と同じ集計, コマごとの CSV → eusview/bvh/qpcompare.py で Swift と比べる. make test-qp）
app/src/main/cpp/
  odesim.h, odesim.cpp   iOS 版 eusview/ios/EusView/Physics/ のコピー（変えない。`make sync-odesim` で同期）
  wbqp.h, wbqp.cpp       iOS 版 eusview/ios/EusView/QP/ のコピー（全身 QP. 変えない。`make sync-wbqp` で同期）, wbqp_jni.cpp（JNI）
  odesim_jni.cpp         JNI（jp.jsk.eusview.OdeNative. デスクトップ版も同じファイルを使う）
  CMakeLists.txt         libeusviewode.so = odesim + JNI + third_party/ode の libode.a（16 KB ページ対応）
third_party/
  build-ode-android.sh   ODE 0.16.5 を NDK で arm64-v8a / x86_64 の静的ライブラリにする（`make ode`）
  ode/include, ode/lib/<ABI>/libode.a, ode/LICENSE-BSD.TXT   その結果（リポジトリに入れる。普段のビルドは ODE のソース不要）
```

- ODE のオプションは iOS 版 `ios/third_party/build-ode.sh` と同じ（倍精度, 静的, `ODE_NO_BUILTIN_THREADING_IMPL`,
  `ODE_WITH_LIBCCD`）。デモ・テストなし。
- 表示: EusLisp の座標（z が上）のまま描き、カメラの上方向を z にしている。最初のカメラは iOS 版と同じ向き・距離
  （ロボットの外接箱の半径 r に対して (1.6, −2.2, 0.9) r）。描画は変化があったときだけ（`RENDERMODE_WHEN_DIRTY`）。
  4x MSAA（使えないときはなし）。ダークモードでは背景と床を暗くする。影はない（iOS 版はある）。
- 物理は iOS 版と同じくメインスレッドで、約 16 ms ごとに経過した実時間（最大 0.1 秒）を `step` に渡す（dt = 0.01 s の端数は持ち越し）。
  物理モードをやめるとルートを元の位置に戻して関節角で表示する（iOS 版は倒れた位置のまま）。

## BVH（モーションキャプチャ）の再生

一覧の右上の「BVH」→ 種類 → ファイル（名前で探す）/ 自動再生（全部, 種類ごと）。iOS 版と同じ（`eusview/README.md` の「BVH」）。
- データは `eusview/bvh/convert_bvh.py` で作る `eusview/bvh/cache/`（git に入れない, 約 93 MB）。ビルドのたびに Gradle の
  `copyBvh`（Sync）が `app/build/generated/bvhAssets/bvh/` にコピーして APK の `assets/bvh/` に入る（cache がなければ空で,
  BVH の画面に作り方を出す）。APK は約 100 MB（debug）になる。
- 骨格: BVH の関節を 1 つずつリンクにした `RobotModel` を作り（関節に球, 親の関節のリンクに子までの細い四角柱, End Site まで）,
  コマごとに関節のワールドの変換を `RobotScene.setWorldPoses` に入れる。モーションを替えるたびに GLSurfaceView を作り直す
  （種類で関節が違うため）。床の格子は 1 m（`RobotGLView(..., grid = [1, 12])`）。「カメラが追う」は `RobotGLView.follow` で注視点を腰の水平の動きだけずらす。
- 読み込んだときに Python で求めた関節の位置（ヘッダの check）と比べて logcat に `BVH <種類>/<名前> check: max error 0.007 mm` を出す。

## 確かめたこと（2026-10-05, Pixel 7a / Android 17, Intel Mac でビルド）

- `./gradlew assembleDebug` / `assembleRelease` が通る。APK に `lib/arm64-v8a/libeusviewode.so`（JNI の関数 16 個, LOAD の
  アラインメント 16 KB）と `lib/x86_64/...`、`assets/robots/{kxr,khr,jsk}/*.json` 121 個が入っている。
- 端末に入れて起動: 一覧（KXR 36 / KHR 43 / JSK 42, 検索）, kxrl2l6a6 の表示（reset-pose）, 1 本指の回転,
  物理モード（立ったまま, 接触 8 点, 1 コマ 1.5〜6 ms）, 物理モードで「ゆっくり歩行前（5回）」を繰り返し再生して前に進む,
  sample-robot-walk の歩行（ルートの動き）, ダークモード / ライトモード（表示中に切り替えても追従）,
  接続（Mac の live.py に ws://192.168.1.59:8766/ でつなぎ, TCP 8767 から送った関節角で khr3 が動く「受信中」）。logcat に例外なし。
- BVH: 一覧 → BVH → 種類 → ファイル / 自動再生（rikiya を順に: A01 → A02 → A03 と進む）, 5 種類それぞれ再生, 止める, 2x。
  照合（logcat）は 5 種類とも 0.006〜0.007 mm。
- まだ: 2 本指の操作（adb では試せない）, エミュレータ（x86_64 の .so は入れてあるが未確認）。

## BVH → ロボット（2026-10-05）

iOS 版と同じ（eusview/README.md の「BVH → ロボット（KXR / KHR / JSK）への移し替え」）。BVH の画面の下の「ロボット: …」で選び,
棒人形 / 関節名 / GMR / 人の大きさ を切り替える。棒人形と 2 体のロボットのリンクを 1 つの RobotModel（どのリンクも親なし）にまとめて
ワールドの変換を入れるので, RobotGLView はそのまま使う（見せないものは大きさ 0 の行列）。ロボットの画面の「動作」の「BVH から選ぶ」で
種類 → ファイル → 方法を選ぶと, 全部のコマを計算してから動作として再生する（物理オンなら関節角がサーボの目標）。
起動の引数（確認用）: `adb shell am start -n jp.jsk.eusview/.MainActivity --es bvh rikiya/rbvh_a/A01 --es robot khr --es method both`,
`--es open khr20h2 --es bvhmotion mocopi/greeting1 --es method gmr --es physics 1`。

## GMR + 全身 QP（2026-10-05）

iOS 版と同じ（`eusview/bvh/QP.md`）。`wbqp.{h,cpp}`（iOS 版のコピー）と `wbqp_jni.cpp` を odesim と同じ `libeusviewode.so` に入れ,
共通の `WholeBodyQp.kt` から呼ぶ。BVH の画面: 「GMR+QP」を GMR の右に（裏で全部のコマを計算, 計算前のコマは GMR の姿勢を薄く）,
「違反」で衝突のリンクを赤・可動範囲の端を橙, 重心の球・床の円・支持多角形（緑 = 中, 赤 = 外）。ロボットの画面: 方法「GMR + QP」
（物理オンで始めるときは今の姿勢から初めのコマへ 0.8 秒）。起動の引数 `-method gmrqp` など（デスクトップ版の README）。
- 確かめたこと: ビルド（debug / release）, 単体テスト（`make test-qp`: Swift の qptest とコマごとに一致）。**実機（Pixel 7a）では確かめていない**（つながっていなかった）。
