# EusView デスクトップ版（Ubuntu / Mac）

iPhone / Mac / Android 版の EusView と同じ機能を、1 つのウィンドウにまとめたデスクトップアプリ。
Kotlin + Compose Multiplatform Desktop（JVM）。Ubuntu（x86_64 / aarch64）用で、確認のため Mac（Intel）でも動く。

- 左: ロボットの一覧（KXR / KHR / JSK, 名前で探す）, BVH, 表示（自動 / 明るい / 暗い）
- 右: 3D 表示（左ドラッグで回転, 右ドラッグ・中ドラッグ・Shift + 左ドラッグで移動, ホイール・2 本指スクロールで拡大縮小）,
  物理（ODE）・サーボ・置き直す（物理の状態を左上に表示）, 関節 / 姿勢 / 動作（繰り返し, BVH から選ぶ）/ 接続（live の WebSocket）
- BVH: 種類 → ファイル（名前で探す）, 自動再生（全部 / 種類ごと）, 棒人形と移したロボット（関節名 / GMR / GMR + 全身 QP）, 違反の表示, ロボットを選ぶ

## Ubuntu で使う

```
sudo apt install openjdk-17-jdk cmake g++ libode-dev pkg-config curl fakeroot binutils fonts-noto-cjk
cd eusview/desktop
make native      # 物理の JNI ライブラリ → build/native/linux-<x64|arm64>/libeusviewode.so（ODE は pkg-config ode）
make run         # 起動（初回は Gradle が Compose・LWJGL などを取ってくる）
make deb         # .deb を作る（ODE はソースから静的に作って入れる: make ode）
sudo apt install ./build/compose/binaries/main/deb/eusview_1.0.0-1_*.deb
```
- `.deb` には JRE・ロボットの JSON・BVH・物理のライブラリ・アイコン（iOS 版と同じ）が入り、アプリ一覧に
  「eusview」が出る。入る場所は `/opt/eusview`（`/opt/eusview/bin/eusview` で起動の引数も渡せる）。消すのは `sudo apt remove eusview`。
- データ（`eusview/robots/<グループ>/*.json`, `eusview/bvh/cache/`, `eusview/bvh/retarget_tables.json`）は git に入れていないので、
  先に Mac などで作ってコピーしておく（BVH がなければ BVH の画面に作り方が出る）。`make run` はリポジトリのものをそのまま読み,
  `make deb` はビルドのときに `build/appResources/common/data/` にコピーして入れる。
- 日本語の表示には日本語のフォント（`fonts-noto-cjk` など）が要る。
- ODE: `make native` は `third_party/ode-<os>-<arch>/`（`make ode` で ODE 0.16.5 をソースから作った静的ライブラリ,
  倍精度・libccd あり・スレッドなしで iOS / Android 版と同じ）があればそれを、なければ `pkg-config ode`（libode-dev）を使う。
  `make deb` は入れる先に libode がなくてもよいように、`make ode` を先にする。
- JDK は 17 以上（`JAVA_HOME` を指定しなければ `/usr/lib/jvm/java-17-openjdk-*`）。Gradle は wrapper（8.10.2）が取ってくる。

## Mac で使う（確かめる用）

```
cd eusview/desktop
make native      # ODE は ../ios/third_party/ODE.xcframework/macos-x86_64（Intel Mac）. Apple Silicon は make ode
make run ARGS="-open kxrl2l6a6h2 -physics 1 -motion 1"
make thumbs      # ロボットの一覧の画像 ../robots/<グループ>/<名前>.png（ONLY=名前の一部）
make dist        # build/compose/binaries/main/app/eusview.app（JRE・データ入り）
```
JDK は `~/Library/Java/jdk-17*`（なければ `/usr/libexec/java_home -v 17`）。

## 起動の引数（確認用。iOS / Android 版と同じ名前）

| 引数 | 意味 |
|---|---|
| `-open <ロボット>` | そのロボットを開く |
| `-physics 1` | 物理モードで始める |
| `-motion <名前か番号>` | ロボットの動作を繰り返し再生（デスクトップ版だけ） |
| `-live ws://localhost:8766/` | 接続の欄でその URL に接続（デスクトップ版だけ） |
| `-bvhmotion <種類>/<名前> -method names\|gmr\|gmrqp` | ロボットの画面で BVH を移した動作を再生（gmrqp: GMR + 全身 QP） |
| `-bvh home\|auto\|auto:<種類>\|<種類>\|<種類>/<名前>` | BVH の画面 |
| `-robot kxr\|khr\|jsk\|<名前> -method all\|both\|names\|gmr\|qp\|gmrqp -stick 0 -speed 2` | BVH の画面で移すロボット・方法（all: 関節名・GMR・GMR+QP）・棒人形・速さ |
| `-violations 0` / `-frame <n>` | 違反（衝突・可動範囲・重心）の表示を消す / そのコマで止める（確認用） |
| `-tab 0..3` `-theme auto\|light\|dark` | 下の欄（関節 / 姿勢 / 動作 / 接続）, 表示 |
| `-data <フォルダ>` `-robots <フォルダ>` | データのフォルダ（`robots/` と `bvh/`）, JSON を足すフォルダ |
| `-width 1300 -height 820 -x 40 -y 30` | ウィンドウの大きさと位置（dp） |
| `-fps 1` | 3D の描く速さを 5 秒ごとにログへ |

