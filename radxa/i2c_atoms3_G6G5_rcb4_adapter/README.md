# i2c_atoms3_G6G5_rcb4_adapter — Radxa I2C(I2C_EE_M1) <-> RCB4-mini UART

Radxa Zeroの「I2C_EE_M1」ポートと、AtomS3のG1/G2(I2C)・G6/G5(RCB4-mini向け
UART)を使って、RadxaからRCB4-miniを直接制御できるようにするブリッジ。
`../../atom/atoms3_rcb4_adapter/`(PCがUSB経由でRCB4を叩く版)のI2C版で、
液晶表示・RCB4フレームのLEN/CMD/checksum検証も同様に踏襲している。

## 構成

```
Radxa Zero (I2C_EE_M1, マスター) --I2C--> AtomS3(スレーブ, G1=SCL/G2=SDA)
                                              |
                                         UART1(1.25Mbps, 反転)
                                              |
                                          RCB4-mini(G6=TX/G5=RX)
```

- `i2c_atoms3_G6G5_rcb4_adapter.ino` — AtomS3側ファームウェア。I2Cスレーブ
  として振る舞い、書き込まれたバイト列をそのままRCB4-mini向けUARTへ中継、
  RCB4からの応答は貯めておいてRadxaが読み出すたびに返す。
- `i2c_rcb4_bridge.py` — Radxa側の常駐デーモン。I2C経由でAtomS3と通信し、
  PTYを1つ作ってそのスレーブ側デバイスを`/dev/ttyRCB4-i2c`(既定)へ
  シンボリックリンクする。euslisp側は`:rcb4-open :devname`でこれを
  そのまま生ttyとして開ける(`s3_wifi_captiv`のsocat PTY,linkと同じ考え方)。
- `i2c-rcb4-bridge.service` — 上記デーモンを常駐させるsystemdユニットの
  ひな形。
- `setup.sh` — AtomS3ファームウェアのコンパイル・書き込み(arduino-cli自動
  導入込み、`../../atom/atoms3_rcb4_adapter/setup.sh`と同じ作り)。

## 配線

| AtomS3 | 相手 | 信号 |
| --- | --- | --- |
| G1 | Radxa I2C_EE_M1 | SCL |
| G2 | Radxa I2C_EE_M1 | SDA |
| G6 | RCB4-mini COM(一番奥) | TX(→RCB4 Rx) |
| G5 | RCB4-mini COM(GND隣) | RX(←RCB4 Tx) |
| GND | 両方 | 共通GND |

RCB4-mini COMコネクタのピン順(GND-Rx-Tx)・電圧レベルの注意点は
`../../atom_phone/atom_rcb4_bridge_kxrl4d/README.md`と同じなのでそちらを参照。

## 【重要】Radxa側のI2Cバス番号は未検証

「I2C_EE_M1」はRadxa Zeroのピンヘッダ上のラベルで、実際にLinux上で
`/dev/i2c-何番`に対応するかは**確認できていない**(機体・OSイメージの
device tree設定次第で変わりうる)。実機で必ず以下を確認してから使うこと。

```bash
i2cdetect -l                 # ラベルやアダプタ名から該当バスの番号(N)を探す
# ファームウェア書き込み後
i2cdetect -y <N>              # AtomS3のアドレス(既定0x08)が実際に見えるか確認
```

見つかったバス番号を、`i2c_rcb4_bridge.py --bus <N>`や
`i2c-rcb4-bridge.service`内の`--bus 3`(仮の値、要書き換え)に反映すること。

## I2Cワイヤプロトコル

- **書き込み(Radxa→AtomS3→RCB4)**: I2Cの1回の書き込みトランザクションに
  RCB4向け生フレーム(`[length,opcode,...,checksum]`)をラッパー無しで
  そのまま乗せる。RCB4フレーム自体が先頭バイトに全長を持つため、追加の
  枠組みは不要(`../../atom_phone/atom_rcb4_bridge_kxrl4d/`系と同じく、プロトコルの
  中身の解釈はしない)。
- **読み出し(RCB4→AtomS3→Radxa)**: I2Cの読み出しは常に固定64バイト。
  内訳は`[有効バイト数(1byte)][データ(最大63byte、残りは0埋め)]`。
  1回で収まらない場合は次の読み出しに持ち越される。
- SMBusのブロック転送(`i2c_smbus_read/write_block_data`)は1回32byteまで
  という制限があり、RCB4フレーム(最大255byte)を丸ごとは乗せられないため、
  `smbus2`の`i2c_msg`(SMBusを介さない生のI2Cメッセージ)を使っている。

## 依存パッケージ(Radxa側)

```bash
pip3 install smbus2
```

## 使い方

### 1. AtomS3ファームウェア書き込み

```bash
cd ~/kxreus/radxa/i2c_atoms3_G6G5_rcb4_adapter
./setup.sh /dev/ttyACM0
```

### 2. ブリッジデーモンを起動(手動、動作確認用)

```bash
python3 i2c_rcb4_bridge.py --bus <i2cdetectで確認した番号>
```

`pty=... link=/dev/ttyRCB4-i2c`のような行が出れば起動成功。

### 3. euslisp側から接続

Radxa本体でeuslispを動かす前提(このデーモンはRadxa上の`/dev/i2c-N`を
直接叩くため)。

```lisp
(load "rcb4robots.l")
(load "atominterface.l")
(send *ri* :rcb4-open :devname (start-i2c-rcb4-bridge :bus <番号>))
(send *ri* :timer-on)
```

`start-i2c-rcb4-bridge`は`i2c_rcb4_bridge.py`をバックグラウンドで起動し、
起動ログの1行目を確認した上で`:devname`にそのまま渡せる文字列
(`"ttyRCB4-i2c"`)を返す。

### 4. 常駐化(systemd)

```bash
sudo cp i2c-rcb4-bridge.service /etc/systemd/system/
sudo sed -i 's#--bus 3#--bus <実際の番号>#' /etc/systemd/system/i2c-rcb4-bridge.service
sudo systemctl daemon-reload
sudo systemctl enable --now i2c-rcb4-bridge
```

常駐化した場合、euslisp側は`start-i2c-rcb4-bridge`を呼ばずに直接
`:rcb4-open :devname "ttyRCB4-i2c"`でよい。

## 液晶表示

`../../atom/atoms3_rcb4_adapter/`と同様、起動時に配線早見表を表示し、
通信中は緑の■、RCB4フレームのLEN/CMD(正常時は緑/オレンジ、
checksum不一致またはLEN不正な異常フレームは赤)を随時更新表示する。
