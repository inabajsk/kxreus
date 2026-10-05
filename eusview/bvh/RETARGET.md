# BVH → ロボットへの移し替え（EusView 共通の仕様）

BVH の人の動きを KXR / KHR / JSK のロボットに移して、棒人形と並べて再生する。方法は 2 つ。
アプリ（iPhone / Mac / Android）と kxreus の eusview（irteusgl）で同じ考え方にする。

## 対象のロボット（BVH の画面で選ぶ。既定は各グループ 1 体）

| グループ | 既定 | 条件 |
|---|---|---|
| KXR | kxrl2l6a6h2 | 関節名が `<limb>-<joint>-<r|p|y>`（limb = larm, rarm, lleg, rleg, head, torso） |
| KHR | khr20h2（khr3 も可） | 同上 |
| JSK | sample-robot（h7 も可） | 同上（darwin などこの命名でないものは選べない） |

## 方法 1: 関節名で対応（kxreus bvh-demo.l / jskeus irtbvh.l の `:copy-state-to`）

- BVH の骨格を jskeus の `bvh-robot-model`（データの種類ごとのクラス: lafan1-, mocopi-, sfu-, rikiya-, tum-bvh-robot-model）で読み、
  その limb（larm, rarm, lleg, rleg, torso, head）・関節（collar, shoulder, elbow, wrist / crotch, knee, ankle / chest / neck）の
  3 自由度の関節角をロボットの同じ名前の関節へ写す（kxreus bvh-demo.l の `rikiya-bvh-robot-model :copy-joint-to-`）:
  - ロボットの `<limb>-<joint>-r` ← BVH の関節角の要素 2、`-p` ← 要素 0、`-y` ← 要素 1
  - 符号: ロボットの関節軸の該当成分（r: x, p: y, y: z）が負なら −1。:mirrored のロボットは右手足に −1。head の neck は −1
  - 腰（ルート）の位置・姿勢は BVH のルートに合わせる（`stay` のとき動かさない）
- **基準は EusLisp の結果**。アプリの実装は、EusLisp で同じ BVH・同じロボットを `:copy-state-to` したときの関節角と比べて確かめる。

## 方法 2: GMR（General Motion Retargeting の考え方: 体の部位の位置・向きを合わせる逆運動学）

GMR（Araujo, Ze ほか 2025, "Retargeting Matters: General Motion Retargeting for Humanoid Motion Tracking"）は、人とロボットの
体の部位の対応表、部位ごとのスケール、IK（位置と向き）で人の動きをロボットに移す。ここではその考え方を小さなロボット向けに簡単にする。

1. **部位の対応**: 人（BVH）とロボットで次を対応させる。
   腰（pelvis ↔ ルートリンク）, 胸（spine の上 ↔ torso の先 / ルート）, 頭（head ↔ head の先）,
   左右の 上腕の付け根（shoulder ↔ arm の最初の関節のリンク）, 肘（forearm ↔ elbow のリンク）, 手首（hand ↔ arm の end-coords）,
   左右の 股（upleg ↔ leg の最初の関節）, 膝（leg ↔ knee）, 足首（foot ↔ leg の end-coords）。
   BVH の関節名はデータの種類ごとの表（上の bvh-robot-model と同じ: 例 lafan1 は LeftArm / LeftForeArm / LeftHand / LeftUpLeg / LeftLeg / LeftFoot …）。
2. **スケール**: 人の脚の長さ（股→膝→足首）とロボットの脚の長さの比 s_leg、腕は肩→肘→手首の比 s_arm、胴（腰→肩の高さ）は s_torso。
   ロボットの各部位の目標位置 = ロボットの腰 + R_root · s_k · (人の部位の位置 − 人の腰)（人の腰の座標系で表して、部位ごとの s を掛ける）。
3. **腰**: ロボットのルートの向き = 人の骨盤の向き（BVH の初期姿勢との差をロボットの reset-pose / zero-pose の向きに足す）、
   高さ = ロボットが reset-pose で立つ高さ ×（人の腰の高さ / 人の初期の腰の高さ）、水平位置 = s_leg × 人の腰の水平位置。
4. **IK**: limb ごとに（左右の腕・脚）、手首 / 足首の位置（重み 1）と向き（重み 0.3, 足は 0.6）、肘 / 膝の位置（重み 0.3）を目標に、
   減衰付き最小二乗（λ = 0.05, 1 コマあたり最大 10 回, 前のコマの答えから始める）。関節の可動範囲で切る。頭と胴は向きだけを合わせる。
5. **床**: 足首の目標は床（z = 0）より下にしない。表示のときは両足のうち低い方を床に合わせる（物理なしのとき）。
6. 1 コマあたりの計算は 30 fps で間に合うこと（KXR で数 ms が目安）。

## 再生のしかた

- BVH の画面: 棒人形（左）・方法 1 のロボット（中）・方法 2 のロボット（右）を並べて同じ時刻で再生。どれを出すか切り替えられる。
  ロボットは KXR / KHR / JSK から選ぶ（既定は上の表）。
- ロボットの画面の「動作」: KXR / KHR の動作の並びに「BVH」を足し、種類 → ファイル → 方法（関節名 / GMR）を選ぶと、
  そのロボットで BVH から移した関節角の列を動作として再生する。物理（ODE）オンのときは、この関節角をサーボの目標にする
  （オン / オフで、倒れる・滑るなどの違いを見る）。

## GMR + QP（全身 QP で自己衝突・関節の可動範囲・重心を直す）

GMR の答えをコマごとに全身 QP で直す方法を足した（BVH の画面の 4 つ目「GMR+QP」, ロボットの画面の方法「GMR + QP」）。仕様は `QP.md`。
