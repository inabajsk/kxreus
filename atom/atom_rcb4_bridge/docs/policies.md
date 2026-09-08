# 複数ポリシーをAtomS3に載せる — 手順と、間違えた箇所

AtomS3の中で6つの学習済みポリシーを切り替えて走らせるための作業メモ。
README の「POLICY モード」が1ポリシー時代の記述なので、複数ポリシーと遷移に
ついてはこちらを見る。

**このファイルの目的は手順の記録ではなく、実際に間違えた箇所の記録である。**
手順だけなら30行で済む。残りは全部、一度やって間違えたことの理由。

---

## 1. いま載っている6つ

`lib/policy_mode/policy_mode.h:96` の `enum Actor`。

| # | 名前 | 出どころ | VX_MIN | VX_MAX | WZ_MAX | 用途 |
|---|------|----------|--------|--------|--------|------|
| 0 | `crawl` | 以前の歩行ハンド (`walking_hand_mjlab`) | -0.03 | 0.14 | 0.25 | **歩行はこれ** |
| 1 | `omni`  | `wheeledhand_deploy` | -0.156 | 0.156 | 0.6 | 車輪(全方向) |
| 2 | `walk`  | `wheeledhand_deploy` | 0.078 | 0.156 | 0.0 | 未使用 |
| 3 | `legs`  | `wheeledhand_deploy` legs_walk | 0.125 | 0.25 | 0.0 | 遷移の中間姿勢のみ |
| 4 | `rise`  | `wheeledhand_deploy` | 0 | 0 | 0 | 立ち上がり(遷移専用) |
| 5 | `sit`   | `wheeledhand_deploy` | 0 | 0 | 0 | 座り(遷移専用) |

指令範囲は `lib/policy/policy_spec_<名前>.h` の `COMMAND_VX_MIN` 等が出典。

### 間違えた: 歩行に `legs` を割り当てた

`rise` の着地先を `legs` にしていた。表を見れば分かるとおり **`legs` は
WZ_MAX = 0 で曲がれず、VX_MIN = 0.125 で止まれない**。`a`/`d` が効かず、`s` で
減速しても進み続ける。

歩行は `crawl` を使う。**ロボットは以前の歩行ハンドと同じ個体**で、実際に歩いた
実績があるのは `crawl` だけ。`wheeledhand_deploy` の walk 系は実機で歩いていない。

`walk` は載せてあるが使っていない。`legs` は遷移の中間姿勢としてしか使わない。

---

## 2. ホーム姿勢が全部同じではない ← 最重要

各ポリシーの `kPolicyHomeRad*` の最大関節差 [deg]:

```
        crawl   omni   walk   legs   rise    sit
crawl     0.0   81.4   81.4   81.9   81.4   81.4
omni     81.4    0.0    0.0   92.2    0.0    0.0
walk     81.4    0.0    0.0   92.2    0.0    0.0
legs     81.9   92.2   92.2    0.0   92.2   92.2
rise     81.4    0.0    0.0   92.2    0.0    0.0
sit      81.4    0.0    0.0   92.2    0.0    0.0
```

- **`omni` / `walk` / `rise` / `sit` の4つは完全に同一のホーム姿勢**
- **`crawl` だけ 81° 離れている**(別プロジェクトなので当然)
- **`legs` だけ 92° 離れている**

再測定するには:

```bash
uv run --no-project --with numpy python - <<'PY'
import re, io, math
def home(n):
    s = io.open("lib/policy/policy_spec_%s.h" % n).read()
    m = re.search(r"HomeRad\w*\[[^\]]*\]\s*=\s*\{(.*?)\}", s, re.S)
    return [float(x) for x in re.findall(r"-?\d+\.\d+(?:e[-+]?\d+)?f?",
                                         m.group(1).replace("f,", ","))]
ns = ["crawl","omni","walk","legs","rise","sit"]
h = {n: home(n) for n in ns}
for a in ns:
    print("%-6s" % a, " ".join("%6.1f" %
        (max(abs(x-y) for x,y in zip(h[a],h[b])) * 180/math.pi) for b in ns))
print("      ", " ".join("%6s" % n for n in ns))
PY
```

### 間違えた: `beginActor()` が手を動かすと思っていた

`lib/policy_mode/policy_mode.cpp` の `beginActor()` は

- 重みを差し替え (`policy::select`)
- 歩行位相カウンタを 0 に戻す
- 行動履歴を消す

これだけで、**サーボには1バイトも書かない。** 手は動かない。

なので着地先を `legs`(そこにいる) から `crawl`(81°離れている) に変えるときは、
**方策名を書き換えるだけでは足りない。** ランプを1段足さないと、crawl は自分の
ホームから81°ずれた姿勢 — 学習中に一度も見ていない状態 — から走り出す。

