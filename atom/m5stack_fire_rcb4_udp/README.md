# m5stack_fire_rcb4_udp — RCB4-mini用 WiFi/UDP ブリッジ(M5Stack FIRE)

`../atoms3_rcb4_adapter/`(USB版、AtomS3専用)のWiFi版。PC側の
`atominterface.l`/`rcb4interface.l`から、USBケーブルなしでロボットの
RCB4-miniと通信できるようにする。

```
PC (atominterface.l) <--WiFi/UDP--> M5Stack FIRE <--UART(Port C, 反転)--> RCB4-mini
```

## 配線

- **Port C (UART, GND/RXD2=G16/TXD2=G17)** → RCB4-miniのCOMコネクタ
  (GND側から GND-Rx-Tx の順、HeartToHeart4マニュアル準拠)。
- **Port A (I2C, G21/G22)** → M5StickV(別途I2C接続する場合。このスケッチ
  自体はI2C/M5StickVには関与しない)。

## 書き込み前にやること

`m5stack_fire_rcb4_udp.ino`冒頭の以下を書き換える:

```cpp
static const char *WIFI_SSID = "CHANGE_ME_SSID";
static const char *WIFI_PASSWORD = "CHANGE_ME_PASSWORD";
```

現状は決め打ち(NVS保存やcaptive portalでの設定画面は無い)。書き込み後、
画面にIPアドレスとポート番号(既定2000)が表示される。

## 書き込み

```bash
cd ~/kxreus/atom/m5stack_fire_rcb4_udp
./setup.sh /dev/ttyUSB0   # 省略時 /dev/ttyUSB0
```

`arduino-cli`が無ければ自動で`~/.local/bin`へ導入する
(`../atoms3_rcb4_adapter/setup.sh`と同じ仕組み)。

**注意**: このリポジトリの環境には`arduino-cli`が無く、実際にコンパイルを
通した実績がまだない。FQBN(`m5stack:esp32:m5stack-fire`)が実際に
正しいかも含め、初回の書き込みで問題が出たら教えてほしい。

## PC側(EusLisp)からの使い方

FIREの画面に表示されたIPアドレスを使って、通常のシリアル接続の代わりに
`:udp-host`を渡すだけでよい:

```lisp
(require :rcb4robots)
;; ロボットモデルの生成とハードウェア接続は別ステップ(teleop/bilateral.l等
;; 既存コードと同じ流儀): まずロボット名でインターフェースを作り、
;; 接続方法(ここではUDP)は後から:com-initで指定する。
(setq *ri* (kxr-make-robot-interface "kxrl4t" :viewer t))
(send *ri* :com-init :udp-host "192.168.1.xx" :udp-port 2000)  ;; FIREの画面のIP
;; 以降、:read-angle-vector や :timer-on など、シリアル接続時と
;; 全く同じメソッドがそのまま使える。
```

`:udp-port`は省略すると2000(このスケッチの既定`UDP_PORT`と一致)。

内部的には`uart.l`の`udp-interface`クラス(既存の`uart-interface`と同じ
`:ready?`/`:read1`/`:read-data`/`:write-data`という表面を持つ)が
`com-port`スロットに入るので、`rcb4-interface`側のコードは一切変更なしで
動く。

## IMU(0x90オペコード)

`atoms3_rcb4_adapter.ino`と同じプロトコルで、FIRE内蔵IMUの値を
`atominterface.l`の`:read-imu`から読める。ただし**このFIRE個体の
取り付け向き補正(`IMU_Y_SIGN`/`IMU_Z_SIGN`)は未計測で、恒等変換の
プレースホルダのまま**。`:timer-on`で姿勢表示がおかしければ、
`atoms3_rcb4_adapter.ino`本体のコメントにある調べ方(Madgwickの
シミュレーションと実機の生値を突き合わせる)で決め直すこと。

## USB版との違い(設計メモ)

USB版(`atoms3_rcb4_adapter.ino`)はUSB-CDCという**バイト列のストリーム**
を中継するので、届いたバイト列を`feedFrameParser`で解析しながら
RCB4コマンドフレーム境界を追いかける必要があった。

UDPは**メッセージ(データグラム)単位**の通信で、`rcb4interface.l`側
(`uart-interface`/`udp-interface`どちらも)は「1回の書き込み=1個の
完全なコマンドフレーム」という前提で動く。つまりPCから届く1個の
UDPパケットは、常にちょうど1個の完全なRCB4コマンドフレームになる
ので、このスケッチはバイト列再構成をせず、届いたパケットをそのまま
RCB4へ渡し、RCB4からの応答をLENバイトぶん読み切ってから1個のUDP
パケットとして送り返すだけでよい。

これは実際にPC側(`uart.l`の`udp-interface`)を実装・検証する過程で
分かった制約でもある: UDPソケットを1バイトずつ`recv`すると、そのつど
新しいデータグラムを消費してしまい、同じフレームの残りバイトは失われる
(TCPやシリアルのような連続ストリームとは違う)。このスケッチが
「1回のUDP送受信=1個の完全なフレーム」を厳守しているのはこのため。
