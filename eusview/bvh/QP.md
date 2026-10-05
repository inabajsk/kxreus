# GMR + 全身 QP（自己衝突・関節の可動範囲・重心）

GMR（`RETARGET.md` の方法 2）で BVH から移した関節角とルートの姿勢を、コマごとに 2 次計画法（QP）で直す。
考え方は AIST / CNRS の mc_rtc（Tasks の QP: タスクの重み付き最小二乗 + 不等式制約, `CollisionConstraint` の速度ダンパ）と同じだが、
コードは自前（mc_rtc・Eigen・QP ライブラリは使わない）。

- コード: `eusview/ios/EusView/QP/wbqp.h`（C の API）, `wbqp.cpp`（C++17 の標準ライブラリだけ）。
  Swift の包み: `WholeBodyQP.swift`（RobotModel / BVHRetargeter からモデルを作る, `runGMRQP`, `makeGMRQPMotion`）。
- Android・デスクトップ（Kotlin, JNI）と kxreus（EusLisp, defforeign）も **同じ `wbqp.{h,cpp}`** を写して使う（下の「組み込み」）。
- ライセンス: 自前のコード（EusView の一部）。QP ソルバは Goldfarb & Idnani (1983)
  "A numerically stable dual method for solving strictly convex quadratic programs" の手順を論文から書いたもの
  （eiquadprog / QuadProg++ などの LGPL・GPL のコードは使っていない）。

## 定式化（1 コマ）

変数 x = [ルートの並進 dp（3, m）, ルートの回転 dω（3, ワールドの回転ベクトル）, 関節角の変化 dq（n）, 緩め s ≥ 0（衝突の組ごと + 重心 1）]。
今の姿勢で順運動学とヤコビアン（回転関節の列 = 軸 × (点 − 関節の位置), 直動 = 軸, ルートの回転の列 = e_k × (点 − ルート)）を求め、

最小化 Σ w_i² ‖J_i x − e_i‖² + w_reg ‖x‖² + w_slack ‖s‖²

| タスク | 誤差 e | 重み（既定） |
|---|---|---|
| 関節角を参照（GMR）に | q_ref − q | `w_posture` 1 |
| ルートの向き | log(R_ref R^T) | `w_root_rot` 2 |
| ルートの位置 | (p_ref + δ − p) / L | `w_root_pos` 0.5 |
| 手首の位置（GMR の答えの順運動学） | (p* + δ − p) / L | `w_hand` 2 |
| 浮いている足の位置・向き | 同上 / log | `w_foot` 3, `w_foot_rot` 1 |
| 床に着いた足（止める） | 止めた位置・向き（水平にした）との差 | `w_stance` 30, `w_stance_rot` 10 |

L = 脚の長さ（関節角 0 でルートと足の裏の高さの差。KXR 0.212 m, KHR 0.296 m, sample-robot 0.713 m）。位置は L で割ってロボットの大きさによらない重みにする。
δ = 止めた足と参照の足の水平のずれの平均（`delta_gain` 0.2 でならす）。止めた足に合わせて手・浮いた足・ルートの目標もずらす（足がすべらない分だけ全体が参照からずれる）。

制約（C x ≥ c, Goldfarb–Idnani で解く）:
1. **関節の可動範囲**: lo + `joint_margin` ≤ q + dq ≤ hi − `joint_margin`（既定 0.035 rad = 2°）
2. **関節の速さ**: |q + dq − q_前のコマ| ≤ vmax · dt（vmax は JSON の physics の vmax, なければ `vmax_default` 8 rad/s）。範囲と両立しないときは速さを優先
3. **足の裏は床より上**: 足の裏の多角形の頂点 z ≥ 0
4. **自己衝突**（速度ダンパ, mc_rtc の CollisionConstraint と同じ形）: 影響の距離 d_i = `d_influence`·L（0.15 L）より近いカプセルの組ごとに
   nᵀ(J_a − J_b) x + s ≥ −ξ (d − d_s),  ξ = `xi` 0.5, d_s = `d_safe`·L（0.01 L）。リンクの組ごとに最も近いカプセルの組だけ, 近い順に `max_collision_rows`（24）組
5. **重心**: 重心の床への投影が支持多角形（支える足の裏の凸包, `com_margin`·L だけ内側, 狭いときは内接の 4 割まで）の各辺の内側:
   mᵀ(c + J_c x) ≤ b − margin（+ 緩め）
