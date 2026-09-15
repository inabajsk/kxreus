# kxr/ — KXRモジュールロボット群の「立ち上がり・歩行」を1つのレシピで学習する

`walking-hand-rl` 本体(5本指ハンドが指だけで起き上がって歩く)と同じ
mjlab(MuJoCo-Warp)+ rsl_rl PPO の学習基盤を、**KXR(近藤科学)のモジュール型
脚ロボット**に一般化したサブプロジェクト。KXRは同じサーボモジュール
(股・膝・足首・肩・肘・手首・首・グリッパ)を組み替えて多種多様な機体を
作れるのが特徴で、このディレクトリはその「型」を活かし、**ロボットごとに
コードを書き直さず**、URDFと `kxreus` の関節構成定義(yaml)から自動的に
立ち上がり(Getup)・歩行(Walk)タスクを組み立てる。

上位の `walking-hand-rl` とはパッケージ名(`kxr_rl` vs `walking_hand_rl`)も
`uv` プロジェクトも別で、`kxr/` の中で独立して動く(`pyproject.toml` /
`uv.lock` を自前で持つ)。ロボット資産(URDF・メッシュ)は
`robot/kxreus/` に同梱済みで、外部リポジトリへの依存は無い。

対応ロボット(`robot/kxreus/urdfs/` 内、`kxr_rl.robots.DEFAULT_ROBOTS`):

| ロボット | 脚のDOF構成 | 特徴 |
|---|---|---|
| `kxrl4d` | 股(pitch+roll)+膝+足首(pitch) = 4DOF | 標準的な2足歩行脚。腕2本+頭 |
| `kxrl4t` | 股(yaw+roll)のみ = 2DOF、膝・足首なし | 腕2本も同一構造で、**4本のリム全部で立って歩く** |
| `kxrl2g` | 股(roll+pitch)+膝+足首(pitch+roll) = 5DOF | 最もDOFが多い脚。腕にグリッパ付き |
| `kxrl6` | 股(yaw+pitch)+膝 = 3DOF、足首なし | 脚2本+腕4本(通常腕2+中間腕2) |

新しいKXRロボットを追加するのに新規コードは要らない: `kxr_rl/robots.py` の
`DEFAULT_ROBOTS` に名前を足し、`build_mjcf.py` / `measure_home.py` を回すだけで
学習タスクが生える(下記§2)。これが「モジュール型だから多種類作れる」という
KXRの強みをそのままRL学習基盤の強みに変換している部分。

---

## TL;DR

```bash
cd kxr
uv run check.py                          # 4体のhomeを検証: 静定・胴体浮上・自己貫入なし(数秒)
uv run play.py kxrl4d standwalk          # 学習済み方策で倒れる->起き上がる->歩く動画
uv run train.py kxrl4d walk              # 一から学習し直す場合
```

セットアップコマンドは無い。最初の `uv run` が `kxr/uv.lock` どおりに
(`walking-hand-rl` 本体とは別の)venv を作り、最初の `import kxr_rl` が上流
unitree_rl_mjlab を固定コミットで `kxr/.upstream/` に取得する。事前に要るのは
**git・NVIDIA ドライバ(CUDA 12系)・uv** だけ。

