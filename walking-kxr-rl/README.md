# walking-kxr-rl — KXRモジュールロボット群の「立ち上がり・歩行」を1つのレシピで学習する

[walking-hand-rl](https://github.com/iory/walking-hand-rl)(5本指ハンドが指だけで
起き上がって歩く)と同じ mjlab(MuJoCo-Warp)+ rsl_rl PPO の学習基盤を、
**KXR(近藤科学)のモジュール型脚ロボット**に一般化したもの。KXRは同じサーボ
モジュール(股・膝・足首・肩・肘・手首・首・グリッパ)を組み替えて多種多様な
機体を作れるのが特徴で、このリポジトリはその「型」を活かし、**ロボットごとに
コードを書き直さず**、URDFと `kxreus` の関節構成定義(yaml)から自動的に
立ち上がり(Getup)・歩行(Walk)タスクを組み立てる。

対応ロボット(`~/kxreus/urdfs/` 内、`kxr_rl.robots.DEFAULT_ROBOTS`):

| ロボット | 脚のDOF構成 | 特徴 |
|---|---|---|
| `kxrl4d` | 股(pitch+roll)+膝+足首(pitch) = 4DOF | 標準的な2足歩行脚。腕2本+頭 |
| `kxrl4t` | 股(yaw+roll)のみ = 2DOF、膝・足首なし | 前後に脚を振れない極小DOF脚 |
| `kxrl2g` | 股(roll+pitch)+膝+足首(pitch+roll) = 5DOF | 最もDOFが多い脚。腕にグリッパ付き |
| `kxrl6` | 股(yaw+pitch)+膝 = 3DOF、足首なし | 脚2本+腕4本(通常腕2+中間腕2) |

新しいKXRロボットを追加するのに新規コードは要らない: `kxr_rl/robots.py` の
`DEFAULT_ROBOTS` に名前を足し、`build_mjcf.py` / `measure_home.py` を回すだけで
学習タスクが生える(下記§2)。これが「モジュール型だから多種類作れる」という
KXRの強みをそのままRL学習基盤の強みに変換している部分。

---

## TL;DR

```bash
cd walking-kxr-rl
uv run check.py                          # 4体ぶんのhome姿勢の安定性を検証(数秒)
uv run train.py kxrl4d walk              # 一から学習する
uv run play.py kxrl4d standwalk          # 倒れる->起き上がる->歩く、を1本の動画に
```

セットアップコマンドは無い。最初の `uv run` が uv.lock どおりに venv を作り、
最初の `import kxr_rl` が上流 unitree_rl_mjlab を固定コミットで `.upstream/` に
取得する。事前に要るのは **git・NVIDIA ドライバ(CUDA 12系)・uv** だけ。

---

## 1. 仕組み — URDFから自動でRLタスクを組み立てる

### 1.1 パース(`kxr_rl/robots.py`)

KXRのURDFは全モデル共通の命名規則を持つ: 関節名 = 子リンク名で、
`lleg-`/`rleg-`(脚)、`larm-`/`rarm-`(腕)、`lmarm-`/`rmarm-`(中間腕)、
`head-`(頭)のプレフィクスで所属する肢が分かる。`kxreus/yamls/<name>.yaml`
(`kxreus` の `eus2yaml` が吐く肢->関節リストのマップ)があればそれを最優先で
使い、無ければURDFの命名規則から同じ構造を復元する。

これで各ロボットについて:
- 胴体リンク名(URDFで一度も子リンクにならないリンク)
- 各脚の関節チェーン(股->膝->足首の順)と**足リンク**(チェーン末端 = 足首が
  あれば足首、無ければ膝)
- それ以外の肢(腕・頭)の関節リスト

が全て自動で分かる。全KXR関節は同一サーボ仕様(**0.656248 N·m** stall、
7.48 rad/s — walking-hand-rlのハンドと同じ実測値)を共有するので、
アクチュエータ設定も一切ハードコード不要。

### 1.2 URDF -> MJCF(`robot/build_mjcf.py`)

ハンドと違い**Z-up回転のハックが不要**: KXRのURDFは元々 root の +Z が上、
脚が -Z 方向に伸びる標準的なROS向き。scikit-robot の `urdf_to_mjcf` に
アクチュエータ無し・自己衝突無しでそのまま渡すだけ。メッシュの
`package://<name>/meshes/...` 参照は scikit-robot が URDF の親ディレクトリを
辿って自動解決する(`kxreus/urdfs/<name>/urdf/` から2段上がると
`kxreus/urdfs/<name>/meshes/` に当たる)。