6. （試し, 既定オフ `zmp` 0）ZMP = c − z_c/g · c̈（c̈ は答えの重心の差分）も支持多角形に。先読みがないと発散するので使っていない

緩めの重み `w_slack` 1e6（ほぼ固い制約。解けないときだけ緩む）。逐次 QP を `iterations`（3）回（変化が 1e-4 未満で止める）。
始める姿勢は前のコマの答え（初めのコマは参照）。

### 足の接地と先読み

- 接地 (contact): 参照の足の裏のいちばん低い点の高さ < `contact_on`·L（0.04 L）で着く, > `contact_off`·L（0.08 L）で離れる（ヒステリシス）。
- 着いた足は着いたコマの参照（+δ）の位置で, 向きは水平（ヨーだけ残す）, 裏が z = 0 になる高さで止める。参照の足が止めた所から
  `reanchor_dist`·L（0.3 L）か `reanchor_yaw`（0.5 rad）より離れたら置き直す（その場で回るなど）。
- 支え (support): この先 `preview` コマ（8）の間ずっと着いている足（片足を上げる前に重心を残る足に移す）。全部が離れるならその手前まで。

### モデル（初めに 1 度, `wbqp_finalize`）

- カプセル: リンクのメッシュの頂点の主成分（ヤコビ法）。主軸の向きに、断面（第 2・第 3 の軸, 2〜98% の幅）を 1×1 / 2×1 / 2×2 の升に分け
  （箱をカプセルで包んだときの出っ張りが断面の短い方の 3 割以下になる最小の分け方, 主軸が 0.15 L より短いリンクは 1 つ）、
  升ごとに半径 = 頂点の 80%（`capsule_cover`）を覆う距離。KXR 46 個 / KHR 36 個 / sample-robot 33 個。
- 調べる組: 木で 2 つ以内（`exclude_tree`）のリンク, 関節角 0 と reset-pose で d < d_s の組を除く（KXR 879 / KHR 506 / sample-robot 446 組）。
- 足の裏: 足のリンク（GMR の脚の footLink）の関節角 0 でいちばん低い頂点から `sole_tol`·L 以内の点の凸包（8 頂点まで）。
- 質量・重心: JSON の physics（KXR, KHR）, なければ頂点の外接箱 × 400 kg/m³（PhysicsSim と同じ）。

## C の API（`wbqp.h`）

単位は m・rad・kg, z が上, 床は z = 0。姿勢は 12 個の double（位置 x y z, 回転 3×3 行優先）。**ルートの姿勢 = ルートのリンクのワールドの姿勢**
（BVHRetargeter の T ではなく `rootLinkPose(T) = T · rest_root`）。直動関節は m（アプリの関節角は mm, 度なので変換する）。

```c
WbQP *h = wbqp_create();
for (each link i, 根元から)   wbqp_add_link(h, parent, rest12);           // rest: 親から見た関節角 0 の姿勢
                              wbqp_add_link_vertices(h, i, xyz, nv);      // メッシュの頂点 (float, m)
                              wbqp_set_link_mass(h, i, mass, com);        // あれば
for (each joint k, JSON の順) wbqp_add_joint(h, link, type(0 回転 / 1 直動), axis, lo, hi, vmax);
wbqp_set_hand(h, 0 /*左*/, link, offset); wbqp_set_hand(h, 1, ...);      // GMR の腕の endLink + endOffset
wbqp_set_foot(h, 0, link); wbqp_set_foot(h, 1, link);                     // GMR の脚の footLink
wbqp_set_param(h, "dt", 1.0 / fps);                                       // ほかのパラメータも名前で
wbqp_finalize(h, reset_pose_rad, 1);                                      // この姿勢で当たる組は調べない

wbqp_reset(h);                                                            // 動作の初め
for (i = 0; i < n; i++) {
  // contact は wbqp_contact_of (1 コマずつ) か wbqp_plan_contacts (動作全体, 先読みの support も) で
  wbqp_solve(h, q_ref[i], root_ref[i], contact[i], support[i], NULL, q_out, root_out, &diag);
}
wbqp_eval(h, q, root, support, &ev, link_flags, poly, 32);                // 評価だけ (表示用, 状態を変えない)
wbqp_destroy(h);
```