> **学習状況**: 4体とも Walk 学習済み(1500 iter、`policies/<robot>_walk.pt`)。
> `kxrl4d` は Getup(2000 iter)も。`tools/gait_diag.py` でシードを変えて6回ずつ
> 実測した前進速度(world座標、10秒の正味移動):
>
> | ロボット | 速度(6シード平均) | 範囲 | stance slip | 指令上限 |
> |---|---:|---:|---:|---:|
> | `kxrl6` | **0.293 m/s**(六脚) | 0.284〜0.305 | 0.15〜0.18 | 0.35 |
> | `kxrl2g` | **0.301 m/s** | 0.291〜0.314 | 0.04〜0.06 | 0.319 |
> | `kxrl4d` | **0.268 m/s** | 0.257〜0.273 | 0.08〜0.13 | 0.289 |
> | `kxrl4t` | **0.133 m/s** | 0.073〜0.158 | 0.24〜0.84 | 0.190 |
>
>
> | ![kxrl2g](docs/media/kxrl2g_walk.gif) | ![kxrl6](docs/media/kxrl6_walk.gif) |
> |:--:|:--:|
> | `kxrl2g` 0.30 m/s(2足) | `kxrl6` 0.29 m/s(六脚トライポッド) |
> | ![kxrl4d](docs/media/kxrl4d_walk.gif) | ![kxrl4t](docs/media/kxrl4t_walk.gif) |
> | `kxrl4d` 0.27 m/s(手首+足首の4点) | `kxrl4t` 0.13 m/s(4リムトロット) |
>
> 全部 world 固定カメラ、10秒。`kxrl6` の上面図は `docs/media/kxrl6_walk_top.gif`、
> `kxrl4d` の倒れた状態からの起き上がり→歩行は `docs/media/kxrl4d_standwalk.gif`。
>
> どれも Getup は `kxrl4d` 以外未学習 -- `uv run train.py <robot> getup` で
> 同じ手順で学習できる(学習済みポリシーは後続コミットで追加予定)。

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
残留速度が閾値内に収まる姿勢をhomeとして採用する。0姿勢で立てない場合は
候補を増やして同じ物理沈み込みにかける — クラウチのグリッド(まず脚だけ、次に
頭以外の全リム)と、**逆運動学で解いた立位**(胴体水平・全リム先端が z=0・
左右対称・**支持点の重心が COM の真下**)を複数のクリアランスで。最後の重心条件が
無いと、脚を後ろに掃き腕を胴体真下に畳んだ「4点とも同じ高さだが COM が支持多角形の
前に出た」姿勢が解になり、物理を回した瞬間に前へ倒れて腕2本で立つ。

候補の優劣は、順に: **リンク同士がめり込んでいない**(自己衝突は無効なので物理は
腕が胴体を貫通した姿勢も平然と保持する — `mj_geomDistance` で明示的に測る。
URDF 由来でゼロ姿勢から重なっているグリッパの2枚爪などは除外)、**荷重が全部
リム先端に乗っている**(肘や脛で支えていない)、**胴体が床から浮いている**、
静定している、そして最後に高さ。水平で静止していても腹ばいなら立位ではなく、
そこから先の歩行報酬は全て無意味になる。**どのリムで立っているか**(先端が荷重を
持つリム)は `support_limbs` として記録し、gait報酬はそれを「足」として扱う。
左右のroll/yaw関節は**符号を反転してミラー**する(同符号を入れると片方が下がり
もう片方が上がるので、対称な立位が探索候補に一度も現れない)。

さらに、支持リムの各関節が**自分の接地点をどれだけ前後に運べるか/持ち上げられるか**
(`gait_joints`)と、**接地点がリンク座標のどこにあるか**(`foot_offsets`)も測る。
接地点はリンク原点ではない — `kxrl4t` ではリンク原点が roll 関節そのもので、
roll をいくら回しても高さが変わらない。§1.5 の速度スケールと姿勢regularizationは
これらの実測値から決まる。

**実測結果**(このリポジトリで再現したもの):

| ロボット | home base高さ | 傾き | 支持リム | 先端荷重 | 備考 |
|---|---:|---:|---|---:|---|
| `kxrl2g` | 0.175 m | 0.41° | 脚2本 | 100% | 0姿勢がそのまま安定。唯一の真の2足機 |
| `kxrl4d` | 0.150 m | 0.01° | **4本全部** | 100% | 手首と足首の4点。腕が体重の約半分を持つ |
| `kxrl6` | 0.086 m | 0.15° | **6本全部** | 100% | 逆運動学で解いた六脚立位。旧探索では 0.057 m・11°前傾・先端荷重44%(肘で支持) |
| `kxrl4t` | 0.038 m | 0.02° | **4本全部** | 100% | 腕2本も同一の2-DOFリム。roll -1.2 rad で先端4点支持、保持トルク1.8% |

`kxrl6` の旧 home が象徴的だった: 傾き 11°、腕の先端は荷重ゼロ、体重の56%が
腕の**肘**を通り、脚は後ろで屈んでいる — 手押し車の姿勢。4リムとも胴体から
0.151 m 下まで届くので機構上の必然ではなく、探索がその姿勢を出せなかっただけ。
解いた最初の立位はさらに腕を腕に 14.8 mm めり込ませていた(自己衝突無効なので
物理は止めない)。今の home はどちらも満たす。

### 1.4 タスク定義(`kxr_rl/env_cfgs.py`)