**規則: 遷移でポリシーを切り替えるときは、上の表で移動先との差を見る。
0°でなければ `{Step::Kind::RAMP, 移動先, 秒}` を先に入れる。**

`beginRamp()` は所要時間を `span / RAMP_MAX_RATE` (1.2 rad/s) まで自動で
延ばすので、指定秒数は下限であって上限ではない。81° = 1.42 rad なら最低1.19秒
かかる。短く書いても壊れないが、実時間を書いたほうが読んで分かる。

---

## 3. 遷移シーケンス

`lib/policy_mode/policy_mode.cpp` の `kRiseSequence` / `kSitSequence`。

**rise (`g`)** 約5.5秒:

| 段 | 種別 | 対象 | 秒 | 意味 |
|----|------|------|-----|------|
| 1 | RAMP | `omni` | 0.5 | rise が期待する開始姿勢へ |
| 2 | RUN  | `rise` | 3.0 | 立ち上がる |
| 3 | RAMP | `crawl` | 2.0 | 歩行方策の姿勢へ (81°) |

着地 = `crawl`。

**sit (`h`)** 約4秒:

| 段 | 種別 | 対象 | 秒 | 意味 |
|----|------|------|-----|------|
| 1 | RAMP | `legs` | 1.0 | sit が期待する開始姿勢へ (実測1.2秒) |
| 2 | RUN  | `sit`  | 2.0 | 座る |
| 3 | RAMP | `omni` | 0.5 | 車輪方策の姿勢へ |

着地 = `omni`。

配列長は `policy_mode.h:173` の `kRiseSequence[3]` / `kSitSequence[3]` にも
書いてある。**段を増やしたらヘッダ側も直す**(片方だけ直すとリンクは通って
実行時に配列の外を読む)。

**確認方法:** テレメトリの `actor` が `omni → rise → crawl` と変われば正常。
`omni → rise → legs` なら着地先が古い。

---

## 4. IMU の既定値は3箇所にある ← 揃っていないと意味がない

コマンドフレーム `buf[1]` の **bit 7 = 1 で「IMUを使わない」**(ポリシー自身の
静止時重力定数を使う)。`policy_mode.cpp:298` の
`use_imu_ = (buf[1] & 0x80) == 0`。

| 場所 | 変数 | あるべき値 |
|------|------|-----------|
| デバイス | `lib/policy_mode/policy_mode.h:338` `use_imu_` | `false` |
| ウェブページ | `lib/web/web_page.h:73` `useImu` | `false` |
| ターミナル | `tools/policy_teleop.py` `use_imu` と `host_frame()` の既定引数 | `False` |

### 間違えた: デバイス側だけ直して「既定は固定値」と言った

デバイスとウェブは `false` だったが `policy_teleop.py` が `use_imu = True` の
ままだった。ホストは 10 Hz でフレームを送り続けるので、**最初の1フレームで
デバイス側の既定は上書きされる。** つまり「既定は固定値」が成立していたのは
USBを挿さずウェブから触ったときだけで、`policy_teleop.py` を使うと常にIMUが
入っていた。

**デバイス側の既定は、ホストが黙っている間しか効かない。ホストが喋り始めた
瞬間に意味を失う。** 既定値を変えたら3箇所すべてを直す。

現状 IMU を切ってあるのは、IMU が壊れているからではなく:

- 実際に走った試行はどれもIMU無しだった
- 取り付け回転になお約10°の残差があり、「基板が傾いている」のか「手が水平で
  ない」のかを分離できていない(180°回転テストで分離できるが未実施)

分離できたら既定を戻す価値はある。

**確認方法:** テレメトリのポリシー名の後ろの `*` が固定値を意味する
(`actor` の bit 7)。`*` があれば固定値。

---

## 5. 遷移要求は「押した瞬間」ではなく「保留」で扱う

ホストは同じフレームを 10 Hz で送り続けるので、`rise`/`sit` を毎フレーム発火
させるわけにはいかない。「要求が変化したとき」に発火させる。

### 間違えた その1: 受け付けなかった要求を「見た」ことにした

```cpp
// 壊れていた版
const bool request_changed = request != last_acted_request_;
last_acted_request_ = request;              // 受け付けなくても記録
case Request::SIT:
    if (request_changed && (state_ == RUNNING || state_ == HOLDING)) ...
```

`hold` は `IDLE → HOMING → HOLDING` と進む。**HOMING 中に `h` を押すと:**

1. `state_` が `HOMING` なので発火しない
2. なのに `last_acted_request_ = SIT` と記録済み
3. `HOLDING` に着いた頃には要求は変化していないので、もう二度と発火しない

一度も発火せず、押し直しても(値が変わらないので)発火しない。

### 間違えた その2: マスク後の値を記録した

