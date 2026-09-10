# ATOM(AtomS3) を RCB4-mini 用 USB Dual Adapter の代わりにする

近藤科学 KXR の制御ボード RCB4-mini に、M5Stack ATOM(AtomS3系, ESP32-S3, USB-C)を
USBシリアル変換アダプタとして接続し、純正「USB Dual Adapter HS」の代わりに使うための
配線・ファームウェア・PC側サンプル・kxreus連携方法をまとめる。

実機(ATOM 2台、RCB4-mini 搭載ロボット)で動作確認済み。

**液晶付きAtomS3を使っていて、配線早見表・通信中インジケータ・RCB4コマンドの
LEN/CMD/checksum検証結果を液晶に表示したい場合は、`../atoms3_rcb4_adapter/`
(この`atom_rcb4_bridge`をベースにした液晶表示付き版、AtomS3専用)を使うこと。**
このフォルダの`atom_rcb4_bridge.ino`は液晶の無いプレーンなATOMでも動く
バイト中継専用の素の版のまま維持している。

## 対象ハードウェア

- ATOM: M5Stack AtomS3 / AtomS3 Lite 系(ESP32-S3、USB-C、ネイティブUSB-CDC)
  - Arduino board (arduino-cli): `m5stack:esp32:m5stack_atoms3`
  - USBデバイスとして `303a:1001`(Espressif USB JTAG/serial debug unit)で認識される
- RCB4-mini(近藤科学 KXR用制御ボード)
  - COMポート: ZHコネクタ、最大1.25Mbps、信号レベル 0V(LOW)/5V(HIGH) の**反転UART**
  - 出典: `HeartToHeart4ユーザーズマニュアル`(`HTH4_Ver6-20160712.pdf`)

## 配線

RCB4-mini の COM コネクタは、GND側から **GND - Rx - Tx** の順(マニュアル記載の図より)。
ATOM(AtomS3)の Grove ポート(Port A)は **G1 / G2**。

| RCB4-mini COM | 信号        | ATOM(AtomS3) |
|---------------|-------------|--------------|
| GND           | 共通GND     | GND          |
| Rx (GND隣)     | RCB4の受信  | **G2**       |
| Tx (一番奥)    | RCB4の送信  | **G1**       |

- **ATOMは G2 で送信、G1 で受信する**(ATOMのTXがRCB4のRxへ、ATOMのRXがRCB4のTxへ、という通常のクロス接続)。
- **電源線(5V)は接続しない。** RCB4-miniはバッテリ側で給電され、ATOMはUSB-Cから給電されるため、繋ぐのはGNDと信号線のみでよい。二重給電を避ける。
- **既知の注意点:** RCB4-mini の COM 信号は 0V/5V(5Vロジック)である一方、ATOM(ESP32-S3)のGPIOは3.3V系。今回は直結で動作が確認できたが、絶対最大定格を超える入力であり長期的にはGPIOを傷める可能性がある。恒久的な運用では、RCB4のTx→ATOMのG1間に抵抗分圧またはレベル変換IC(3.3V側)を入れることを推奨する。

## ファームウェア(ATOM側)

`atom_rcb4_bridge.ino`: USB-CDCとRCB4向けUART(反転)の間でバイト列をそのまま中継するだけの
ブリッジ。プロトコル解釈は一切行わず、コマンドやチェックサムの処理はPC側(kxreus)に任せる。

主要設定(実機確認済み):

```cpp
static const int RCB4_TX_PIN = 2;      // ATOM TX(G2) -> RCB4-mini Rx
static const int RCB4_RX_PIN = 1;      // ATOM RX(G1) <- RCB4-mini Tx
static const uint32_t RCB4_BAUD = 1250000;  // RCB4-mini既定の高速モード
RCB4Serial.begin(RCB4_BAUD, SERIAL_8E1, RCB4_RX_PIN, RCB4_TX_PIN, /*invert=*/true);
```

ロボット側が低速(:slow)設定の場合は `RCB4_BAUD` を `115200` に変更する。