- `WbqpDiag`: before / after（`WbqpEval`: 最小距離とリンクの組, 衝突の組の数, 可動範囲の外 / 端の関節の数, 重心, 支持多角形との余裕（m, 正 = 中, 足が浮くと NAN）,
  左右の足の高さ）, contact, support, status（0 / 1 / −1 = 解けない → 前の答え）, 逐次 QP と有効制約法の回数, 制約の数, 緩めの最大, 時間（ms）。
- `link_flags`: bit0 = 衝突（d < 0）, bit1 = 関節が可動範囲の端（端から 0.5° 以内）か外, bit2 = d < d_s。
- 情報: `wbqp_num_capsules` / `wbqp_capsule`, `wbqp_num_pairs` / `wbqp_pair`, `wbqp_sole`, `wbqp_total_mass`, `wbqp_get_param(h, "scale")`（= L）, `wbqp_fk`。
- スレッド: `wbqp_solve` は h の状態を書き換える（1 つの h は 1 つのスレッドで）。`wbqp_eval` / `wbqp_fk` は読むだけ。

## 組み込み（2026-10-05）

| 環境 | 呼び方 | ファイル | 画面 |
|---|---|---|---|
| iPhone / Mac（iOS アプリ） | ブリッジングヘッダ | `ios/EusView/QP/wbqp.{h,cpp}`（元）, `WholeBodyQP.swift` | BVH の画面の 4 体目「GMR+QP」と「違反」, ロボットの画面の方法「GMR + QP」 |
| Android | JNI（`libeusviewode.so`, odesim と同じ） | `android/app/src/main/cpp/wbqp.{h,cpp}`（コピー, `make -C android sync-wbqp`）, `wbqp_jni.cpp`, 共通の `shared/kotlin/.../WholeBodyQp.kt` | iOS 版と同じ（共通の `BvhPlayer.kt` / `BvhScreens.kt` / `RobotState.kt` / `RobotPanels.kt`） |
| デスクトップ（Ubuntu / Mac） | JNI（`desktop/native/CMakeLists.txt` が Android と同じソースを使う） | 同上 | 同上（`make native && make run ARGS="-bvh mocopi/greeting1 -robot kxr"`） |
| kxreus EusView（irteusgl） | defforeign（`eusviewqp_*`, `eusview-ode/eusviewode.cpp`） | `~/kxreus/eusview-ode/wbqp.{h,cpp}`（コピー）, `eusview-qp.l`, `make eusview-ode` で `$ARCHDIR/lib/libeusviewode.so` | BVH のパネルの「QP: ON/off」（棒人形・関節名・GMR の横に GMR+QP）, ロボットのパネルの BVH の「method: GMR + QP」 |

- Kotlin（`WholeBodyQp.kt`）: `WholeBodyQp(model, rt, fps)`, `runGmrQp`（Swift の `runGMRQP` と同じ: GMR の初めのコマを 8 回解く,
  先読み `preview` コマの support）, `makeGmrQpMotion`, `qpSummary`。`WbqpEval` は 14 個, `WbqpDiag` は 37 個の double で JNI から受け取る。
  描画（Android `RobotGLView` / デスクトップ `RobotGLView`）: `RobotScene.tints`（リンクごとに 赤 = 衝突, 橙 = 可動範囲の端, 薄く = まだ計算していないコマ）と
  `RobotScene.overlays`（重心の球（体に隠れても見える）・床の円・支持多角形, 緑 = 中 / 赤 = 外）。
- EusLisp（`eusview-qp.l`）: `(instance eusview-qp :init robot :fps 30)` がロボットのリンク（`evp-sort-links`, 関節角 0 での親からの座標）,
  回転・直動関節（軸は子のリンクの座標, 範囲は `:min-angle` / `:max-angle`）, 質量・重心（`eusview-physics.l` の `evp-link-physics`）,
  ボディの頂点（カプセルは wbqp が作る）, 手（`:larm` / `:rarm` の `:end-coords` の親リンク）, 足の裏（`:lleg` / `:rleg` の `:end-coords` の親リンク）から QP を作る。
  参照は kxreus の GMR（`eusview-retarget.l` の `:gmr`）。BVH のパネルは表示するコマごとに解く（先読みなし。描画が遅くてコマが飛ぶときは
  飛んだコマ数（8 まで）だけ同じ参照で解き直す, 戻る・30 コマより飛ぶときは `wbqp_reset`）。ロボットのパネルのキー（15 fps）は `wbqp_plan_contacts` で先読みしてから解く。
  違反: 衝突のリンクの面を赤・可動範囲の端を橙（`:set-color`, 元の色に戻す）, 重心（十字と床への線・床の円）と支持多角形（半透明の面と縁）を
  `eusview-viewer :draw-objects` の最後に OpenGL で描く。
