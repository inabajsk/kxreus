# ATOM(AtomS3) を RCB4-mini 用 USB Dual Adapter の代わりにする

近藤科学 KXR の制御ボード RCB4-mini に、M5Stack ATOM(AtomS3系, ESP32-S3, USB-C)を
USBシリアル変換アダプタとして接続し、純正「USB Dual Adapter HS」の代わりに使うための
配線・ファームウェア・PC側サンプル・kxreus連携方法をまとめる。

実機(ATOM 2台、RCB4-mini 搭載ロボット)で動作確認済み。

## 対象ハードウェア

- ATOM: M5Stack AtomS3 / AtomS3 Lite 系(ESP32-S3、USB-C、ネイティブUSB-CDC)
  - Arduino board (arduino-cli): `m5stack:esp32:m5stack_atoms3`
  - USBデバイスとして `303a:1001`(Espressif USB JTAG/serial debug unit)で認識される
- RCB4-mini(近藤科学 KXR用制御ボード)
  - COMポート: ZHコネクタ、最大1.25Mbps、信号レベル 0V(LOW)/5V(HIGH) の**反転UART**
  - 出典: `HeartToHeart4ユーザーズマニュアル`(`HTH4_Ver6-20160712.pdf`)

## 配線

RCB4-mini の COM コネクタは、GND側から **GND - Rx - Tx** の順(マニュアル記載の図より)。
ATOM(AtomS3)の Grove ポート(Port A)は **G1 / G2**。

| RCB4-mini COM | 信号        | ATOM(AtomS3) |
|---------------|-------------|--------------|
| GND           | 共通GND     | GND          |
| Rx (GND隣)     | RCB4の受信  | **G2**       |
| Tx (一番奥)    | RCB4の送信  | **G1**       |

- **ATOMは G2 で送信、G1 で受信する**(ATOMのTXがRCB4のRxへ、ATOMのRXがRCB4のTxへ、という通常のクロス接続)。
- **電源線(5V)は接続しない。** RCB4-miniはバッテリ側で給電され、ATOMはUSB-Cから給電されるため、繋ぐのはGNDと信号線のみでよい。二重給電を避ける。
- **既知の注意点:** RCB4-mini の COM 信号は 0V/5V(5Vロジック)である一方、ATOM(ESP32-S3)のGPIOは3.3V系。今回は直結で動作が確認できたが、絶対最大定格を超える入力であり長期的にはGPIOを傷める可能性がある。恒久的な運用では、RCB4のTx→ATOMのG1間に抵抗分圧またはレベル変換IC(3.3V側)を入れることを推奨する。

## ファームウェア(ATOM側)

`atom_rcb4_bridge.ino`: USB-CDCとRCB4向けUART(反転)の間でバイト列をそのまま中継するだけの
ブリッジ。プロトコル解釈は一切行わず、コマンドやチェックサムの処理はPC側(kxreus)に任せる。

主要設定(実機確認済み):

```cpp
static const int RCB4_TX_PIN = 2;      // ATOM TX(G2) -> RCB4-mini Rx
static const int RCB4_RX_PIN = 1;      // ATOM RX(G1) <- RCB4-mini Tx
static const uint32_t RCB4_BAUD = 1250000;  // RCB4-mini既定の高速モード
RCB4Serial.begin(RCB4_BAUD, SERIAL_8E1, RCB4_RX_PIN, RCB4_TX_PIN, /*invert=*/true);
```

ロボット側が低速(:slow)設定の場合は `RCB4_BAUD` を `115200` に変更する。

### 書き込み方法(arduino-cli)

```bash
# 初回のみ: arduino-cliインストール & ボードパッケージ導入
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | BINDIR=~/.local/bin sh
export PATH="$HOME/.local/bin:$PATH"
arduino-cli config init --overwrite
arduino-cli config add board_manager.additional_urls https://static-cdn.m5stack.com/resource/arduino/package_m5stack_index.json
arduino-cli core update-index
arduino-cli core install m5stack:esp32

# 書き込み(ATOMをUSB接続した状態で)
arduino-cli compile --fqbn m5stack:esp32:m5stack_atoms3 ~/AtomS3/atom_rcb4_bridge/atom_rcb4_bridge.ino
arduino-cli upload -p /dev/ttyACM0 --fqbn m5stack:esp32:m5stack_atoms3 ~/AtomS3/atom_rcb4_bridge/atom_rcb4_bridge.ino
```

Arduino IDE(GUI)を使う場合は、`ファイル > 環境設定` の追加のボードマネージャURLに上記M5StackのURLを追加して
ボードマネージャから `M5Stack` を導入し、Board: `M5AtomS3`、USB CDC On Boot: `Enabled` を選んで書き込む。