### 書き込み方法(arduino-cli)

```bash
# 初回のみ: arduino-cliインストール & ボードパッケージ導入
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | BINDIR=~/.local/bin sh
export PATH="$HOME/.local/bin:$PATH"
arduino-cli config init --overwrite
arduino-cli config add board_manager.additional_urls https://static-cdn.m5stack.com/resource/arduino/package_m5stack_index.json
arduino-cli core update-index
arduino-cli core install m5stack:esp32

# 書き込み(ATOMをUSB接続した状態で)
arduino-cli compile --fqbn m5stack:esp32:m5stack_atoms3 ~/AtomS3/atom_rcb4_bridge/atom_rcb4_bridge.ino
arduino-cli upload -p /dev/ttyACM0 --fqbn m5stack:esp32:m5stack_atoms3 ~/AtomS3/atom_rcb4_bridge/atom_rcb4_bridge.ino
```

Arduino IDE(GUI)を使う場合は、`ファイル > 環境設定` の追加のボードマネージャURLに上記M5StackのURLを追加して
ボードマネージャから `M5Stack` を導入し、Board: `M5AtomS3`、USB CDC On Boot: `Enabled` を選んで書き込む。

## IMU予約OPCODE(0x90)

RCB4-miniにはIMUが無い。AtomS3にはあるので、他のkxreus ATOMファーム
(`s3_echo_bridge`, `s3_echo_with_I2C`, `s3_wifi_captiv`)と同じく、RCB4が使って
いないオペコード`0x90`をIMU読み出し用に予約し、AtomS3が横取りして自分のIMUを
返す。PC側からロボットの姿勢を得る唯一の経路になる。

```
リクエスト: [0x03, 0x90, 0x93]           checksum=(0x03+0x90)&0xFF
応答:      [0x0F, 0x90,
            ax,ay,az (各int16 LE, milli-g),
            gx,gy,gz (各int16 LE, 0.1deg/s), checksum]
```

中継のレイテンシを増やさないため、フレーム先頭の**2バイト(長さ+オペコード)
だけ**を保留して判定し、`0x90`でなければ即座に吐き出して残りは素通しする。
1フレームにつき2バイトしか保留しない。

IMUが初期化できていない場合は全ゼロで応答する(他ファームと同じ)。加速度が
零ベクトルになるので、重力方向を求める側で必ず失敗する。読む側は全ゼロを
エラーとして扱うこと。

Python側(pyserialだけで完結する。上の疎通確認スクリプトと同じ書き方):

```python
import struct
import serial

with serial.Serial("/dev/ttyACM0", 1250000, timeout=1.0) as port:
    port.write(bytes([0x03, 0x90, 0x93]))
    reply = port.read(15)

assert len(reply) == 15 and reply[1] == 0x90
assert sum(reply[:14]) & 0xFF == reply[14], "checksum"
ax, ay, az, gx, gy, gz = struct.unpack("<6h", reply[2:14])
accel = [v / 1000.0 * 9.80665 for v in (ax, ay, az)]   # milli-g -> m/s^2
gyro = [v / 10.0 * 3.141592653589793 / 180.0
        for v in (gx, gy, gz)]                         # 0.1deg/s -> rad/s
assert any(accel), "IMU returned all zeros"
```

**応答の値はフレームの先頭からではなく2バイト目から始まる。** 長さとオペコード
を読み飛ばさずにunpackすると、エラーにはならず、もっともらしい大きさの誤った
値が返る。

クォータニオンは返らない(ブリッジは生値を送るだけでフィルタを持たない)ので、
重力方向は加速度から求める。デプロイスクリプトなら
`imu_gravity_source: accel`。

## PC側動作確認スクリプト

`rcb4_bridge_test.py`(pyserial使用)。RCB4のバージョン問い合わせコマンド(`03 FD 00`)を送り、
RCB4形式のフレーム(先頭バイト=長さ, 以降 長さ-1 バイトが本体)を読み返して疎通を確認する。