- 3 つの GMR は同じではない（Swift と Kotlin は同じ式, kxreus は `:inverse-kinematics` の自前の GMR）。QP の C++ は全部同じ。

### Swift と Kotlin（JNI）の照合（Mac, 2026-10-05）

`ios/tools/qptest -physics 0 -dump ios/build/qpdump` と `make -C android test-qp`（`QpTest.kt`, デスクトップ版の JNI ライブラリを JVM で読む）の
コマごとの CSV を `python3 bvh/qpcompare.py ios/build/qpdump android/build/qptest` で比べた（greeting1 946 コマ, rikiya A01 131 コマ × KXR / KHR / sample-robot）:
参照（GMR）の関節角の差 最大 0.0003°, QP の答えの差 最大 0.0002°（平均 0.00001°）, ルートの位置の差 0.001 mm 以下（CSV の桁）,
接地（contact）と衝突のコマは全部一致。集計（衝突・重心・ずれ・解けない 0）も上の表と同じ値。

### デスクトップ版・Android 版（2026-10-05）

- デスクトップ版（Mac, Intel）: `make run ARGS="-bvh mocopi/greeting1 -robot kxr -frame 230"`（`-frame` はそのコマで止める）で 4 体（棒人形・関節名・GMR・GMR+QP）。
  コマ 231: GMR は衝突 9 組（−20 mm, 赤）, GMR+QP は衝突なし（2 mm）, 重心 41〜45 mm 中（緑）。裏の計算 946 コマ 1.1〜1.9 秒（QP 0.64〜0.86 ms/コマ, 衝突 7.1% → 0%）。
  rikiya A01 × KXR コマ 61: GMR は胴が赤（衝突 1, −3 mm）, GMR+QP は衝突なし（131 コマ 0.33 秒, 衝突 100% → 1.5%）。
  ロボットの画面 `-open khr20h2 -physics 1 -bvhmotion mocopi/greeting1 -method gmrqp`: 946 コマを 1.3 秒で計算, 30 秒たっても立っている（両足 8 点で接地）。
  同じく `-method gmr` は倒れる（18 秒の時点で床に寝ている）。
- Android: `./gradlew assembleDebug assembleRelease` と単体テスト（RetargetTest, JsonReaderTest, QpTest）が通る。`libeusviewode.so`（arm64-v8a, x86_64）に wbqp が入る。
  実機（Pixel 7a）はつながっていなかったので画面は確かめていない。
- GMR の `placeHeight` の不具合（T の高さだけずれる）は Kotlin（`BvhRetarget.kt`）も直した。`RetargetTest` に足の裏の高さの確認を足した
  （GMR の足の裏のいちばん低い点: −70〜+33 mm, 脚の長さの 30% より下なら失敗。直す前の sample-robot は 0.71 m 沈んでいた）。

### kxreus（EusLisp, Mac の jskeus irteusgl, 2026-10-05）

kxreus の GMR（`:inverse-kinematics`, 毎コマ）→ QP, 全部のコマ（BVH のパネルと同じ, 先読みなし）:

| BVH × ロボット | コマ | QP ms/コマ | 自己衝突のコマ GMR → QP | 重心が外 GMR → QP |
|---|---|---|---|---|
| mocopi greeting1 × KXR | 946 | 1.07 | 100% → 0% | 0 → 0 |
| rikiya A01 × KXR | 131 | 1.20 | 100% → 29% | 6.9% → 0.8% |
| mocopi greeting1 × KHR | 946 | 0.31 | 27% → 0.2% | 0 → 0 |
| rikiya A01 × KHR | 131 | 0.54 | 100% → 1.5% | 20.6% → 0 |

