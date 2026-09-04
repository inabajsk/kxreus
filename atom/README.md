# atom — KXR/RCB4無線ブリッジ ファームウェア一式

`~/kxreus/atominterface.l`(`rcb4-interface`のATOM Echo/AtomS3/M5StickV拡張)が
通信する実機のファームウェア・書き込みスクリプト・ドキュメントをここに
まとめている。**このkxreusリポジトリをclone するだけで、すべて最初から
書き込める状態になる**ことを目標にしている(他ディレクトリへの参照は無し)。

## 構成(用途別に4フォルダ)

機体の構成(腕・M5StickVカメラの有無、ESP-NOW中継かWiFi直結か)ごとに、
PC側・ロボット側ファームウェアとセットアップスクリプトを1つのフォルダに
まとめている。**フォルダをまたぐ相対パス参照は無い**(各フォルダ単体で
clone・セットアップが完結する)。

| フォルダ | ロボット側 | 位置づけ |
| --- | --- | --- |
| `echo_echo/` | ATOM Echo(プレーン) | 腕・M5StickVカメラを持たない機体(4脚・6脚等)向け。IMU無し。ESP-NOW中継 |
| `s3_echo_with_I2C/` | AtomS3(I2C拡張版) | 腕・M5StickVカメラを搭載する機体(本プロジェクトのメイン機体)向け。IMU内蔵・M5StickV用I2Cブリッジあり。ESP-NOW中継 |
| `s3_echo_bridge/` | AtomS3(簡易版) | 腕・M5StickVカメラは無いがIMUによる姿勢表示(euslisp`:timer-on`)は欲しい機体向け。I2Cブリッジ無し、RCB4 UARTはGroveコネクタ(G1/G2)1本で配線。ESP-NOW中継 |
| `s3_wifi_captiv/` | AtomS3(WiFi captive portal版) | ESP-NOW/ATOM Echoを使わず、AtomS3自身がWiFiへ接続してRCB4をTCPで直接公開する構成。PCは`socat`等で仮想ttyを作って接続する。音声認識機能は無し |

各フォルダの構成は共通で、`atom_echo_pc/`(PC側、共通ファームウェアの
コピー)・ロボット側フォルダ・`setup_*.sh`(MAC取得+コンパイル+書き込み一括)
を持つ。`edge_impulse/`(音声コマンド認識モデル)だけは3フォルダ共通で
このディレクトリ直下に置き、各ロボット側`flash.sh`から`../../edge_impulse/`
として参照する。

```
PC ── USB ──  ATOM Echo(PC側, atom_echo_pc/)  ==ESP-NOW(無線)==  ロボット側(AtomS3 or ATOM Echo)
                                                                      |  UART
                                                                      |  → RCB4(ロボットの制御基板)
                                                                      |
                                                          (s3_echo_with_I2Cのみ) I2C(G1=SCL/G2=SDA)
                                                          ├── M5StickV 左目(0x24)
                                                          └── M5StickV 右目(0x25)
                                                               m5stickv/
```

- **`echo_echo/`**: `atom_echo_pc/` ⇔ `atom_echo_robot/`。`setup_echo_echo.sh`で
  セットアップ。
- **`s3_echo_with_I2C/`**: `atom_echo_pc/` ⇔ `atom_s3_robot/`。`setup_s3_echo.sh`
  でセットアップ。IMU・M5StickV用I2Cブリッジ・Edge Impulse音声認識あり。
- **`s3_echo_bridge/`**: `atom_echo_pc/` ⇔ `atoms3_simple_robot/`。
  `setup_s3_echo_bridge.sh`でセットアップ。`s3_echo_with_I2C`からM5StickV用
  I2Cブリッジを外し、RCB4 UARTをG5/G6(基板底面はんだ付け)からG1/G2
  (Groveコネクタ)へ戻した版。IMU・Edge Impulse音声認識はそのまま使える。
- **`s3_wifi_captiv/`**: AtomS3(`atoms3_wifi_captiv/`)単体で完結、PC側
  ATOM Echoやペアリングは無い。起動時にSoftAP+captive portal+QRを出し、
  スマホでWiFi設定するとAtomS3自身がそのWiFiへSTA接続、液晶にIP表示。
  PCはWiFi(TCP、既定ポート4000)でRCB4向けUARTへ直接繋がる(`socat`等で
  仮想tty化すればeuslisp側は無変更で使える)。IMU予約オペコード(0x90)は
  他構成と共通で使えるが、音声認識・ESP-NOWは無い。
- **`m5stickv/`**: ロボットの両目に載せるM5StickV(K210)。AprilTag検出・
  ルービックキューブの色ブロブ発見・音声合成を行い、`s3_echo_with_I2C`の
  AtomS3とI2Cで通信する。
- **`edge_impulse/`**: AtomS3/ATOM Echoロボット側が使う音声コマンド認識モデル
  (Edge Impulse Studioが生成したArduinoライブラリ)と、学習データ・データ
  収集ツール一式(3フォルダ共通)。

各ロボット側・PC側フォルダに `README.md`(役割・配線・使い方)と
`flash.sh`(書き込みスクリプト)がある。

### 4構成の使い分け