### 1.3 home姿勢の実測(`robot/measure_home.py`)

`kxreus` の `reset-pose`(全関節0)が実機の想定ニュートラル姿勢であることを
利用し、**まず全関節0で物理シミュレーションを実行して沈み込ませ**、傾き・
残留速度が閾値内に収まる姿勢をhomeとして採用する。0姿勢では立てない
(`kxrl4t`の股yaw+roll onlyの脚、`kxrl6`の足首無し脚)場合のみ、股pitch/膝/
足首pitchの小さな屈伸グリッドサーチにフォールバックする。得られたhomeは
左右対称化してJSONに保存(`robot/mjcf/<name>/home.json`)。

**実測結果**(このリポジトリで再現したもの):

| ロボット | home base高さ | 傾き | 備考 |
|---|---:|---:|---|
| `kxrl4d` | 0.144 m | 0.01° | 0姿勢がそのまま安定 |
| `kxrl2g` | 0.175 m | 0.41° | 0姿勢がそのまま安定 |
| `kxrl6` | 0.058 m | 11.0° | 屈伸探索で0.026->0.058mに改善、やや前傾 |
| `kxrl4t` | 0.026 m | 4.1° | 股yaw+rollのみで前後に脚を振れず、構造上これ以上高くならない |

`kxrl4t` の低さは**バグではなく機構上の事実**: 股関節が yaw と roll しか
無く、膝も足首も無いため、脚を鉛直に伸ばす自由度が存在しない。

### 1.4 タスク定義(`kxr_rl/env_cfgs.py`)

ハンドのタスクは指クロールという特殊形態のため報酬をほぼ全て自作したが、
KXRの2足ロボットは**mjlabの標準velocityタスクがそのまま前提とする形態**
そのものなので、上流 `unitree_rl_mjlab` の標準レシピ(`track_lin/ang_vel`・
`body_orientation_l2`・`variable_posture`・`feet_gait`・`feet_clearance`・
`feet_slip`・`soft_landing`・`joint_pos_limits` 等)を**パースした構造で
パラメータ化するだけ**で歩行タスクが組める。自作した報酬は
起き上がり保持(`getup_hold`、walking-hand-rlから移植)の1つだけ。

- **Walk**: 2本足の逆位相ゲイト(`offset=[0, 0.5]`)。姿勢regularizationの
  std は脚DOFの役割(hip_pitch/hip_roll/knee/ankle_pitch/ankle_roll)ごとに
  自動で緩急を付け、腕・頭などは一律ゆるめ。目標歩行速度・遊脚高さは
  各ロボットの実測home高さに対する比率で決める(絶対値をハードコードしない
  ことで、2.6cmのkxrl4tから17.5cmのkxrl2gまで同じコードで扱える)。
- **Getup**: 平ら(base高を home の一部までランダムに落とす)+ 任意の
  roll/pitch/yawで倒れた姿勢からの起立。歩行系の報酬は全てweight=0にして
  `getup_hold`(目標高さの片側クランプ×静止ゲート、ハンドと同じ
  跳躍exploit対策)を主報酬にする。

---

## 2. 新しいKXRロボットを追加する

```bash
# 1. kxr_rl/robots.py の DEFAULT_ROBOTS に名前を追加
# 2. MJCF変換
uv run robot/build_mjcf.py <name>
# 3. home姿勢の実測
uv run robot/measure_home.py <name>
# 4. 安定性チェック
uv run check.py <name>
# 5. 学習(タスクは import 時に自動登録される)
uv run train.py <name> walk
uv run train.py <name> getup
```

新規コードは不要 -- `kxr_rl.robots.load_robot_spec()` が脚のDOF構成を自動で
読み、`kxr_rl.env_cfgs.kxr_env_cfg()` がそれに合わせて報酬・観測・アクチュ
エータを組み立てる。脚が生えていて、URDFがKXRの命名規則(またはyaml)に
従っている限り、機種を問わない。

---

## 3. 学習・実行