- kxreus の GMR は手を位置だけで IK するので手首が曲がり, KXR では肘とグリッパーが全部のコマで当たる（アプリの GMR は 7.1%）。
  KXR × rikiya は参照のめり込みが深く（−23 mm）, 先読みなしの 1 コマずつの QP では 29% のコマに衝突が残る。
- irtviewer（XQuartz）で再生すると描画が約 150 ms/コマで 5 コマに 1 回しか解けない。rikiya A01 × KXR（1x）で衝突 100% → 65% だったのを,
  飛んだコマ数だけ解き直して 100% → 12% にした。BVH のパネルの状態の行と端末に集計を出す（例 greeting1 × KHR 4x: 22% → 2%）。
- kxreus の GMR の不具合を直した: `eusview-bvh-robot-min-z` がボディの頂点を `:worldcoords` で更新せずに読んでいたので,
  kxrl2l6a6h2 が床から 44 mm 浮いていた（足が浮いて QP が接地を見つけなかった）。KHR は影響なし。
- 物理（`eusview-physics.l`, ロボットのパネルと同じキー 15 fps, 初めに 0.8 秒で移る, 39 秒）: KXR は GMR・GMR+QP とも倒れない（腰の傾き 15° / 25°）,
  KHR は GMR 1.6 秒・GMR+QP 1.8 秒で倒れる（kxreus の物理はアプリと接触・サーボのパラメータが違う。アプリでは KHR × greeting1 は GMR+QP で倒れない）。

## 確かめたこと（Mac, `ios/tools/qptest.swift`, 2026-10-05）

`ios/tools/build-qptest.sh && ios/build/qptest/qptest [-realservo 1] [-maxsec 60] [-p 名前=値] [-json 出力]`。
QP ソルバ単体: 3000 個のでたらめな QP（2〜5 変数, 2〜8 制約）を有効制約の全部の組み合わせと比べ、最適値が全部一致, 解なし 656 個も全部「解なし」。

「前 → 後」= GMR → GMR + QP（カプセルでの判定）。重心が外 = 足が着いたコマのうち, 着いた足の裏の凸包の外。QP の時間は Mac（Intel）。

| BVH × ロボット | コマ | QP ms/コマ 平均（最大） | 自己衝突のコマ | 可動範囲の端 | 重心が外 | 関節のずれ 平均 / 95% |
|---|---|---|---|---|---|---|
| mocopi greeting1 × KXR | 946 | 0.65 (1.1) | 7.1% → 0% | 0 → 0 | 0 → 0 | 1.1° / 5.4° |
| rikiya A01 × KXR | 131 | 0.81 (1.3) | 100% → 1.5% | 0 → 0 | 0 → 0 | 3.2° / 13.5° |
| lafan1 dance1 × KXR | 3945 | 1.35 (4.6) | 88.9% → 11.8% | 3.0% → 0 | 11.4% → 19.1% | 29° / 115° |
| lafan1 fallAndGetUp1 × KXR | 5047 | 1.59 (3.2) | 93.0% → 27.6% | 7.5% → 0 | 47.9% → 26.1% | 37° / 130° |
| sfu Walking001 × KXR | 1173 | 0.63 (1.2) | 46.2% → 3.6% | 0 → 0 | 0 → 0 | 3.5° / 16° |
| mocopi greeting1 × KHR | 946 | 0.31 (0.7) | 0.8% → 0% | 1.1% → 0 | 0 → 0 | 1.8° / 7.1° |
| rikiya A01 × KHR | 131 | 0.37 (0.8) | 7.6% → 0% | 0 → 0 | 2.3% → 0 | 5.1° / 17° |
| lafan1 dance1 × KHR | 3945 | 0.65 (2.3) | 41.9% → 16.3% | 27.1% → 0 | 24.0% → 6.0% | 24° / 98° |
| lafan1 fallAndGetUp1 × KHR | 5047 | 0.76 (2.1) | 45.4% → 19.4% | 30.9% → 0 | 49.4% → 10.7% | 34° / 125° |
| sfu Walking001 × KHR | 1173 | 0.39 (0.8) | 0 → 0 | 0 → 0 | 9.8% → 0 | 5.0° / 17° |
| mocopi greeting1 × sample-robot | 946 | 0.34 (0.7) | 0 → 0 | 0 → 0 | 0 → 0 | 1.2° / 6.3° |
| rikiya A01 × sample-robot | 131 | 0.45 (0.8) | 0 → 0 | 0 → 0 | 0 → 0 | 2.9° / 12° |
| lafan1 dance1 × sample-robot | 3945 | 0.88 (2.7) | 6.6% → 4.8% | 16.2% → 0 | 17.2% → 38.6% | 22° / 95° |
| lafan1 fallAndGetUp1 × sample-robot | 5047 | 0.94 (4.9) | 9.9% → 6.7% | 35.0% → 0 | 49.2% → 41.5% | 25° / 97° |
| sfu Walking001 × sample-robot | 1173 | 0.50 (8.2) | 0 → 0 | 0 → 0 | 0.8% → 0 | 3.1° / 14° |