| | `s3_echo_with_I2C` | `s3_echo_bridge` | `echo_echo` | `s3_wifi_captiv` |
| --- | --- | --- | --- | --- |
| ロボット側 | AtomS3 | AtomS3(簡易版) | ATOM Echo(プレーン) | AtomS3(WiFi版) |
| PC側 | ATOM Echo(ESP-NOW) | ATOM Echo(ESP-NOW) | ATOM Echo(ESP-NOW) | **無し(WiFi/TCP直結)** |
| IMU | あり(内蔵) | あり(内蔵) | **無し** | あり(内蔵) |
| M5StickV(I2C)・カメラ | 対応 | **非対応** | 非対応 | 非対応 |
| RCB4 UART配線 | G5/G6(基板底面、はんだ付け) | G1/G2(Groveコネクタ) | (ATOM Echo側の配線) | G1/G2(Groveコネクタ) |
| 音声認識 | Edge Impulse(共通モデル) | 同左 | 同左(素のESP32ではESP-NN高速化カーネルが使えず汎用カーネルにフォールバックするが実機コンパイル確認済み) | **無し** |
| 向いている機体 | 腕・カメラ(M5StickV)を搭載する機体(本プロジェクトのメイン機体) | 腕・M5StickVは無いがIMUで姿勢表示したい機体 | 4脚・6脚など腕もM5StickVも無く、**とにかく無線でRCB4を操作したいだけ**のロボット | ESP-NOW/ATOM Echoを使わずWiFi環境だけでRCB4を無線化したい場合 |
| コスト・サイズ | 大きめ | 中間(AtomS3だが配線が単純) | 小さい・安い | AtomS3 1台のみ(PC側ハード不要) |
| RCB4中継プロトコル | ACK付き再送(共通) | ACK付き再送(共通) | ACK付き再送(共通) | TCP(信頼性はTCP自体に依存、ACK層無し) |

腕やM5StickVを載せない機体であっても、姿勢による転倒検知・傾き補正など
IMUを使いたい場合は`s3_echo_with_I2C`・`s3_echo_bridge`・`s3_wifi_captiv`の
いずれかが適している(ATOM EchoにはIMUが無いため)。

## クイックスタート(clone後、実機を書き込む手順)

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

### 2. 使う構成のフォルダで一括セットアップ

ESP-NOWは双方が相手の固定MACアドレスを`PEER_MAC`として持つ1対1構成。
`PEER_MAC`は手書きせず、`get_my_mac.sh`(内部で`esptool read-mac`を使う)が
相手側の`.ino`から`#include`されるヘッダファイル(`robot_mac.h`/`pc_mac.h`)を
自動生成する(生成先はスクリプト自身ではなく相手フォルダ内)。

ロボット側・PC側の両方をPCへ接続した状態で、各フォルダの`setup_*.sh`が
「双方のMAC取得 → 双方のコンパイル・書き込み」を1回でまとめて行う:

```bash
# 腕・M5StickVカメラを搭載する機体(メイン機体)
cd s3_echo_with_I2C && ./setup_s3_echo.sh [AtomS3のポート] [ATOM Echoのポート]
# 省略時 AtomS3=/dev/ttyACM0, ATOM Echo=/dev/ttyUSB0

# 腕・M5StickVは無いがIMU姿勢表示は欲しい機体
cd s3_echo_bridge && ./setup_s3_echo_bridge.sh [AtomS3のポート] [ATOM Echoのポート]

# 4脚・6脚など、腕もM5StickVもIMUも無くRCB4を無線化したいだけの機体
cd echo_echo && ./setup_echo_echo.sh <ロボット側ATOM Echoのポート> <PC側ATOM Echoのポート>
```

新品の機体に交換した時・初めてこのリポジトリをセットアップする時はこれを
実行すればよい(現行の実機ペア用に生成済みのヘッダも既にリポジトリに
入っているので、機体を交換しない限り省略可)。個別に行いたい場合は各
フォルダ内の`<ロボット側>/get_my_mac.sh`・`<ロボット側>/flash.sh`・
`atom_echo_pc/get_my_mac.sh`・`atom_echo_pc/flash.sh`をそれぞれ参照
(各READMEに詳細あり)。

`s3_wifi_captiv`構成はESP-NOWペアリングが無いため、AtomS3単体を書き込む
だけでよい:

```bash
cd s3_wifi_captiv/atoms3_wifi_captiv && ./flash.sh [ポート]   # 省略時 /dev/ttyACM0
```

### 3. M5StickVを左目・右目それぞれ書き込み(`s3_echo_with_I2C`構成のみ)

SDカードを挿した状態で実行すること(初回は発話用WAVクリップも`/sd/`へ
書き込むため数分かかる。2回目以降は`--skip-clips`でboot.pyのみ高速に
書き込める。詳細は`m5stickv/README.md`参照)。

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
(send *ri* :scan-m5stickv-i2c)     ;; s3_echo_with_I2C構成: 0x24/0x25が両方見えるか確認
(send *ri* :timer-on)              ;; s3_echo_with_I2C/s3_echo_bridge構成: IMU姿勢をPC(irtviewer)に表示
```

## 各USBポートの見分け方

複数のFTDI/USBシリアルが挿さっている環境では、`udevadm info -a -n /dev/ttyUSBn`
の`ATTRS{serial}`(個体ごとのシリアル番号)で区別するのが確実
(`atominterface.l`の`ttyusb-devnames`/`ttyusb-udev-attr`と同じ方法)。
AtomS3はネイティブUSB-CDCのため`/dev/ttyACMn`として見え、シリアル判別は不要。