ハンドのタスクは指クロールという特殊形態のため報酬をほぼ全て自作したが、
KXRの2足ロボットは**mjlabの標準velocityタスクがそのまま前提とする形態**
そのものなので、上流 `unitree_rl_mjlab` の標準レシピ(`track_lin/ang_vel`・
`body_orientation_l2`・`variable_posture`・`feet_gait`・`feet_clearance`・
`feet_slip`・`soft_landing`・`joint_pos_limits` 等)を**パースした構造で
パラメータ化するだけ**で歩行タスクが組める。自作した報酬は
起き上がり保持(`getup_hold`、walking-hand-rlから移植)の1つだけ。

- **Walk**: ゲイトの位相は支持リムの取り付け位置から自動で決まる — 支持リムが
  2本なら逆位相(`offset=[0, 0.5]`)、4本なら対角同相のトロット。姿勢
  regularizationの std は支持DOFの役割ごとに緩急を付けるが、**その関節が
  ストライドを生む関節なら実測した振り幅まで広げる**(§1.5)。遊脚高さは
  各ロボットの実測home高さに対する比率(絶対値はハードコードしない)。
- **Getup**: 平ら(base高を home の一部までランダムに落とす)+ 任意の
  roll/pitch/yawで倒れた姿勢からの起立。歩行系の報酬は全てweight=0にして
  `getup_hold`(目標高さの片側クランプ×静止ゲート、ハンドと同じ
  跳躍exploit対策)を主報酬にする。

### 1.5 速度スケールを機体から決める(`kxr_rl/env_cfgs.py::_SpeedScale`)

上流の速度まわりの定数は **1 m/s のヒューマノイド**を前提にしている。指令だけ
小さくして定数を据え置くと、13 cm のロボットでは解けないタスクになる:

- **追従カーネル**。`exp(-‖cmd-v‖²/std²)` に std=0.5 と 0.1 m/s の指令を入れると、
  **完全に静止したロボットが満点の 0.99** を取る。動く価値は報酬 0.01 相当で、
  動いたときの action_rate 罰の方が大きい。
- **ゲート**。`foot_clearance` / `foot_slip` / `soft_landing` の `command_threshold`
  は 0.1 で、kxrl4t の全速 0.19 m/s でも**一度もONにならない**。逆に home姿勢からの
  逸脱を罰する `stand_still` は**一度もOFFにならない**。
- **姿勢regularization**。これが決定打だった。hip_yaw の std=0.2 は「hip yaw は
  バランス用DOF」というヒューマノイド前提の値だが、kxrl4t では hip_yaw が
  **唯一の推進DOF**で、歩ける歩容は 0.9 rad 振る。`exp(-(0.9/0.2)²)=exp(-20)` —
  姿勢項(weight 1.0)が歩いた瞬間に全損し、追従で得られるのは最大 0.53。
  **歩かない方が得**という状態になる。

そこで `measure_home.py` の実測値からスケールを導く: 1本の支持リムが接地点を
運べる距離(`stride_span_m`)を立脚(=半周期)で割って上限速度、指令帯はその
半分〜上限で**0を含まない前進のみ**、追従の std は上限の半分(legged_gym と同じ
比率 — 全速指令下の静止が `exp(-4)`)、全ゲートは指令帯の下、そして**ストライドを
生む関節の姿勢 std は必要な振り幅まで広げる**。

`stride_span_m` を持たない home.json(この節より前に計測されたもの)は
従来の固定値のまま動くので、既存ロボットの挙動は変わらない。

導出値は `tools/openloop_gait.py` で検証してある(下記)。**ただし導出式には
既知の限界がある**: 脚が横に寝る立位(kxrl6 の6点接地、体高 8.6 cm で脚長 15 cm)
では、1関節の yaw 掃引が接地点を 0.35 m 動かすため上限 0.81 m/s と出るが、
開ループのトライポッド(六脚は静的に安定なので妥当な参照)は 0.11 m/s しか出ない。
この帯で学習させると立ちすくみ(0.0035 m/s)になった。式は kxrl4t で較正したもので、
寝た脚の横方向の弧を「体を運べる距離」として過大評価する(六脚では隣のリムに当たる
ので実際にはその振幅で振れない)。そのため上限を明示的に指定できるようにし、kxrl6 は
`robot/mjcf/kxrl6/task.json` で 0.35 m/s(ストライドを脚長で頭打ち)に固定している。
home.json は計測値、task.json は「導出が外れた箇所の手当てと理由」で、混ぜない。
実験用には `$KXR_VMAX` が task.json より優先する。同様に `$KXR_GAIT_WEIGHT` でゲイトクロックの重みを上書きできる:
クロック報酬は支持リムの**平均**一致率なので、6本に分けると1本あたりの取り分は
0.08 になり、1本を一度も着かずに5本で歩く方策に何のコストも無かった。

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
uv run train.py kxrl4d walk                 # 既定 1500 iter / 4096 env(同梱の方策はこの設定)
uv run train.py kxrl4d getup                # 既定 2000 iter