```bash
python3 ~/AtomS3/atom_rcb4_bridge/rcb4_bridge_test.py /dev/ttyACM0
```

正常時の出力例(実機で確認済み。`CB-4 V1.0` はRCB-4のファームウェアバージョン文字列):

```
-> send: 03 fd 00
<- recv: 23 fd 43 42 2d 34 20 56 31 2e 30 20 20 20 20 20 20 30 39 30 37 31 35 20 20 20 20 20 20 20 20 20 20 c7 08
疎通確認 OK
```

## kxreus側の設定

`rcb4interface.l` / `uart.l` の編集は不要。`uart-interface`(`uart.l`)は元々 `:devname` 経由で
生tty接続する機能を持っており、`rcb4interface.l` の `:rcb4-open` → `:com-open` はキーワード引数を
そのまま `uart-interface` に転送する作りになっている。

FTDI版USB Dual Adapter(vid `#x165c`)を自動探索する `:com-init` の代わりに、明示的に `:devname` を
指定して `:rcb4-open` を呼んでから `:timer-on` する:

```lisp
(send *ri* :rcb4-open :devname "ttyACM0")  ;; 実際のデバイス名に置き換える
(send *ri* :timer-on)
```

`:timer-on` は `com-port` が既に設定済みなら内部の `:com-init`(FTDI探索)を呼ばない実装のため、
上記の順で呼べばFTDI探索をバイパスしてATOM経由の接続がそのまま使われる。実機で双方向通信を確認済み。

### デバイス名の固定(複数ATOM接続時)

ATOM(AtomS3系)はどれも同じUSB ID(`303a:1001`)で認識されるため、他のAtomS3機器(ロボットの目など)を
同時に挿すと `/dev/ttyACM0` の番号がずれる。シリアル番号で固定名を作る:

```bash
udevadm info -a -n /dev/ttyACM0 | grep -i serial   # このATOM個体のシリアル番号を確認
```

```
# /etc/udev/rules.d/99-my-rcb4-atom.rules
SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", ATTRS{idProduct}=="1001", ATTRS{serial}=="<確認したシリアル>", SYMLINK+="ttyACM-rcb4", GROUP="dialout"
```

```bash
sudo cp 99-my-rcb4-atom.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger
```

以降は `"ttyACM0"` の代わりに `"ttyACM-rcb4"` を使う。

## トラブルシューティングの記録

配線・設定の切り分けで実際に役立った手順:

1. **ATOM単体の健全性確認**: RCB4を外し、G1-G2をジャンパー線で直結してループバックさせる。
   `HardwareSerial` で送ったバイトがそのまま返ってくれば、ATOM側のUARTペリフェラル・ファームウェアは正常。
2. **配線の生きているピンの確認**: UARTを使わず `digitalWrite`/`digitalRead` で単純なGPIO導通テストを行う。
3. **アイドル電位だけでの判断は不十分**: RCB4側のRx/Tx各ピンには恐らくアイドル状態を規定する
   受動素子(プルダウン等)があり、電源ON/OFFに関わらず一定電位を示すことがある。「配線が生きているか」は
   アイドル電位ではなく、**コマンド送信直後に生の電気的な変化(トランジション)があるか**で判定するのが確実。
4. **ピン対応の最終確認は公式マニュアルで**: 目視や手探りでの「隣のピンだから多分TXD」という判断は誤りやすい。
   `~/rcb4eus/pdfs/HTH4_Ver6-20160712.pdf` のようなハードウェア接続図で正式なピン順(GND-Rx-Tx)を確認したことで
   原因(TX/RXピンの割り当てミス)が判明した。

## POLICY モード: 学習済みポリシーをAtomS3の中で走らせる

PCを指令だけの役に減らし、観測の組み立て・推論・サーボ読み書きを全部AtomS3で
行うモード。ボタンで `BRIDGE -> STATUS -> POLICY` と切り替わる。

