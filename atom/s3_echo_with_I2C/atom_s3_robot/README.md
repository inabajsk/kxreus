# atom_s3_robot — ロボット側AtomS3ファームウェア(I2C拡張版)

ファイル: `atoms3_i2c_robot.ino`
書き込み: `./flash.sh [ポート]`(既定 `/dev/ttyACM0`)

## 役割

ロボット本体に搭載するAtomS3。4つの役割を持つ:

1. PC側ATOM Echo(`../atom_echo_pc/`)とESP-NOWで通信し、受けたRCB4コマンドを
   実RCB4へUART中継、RCB4からの応答もESP-NOW経由でPCへ返す(最優先処理)。
2. 内蔵IMU(MPU6886)の値を、RCB4の未使用オペコード(0x90)を横取りする形で
   読み出せるようにする。
3. 外部Grove I2Cに繋がる2台のM5StickV(`../../m5stickv/`)とのI2Cブリッジ
   (RCB4未使用オペコード0x91)。
4. PC側ATOM Echoから送られてくる音声データを受け取り、Edge Impulseの
   キーワード認識モデルで単語を判定し、対応する`call-motion`をRCB4へ直接
   送信する(euslisp/PCを介さず、AtomS3単体で完結)。

## 配線(ピン割り当て)
| 用途 | ピン | 備考 |
| --- | --- | --- |
| RCB4 UART TX | G6 | 基板底面の拡張用GPIOパッド(はんだ付け。Groveコネクタではない) |
| RCB4 UART RX | G5 | 同上 |
| RCB4 UART ボーレート | 1,250,000bps | `SERIAL_8E1`(8bit, Even parity, 1 stop)。RCB4-mini側の仕様通り |
| RCB4 UART 論理反転 | TX/RX共に反転 | `HardwareSerial.begin()`のinvert引数はESP32-S3で不安定なため、`begin(invert=false)`後に`uart_set_line_inverse()`で個別設定(実機確認) |
| RCB4 UART RXバッファ | 4096byte | 既定(~256byte)だとESP-NOW中継のACK待ち(最大750msブロック)中にオーバーフローし、`call-motion`実行時などにバイト欠落が起きた(実機確認、2026.8)。`setRxBufferSize()`は`begin()`より前に呼ぶ必要がある |
| 内蔵IMU(MPU6886) I2C SDA | G38 | 内蔵配線 |
| 内蔵IMU I2C SCL | G39 | 内蔵配線 |
| 外部I2C(M5StickV用) SDA | G2 | Grove(HY2.0-4P)コネクタ。無印AtomS3のボード定義でSDA=G2 |
| 外部I2C(M5StickV用) SCL | G1 | Grove(HY2.0-4P)コネクタ。無印AtomS3のボード定義でSCL=G1 |
| 外部I2Cクロック | 100kHz | `Wire.setClock(100000)` |
| LCD | G15,G16,G17,G21,G33,G34 | 内蔵、状態表示専用 |

ATOMS3 (GND, G6(TX), G5(RX)) -> RCB4 UART COM  3pin (GND, RX, TX)
ATOMS3 (GND, 5V, G2(SDA), G1(SCL)) -> I2C Hub -> M5StickV Grove(I2C address 0x24)
ATOMS3 (GND, 5V, G2(SDA), G1(SCL)) -> I2C Hub -> M5StickV Grove(I2C address 0x25)

RCB4-miniのCOMコネクタのピン順は「GND-Rx-Tx」(GND側から。HeartToHeart4
マニュアル準拠)。

## RCB4-mini本体への接続

RCB4-mini側のCOMコネクタ(GND-Rx-Tx)と、AtomS3のG5(RX)/G6(TX)/GNDを
対応する信号同士で結線する(RCB4のTx→AtomSのRX=G5、RCB4のRx→AtomSのTX=G6、
GND同士)。電圧レベルは双方3.3V系で直結可(実機確認)。

## M5StickV(左目0x24/右目0x25)への接続

外部Grove I2C(G1=SCL/G2=SDA)にI2Cハブ経由で2台のM5StickVを並列に繋ぐ
(両方とも同じ2線に繋がり、I2Cスレーブアドレス0x24/0x25で区別される)。
M5StickV側の配線・レジスタ仕様は `../../m5stickv/README.md` 参照。

## RCB4予約オペコード(実RCB4には存在しない、このファームウェア独自の拡張)

RCB4の実オペコードは`0x00`-`0x12`,`0xFD`,`0xFE`で使用済み。以下の未使用値を
「PCから来たRCB4コマンド列を実RCB4へ転送する前に横取りする」ために予約している
(euslisp側は`atominterface.l`の対応メソッドがこのプロトコルで送受信する)。

### 0x90: IMU読み出し

- リクエスト: `[0x03, 0x90, 0x93]`
- 応答: `[0x0F, 0x90, ax,ay,az(各int16LE, milli-g), gx,gy,gz(各int16LE, 0.1deg/s), checksum]`

### 0x91: M5StickV I2Cブリッジ

リクエスト: `[length, 0x91, i2c_addr, subcmd, (追加引数...), checksum]`

| subcmd | 意味 | 追加引数 | 応答 |
| --- | --- | --- | --- |
| 0 | READ | なし | `[len,0x91,addr,0,i2c_ok,データ長,データ...,cksum]`(M5StickV側reg0x01→0x02...を読む) |
| 1 | WRITE(制御レジスタ固定) | value | `[len,0x91,addr,1,i2c_ok,cksum]`(reg0x00へvalue書き込み) |
| 2 | SCAN | なし | `[len,0x91,0,2,count,addr...,cksum]`(バス上の生存アドレス一覧) |
| 3 | WRITE_REG(任意レジスタ) | regAddr, value | `[len,0x91,addr,3,i2c_ok,cksum]`(2026.8追加。ADDR_SPEAK_ENABLE等、0x00以外への書き込み用) |

`i2c_ok`はそのアドレスへのI2Cトランザクション自体が成功したか(ACK=1/NACK=0)。

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

両方を接続した状態なら、`../setup_s3_echo.sh`で双方のMAC取得・コンパイル・
書き込みを1回にまとめて行える。

## LCD表示

画面上端に`LINK OK/NG`(ESP-NOWリンク)と`RCB4 OK/NG/--`(RCB4 UART中継、
IDLE/OK/NG の3状態、直近の送受信タイミングから判定)を常時表示。音声認識時は
認識ラベル・信頼度・実行モーション番号を画面全体に表示する。ロボットへの
取り付けが上下逆さのため、表示は180度回転させてある。
