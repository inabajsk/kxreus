# AtomS3(液晶付き)を RCB4-mini 用 USB Dual Adapter の代わりにする(液晶表示版)

`../atom_rcb4_bridge/`(バイト中継専用、液晶なしATOMでも書き込める素の版)を
ベースに、AtomS3の液晶へ配線早見表・通信中インジケータ・RCB4コマンドの
LEN/CMD/checksum検証結果を表示する機能を追加した版。

**液晶の無いプレーンなATOM(ATOM Lite/Matrixなど)には書き込めない。**
その場合は `../atom_rcb4_bridge/` を使うこと。

配線・対象ハードウェア・PC側(kxreus)の設定・トラブルシューティングは
`../atom_rcb4_bridge/README.md` と共通なのでそちらを参照。以下はこの版で
追加した液晶表示機能についてのみ記す。

## 液晶表示

起動時(静止部分、1回だけ描画):

```
RCB4          <- タイトル(黄色, 大きめ)
Grove
GND,G1,G2
-> RCB4       <- シアン色
GND,RX,TX2
```

通信中(可変部分、loop()で随時更新):

```
RCB4: ■        <- 緑=直近200ms以内に通信あり、灰色=無し
L=3  C=253     <- 直近のRCB4コマンドのLEN/CMD(緑/オレンジ=正常、赤=異常)
```

- **LEN/CMD**: RCB4のコマンド形式(PC→RCB4方向)は
  `[LEN][CMD]...ボディ...[checksum]` で、LENはこのフレーム全体の
  バイト数(LEN自身とchecksumも含む)、CMDはコマンド番号。この2バイトを
  覗き見て表示する。
- **checksum検証**: `~/kxreus/rcb4asm.l` の `rcb4-checksum` と同じ計算式
  (LENからchecksum直前までの総和の下位8bit)で検証し、最後の1バイトと
  一致するか確認する。一致しない場合、またはLENが3未満(LEN・CMD・
  checksumの最低3バイトすら無い)場合は、RCB4コマンドフォーマット違反と
  みなして`L=... C=...`の表示を赤色にする。
- この検証・表示はあくまで覗き見であり、**中継処理自体(PC⇔RCB4間の
  バイト転送)には一切影響しない**。フォーマット違反のデータもそのまま
  RCB4へ転送される(PC側で意図的に不正なデータを送った場合の動作確認や、
  配線・ノイズ由来の化けをその場で見つけるための表示専用機能)。

## IMU予約OPCODE(0x90)

`../s3_echo_bridge/atoms3_simple_robot/`と同じプロトコルで、AtomS3内蔵IMU
(MPU6886)の値をRCB4の予約OPCODE経由で返す機能を持つ。RCB4の実オペコードは
0x0-0x12,0xFD,0xFEで使用済みのため、0x90はIMU読み出し用に予約している。

```
リクエスト: [0x03, 0x90, 0x93]  (checksum=(3+0x90)&0xFF=0x93)
応答:       [0x0F, 0x90,
             ax_lo,ax_hi, ay_lo,ay_hi, az_lo,az_hi,   (加速度 int16 LE, milli-g)
             gx_lo,gx_hi, gy_lo,gy_hi, gz_lo,gz_hi,   (角速度 int16 LE, 0.1deg/s)
             checksum]
```

このリクエストだけは実RCB4へ転送せず、AtomS3が横取りしてIMU値を返す。
euslisp側`(send *ri* :timer-on)`はこの値でロボットモデルの姿勢を表示する
(`atominterface.l`参照)。他の中継処理と同様、PCから来た1回のUSB読み出し
チャンクが正確にこの3バイトと一致した場合だけ横取りする(それ以外は
通常通りそのままRCB4へ転送する)。

## 取り付け向き(液晶回転・IMUの軸)

液晶の天地(`MOUNTED_UPSIDE_DOWN`、既定`false`、実機確認済み)とIMUの
向き補正は無関係(実機確認の結果、連動していなかった)。

IMU側は当初「Z軸の符号だけ反転する」実装にしていたが、これは物理的に
あり得ない鏡映変換(行列式-1)で、実機で試すと`:timer-on`中に
Madgwickフィルタが不安定になり振動する不具合が出た。実機で
`(send *ri* :read-imu)`の生値を複数姿勢(通常・前傾・後傾)で採取した
ところ、この構成はESP-NOW版`../s3_echo_bridge/atoms3_simple_robot/`に
対してX軸まわり90度ぶん、センサのY軸とZ軸の役割が入れ替わっている
(X軸はロール軸として共通)ことが分かったため、Y/Zを入れ替えつつ片方を
反転する、行列式+1の正しい回転に直した(`IMU_YZ_SIGN`、ジャイロも
同じ回転で変換する)。

- `IMU_YZ_SIGN`(既定`1`): `:timer-on`中にirtviewerで見えるロボットの
  前後の傾きが実機と逆(前傾させると後ろに反る等)に見える場合は`-1`に
  すること(90度回転の向きがもう片方になる。どちらの値でも行列式+1の
  正しい回転になるようにしてあるので、符号を変えても振動は起きないはず)。

## ファイル

| ファイル | 内容 |
| --- | --- |
| `atoms3_rcb4_adapter.ino` | 本体(液晶表示付きブリッジファームウェア) |
| `setup.sh` | コンパイル+書き込み一括スクリプト。`./setup.sh [ポート]`(省略時 `/dev/ttyACM0`) |

## 書き込み方法

```bash
cd ~/kxreus/atom/atoms3_rcb4_adapter
./setup.sh /dev/ttyACM0
```