PCが送るのは `vx, vy, wz` の3つだけ。残り65次元はAtomS3が自分で作る:
歩行位相はステップカウンタ、`joint_pos`/`joint_vel` はRCB-4から読む、
`actions` は自分の前回出力。

`projected_gravity` と `base_ang_vel` の出どころは実行時に切り替わる。既定は
`--imu fixed` 相当で、ポリシー自身の静止時重力定数と角速度0 -- **姿勢を見ない
ので、これは歩容の再現であってバランス制御ではない**。AtomS3のIMUを使う経路も
実装してあり、取り付け回転と角速度バイアスは測定済み(`imu_calibrate.py`)だが、
残差が約10度あり「基板が傾いている」のか「手が水平でない」のかを分離できて
いないため既定では切ってある。切り替えはコマンドフレームの bit 7。

**ポリシーは6つ載っていて、立ち上がり・座りの遷移も端末側で完結する。**
どれがどれで、どこを間違えたかは [`docs/policies.md`](docs/policies.md)。

### 重みの書き出し

```bash
R=~/src/github.com/iory/rl-benchmark/walking_hand_mjlab/real_robot
uv run --no-project --with onnx --with onnxruntime --with pyyaml --with numpy \
  python tools/export_policy.py \
    --onnx $R/policies/walk.onnx --spec $R/deploy_spec.json \
    --calib $R/calibration.yaml --control-hz 30 --outdir lib/policy
```

ONNXランタイムはAtomS3に載らないが、actorは正規化器付きの4層ELU MLPでしか
ないので、重みを `.rodata` に焼いて順伝播を手で書く
(`feetech-cli/arduino/arduino_quad` と同じ手口)。書き出しの前に
onnxruntimeと突き合わせ、合わなければヘッダを書かない。

出力は2つ。`policy_spec.h` (3 KiB、次元と制御定数と手先姿勢とサーボID) と
`policy_weights.h` (918 KiB、重み本体)。分けてあるのは、ポリシーに触れる
たびに235 KiBのfloatリテラルを再コンパイルしないため。

`--name omni` のように名前を付けると `policy_spec_omni.h` /
`policy_weights_omni.h` になり、複数のポリシーを同居させられる。実際の運用は
こちらで、6つ載っている。足すとき・差し替えるときの手順と落とし穴は
[`docs/policies.md`](docs/policies.md)。

### 実測 (AtomS3, RCB-4 mini, 19サーボ)

`pio run -e bench -t upload` で再現できる。

| 項目 | 時間 |
|------|------|
| 推論 (重みをSRAMに置く) | 3.02 ms |
| 19関節の読み出し | 20.23 ms |
| サーボ指令 | 1.59 ms |
| **合計** | **24.8 ms** |

実測して分かった事実が2つ、どちらも設計を変えた:

**1. 重みはSRAMに置く。** フラッシュはメモリマップされているので `const float[]`
のまま読めるが、1推論あたり235 KiBを流すとキャッシュラインフィルが数千回起きる。
実測 **9.84 ms (flash) 対 3.02 ms (SRAM)**。`-DPOLICY_WEIGHTS_IN_RAM` で
起動時にコピーする。RAM使用率は81%になる。`-O2` は効果ゼロだった(3.019 ms
のまま)ので入れていない。

**2. 読み出しはバイト数がすべて。** 基板の応答は固定 約0.75 ms + **54 µs/byte**。
1.25 Mbpsなら1バイト8.8 µsのはずで、**基板は自分の配線の6分の1でしか喋れない**。
したがって19関節×2バイトを個別に読む(38バイト、19往復)ほうが、
テーブル全体を5回で読む(630バイト、5往復)より速い: **20.2 ms 対 37.4 ms**。
隣接IDをまとめても1サーボあたり1.09 msでほぼ変わらないので、まとめる意味はない。

読み出しサイズ対コスト(USBを一切介さない実測):

