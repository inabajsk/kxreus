# atoms3_simple_robot — ロボット側AtomS3ファームウェア(簡易版・I2C無し)

ファイル: `atoms3_simple_robot.ino`
書き込み: `./flash.sh [ポート]`(既定 `/dev/ttyACM0`)

`../../s3_echo_with_I2C/atom_s3_robot/`(I2C拡張版)からM5StickV用I2Cブリッジを
外し、RCB4 UARTをGrove(HY2.0-4P)コネクタ(G1/G2)へ戻した簡易版。腕や
M5StickVカメラを持たない機体で、IMUによる姿勢表示とRCB4無線化さえできれば
よい場合の、配線が最小限(Groveケーブル1本)で済む構成。

## 役割

ロボット本体に搭載するAtomS3。3つの役割を持つ:

1. PC側ATOM Echo(`../atom_echo_pc/`)とESP-NOWで通信し、受けたRCB4コマンドを
   実RCB4へUART中継、RCB4からの応答もESP-NOW経由でPCへ返す(最優先処理)。
2. 内蔵IMU(MPU6886)の値を、RCB4の未使用オペコード(0x90)を横取りする形で
   読み出せるようにする。euslisp側`(send *ri* :timer-on)`はこの値を使って
   ロボットモデルの姿勢をMadgwickフィルタ経由でPC(irtviewer)に表示する
   (`atominterface.l`参照)。
3. PC側ATOM Echoから送られてくる音声データを受け取り、Edge Impulseの
   キーワード認識モデルで単語を判定し、対応する`call-motion`をRCB4へ直接
   送信する(euslisp/PCを介さず、AtomS3単体で完結)。

(I2C拡張版にあったM5StickVとのI2Cブリッジ(予約オペコード0x91)は無い。)

## 配線(ピン割り当て)

| 用途 | ピン | 備考 |
| --- | --- | --- |
| RCB4 UART TX | G2 | Grove(HY2.0-4P)コネクタ。はんだ付け不要 |
| RCB4 UART RX | G1 | 同上 |
| RCB4 UART ボーレート | 1,250,000bps | `SERIAL_8E1`(8bit, Even parity, 1 stop)。RCB4-mini側の仕様通り |
| RCB4 UART 論理反転 | TX/RX共に反転 | `HardwareSerial.begin()`のinvert引数はESP32-S3で不安定なため、`begin(invert=false)`後に`uart_set_line_inverse()`で個別設定(実機確認) |
| RCB4 UART RXバッファ | 4096byte | 既定(~256byte)だとESP-NOW中継のACK待ち(最大750msブロック)中にオーバーフローし、`call-motion`実行時などにバイト欠落が起きた(実機確認、2026.8)。`setRxBufferSize()`は`begin()`より前に呼ぶ必要がある |
| 内蔵IMU(MPU6886) I2C SDA | G38 | 内蔵配線 |
| 内蔵IMU I2C SCL | G39 | 内蔵配線 |
| LCD | G15,G16,G17,G21,G33,G34 | 内蔵、状態表示専用 |

```
ATOMS3 (GND, G2(TX), G1(RX)) -> RCB4 UART COM 3pin (GND, RX, TX)
```

RCB4-miniのCOMコネクタのピン順は「GND-Rx-Tx」(GND側から。HeartToHeart4
マニュアル準拠)。

## RCB4-mini本体への接続

RCB4-mini側のCOMコネクタ(GND-Rx-Tx)と、AtomS3のG1(RX)/G2(TX)/GNDを
対応する信号同士で結線する(RCB4のTx→AtomSのRX=G1、RCB4のRx→AtomSのTX=G2、
GND同士)。電圧レベルは双方3.3V系で直結可(実機確認、I2C拡張版と共通)。

## RCB4予約オペコード(実RCB4には存在しない、このファームウェア独自の拡張)

RCB4の実オペコードは`0x00`-`0x12`,`0xFD`,`0xFE`で使用済み。以下の未使用値を
「PCから来たRCB4コマンド列を実RCB4へ転送する前に横取りする」ために予約している
(euslisp側は`atominterface.l`の対応メソッドがこのプロトコルで送受信する)。

### 0x90: IMU読み出し

- リクエスト: `[0x03, 0x90, 0x93]`
- 応答: `[0x0F, 0x90, ax,ay,az(各int16LE, milli-g), gx,gy,gz(各int16LE, 0.1deg/s), checksum]`

## Edge Impulse音声コマンド認識

`#include <kxr-voice-commands_inferencing.h>`(`../../edge_impulse/`のライブラリを
`flash.sh`が初回のみ`~/Arduino/libraries/`へコピーしてから通常のライブラリ
解決に任せる。`--library`で直接指定すると`~/Arduino/libraries/`に既に同名の
ライブラリがある場合に競合しESP-NNのビルドキャッシュが壊れてリンクエラーに
なることを実機確認したため、この方式にしている)。PC側ATOM Echoから受けた8kHz/
1000ms分のPCM(`EI_CLASSIFIER_RAW_SAMPLE_COUNT=8000`)を`run_classifier()`に
渡し、最も確信度の高いラベルが閾値(`CONFIDENCE_THRESHOLD=0.6`)以上なら
対応する`call-motion`をRCB4へ直接送信する(`sendCallMotion()`、ROM上の
モーションアドレス`0x0B80 + n*2048`を`CALL`命令で呼ぶ)。

| ラベル | call-motion番号 |
| --- | --- |
| aisatsu(挨拶) | 20 |
| mae(前) | 0 |
| ushiro(後) | 1 |
| hidari(左) | 2 |
| migi(右) | 3 |
| noise | (動作なし) |

単語を増やす・認識率を上げる方法は `../../edge_impulse/README.md` を参照。

## ESP-NOWペアリング

`.ino`冒頭は

```cpp
#include "pc_mac.h"
static uint8_t PEER_MAC[6] = PC_MAC_BYTES;
```

`pc_mac.h`は手書きせず、PC側ATOM Echoを実機接続した状態で
`../atom_echo_pc/get_my_mac.sh`を実行すると自動生成される
(内部で`esptool read-mac`を使う)。生成後、このAtomS3を`./flash.sh`で
再書き込みすること。無線チャンネルは1固定。

両方を接続した状態なら、`../setup_s3_echo_bridge.sh`で双方のMAC取得・
コンパイル・書き込みを1回にまとめて行える。

## LCD表示

画面上端に`LINK OK/NG`(ESP-NOWリンク)と`RCB4 OK/NG/--`(RCB4 UART中継、
IDLE/OK/NG の3状態、直近の送受信タイミングから判定)を常時表示。音声認識時は
認識ラベル・信頼度・実行モーション番号を画面全体に表示する。取り付け向きに
応じて180度回転させたい場合は`.ino`の`setup()`内コメント参照。
