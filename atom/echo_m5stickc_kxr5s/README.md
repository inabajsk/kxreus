# echo_m5stickc_kxr5s

PC側 ATOM Echo ⇔ ロボット側 M5StickC を ESP-NOW で結び、PC(EusLisp)からの
RCB4 コマンドを無線で中継する構成。

```
PC --USB(500000bps)--> ATOM Echo ==ESP-NOW(ch1)==> M5StickC --UART--> RCB4
PC <-----------------  ATOM Echo <================ M5StickC <-------- RCB4
```

| フォルダ | 機器 | 元にしたもの |
|---|---|---|
| `atom_echo_pc/` | PC側 ATOM Echo (arduino-cli, `m5stack:esp32:m5stack_atom`) | `../s3_echo_with_I2C/atom_echo_pc` |
| `m5stickc/` | ロボット側 M5StickC (PlatformIO, env `m5stickc`) | `../../m5stack/m5stickc_m5stickv_kxr5s/m5stickc` |

## プロトコル (両側で共通)
- `PKT_DATA [0x01, seq, data≤240B]` を stop-and-wait で送り、受信側は必ず
  `PKT_DATA_ACK [0x04, seq]` を返す(25ms × 最大30回再送、直前seqと同じなら重複として破棄)。
- `PKT_PING/PKT_PONG [0x02/0x03, u32]` はハートビート(リンク判定のみ)。
- チャンネル1固定。

## ペアリング (MAC)
双方が相手の MAC を `PEER_MAC` として持つ 1対1構成。

| ヘッダ | 中身 | 生成スクリプト |
|---|---|---|
| `m5stickc/lib/espnow_link/pc_mac.h` | ATOM Echo のベースMAC (STA) | `atom_echo_pc/get_my_mac.sh <Echoのポート>` |
| `atom_echo_pc/atom_echo_voice_cmd_pc/robot_mac.h` | M5StickC の **SoftAP MAC (ベースMAC+1)** | `m5stickc/get_my_mac.sh <M5StickCのポート>` |

M5StickC 側は ESP-NOW を `WIFI_IF_AP` で送受信するため、送信元MACは SoftAP の MAC
(esptool が表示するベースMAC + 1)になる。ATOM Echo は送信元MACが一致しないパケットを
捨てるので、`robot_mac.h` には +1 した値を入れる(2026-11-08 実機で確認済み)。

現在の値 (2026-11-08):
- ATOM Echo: `64:b7:08:80:30:00`
- M5StickC: ベース `24:a1:60:46:ef:ec` / SoftAP `24:a1:60:46:ef:ed`

## 書き込み
```bash
cd atom_echo_pc && ./flash.sh /dev/ttyUSB0     # ATOM Echo (115200で書き込み)
cd m5stickc     && ./flash.sh /dev/ttyUSB1     # M5StickC
```
`m5stickc/platformio.ini` は `espressif32@6.13.0` (Arduinoコア2.0.17) に固定している。
無指定だと 8.x (コア3.x / mbedTLS 3.x) が入り、`cert_store`・`espnow_link`・`net` がビルドできない。

## 注意: M5StickC の WiFi 設定
`espnow_link` は「M5StickC が自前の AP (チャンネル1) で動いている」ことを前提にしている。
WiFi 認証情報が保存されていると STA で研究室APに接続しに行き、チャンネルがずれて
`E ESPNOW: Peer channel is not equal to the home channel, send fail!` となり通信できない。
USB シリアル(115200)で `net?` で状態確認、`net!` で保存済み認証情報を消去できる。

## 動作確認 (2026-11-08)
M5StickC の WiFi 設定を `net!` で消去し、両方に書き込んだ後、ATOM Echo (500000bps) から
RCB4 バージョン問い合わせ `03 FD 00` を10回送信 → 10/10 応答
(`CB-4 V1.0 090715`、往復 約10〜20ms、初回のみ約50ms)。