```
   2 B: 0.751 ms      64 B: 3.826 ms
   8 B: 1.077 ms      96 B: 5.059 ms
  16 B: 1.539 ms     126 B: 7.456 ms
  32 B: 3.043 ms
```

### 制御レートは30 Hz (PCは40 Hz)

合計24.8 msは40 Hzの予算25 msに対して余裕がない -- 読み出し単体の最悪値が
24.8 msある。30 Hz(33.3 ms)にして8.5 msの余裕を取った。`calibration.yaml` は
sim で20 Hzまで歩容が保たれる(50 Hz比60-95%の前進速度)ことを記録しているので、
30 Hzは安全側。`--control-hz` で書き出し時に決まる。

歩行位相は `step/control_hz`、`joint_vel` の窓は秒で持っているので、PC側と
レートが違っても観測の意味は変わらない。

### 起動シーケンス: home を経由しないと動かない

`r` を押すと、ポリシーを回す前に3つやる。どれも省くと動かない -- ここは
`hand_deploy.py` の `mode_teleop` が黙ってやっていたことの写しである。

1. **`0x7FFF` を全サーボに送る(hold)。** モードに入るとき `0x8000` でfreeして
   いるので、**free状態のサーボは位置指令だけでは入り直さない**。ホスト側
   ライブラリが `interface.hold(...)` を独立した手順として呼んでいるのは
   このため。実測: これが無いと関節角度が210ステップまったく変化しなかった
   (`pose_err` が固定値のまま)。
2. **stretch を書く**(`servo_stretch: 90`)。基板の既定値127は
   `calibration.yaml` に「buzzed」と記録されている。
3. **500 ms かけて home 姿勢へ移動**し、1秒待つ。**ポリシーの出力は home からの
   オフセット**で、観測の `joint_pos` も home からの相対値なので、寝ている手から
   始めると学習で見たことのない姿勢について聞くことになる。

この間の状態は `HOME`(水色)。終わった瞬間に home との最大誤差を測って
`home_err` としてラッチする -- **これが無いと「手が動かなかった」と
「動いたが読めていない」を画面から区別できない**。床置きだと親指が突っ張って
30度台になるが、これは接触であって異常ではない(`calibration.yaml` に34度と記録)。

### テレメトリ

`device -> host` は34バイト固定。見るべきものが3つある。

| 欄 | 意味 |
|----|------|
| `rx` | AtomS3が受け取ったホストフレーム数。**増えていなければPC->AtomS3が通っていない**(たいていボタンがPOLICYになっていない) |
| `home_err` | homing直後のhomeとの最大誤差。手が本当にstanceに着いたか |
| `pose_err` | 毎ステップのhomeとの最大誤差。**変化しないならサーボが駆動されていない** |

`vx`/`wz` もAtomS3が解釈した値を返すので、打った値と食い違えばその場で分かる。

### ボタンを押さずにPOLICYへ入る(テスト用)

```bash
pio run -e policy-boot -t upload      # 起動モードをPOLICYにしたビルド
```

起動時はサーボfreeでホストが `RUN` と言うまで動かないので安全ではあるが、
テスト用であって robot に残すビルドではない。既定(`-e m5stack-atoms3`)は
BRIDGE起動。

### 使い方

```bash
# ボタンを2回押してPOLICYモードへ(画面に "POLICY" と出る)
python3 tools/policy_teleop.py /dev/ttyACM0
```

```
r       開始 <- 最初に押すのはこれ。home へ移動してからポリシーが立たせる
w / s   前進速度 上げ/下げ      space  ホールド(home姿勢へ戻す。推論は回り続ける)
a / d   旋回 左/右              f      全サーボfree
                                q      終了(抜けるときfreeする)
```

画面のランプ: 灰=IDLE、**水色=HOME**、緑=RUN、黄=HOLD、赤=FAULT。

**安全側の作り:**