シーケンス実行中は `free` 以外を `0xFF` に潰している。その `0xFF` を
`last_acted_request_` に入れていたので、シーケンスが終わった瞬間に
`0xFF → RISE` が「新しい押下」に見え、**押しっぱなしの `rise` が永久に
再起動した。**

### 間違えた その3: `run` で保留を取り消した

ウェブページは rise/sit を **400 ms 送って `run` に戻す**
(`web_page.h:146`、ボタンを離す動作に相当)。「他の要求が来たら保留を取り消す」
にしていたので、**homing 中にスマホから押した保留が 400 ms で消えた。**
その1と同じ症状が無線側だけ残っていた。

### いまの形

- **生の**要求(マスク前)の変化だけを押下とみなす
- `rise`/`sit` は `pending_transition_` に**積む**
- `RUNNING` か `HOLDING` になった時点で自動的に走り出す
- 発火時に `pending_transition_` を消す(繰り返さない)
- **取り消すのは `free` だけ。** `run`/`hold` は取り消さない — どちらも遷移の
  出発点になる状態そのもので、取り消す理由がない
- `IDLE` から `g`/`h` を押した場合は `hold` と同じく先にホームへ行く
  (以前はサーボfreeで遷移元の姿勢が無く、完全に無反応だった)

---

## 6. ポリシーを1つ足す/差し替える手順

```bash
R=~/src/github.com/iory/rl-benchmark/walking_hand_mjlab/real_robot
uv run --no-project --with onnx --with onnxruntime --with pyyaml --with numpy \
  python tools/export_policy.py \
    --onnx $R/policies/omni.onnx --spec $R/deploy_spec.json \
    --calib $R/calibration.yaml --control-hz 30 \
    --name omni --outdir lib/policy
```

`--name` を付けると `policy_spec_omni.h` / `policy_weights_omni.h` が出る
(付けないと1ポリシー配置の名前になる)。書き出し前に onnxruntime と突き合わせ、
合わなければヘッダを書かない。

その後、手で直す必要があるもの:

1. `lib/policy/policy.cpp` の `#include` と `kActors[]` に1件足す
2. `lib/policy_mode/policy_mode.h:96` の `enum Actor` に足す
3. `platformio.ini:38` の `POLICY_RAM_WEIGHT_BYTES`(現在 202240)を確認 —
   **新しいポリシーの最大2層がこれより大きいと実行時に足りない**
4. `tools/policy_teleop.py` と `lib/web/web_page.h:174` の `ACTORS` 表示名

### `--command-range` に注意

spec に `command_ranges_trained` が無い古い書き出しでは、指定しないと
ファームは ±1 にクランプする。これは制限として機能しない。

**間違えた:** `hand_deploy.py` の teleop 上限を読み違えて
`--command-range -0.3 0.5 1.0` で書き出した。正しくは
`VX_MIN, VX_MAX = -0.03, 0.14`、`WZ_MAX = 0.25`。10倍近く違う。
**ソースを開いて定数を目で見てから書く。**

### RAM は増えない、Flash は増える

重みは全部 flash(`.rodata`)にあり、選択中の1つの最大2層だけを SRAM の固定
バッファにコピーする。**ポリシーを足しても RAM は増えない。**
現在 Flash 72.0% / RAM 78.3%。

---

## 7. 動作確認

```bash
# USB
uv run python tools/policy_teleop.py /dev/ttyACM0

# 無線(mDNS)
uv run python tools/policy_teleop.py

# 無線(アドレス直指定)
uv run python tools/policy_teleop.py 192.168.1.23

# ブラウザ / スマホ
http://kxr-hand.local
```

mDNS は `/etc/nsswitch.conf` の hosts 行に `mdns4_minimal` があれば
`socket.gethostbyname` だけで引ける(`avahi-resolve` コマンドは不要)。

無線の生存確認だけなら UDP 9000 に FREE フレームを投げて34バイトの返りを見る。

**テレメトリで見るところ:**

| 欄 | 意味 |
|----|------|
| `rx` | デバイスが受理したフレーム数。**増えていなければ何も届いていない**(POLICYモードに入っていない可能性) |
| `state` | `idle / run / hold / fault / homing / seq` |
| `actor` | 現在のポリシー名。後ろの `*` = 姿勢は固定値(IMU不使用) |
| `home` | homing 完了時にラッチした最大関節誤差。**手が実際にそこへ着いたか**を言う唯一の値 |

### 覚えておくこと

- **`free` (space) は遷移中でも必ず効く。** 他は効かない
- サーボを `0x8000` で free にすると、位置指令だけでは再係合しない。
  先に `0x7FFF`(hold)を送る。これを知らずに「210ステップ動かない」を追った
- homing は1回の補間では届かない(725 mrad 残った)。最大4回リトライして16 mrad