## PC側動作確認スクリプト

`rcb4_bridge_test.py`(pyserial使用)。RCB4のバージョン問い合わせコマンド(`03 FD 00`)を送り、
RCB4形式のフレーム(先頭バイト=長さ, 以降 長さ-1 バイトが本体)を読み返して疎通を確認する。

```bash
python3 ~/AtomS3/atom_rcb4_bridge/rcb4_bridge_test.py /dev/ttyACM0
```

正常時の出力例(実機で確認済み。`CB-4 V1.0` はRCB-4のファームウェアバージョン文字列):

```
-> send: 03 fd 00
<- recv: 23 fd 43 42 2d 34 20 56 31 2e 30 20 20 20 20 20 20 30 39 30 37 31 35 20 20 20 20 20 20 20 20 20 20 c7 08
疎通確認 OK
```

## kxreus側の設定

`rcb4interface.l` / `uart.l` の編集は不要。`uart-interface`(`uart.l`)は元々 `:devname` 経由で
生tty接続する機能を持っており、`rcb4interface.l` の `:rcb4-open` → `:com-open` はキーワード引数を
そのまま `uart-interface` に転送する作りになっている。

FTDI版USB Dual Adapter(vid `#x165c`)を自動探索する `:com-init` の代わりに、明示的に `:devname` を
指定して `:rcb4-open` を呼んでから `:timer-on` する:

```lisp
(send *ri* :rcb4-open :devname "ttyACM0")  ;; 実際のデバイス名に置き換える
(send *ri* :timer-on)
```

`:timer-on` は `com-port` が既に設定済みなら内部の `:com-init`(FTDI探索)を呼ばない実装のため、
上記の順で呼べばFTDI探索をバイパスしてATOM経由の接続がそのまま使われる。実機で双方向通信を確認済み。

### デバイス名の固定(複数ATOM接続時)

ATOM(AtomS3系)はどれも同じUSB ID(`303a:1001`)で認識されるため、他のAtomS3機器(ロボットの目など)を
同時に挿すと `/dev/ttyACM0` の番号がずれる。シリアル番号で固定名を作る:

```bash
udevadm info -a -n /dev/ttyACM0 | grep -i serial   # このATOM個体のシリアル番号を確認
```

```
# /etc/udev/rules.d/99-my-rcb4-atom.rules
SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", ATTRS{idProduct}=="1001", ATTRS{serial}=="<確認したシリアル>", SYMLINK+="ttyACM-rcb4", GROUP="dialout"
```

```bash
sudo cp 99-my-rcb4-atom.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger
```

以降は `"ttyACM0"` の代わりに `"ttyACM-rcb4"` を使う。

## トラブルシューティングの記録

配線・設定の切り分けで実際に役立った手順:

1. **ATOM単体の健全性確認**: RCB4を外し、G1-G2をジャンパー線で直結してループバックさせる。
   `HardwareSerial` で送ったバイトがそのまま返ってくれば、ATOM側のUARTペリフェラル・ファームウェアは正常。
2. **配線の生きているピンの確認**: UARTを使わず `digitalWrite`/`digitalRead` で単純なGPIO導通テストを行う。
3. **アイドル電位だけでの判断は不十分**: RCB4側のRx/Tx各ピンには恐らくアイドル状態を規定する
   受動素子(プルダウン等)があり、電源ON/OFFに関わらず一定電位を示すことがある。「配線が生きているか」は
   アイドル電位ではなく、**コマンド送信直後に生の電気的な変化(トランジション)があるか**で判定するのが確実。
4. **ピン対応の最終確認は公式マニュアルで**: 目視や手探りでの「隣のピンだから多分TXD」という判断は誤りやすい。
   `~/rcb4eus/pdfs/HTH4_Ver6-20160712.pdf` のようなハードウェア接続図で正式なピン順(GND-Rx-Tx)を確認したことで
   原因(TX/RXピンの割り当てミス)が判明した。

## 関連ファイル

- `atom_rcb4_bridge.ino` : 本番用ブリッジファームウェア(このドキュメントの設定で確認済み)
- `rcb4_bridge_test.py` : PC側動作確認スクリプト
- `~/AtomS3/atom_rcb4_bridge_diag/atom_rcb4_bridge_diag.ino` + `rcb4_bridge_sweep.py` : 配線トラブル時に
  反転/TX-RX入れ替え/ボーレートの組み合わせを再書き込みなしで一括確認するための診断ツール