- モードに入った時点ではサーボはfree。ホストが `RUN` と言うまで動かない。
- ホストが **0.5秒** 黙ったら指令をゼロにする(= 立ち止まる。歩行位相も止まる)。
- **3秒** 黙ったら全サーボfree。ケーブルが抜けた手が歩き続けないため。
- 読み書きが **2回連続** で失敗したらfreeしてFAULT。自動復帰しない
  (各失敗はすでにサーボあたり4回リトライした後のもの)。
- モードを出るときもfree。駆動したままBRIDGEに渡さない。

BRIDGEとPOLICYは同じUARTを取り合うので、両立しない。だからオプションではなく
モードにしてある。

## 無線化

研究室のAPに参加する(自分がAPになるのではなく)。SoftAPだとスマホをそれまでの
ネットワークから引き剥がすことになり、iOSは「インターネットに接続していません」
と言って離れようとするし、PCもロボットとインターネットに同時に繋がれなくなる。
同じネットに全員が居るほうが素直で、ロボット自身のアドレスをQRで配れるのも
この構成だからできる。

### なぜESP-NOWにしなかったか

- **混線しないわけではない。** ESP-NOWは独立した無線ではなく、Wi-Fiの
  action frameとして同じ2.4GHzの1チャンネルに乗る。通常のWi-Fiと同じ
  CSMA/CAで電波を取り合うし、APに接続している場合は
  [ESP-NOWのチャンネルはAPのチャンネルと同一でなければならない](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-reference/network/esp_now.html)。
