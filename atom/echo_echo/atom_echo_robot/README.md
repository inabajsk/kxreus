# atom_echo_robot — ロボット側ATOM Echoファームウェア(プレーン版・音声コマンド対応)

ファイル: `atom_echo_voice_cmd_robot/atom_echo_voice_cmd_robot.ino`
書き込み: `./flash.sh <ポート>`(既定値なし、必ずポートを指定)
MAC取得: `./get_my_mac.sh <ポート>`

対になるPC側ファームウェアは`../atom_echo_pc/`(AtomS3構成と共通。後述)。

## 位置づけ(AtomS3版との違い)

`../../s3_echo_with_I2C/atom_s3_robot/`(AtomS3)がIMU内蔵・M5StickV用I2Cを
持つのに対し、こちらはロボット側にAtomS3ではなく**もう1台のATOM Echo**を
使う、より安価・小型な構成。IMUもM5StickV用I2Cも無い代わりに、4脚・6脚など
**腕もM5StickVも載せず、とにかく無線でRCB4を操作したいだけのロボット**に
向いている。

**腕やM5StickVを載せない機体であっても**、姿勢による転倒検知・傾き補正など
**IMUが必要な用途では、ATOM EchoにはIMUが無いためAtomS3構成
(`../../s3_echo_with_I2C/`または`../../s3_echo_bridge/`)の方が適している**。
こちらは「無線化だけできればよい」場合の軽量な選択肢という位置づけ。

## 音声コマンド機能: AtomS3版と同じEdge Impulseモデルを使用(2026.8)

PC側ATOM Echo(`../atom_echo_pc/`)のボタンを押すと録音した約1秒の
音声がESP-NOW経由で送られてくると、AtomS3版と全く同じEdge Impulseモデル
(`../../edge_impulse/`)で単語認識し、一致すればRCB4-miniへcall-motion
コマンドを直接送って実際に動かす。

以前は自作の簡易テンプレートマッチング方式で、書き込み直後は毎回シリアル
経由で単語を学習させる必要があった(電源を切ると学習結果が消えるため
使い勝手が悪かった)が、Edge Impulseの事前学習済みモデルに変更したことで
**書き込み直後から学習不要で動作する**。認識ロジック自体はAtomS3版と全く
同じ(`signal_t`/`run_classifier()`呼び出し・ラベル→motion対応)で、
AtomS3には無いもの(LCD表示)だけRGB LED+スピーカーの合図に置き換えている。

ESP32-S3向けのESP-NN高速化カーネルは素のESP32(ATOM Echo)では使えないため
汎用カーネルにフォールバックする(Edge Impulse SDK側で自動的に切り替わる。
実機コンパイルで確認済み、フラッシュ1041237byte(33%)/RAM 65464byte(19%)、
問題なく収まる)。単語登録・学習方法・単語一覧・モデルの再学習方法は
`../../edge_impulse/README.md`参照。

### 【重要】run_classifier()は別FreeRTOSタスク(別コア)で実行している

高速化カーネルが使えない分、`run_classifier()`のブロック時間がAtomS3より
長くなるため、`loop()`内で直接呼ぶと、その間RCB4Serialの読み出し・ESP-NOW
中継が止まり、`:timer-on`でポーリング中にPC側ボタンで発話するとRCB4との
通信が乱れる不具合が実機で確認された。対策として`run_classifier()`は
`classifyTask()`という別タスクへ切り出し、コア0にpinして実行することで
`loop()`(コア1、RCB4/ESP-NOW中継担当)を絶対にブロックしないようにして
ある。ハードウェアアクセス(RCB4Serial/esp_now_send/I2S)は`loop()`側だけに
限定し、`classifyTask`は純粋な計算だけを行って結果をvolatile変数経由で
渡す(`serviceClassifyResult()`参照)。分類中(`classifyBusy`)は新しい発話の
録音を受け付けない(認識は短時間で終わるため実用上問題にならない想定)。

### motion番号の対応

`call-motion`はRCB4のROM上のモーションテーブル(0x0B80番地から2048byte毎、
120スロット)を呼び出すCALL命令を直接組み立てて送るだけ(モーションデータ
自体は送らない。KXRL2Gの標準プロジェクトが書き込み済みであることが前提)。

| 番号 | 単語 | スロット |
| --- | --- | --- |
| ラベル | call-motion番号 |
| --- | --- |
| aisatsu(挨拶) | 20 |
| mae(前) | 0 |
| ushiro(後) | 1 |
| hidari(左) | 2 |
| migi(右) | 3 |
| noise | (動作なし) |

## ハードウェア

| 項目 | 内容 |
| --- | --- |
| チップ | ESP32(無印)、USBは外付けFTDIチップ経由(VID:PID `0403:6001`) |
| 書き込み速度 | `UploadSpeed=115200`が必須(既定の高速だと不安定) |
| RCB4-mini接続 | Grove(Port A): TX=G26, RX=G32, 1250000bps |
| マイク | このファームウェアでは未使用(音声は全てPC側から受信) |
| スピーカー | NS4168、BCLK=G19, LRCK=G33, DOUT=G22(識別音・状態音用) |
| ボタン | G39(押下でLOW)。押すと識別音を鳴らすだけの補助機能 |
| RGB LED | SK6812、G27(LINK状態表示) |
| ESP-NOW無線チャンネル | 1(固定) |

## RCB4中継プロトコル(ACK付き、AtomS3構成と共通・2026.8統一)

AtomS3版と同じ、シーケンス番号+ACK+タイムアウト
再送プロトコル([PKT_DATA, seq, data...] + `PKT_DATA_ACK`応答)。ESP-NOWの
無線層再送だけでは大量連続送信時に取りこぼしが起きることが実機で判明した
ための対策で、以前はこのファイルだけプレーン版(seq/ACK無し)だったが、
PC側を`../atom_echo_pc/`(AtomS3向けと共通のACK付き版)に統一したのに
合わせてこちらもACK対応にした。ACK待ちで最大`ACK_MAX_RETRY(30)×
ACK_TIMEOUT_MS(25)`≈750msブロックしうるため、その間にRCB4からの応答で
UART受信バッファが溢れないよう`RCB4Serial.setRxBufferSize(4096)`も
入れてある(AtomS3側と同じ対策)。

## PEER_MACの設定

`.ino`冒頭は

```cpp
#include "pc_mac.h"
static uint8_t PEER_MAC[6] = PC_MAC_BYTES;
```

`pc_mac.h`は手書きせず、PC側ATOM Echoを実機接続した状態で
`../atom_echo_pc/get_my_mac.sh <ポート>`を実行すると自動生成される。
生成後、このロボット側ATOM Echoを`./flash.sh`で再書き込みすること。

両方を接続した状態なら、`../setup_echo_echo.sh`で双方のMAC取得・コンパイル・
書き込みを1回にまとめて行える。