## EusLisp から使う (`echo-kxrl4t.l`)
ロボットは kxrl4t (サーボID 2-9 が応答、ID 1 の首は未接続)。

```
$ cd ~/kxreus
$ irteusgl atom/echo_m5stickc_kxr5s/echo-kxrl4t.l
1.irteusgl$ (echo-init)             ; モデル+irtviewer作成、Echoのポートを開いてRCB4と初期化
2.irteusgl$ (send *ri* :timer-on)   ; 0.1秒ごとに実機の角度を読んで紫のviewerを更新
3.irteusgl$ (send *ri* :timer-off)  ; 更新停止
```
- ポートは ATOM Echo の FTDI シリアル番号 (`4D5217E152`) で `/dev/ttyUSB*` から自動検出、
  500000bps。明示する場合は `(echo-init :devname "ttyUSB0")`。
- 事前に Echo を `usbipd attach --wsl --busid <BUSID>` で WSL に渡しておくこと。

### 胴体の姿勢 = M5StickC 内蔵IMU
`echo-kxrl4t.l` は `atominterface.l` を読み込み、`:timer-on` の表示で胴体の傾きを
M5StickC 内蔵IMU (RCB4拡張命令 `0x90` を M5StickC が横取りして返す) から求める
(Madgwickフィルタ、ヨーはジャイロ積分)。`(echo-init)` 時に静止状態でジャイロバイアスを校正する。

- atominterface.l の `:read-gravity-imu` / `:madgwick-reset` は AtomS3 逆さ取り付け用の軸補正入りなので、
  echo-kxrl4t.l を読んだ irteusgl の中だけ「生値 + `*echo-imu-mount*` で胴体座標へ回す」版に置き換えている。
- 取り付け向き: 既定値は Z軸まわり -90度 (2026-11-08 実機で前後左右を確認済み)。
  変える場合は `(echo-imu-mount :yaw 90)` (Z軸まわり)、`(echo-imu-mount :flip t)` (上下逆さ)。
  呼ぶと Madgwick を再初期化する(ロボットを静止させておくこと)。
- 胴体のヨーをゼロに戻す/再校正: `(send *ri* :madgwick-reset)`。

### `:call-motion` / `:jump-motion` / `:timer-on` (sysreg の扱い)
2026-11-08 実機 (RCB4 電源投入直後) で確認:
- 正常な待機状態は sysreg=`#xC293` (rom-on=1, **response-on=0**)。PC は RAM `#x44B〜#x46D` を回る。
- RAM の読み出しは response-on=0 でも ROM モーション再生中でも正しく返る。
- response-on=1 のまま ROM モーションを走らせると ROM 命令の応答が COM に流れ出し、読み出しが壊れ、
  モーションも途中で終わる。atominterface.l の `:viewer-update` は毎tick response-on=1 にするので、
  `:timer-on` 中の `:call-motion` でこれが起きてハングし、壊れた応答を書き戻して sysreg の通信ビットまで壊れた。

echo-kxrl4t.l での対処:
- `:viewer-update` は sysreg に一切触らず、RAM (サーボ角度) と IMU だけ読む。
- `:call-motion`/`:jump-motion` は応答を待たずに送り、最後は rom-on=1, response-on=0 に戻す。
  書き込む値の通信/フレーム/ICS ビットは echo-init 時の正常値と照合する。
- 確認: `:call-motion 0` + 0.1秒ごとの `:viewer-update` を2回 → 2回ともモーション完走、読み出しエラーなし、
  終了後 sysreg=`#xC293`。
- 確認用 `(echo-pc)` (PC・sysreg 表示)、異常時 `(echo-recover)`、駄目なら RCB4 の電源再投入。

## WSL への USB 接続 (`wsl/`)
Windows 側で ATOM Echo (と AtomS3) を WSL に渡すスクリプト `wsl/M5-WSL-attach.cmd` / `.ps1`。
Windows のデスクトップ等にコピーし、USB を挿し直したらダブルクリックする。詳細は `wsl/README.md`。