- **到達保証は無い。** 送信コールバックの成功はMAC層で受かったことしか
  意味せず、[アプリケーション層が受け取れる保証は無い](https://docs.espressif.com/projects/esp-faq/en/latest/application-solution/esp-now.html)
  とEspressif自身が明記している。もっとも指令は10Hzで送り続ける設計で、
  0.5秒無通信で停止・3秒でfreeなので、数フレーム落ちても問題にはならない。
- **iPhoneから話せない。** Espressif独自プロトコルで、iOSに生の802.11
  action frameを扱うAPIは無い。ESP32をもう1台ゲートウェイに置くしかない。
  BLEも同様で、[iOS SafariにWeb Bluetoothは無く、Appleは実装予定を表明して
  いない](https://caniuse.com/web-bluetooth)ためネイティブアプリが要る。
- **軽くもない。** 実測(`pio run -e wifi-probe`)では重いのはWi-Fiドライバ
  本体で、その上のプロトコルではなかった。

| | free heap |
|---|---|
| 重みをSRAMに置いた状態 | 85.6 KB |
| + Wi-Fiドライバ(STA) | **33.9 KB** |
| + ESP-NOW | 33.3 KB |
| + SoftAP + UDPソケット | 27.5 KB |

ESP-NOWとUDPの差は約6 KB。推論時間も3.02 → 3.13 msでほぼ無影響だった。

### 重みの配置がここで変わる

Wi-Fiスタックを入れると、235 KiBの重みを全部SRAMに置いたままではリンクが
**DRAMを約2 KiB超過して通らない**。そこで `POLICY_RAM_WEIGHT_BYTES` を予算と
して、**大きい層から順に**載せ、入らなかった層はフラッシュから読む。

`202240` という半端な値は、ちょうど最大2層(`mlp.2` と `mlp.0`、50560 float)
が収まる境界。1バイト少ないと2層目が入らず、代わりに小さい3層が載って
フラッシュに残る重みが倍になり、実測で1推論あたり1 ms余分にかかる。

結果: 4層中3層(予算200704時)で推論5.02 ms、制御周期26.84 ms対33.3 ms予算。

### 設定

認証情報はデバイスのNVSに置く。このリポジトリにもビルドフラグにも入れない
ので、ファームウェアイメージを配ってもネットワークは漏れない。書き込みは
一度だけ、USB経由。**BRIDGEモード(起動時のモード)で行う**。

```bash
python3 tools/wifi_setup.py --ssid lab-wifi --password '...' /dev/ttyACM0
python3 tools/wifi_setup.py --show     # 今の設定
python3 tools/wifi_setup.py --clear    # 忘れさせる
```

中継は本来バイト透過なので、この設定コマンドはRCB-4のトラフィックと区別が
つかないと困る。`'n'` は 0x6E = 110 で**正当なフレーム長**なので、`"net?"`
`"net!"` `"net "` の4バイト目まで保留して照合し、違った瞬間に保留したバイトを
順番どおり中継へ流す。110バイトのフレームが4バイトの遅延だけで無傷に通ることは
実機で確認済み(10/10)。

### 2つのコアの使い分け

制御ループはコア1(Arduinoの`loop()`が載るコア)、**Wi-Fiスタック・Webサーバ・
LCDはコア0**。これは整理のためではなく、実測で決まった。

**Webサーバ。** `server.handleClient()` を制御ループから呼んでいたときは、
POLICYモードが走っていないとページが一切開けなかった -- QRを撮った人が
行きたいのはまさにそのPOLICYモードなのに。QRを描くSTATUSモードから呼んでも、
一つ隣で同じ問題が起きるだけだった。加えて `handleClient()` はブラウザ次第で
何ミリ秒でもブロックするが、制御周期の予算は33 msしかない。

**LCD。** この128x128パネルの再描画は**実測16.5 ms**。制御周期の半分である。
それが、最大27 msかかるステップの直後に、秒4回走っていた。しかも
オーバーラン計測が「1周期まるごと遅れたとき」しか数えていなかったので
`over=0` と表示され、**数字にならず動きとしてしか現れなかった**(手が
振動する)。描画に必要な値は制御ループが既にpublishしているので、
コア0のタスクに移すだけで済んだ。

2つのコアが触れ合うのは2箇所だけで、どちらも `portENTER_CRITICAL` で囲った
数回のmemcpyしかせず、ブロックする処理を含まない:

- ページとLCDが読むテレメトリのスナップショット
- 制御ループが引き取るコマンド**1枠**。キューではない -- 指令は設定値なので
  新しいものだけが意味を持ち、古いものが遅れて届くと操作と喧嘩する

移設後: `draw_ms` 16.5 → 0.0、保持中のループ平均22.1 ms(16.7〜27.4)、
予算33.3 ms内で安定。

### 診断できないものは直せない

無線化の作業で時間を溶かしたのは、ほぼ全部「見えなかった」ことが原因だった。
残した計装はそのための道具である。

- `net?` は**どのモードでも**答える。最初はBRIDGEモードでしか答えず、
  無線の状態を知りたいのはSTATUS画面を見ているときなのに、まさにその
  モードで聞けなかった
- `net?` は**切断理由コード**を返す。`WiFi.status()` は「切断」としか言わず、
  鍵の誤り・拒否・APの消失が全部同じ答えになる。理由15/202/204が
  「パスワードが違う」で、実際これで解決した(保存されていたパスワードが
  9文字、`.env`は10文字だった)
- `net?` は**保存されているパスワードの長さ**を返す(中身は返さない)
- `net scan` は見えるAPを列挙する。ESP32-S3に5GHzは無いので、ここに
  無いネットワークは何をしても繋がらない
- `/c` のJSONは `state` `loop_ms` `err` `over` `draw_ms` `req` `quiet`
  `rx` `step` `try` `home_err` `live` を返す。**状態機械が2状態間で
  往復しているとき、外から往復を眺めても原因は分からない**

`--show`/`--scan` の応答が返らないなら、それ自体が「BRIDGEモードにいない」
という情報である(いや、今はどのモードでも返る -- 返らないならUSBが繋がって
いない)。

### スマホ・PCからの操作

ボタン長押しでSTATUSモードへ行き、**クリックすると画面いっぱいにQRが出る**。
スマホのカメラで撮ればブラウザがロボットのアドレスを開く。アドレスを打つ必要も、
アプリも、探索も要らない。PCも同じURLを開けば同じページが使える。

操作はアナログスティック。指令は連続値の2つなので、ボタンでは角しか送れない。
pointerイベントなので指でもマウスでも同じコードで動く。

- 上下が前進速度(前 +0.5 / 後 -0.3 m/s、非対称)、左右が旋回(±1.0 rad/s)
- 中央付近はデッドゾーンで指令ゼロ = その場で立つ
- **指を離すと中央に戻る。** 離しても動き続ける手にしないため
- 下の run / hold / free がモード。スティックに触れると自動でrunになる

ページは `lib/web/web_page.h` にPROGMEMで置いてある。Wi-Fiスタックが残す
ヒープが約30 KBしかないのでフラッシュに置く必要があり、また外部から何も
取ってこない(フレームワークもフォントもアイコンも無い) -- スマホは研究室の
ネットに繋がったばかりでインターネットへの経路が無いかもしれないため。

送るフレームはUSBと同じ9バイトで、16進にしてGETのクエリに載せる。デバイス側の
パーサは文字列比較と16進デコードだけで済む。

### PCからスクリプトで叩く

`tools/policy_teleop.py` はUSBとUDP(ポート9000)の両方に対応する。ブラウザで
足りるならそちらでよく、これはスクリプトから叩きたいとき -- ROS 2ノードから
繋ぐならHTTPポーリングよりUDPのほうが素直 -- のために残してある。

```bash
python3 tools/policy_teleop.py                # mDNSで kxr-hand.local を探す
python3 tools/policy_teleop.py 192.168.1.23   # アドレス直指定
python3 tools/policy_teleop.py /dev/ttyACM0   # USB
```

### ボタン

**長押しでモード循環**(BRIDGE → STATUS → POLICY)。モードを変えるのは
「このファームが何であるか」を変えることなので、画面をかすめた程度では
起きないようにしてある。短押しとダブルクリックは現在のモードのもの。

| モード | クリック | ダブルクリック |
|---|---|---|
| BRIDGE | Wi-Fiの状態とIPを表示 | -- |
| STATUS | QR表示の切り替え | -- |
| POLICY | **サーボon/off** | ポリシーの実行/停止 |

POLICYの「on」はhome姿勢へ行って保持するところまでで、**歩き出さない**。
電源以外なにも繋がっていなくても効く唯一の操作なので、これが動き出すもので
あってはならない。

なお、ホスト無通信のフェイルセーフは**一度でもホストが喋った後にだけ**効く。
一度も来ていないホストが「居なくなった」ことはあり得ず、そう扱うと
ボタン操作が次のパスで毎回取り消される。ボタンを押すことは「人がそこに居る」
という意味なので、押した時点でローカル操作に切り替わる。

## 関連ファイル

- `platformio.ini`, `src/`, `lib/` : PlatformIO版の本番ファームウェア(3モード)
- `docs/policies.md` : 6ポリシーの一覧・遷移シーケンス・書き出し手順と、間違えた箇所
- `tools/export_policy.py` : ONNX actor -> Cヘッダ。onnxruntimeと突き合わせてから書く
- `tools/policy_teleop.py` : POLICYモード用のPC側クライアント(USB/UDP)
- `tools/wifi_setup.py` : Wi-Fi認証情報をNVSに書く(USB経由、一度だけ)
- `lib/net/`, `lib/web/` : Wi-Fi・UDP・HTTPサーバとスマホ用ページ
- `src/wifi_probe.cpp` (`pio run -e wifi-probe`) : 無線を上げたときの残りヒープ計測
- `src/bench.cpp` (`pio run -e bench`) : 上の実測値を取り直すための計測用ビルド
- `atom_rcb4_bridge.ino` : arduino-cli時代のブリッジ(PlatformIO版に置き換え済み)
- `rcb4_bridge_test.py` : PC側動作確認スクリプト
- `~/AtomS3/atom_rcb4_bridge_diag/atom_rcb4_bridge_diag.ino` + `rcb4_bridge_sweep.py` : 配線トラブル時に
  反転/TX-RX入れ替え/ボーレートの組み合わせを再書き込みなしで一括確認するための診断ツール