- GMR の時間は 0.3〜0.5 ms/コマ。QP の「解けない」は全部 0。可動範囲の外（端の外）はもともと GMR が切っているので前後とも 0。
- 床に着いた足のすべり（コマの間の水平の動き）: 例 sfu Walking × KHR 8.7 → 3.1 mm/コマ, greeting × KXR 0.52 → 0.02 mm/コマ。
- 手首の位置（腰から見た）のずれ: 歩く・挨拶は 2〜24 mm（KXR, KHR）。sample-robot は 9〜55 mm, lafan1 は 50〜350 mm。
- **うまくいかないもの**: lafan1 の踊り・転んで起きる。床に手をつく・寝転ぶ・跳ぶ動きは「足の裏の支持多角形」の前提に合わない。
  腕が体をすり抜ける参照では局所の QP は反対側に引っかかったまま（関節のずれ 95% が 100° 前後）。そのため衝突が残り（11〜28%）, 重心が外のコマが増えることもある。
- カプセルは箱の形の部品を少し太めに包む: KXR で腕を下ろした姿勢では メッシュの頂点は 5〜15 mm 離れているのにカプセルは 2〜8 mm 重なる
  （「GMR の衝突」の割合は実際より多め。QP は少し余計に避ける）。
- iPhone（実機）: lafan1 dance1 × KXR の GMR + QP 3945 コマを 3.78 秒（QP 0.85 ms/コマ）, greeting1 × KHR 946 コマを 0.30 秒。30 fps より十分速い。

### 物理（ODE, PhysicsSim）で倒れるか

関節角の列をサーボの目標にして再生（初めのコマで 0.5 秒置いてから, 60 秒まで）。腰の傾き > 60° で「倒れた」（参照の傾き < 30° のとき）。
アプリの既定のサーボ（eusdyna と同じ, 力の上限 5e5）:

| BVH | KXR GMR → GMR+QP | KHR GMR → GMR+QP | sample-robot |
|---|---|---|---|
| mocopi greeting1 | 0.6 秒 → 0.6 秒 | 0.8 秒 → **倒れない（39 秒）** | 0.5 → 0.5 秒 |
| rikiya A01（歩く 4 秒） | 0.3 秒 → **倒れない** | 0.1 秒 → **倒れない** | 0.0 → 0.4 秒 |
| sfu Walking001 | 0.5 秒 → 5.9 秒 | 0.6 → 0.9 秒 | 0.8 → 1.0 秒 |
| lafan1 dance1 | 5.2 秒 → 0.0 秒 | 5.3 → 21.3 秒 | 0.2 → 0.2 秒 |
| lafan1 fallAndGetUp1 | 0.4 → 0.0 秒 | 5.2 → 5.4 秒 | 0.2 → 0.1 秒 |

KRS の公称のサーボ（`-realservo 1`）でもほぼ同じ（KHR greeting・KXR rikiya は倒れない, KHR rikiya 0.1 → 0.9 秒）。
- 立つ・ゆっくり歩く動きでは倒れにくくなる。速い動き（greeting1 は初めの 0.2 秒で 18° おじぎする）は静的な重心の制約では足りない（ZMP / 動力学が要る）。
- sample-robot は JSON に physics がなく（質量は見積もり）, 参照の姿勢のままでもすぐ倒れる。
- アプリのロボットの画面: 物理オンで動作を始めるとき, 今の姿勢から初めのコマへ 0.8 秒かけて移るようにした（いきなり跳ぶと, 立っていられる動作でも倒れた）。
  khr20h2 × greeting1（GMR + QP）が物理オンで倒れずに続く（Mac で確認）。
