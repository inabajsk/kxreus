# m5stickv — 両目カメラ(K210/MaixPy)ファームウェア

ファイル: `object_detection_I2C_slave.py`(左目・右目で共通、1行だけ違う)
書き込みツール: `maixpy_upload.py`(MicroPythonのraw REPL経由でboot.pyとして転送)
書き込み: `./flash.sh <ポート> [0x24|0x25]`

## 左目・右目の違い

9行目付近の`I2C_INDEX`がI2Cスレーブアドレスであり、これが左目/右目の唯一の
違い。`flash.sh`が書き込み直前にこの1行を書き換える。

| 目 | I2C_INDEX | 画面レイアウト | 発話の前置き |
| --- | --- | --- | --- |
| 左目 | 0x24 | 左上に情報表示 | 「左目で」 |
| 右目 | 0x25 | 右上に情報表示(180度回転取り付けのためX/Y反転あり) | 「右目で」 |

右目は機体取り付けが左目に対し180度回転しているため、座標のミラー処理
(左右反転)や行順(FLIP_Y)を左目と逆にする実機確認済みの補正が入っている
(ソース479行目以降のコメント参照)。

## 接続方法

AtomS3(`../atom_s3_robot/`)の外部Grove I2C(G1=SCL/G2=SDA、100kHz)に、
I2Cハブ経由で左目・右目2台を**並列に**接続する。M5StickV側はMaixPy内部で
`I2C.I2C0`をSCL=34/SDA=35のスレーブモードで初期化しており(ソース内`I2C()`
呼び出し参照)、この2線がGroveケーブル経由でAtomS3側と直結される。両目とも
同じ2線に繋がり、スレーブアドレス(0x24/0x25)で区別される。

## 機能概要

- **AprilTag検出**: `find_apriltags()`。タグの4隅座標・ID・信頼度を返す。
- **ルービックキューブ発見**: 色ブロブのクラスタリング(Union-Find)+面ごとの
  グルーピング。背景クラッタ対策の適応的Lab色許容幅拡大
  (`CUBE_ADAPTIVE_TOL_STEPS`)と、性能保護のためのブロブ数上限
  (`MAX_TOTAL_BLOBS=32`)、肌色除外(`_looks_like_skin`)を実装。
- **キューブ姿勢推定補助**: `find_rects()`によるステッカー矩形検出のオーバーレイ表示。
- **音声合成**: I2S経由でWAVクリップを再生(後述)。
- **ニューラルネットワーク物体検出・色物体検出**: 旧来からの機能(下記レジスタ表参照)。

## 音声出力(I2S)

K210公式サンプル(M5StickV-Maixpy.md「Mic Record and Speaker Play」)準拠の
設定で、以下がすべて揃わないと**エラーも出さず無音になるか、悪くすると
メインループが完全にハングする**(実機確認、要注意点):

- `I2S(I2S.DEVICE_1)`(`DEVICE_0`はマイク用、間違えないこと)
- `board_info.SPK_DIN` を `fm.fpioa.I2S1_OUT_D1` に登録(**D1**。D0ではない)
- `board_info.SPK_SD`(アンプ有効化ピン)をHighに駆動
- `player.play_process(wav_dev)` を **`wav_dev.channel_config(...)`より先に**呼ぶ

## SDカード上の発話クリップ(重要)

発話音声そのものは`boot.py`(=`object_detection_I2C_slave.py`)には含まれず、
M5StickVに挿したSDカード上の`/sd/*.wav`(16bit/44100Hz/モノラル)を
`audio.Audio(path=...)`で再生する方式(ソース内`SPEAK_CLIPS`/`DIGIT_CLIPS`/
`JUU_CLIP`/`HYAKU_CLIP`/`APRILTAG_FOUND_CLIP`/`BAN_DESU_CLIP`/
`EYE_PREFIX_CLIP`参照)。このリポジトリでは`sd_clips/`にWAV本体を同梱して
いるので、`./flash.sh <ポート> [0x24|0x25]`を実行すると**boot.pyの書き込みに
加えて`sd_clips/`の全WAVも`/sd/`へ自動で書き込まれる**(SDカードが挿さって
いる前提)。

WAVクリップは17個(左目/右目の前置き2個・キューブ発見/挨拶2個・数字読み上げ用
`d1`〜`d9`・`juu`(十)・`hyaku`(百)・AprilTag発見・「番です」)あり、
`maixpy_upload.py`はポートを開くたびに実機を再起動して割り込む都合上、
全部書き込むと1回のflashに数分かかる。SDカードに一度書き込めば以後は
`./flash.sh <ポート> [0x24|0x25] --skip-clips`でboot.pyだけを素早く
書き込める(クリップを追加・差し替えた時だけ`--skip-clips`無しで実行し直す)。

## I2Cレジスタマップ

### 基本(旧来からの物体検出用)

| アドレス | 内容 |
| --- | --- |
| 0x00 | コントロールレジスタ(`ADDR_CTRL_REG`) |
| 0x01 | オブジェクトデータの長さ |
| 0x02-0xFC | オブジェクトデータ本体(`ADDR_OBJ_DATA`、最大252byte。0xFD-0xFFは下記の拡張用に予約) |

#### コントロールレジスタ(0x00)のビット

| ビット | 値 | 備考 |
| --- | --- | --- |
| 0 | oneshot_record | 1で画像を保存(保存後自動的に0へ戻る) |
| 1 | led | 1でLED点灯 |
| 2 | nn_en | ニューラルネットワーク認識の有効化 |
| 3 | apriltag_en | AprilTag認識の有効化 |
| 4 | red_en | 赤色物体認識の有効化 |
| 5 | green_en | 緑色物体認識の有効化 |
| 6 | april3d_en | (2026.8追加) |
| 7 | cube_face_en | (2026.8追加、ルービックキューブ面認識) |

#### オブジェクトデータ本体のフォーマット

座標値はすべてVGA(640x480)の100倍にスケール。認識種別(detection_type)は
NN=0, AprilTag=1, 色物体=2/3。

- ニューラルネットワーク(11byte): `detection_type, bbox(x,y,w,h各int16LE), confidence, クラスID`
- AprilTag(20byte): `detection_type, コーナー0-3(x,y各int16LE), タグID(int16LE), confidence`
- 色物体(9byte): `detection_type, bbox(x,y,w,h各int16LE)`

### 拡張レジスタ(2026.8追加、音声・キューブ発見の有効/無効制御)

`atominterface.l`の0x91オペコード subcmd=3(WRITE_REG)経由でPCから読み書きする。

| アドレス | 名前 | 意味 | 既定値 |
| --- | --- | --- | --- |
| 0xFD | `ADDR_CUBE_DISCOVERY_ENABLE` | キューブ発見パイプライン全体のON/OFF | 1(ON) |
| 0xFE | `ADDR_SPEAK_ENABLE` | 発話の有効/無効(ビット単位でキューブ/面/AprilTag) | 0x07(全ON) |
| 0xFF | `ADDR_SPEAK_CMD` | 発話番号を書き込むと該当クリップを再生(1始まり) | - |

## 実機書き込みの注意

`maixpy_upload.py`はポートを開くとDTRトグルでボードがリセットされる仕様
(MicroPythonのraw REPL特有)。カメラ未接続等でboot.py側がブロックする
処理に入っていてもハングしないよう、ポートを開いた直後からCtrl-Cを
連続送信し続けて割り込む方式になっている(詳細はスクリプト内コメント参照)。