環境変数: `EUSVIEW_DATA`（= `-data`）, `EUSVIEW_GL=egl|glfw`（Linux の OpenGL の作り方）。設定（グループ・表示・live の URL）は
`~/.config/eusview/settings.properties`。

## しくみ

```
build.gradle.kts         Kotlin 2.1.0, Compose Multiplatform 1.7.3, LWJGL 3.3.4, OkHttp 4.12.0, org.json
                         srcDir ../shared/kotlin（Android 版と共通のコード）, packageDeb / createDistributable
src/main/kotlin/jp/jsk/eusview/
  Main.kt                ウィンドウ: 左の一覧, 右のロボットの画面（3D・物理・下の欄）, 起動の引数
  DesktopStore.kt        データ（robots/, bvh/）と設定の置き場所, JNI のライブラリの探し方
  RobotGLView.kt         3D 表示: GL のスレッドで FBO（4x MSAA）に描き glReadPixels → Skia の Image → Compose の Canvas,
                         マウスで回転・移動・拡大縮小. 描き方は Android 版 RobotGLView.kt と同じ（OpenGL 3.2 core に）
  OffscreenGL.kt         画面に出さない OpenGL のコンテキスト: macOS は CGL, Linux は EGL（pbuffer か面なし）→ GLFW
  DesktopBvh.kt          BVH の画面の移り変わりと 3D 表示（画面は共通の BvhScreens.kt）
native/
  CMakeLists.txt         libeusviewode = android/app/src/main/cpp/{odesim.cpp, odesim_jni.cpp} + ODE
  build-ode.sh           ODE 0.16.5 をこの PC 用の静的ライブラリに（make ode）
../shared/kotlin/        Android 版と共通: RobotModel, Json, RobotScene, RobotState, PhysicsSim, LiveLink, BvhData,
                         BvhRetarget, BvhPlayer, BvhScreens, RobotPanels, SceneCommon, Platform
```
- 3D を画像で出すのは, Compose の上に重ねる文字（物理の状態, BVH の情報）をそのまま出すためと, macOS（GLFW は
  メインスレッドだけ）と Linux（X11 / XWayland）の両方で同じに動かすため。大きい画面では描く画素を 250 万までに抑えて引き伸ばす。
- Mac（Intel Iris Plus 655, Retina）での計測: kxrl2l6a6h2（7,496 三角形, 1196 × 1464 画素）で 50〜54 コマ/秒, 描く + 読むで
  11〜13 ms/コマ。BVH の画面（棒人形 + ロボット 2 体, 17,804 三角形, 1998 × 946 画素）で 53〜56 コマ/秒, 13〜14 ms/コマ（`-fps 1`）。

## Ubuntu で確かめること（この Mac では確かめていない）

- `make native`（libode-dev, JDK のヘッダ）と `make ode`（ODE 0.16.5 のソースのビルド）が通るか。
- 3D が出るか（ログに `OpenGL (EGL: ...)`）。出なければ `EUSVIEW_GL=glfw make run`。Wayland のときは Java が XWayland で動く。
- `make deb` が通り, `sudo apt install ./...deb` で入り, アプリ一覧のアイコンから起動できるか（`/opt/eusview/bin/eusview`）。
- 日本語が出るか（fonts-noto-cjk）, 高解像度の画面での大きさ（`GDK_SCALE=2` など）, 暗い表示（自動はたぶん効かないので「暗い」）。
- 物理（ODE）・live（`python3 eusview/live.py` と `-live ws://localhost:8766/`）・BVH の移し替えが Mac と同じに動くか。

## GMR + 全身 QP（2026-10-05）

物理と同じ JNI ライブラリ（`make native`）に全身 QP（`wbqp.cpp`, `wbqp_jni.cpp`, Android 版と同じソース）が入る。画面は Android 版と共通
（`eusview/bvh/QP.md` の「組み込み」）。Mac（Intel）で確かめたこと:
- `make run ARGS="-bvh mocopi/greeting1 -robot kxr -frame 230"`: 4 体, GMR の衝突のリンクが赤（9 組, −20 mm）, GMR+QP は衝突なし, 重心と支持多角形が緑。
- `make run ARGS="-bvh rikiya/rbvh_a/A01 -robot kxr -frame 60"`: GMR の胴が赤, GMR+QP は衝突なし（全体で 100% → 1.5%）。
- `make run ARGS="-open khr20h2 -physics 1 -bvhmotion mocopi/greeting1 -method gmrqp"`: 30 秒たっても立っている（`-method gmr` は倒れる）。
- 不具合を直した: `-stick 0` で BVH の画面を開くと落ちた（見せないリンクの行列が init の後で作られていた）。