```bash
uv run train.py kxrl4d walk                 # 既定 700 iter(train_all.shの設定)/ 4096 env
uv run train.py kxrl4d getup --iterations 2000

uv run play.py kxrl4d walk                  # 学習済み方策をmp4に
uv run play.py kxrl4d getup
uv run play.py kxrl4d standwalk             # 起き上がり->歩行を1本の連続軌道で

uv run tools/train_all.sh                   # 4体 x (Walk, Getup) を順番に学習
uv run tools/montage.py --out docs/media/montage.mp4 out/*_standwalk_fixed.mp4
```

チェックポイントは `logs/rsl_rl/<robot>_<mode>/<日時>_<run名>/`。
GPUを共有する場合は逐次実行(`train_all.sh`はそうしている)が安全。

---

## 4. リポジトリ構成

```
walking-kxr-rl/
├─ train.py / play.py / check.py     エントリポイント(uv run <これ>)
├─ kxr_rl/
│   ├─ robots.py       URDF/yamlパース(脚DOF・足リンク・胴体リンクの自動検出)
│   ├─ robot_cfg.py    MJCF読込・接触・アクチュエータ・home keyframe(全ロボット共通ロジック)
│   ├─ env_cfgs.py     Walk/Getupタスク定義(上流velocityレシピのパラメータ化)
│   ├─ rewards.py      getup_hold(walking-hand-rlから移植した唯一の自作報酬)
│   ├─ tasks.py         <Robot>-Walk / <Robot>-Getup を全ロボット分登録
│   ├─ rl_cfg.py / runner: PPOハイパーパラメータ
│   └─ _bootstrap.py   上流 unitree_rl_mjlab を固定shaで取得
├─ robot/
│   ├─ build_mjcf.py   URDF -> MJCF(scikit-robot urdf_to_mjcf、回転ハック無し)
│   ├─ measure_home.py home姿勢の実測(0姿勢優先、必要な脚のみ屈伸探索)
│   └─ mjcf/<name>/    生成されたMJCF + home.json
├─ tools/
│   ├─ render_robot.py    単一方策(walk/getup)のmp4描画
│   ├─ standwalk_eval.py  root高さのヒステリシスで2方策切替、連続軌道で描画
│   ├─ montage.py         複数ロボットのクリップを1本のグリッド動画に合成
│   └─ train_all.sh       4体 x (Walk, Getup) の一括学習
├─ policies/           学習済み方策(.pt)
└─ docs/media/         動画・GIF
```

### 上流との関係

walking-hand-rlと同じ方針: 上流 [`unitreerobotics/unitree_rl_mjlab`]
(固定コミット `1425b15`)には一切パッチを当てず、`kxr_rl` を自前のタスク
パッケージとして上に載せる。`import kxr_rl` が初回に一度だけ upstream を
`.upstream/` に取得する。既にcheckoutがあるなら `UNITREE_RL_MJLAB=<path>`
で何もダウンロードしない。

---

## 5. 既知の制約

- **`kxrl4t` は前後に脚を振れない**(股yaw+rollのみ、膝・足首なし)。
  「歩行」は通常の踏み出し歩容ではなく、体重移動主体の揺動的な前進になる
  見込み。これは学習の失敗ではなく機体側の自由度不足。
- **各ロボットの学習量は同一の反復回数で揃えていない**わけではないが、
  `walking-hand-rl` ほどの反復スイープ・報酬チューニングは行っていない —
  このリポジトリの主眼は「1つの枠組みで多種のKXR機体を扱えること」の実証で
  あり、個々のロボットの歩容品質を極めることではない。
- **sim-to-sim / 実機検証は未実施**。mjlab(MuJoCo)上でのみ確認している。
- **自己衝突は無効**(MJCF変換時、ハンドと同じ選択)。腕や頭が脚や胴体に
  接触判定を持たないため、視覚的にメッシュが重なることがあり得る。

---

## 出典・上流

- KXRロボット資産・関節構成: [`kxreus`](https://github.com/) (Euslispモジュール
  ロボットツールキット。URDF/yamlの生成元)
- 学習コードの上流: [`unitreerobotics/unitree_rl_mjlab`](https://github.com/unitreerobotics/unitree_rl_mjlab)(固定 `1425b15`)
- 同じ学習基盤を使う先行リポジトリ: [`walking-hand-rl`](https://github.com/iory/walking-hand-rl)(5本指ハンドが起き上がって歩く)
