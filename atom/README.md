# atom — KXR/RCB4無線ブリッジ ファームウェア一式

`~/kxreus/atominterface.l`(`rcb4-interface`のATOM Echo/AtomS3/M5StickV拡張)が
通信する4台の実機のファームウェア・書き込みスクリプト・ドキュメントをここに
まとめている。**このkxreusリポジトリをclone するだけで、4台すべてを最初から
書き込める状態になる**ことを目標にしている(他ディレクトリへの参照は無し)。

## 構成

```
PC ── USB ──  ATOM Echo(PC側)  ==ESP-NOW(無線)==  AtomS3(ロボット側)
                atom_echo_pc/                        atom_s3_robot/
                                                        |  UART(1.25Mbps)
                                                        |  → RCB4(ロボットの制御基板)
                                                        |
                                                        |  I2C(G1=SCL/G2=SDA)
                                                        ├── M5StickV 左目(0x24)
                                                        └── M5StickV 右目(0x25)
                                                             m5stickv/
```

- **atom_echo_pc/**: PCとUSB接続するATOM Echo。RCB4コマンドをESP-NOW経由で
  ロボット側へ中継し、ボタン押下で音声コマンドも送る。
- **atom_s3_robot/**: ロボットに搭載するAtomS3。ESP-NOWで受けたRCB4コマンドを
  実RCB4へUART中継し、内蔵IMU・M5StickV(I2C)へのブリッジ、Edge Impulseによる
  音声コマンド認識を行う。
- **m5stickv/**: ロボットの両目に載せるM5StickV(K210)。AprilTag検出・
  ルービックキューブの色ブロブ発見・音声合成を行い、AtomS3とI2Cで通信する。
- **edge_impulse/**: `atom_s3_robot`が使う音声コマンド認識モデル(Edge Impulse
  Studioが生成したArduinoライブラリ)と、学習データ・データ収集ツール一式。

各フォルダに `README.md`(役割・配線・使い方)と `flash.sh`(書き込みスクリプト)
がある。

## もう1つの構成: ロボット側もATOM Echo(腕・M5StickV無しの機体向け)

```
PC ── USB ──  ATOM Echo(PC側)  ==ESP-NOW(無線)==  ATOM Echo(ロボット側)
              atom_echo_pc/(共通)                     atom_echo_robot/
                                                          |  UART(1.25Mbps)
                                                          |  → RCB4(ロボットの制御基板)
```

- **atom_echo_pc/** ⇔ **atom_echo_robot/**: 上記のAtomS3構成とは別の、
  ロボット側にもう1台の**プレーンなATOM Echo**(AtomS3ではない)を使う構成。
  PC側ファームウェアはAtomS3構成と共通の`atom_echo_pc/`をそのまま使う
  (2026.8統一。詳細は`atom_echo_pc/README.md`参照)。`setup_echo_echo.sh`で
  セットアップする(下記「2つの構成の使い分け」参照)。

### 2つの構成の使い分け

| | `setup_s3_echo.sh`(AtomS3+ATOM Echo) | `setup_echo_echo.sh`(ATOM Echo+ATOM Echo) |
| --- | --- | --- |
| ロボット側 | AtomS3 | ATOM Echo(プレーン) |
| IMU | あり(内蔵) | **無し** |
| M5StickV(I2C)・カメラ | 対応 | 非対応 |
| 音声認識 | Edge Impulse(共通モデル。2026.8統一、`edge_impulse/`参照) | 同左(素のESP32では ESP-NN高速化カーネルが使えず汎用カーネルにフォールバックするが実機コンパイル確認済み) |
| 向いている機体 | 腕・カメラ(M5StickV)を搭載する機体(本プロジェクトのメイン機体) | 4脚・6脚など腕もM5StickVも無く、**とにかく無線でRCB4を操作したいだけ**のロボット |
| コスト・サイズ | 大きめ | 小さい・安い |
| RCB4中継プロトコル | ACK付き再送(共通) | ACK付き再送(共通、2026.8統一) |

**腕やM5StickVを載せない機体であっても**、姿勢による転倒検知・傾き補正など
IMUを使いたい場合はAtomS3+ATOM Echo構成(`setup_s3_echo.sh`)の方が適している
(ATOM EchoにはIMUが無いため)。音声認識は以前は`setup_echo_echo.sh`側だけ
自作の軽量テンプレートマッチング方式(学習が必要で使い勝手が悪かった)
だったが、AtomS3構成と同じEdge Impulseモデルに統一し、書き込み直後から
学習不要で動作するようにした(詳細は`atom_echo_robot/README.md`)。

## クイックスタート(clone後、実機4台を書き込む手順)

### 1. 1回だけ行うホスト側セットアップ

```bash
# arduino-cli本体は別途インストール済みであること
arduino-cli config add board_manager.additional_urls \
  https://static-cdn.m5stack.com/resource/arduino/package_m5stack_index.json
arduino-cli core update-index
arduino-cli core install m5stack:esp32

# RCB4/ATOM Echo等のUSBシリアル(FTDI, VID:PID 0403:6001)に一般ユーザーが
# アクセスできるようにする(kxreus/rcb4interface.lのヘッダーコメントにある
# 近藤科学純正Dual USB Adapter用udevルールと合わせて設定してよい)
sudo bash -c 'echo SUBSYSTEMS=="usb", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", MODE="0666" > /etc/udev/rules.d/99-atom-ftdi.rules'
sudo udevadm control --reload-rules

# M5StickV(MaixPy)書き込みにはPythonのpyserialが必要
pip3 install pyserial
```

M5StickVの書き込みはArduino IDEではなくMicroPython(MaixPy)のraw REPL経由
(`m5stickv/maixpy_upload.py`)で行うため、Arduino側のボード定義は不要。

### 2. AtomS3とATOM Echoのセットアップ(MAC取得+コンパイル+書き込み一括)

ESP-NOWは双方が相手の固定MACアドレスを`PEER_MAC`として持つ1対1構成。
`PEER_MAC`は手書きせず、`get_my_mac.sh`(内部で`esptool read-mac`を使う)が
相手側の`.ino`から`#include`されるヘッダファイル(`robot_mac.h`/`pc_mac.h`)を
自動生成する(生成先はスクリプト自身ではなく相手フォルダ内)。

AtomS3・ATOM Echoの両方をPCへ接続した状態で、`setup_s3_echo.sh`が
「双方のMAC取得 → 双方のコンパイル・書き込み」を1回でまとめて行う:

```bash
./setup_s3_echo.sh [AtomS3のポート] [ATOM Echoのポート]
# 省略時 AtomS3=/dev/ttyACM0, ATOM Echo=/dev/ttyUSB2
```

新品の機体に交換した時・初めてこのリポジトリをセットアップする時はこれを
実行すればよい(現行の実機ペア用に生成済みのヘッダも既にリポジトリに
入っているので、機体を交換しない限り省略可)。個別に行いたい場合は
`atom_s3_robot/get_my_mac.sh`・`atom_s3_robot/flash.sh`・
`atom_echo_pc/get_my_mac.sh`・`atom_echo_pc/flash.sh`をそれぞれ参照
(各READMEに詳細あり)。

### 3. M5StickVを左目・右目それぞれ書き込み

SDカードを挿した状態で実行すること(初回は発話用WAVクリップも`/sd/`へ
書き込むため数分かかる。2回目以降は`--skip-clips`でboot.pyのみ高速に
書き込める。詳細は`m5stickv/README.md`参照)。

```bash
cd m5stickv
./flash.sh /dev/ttyUSBn 0x24   # 左目
./flash.sh /dev/ttyUSBm 0x25   # 右目
```

### (代替) ロボット側がAtomS3ではなくATOM Echoの機体の場合

上記の1〜3の代わりに、腕・M5StickVを載せない機体(4脚・6脚等、
「もう1つの構成」参照)では以下を使う:

```bash
./setup_echo_echo.sh <PC側ATOM Echoのポート> <ロボット側ATOM Echoのポート>
```

### 4. euslisp側から接続確認

```lisp
(load "rcb4robots.l")
(load "atominterface.l")
(make-kxr-robot-from-hardware)     ;; RCB4本体(近藤科学Dual USB Adapter優先/無ければttyUSB0)
(send *ri* :scan-m5stickv-i2c)     ;; 0x24/0x25が両方見えるか確認
```

## 各USBポートの見分け方

複数のFTDI/USBシリアルが挿さっている環境では、`udevadm info -a -n /dev/ttyUSBn`
の`ATTRS{serial}`(個体ごとのシリアル番号)で区別するのが確実
(`atominterface.l`の`ttyusb-devnames`/`ttyusb-udev-attr`と同じ方法)。
AtomS3はネイティブUSB-CDCのため`/dev/ttyACMn`として見え、シリアル判別は不要。
