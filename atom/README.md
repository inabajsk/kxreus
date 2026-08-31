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

```bash
cd m5stickv
./flash.sh /dev/ttyUSBn 0x24   # 左目
./flash.sh /dev/ttyUSBm 0x25   # 右目
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
