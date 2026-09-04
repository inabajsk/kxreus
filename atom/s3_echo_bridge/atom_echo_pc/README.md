# atom_echo_pc — PC側ATOM Echoファームウェア

ファイル: `atom_echo_voice_cmd_pc.ino`
書き込み: `./flash.sh [ポート]`(既定 `/dev/ttyUSB2`)

このフォルダ(`s3_echo_bridge/`)ではロボット側がAtomS3(簡易版、
`../atoms3_simple_robot/`)固定でペアリングする(このファームウェア自体は
`../../echo_echo/atom_echo_pc/`・`../../s3_echo_with_I2C/atom_echo_pc/`とも
共通、`.ino`は同一。ロボット側ごとに`atom_echo_pc/`のコピーを分け、それぞれ
ペアリング先固定の`get_my_mac.sh`/`robot_mac.h`を持つことで、複数機体の
混在を避けている)。

## 役割

PC(kxreus/euslisp)とUSBシリアルで繋がるATOM Echo。2つの仕事を持つ:

1. **RCB4コマンド中継(最優先)**: PCがUSBシリアルへ送ったバイト列を、
   そのままESP-NOW経由でロボット側(AtomS3)へ転送し、応答も同じ経路で
   PCへ返す。ロボット側から見るとRCB4が直結されているのと同じに見える
   透過ブリッジ。
2. **音声コマンド録音**: 前面ボタン(G39)を押すと、ロボット側で認識させる
   ための一言を録音してロボット側へ送る。

RCB4中継が最優先で、音声録音中でなければ毎ループRCB4バイトの有無を確認する
(`loop()`参照)。

## 音声コマンドの流れ

```
ボタン押下
  → 150ms 読み捨て(ボタン押下直後の電気的ノイズ対策)
  → 1000ms 本番録音(8kHz, 16bit, モノラル) を PKT_VOICE_AUDIO で逐次送信
  → 録音終了を PKT_VOICE_END で通知
  → (AtomS3側) Edge Impulseで認識 → 単語に対応する call-motion をRCB4へ送信
```

認識処理自体はPC側では行わず、生の音声をそのままロボット側へ送るだけ。
認識ロジック・対応単語・モデルの詳細は `../../edge_impulse/README.md` と
`../atoms3_simple_robot/README.md` を参照。

マイクの録音にはAGC(自動音量調整)やノイズゲートを掛けていない。生の振幅
変化(エネルギー包絡線)が認識モデルの特徴量になっているため、下手にゲインを
いじると認識精度が落ちるおそれがあるため。

## PEER_MAC の設定(重要)

`.ino`冒頭の

```cpp
#include "robot_mac.h"
static uint8_t PEER_MAC[6] = ROBOT_MAC_BYTES;
```

は相手(ロボット側AtomS3、簡易版)の固定MACアドレス。ESP-NOWは1対1で互いの
MACを決め打ちする構成のため、ロボット側を交換した場合は必ず更新が必要。
`robot_mac.h`は手書きせず、ロボット側AtomS3を実機接続した状態で以下を
実行すると自動生成される(内部で`esptool read-mac`を使う):

```bash
../atoms3_simple_robot/get_my_mac.sh <ポート>
```

生成後、このATOM Echoを`./flash.sh`で再書き込みすること。

同様に、ロボット側の`pc_mac.h`(`PEER_MAC`)もこのATOM Echoの実MACに合わせる
必要があり、`./get_my_mac.sh [ポート]`(既定`/dev/ttyUSB0`)で生成する:

```bash
./get_my_mac.sh /dev/ttyUSB0    # -> ../atoms3_simple_robot/atoms3_simple_robot/pc_mac.h
```

（詳細は`../atoms3_simple_robot/README.md`参照)。

両方を接続した状態なら`../setup_s3_echo_bridge.sh`で、双方のMAC取得・
コンパイル・書き込みを1回にまとめて行える。

## ハードウェア

| 項目 | 内容 |
| --- | --- |
| チップ | ESP32(無印)、USBは外付けFTDIチップ経由(VID:PID `0403:6001`) |
| 書き込みポート | `/dev/ttyUSBx`。複数挿さっている場合は`udevadm`のシリアル番号で識別 |
| 書き込み速度 | **`UploadSpeed=115200`が必須**。既定の高速書き込みだとFTDI経由では不安定(実機確認) |
| 実行時ボーレート | `Serial.begin(500000)`(RCB4-mini本体の通信速度とは無関係。PC⇔ATOM Echo間のUSBシリアル速度) |
| マイク | SPM1423(PDM)、DATA=G23, CLK=G33(スピーカーLRCKと共用) |
| スピーカー | NS4168、BCLK=G19, LRCK=G33, DOUT=G22 |
| ボタン | G39(押下でLOW) |
| RGB LED | SK6812、G27(緑=ESP-NOWリンクOK、赤=NG、紫=録音中) |
| ESP-NOW無線チャンネル | 1(固定) |

## RCB4中継の信頼性(ACK+再送)

ESP-NOWの無線層再送だけでは連続送信時に取りこぼしが起きることが実機で
確認されたため、アプリケーション層でシーケンス番号+ACK+タイムアウト再送
(stop-and-wait、最大`ACK_MAX_RETRY(30)`×`ACK_TIMEOUT_MS(25)`≈750ms)を
independentに実装している(`sendChunk()`)。RCB4のUARTフレームは1バイトの
欠落でも以降のチェックサムが全てずれるため、この層が無いと通信が容易に
壊れる。