uv run play.py kxrl4d walk                  # 学習済み方策をmp4に
uv run play.py kxrl4d getup
uv run play.py kxrl4d standwalk             # 起き上がり->歩行を1本の連続軌道で

uv run tools/train_all.sh                   # 4体 x (Walk, Getup) を順番に学習
uv run tools/montage.py --out docs/media/montage.mp4 out/*_standwalk_fixed.mp4
```

チェックポイントは `logs/rsl_rl/<robot>_<mode>/<日時>_<run名>/`。
GPUを共有する場合は逐次実行(`train_all.sh`はそうしている)が安全。

### 学習ログを信じないための2つのツール

平均報酬もエピソード長も、**その場で足踏みしている方策で上がる**。kxrl4t は
平均報酬63・エピソード長1000(転倒ゼロ)のまま 0.0013 m/s だった。歩いたかどうかは
別に測る:

```bash
uv run tools/gait_diag.py --robot kxrl4t --checkpoint policies/kxrl4t_walk.pt
uv run tools/openloop_gait.py --robot kxrl4t --render out/kxrl4t
```

- **`gait_diag.py`** — 方策を転がして、正味移動距離と経路長の比(1に近ければ直進、
  40なら振動しているだけ)、胴体座標系の前進速度、ヨードリフト、接地中の先端の
  滑り率(0で接地、1で滑走)、リムごとの接地率と接地パターンを出す。
  play時のリセットは地形・摩擦・重心をランダム化するので、ばらつきは
  **シードを変えてプロセスごと回して**測る(1プロセス内で reset しても
  再サンプルされず、全ロールアウトが完全同一値になる)。
- **`openloop_gait.py`** — 方策なしの手書きトロットをグリッド探索する。
  「方策が 0.001 m/s」だけでは、歩けない機体なのか報酬が悪いのか物理が悪いのかが
  区別できない。kxrl4t は開ループで 0.195 m/s 出たので、原因は報酬側だと確定した。
  §1.5 の速度上限の導出はこの実測に対して較正してある。

---

## 4. リポジトリ構成

```
kxr/                                    (walking-hand-rl のサブディレクトリ)
├─ train.py / play.py / check.py     エントリポイント(uv run <これ>)
├─ pyproject.toml / uv.lock          独立したuvプロジェクト(本体とは別venv)
├─ kxr_rl/
│   ├─ robots.py       URDF/yamlパース(支持リム・DOF役割・ゲイト位相の自動検出)
│   ├─ robot_cfg.py    MJCF読込・接触・アクチュエータ・home keyframe(全ロボット共通ロジック)
│   ├─ geometry.py     自己貫入の監査(measure_home.py と check.py が共用)
│   ├─ env_cfgs.py     Walk/Getupタスク定義(上流velocityレシピのパラメータ化)
│   ├─ rewards.py      getup_hold(walking-hand-rlから移植した唯一の自作報酬)
│   ├─ tasks.py         <Robot>-Walk / <Robot>-Getup を全ロボット分登録
│   ├─ rl_cfg.py / runner: PPOハイパーパラメータ
│   └─ _bootstrap.py   上流 unitree_rl_mjlab を固定shaで取得
├─ robot/
│   ├─ build_mjcf.py   URDF -> MJCF(scikit-robot urdf_to_mjcf、回転ハック無し)
│   ├─ measure_home.py home姿勢の実測(逆運動学の立位候補、立位/先端荷重/自己貫入の判定、支持リム・接地点・ストライド)
│   ├─ kxreus/          同梱したKXR資産(urdfs/<name> + yamls/<name>.yaml、4体ぶん ~12MB)
│   └─ mjcf/<name>/    生成されたMJCF + home.json(計測値)+ task.json(kxrl6 のみ: 導出を上書きする2値と理由)
├─ tools/
│   ├─ render_robot.py    単一方策(walk/getup)のmp4描画
│   ├─ standwalk_eval.py  root高さのヒステリシスで2方策切替、連続軌道で描画
│   ├─ gait_diag.py       歩いたかを実測(前進・直進性・滑り・接地パターン)
│   ├─ openloop_gait.py   方策なしの手書きトロット探索(機体の実力の上限)
│   ├─ montage.py         複数ロボットのクリップを1本のグリッド動画に合成
│   └─ train_all.sh       4体 x (Walk, Getup) の一括学習
└─ policies/           学習済み方策(.pt)。現時点では kxrl4d と kxrl4t (walk)
```

### 上流との関係

walking-hand-rlと同じ方針: 上流 [`unitreerobotics/unitree_rl_mjlab`]
(固定コミット `1425b15`)には一切パッチを当てず、`kxr_rl` を自前のタスク
パッケージとして上に載せる。`import kxr_rl` が初回に一度だけ upstream を
`.upstream/` に取得する。既にcheckoutがあるなら `UNITREE_RL_MJLAB=<path>`
で何もダウンロードしない。

---

## 5. 既知の制約

- **`kxrl6` は六脚として歩く。** kxreus の yaml は中間腕を腕の続きとして1リストに
  書くが、URDF では `lmarm-shoulder-y` の親は胴体 — 3DOF のリムが6本ある機体。
  `robots.py` は胴体に根を持つ関節でリムを分割し、`measure_home.py` は「脚と同じだけ
  下に届くリムは脚」として6本すべてに荷重を要求する(kxrl2g の腕は脚の半分しか
  届かないので巻き込まれない)。初期姿勢は逆運動学で解いたもので、0姿勢では胴体が
  床に着き、グリッド探索では肘を突いた前傾しか出なかった。
  姿勢と報酬が結果を決めた: 前傾の home では 0.084 m/s(足を引きずり、slip 最大 2.3)、
  4点立位では 0.317 m/s、六脚立位では上流のゲイトクロック重み(0.5)のままだと
  左前腕を一度も着かずに5本で 0.29 m/s、重み 1.5(`task.json`)で6本すべてが
  接地率 27〜54% のトライポッドを組んで 0.293 m/s。3.0 では均等さは増すが
  0.229 m/s・slip 0.25 に落ちる(リズム優先で蹴らなくなる)。
- **`kxrl4t` の歩容は2足歩行ではなく4リムのトロット**。股yaw が唯一の推進DOF、
  股roll が唯一の遊脚上げDOFで、対角のリム2本ずつが交互に接地する。
  6シード平均 0.133 m/s(指令 0.19 m/s の70%、開ループ参照 0.195 m/s の68%)、
  ヨードリフトは10秒で 4〜62° とばらつく。旋回を強く罰する方向(追従カーネルの
  角速度stdを線形と同率で締める)は**実測して棄却した** — ドリフトは 62°→17° に
  減ったが平均速度が 0.133→0.027 m/s に落ち、6シード中4つが停止した。この機体は
  歩行の副作用として旋回するため、旋回を task 報酬と同格で罰すると「動かないのが
  最善」に戻る。
- **各ロボットの学習量は同一の反復回数で揃えていない**わけではないが、
  `walking-hand-rl` ほどの反復スイープ・報酬チューニングは行っていない —
  このリポジトリの主眼は「1つの枠組みで多種のKXR機体を扱えること」の実証で
  あり、個々のロボットの歩容品質を極めることではない。
- **sim-to-sim / 実機検証は未実施**。mjlab(MuJoCo)上でのみ確認している。
- **自己衝突は無効**(MJCF変換時、ハンドと同じ選択)。腕や頭が脚や胴体に
  接触判定を持たないため、視覚的にメッシュが重なることがあり得る。

---

## 出典・上流

- KXRロボット資産・関節構成: `kxreus`(近藤科学KXRシリーズ向けのEuslispモジュール
  ロボットツールキット。URDF/yamlの生成元。`robot/kxreus/` に4体ぶんを同梱)
- 学習コードの上流: [`unitreerobotics/unitree_rl_mjlab`](https://github.com/unitreerobotics/unitree_rl_mjlab)(固定 `1425b15`)
- 学習基盤(mjlab + rsl_rl PPOの載せ方)は本体 `walking-hand-rl`(5本指ハンドが
  起き上がって歩く)と同じパターンを踏襲している
