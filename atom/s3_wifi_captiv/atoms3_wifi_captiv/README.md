# atoms3_wifi_captiv — RCB4無線ブリッジ(WiFi captive portal版)

ファイル: `atoms3_wifi_captiv/atoms3_wifi_captiv.ino`
書き込み: `./flash.sh [ポート]`(既定 `/dev/ttyACM0`)

ESP-NOW/ATOM Echoを使わず、AtomS3単体がPCとWiFi(TCP)で直接繋がり、RCB4を
無線化する構成。`../../radxa/atoms3_radxa_setup/`のcaptive portal+QR表示の
仕組みを流用しているが、そちらが「WiFi情報をRadxa Zeroへ中継する」役割
なのに対し、こちらはAtomS3自身がそのWiFiへ接続してRCB4向けTCPサーバーに
なる。PEER_MACペアリングが無いため、他構成と違い`setup_*.sh`は無い
(このAtomS3単体で完結する)。

## 全体の流れ

1. 起動時にSoftAP(`KXR-XXXX`、パスワードは起動毎にランダム)を立て、液晶に
   そのAPへ接続するためのQRコードを表示する。スマホでQRを撮ると、パスワード
   入力なしでAtomS3のSoftAPに接続され、captive portal検知で設定フォームが
   自動的に開く。
2. フォームで選んだ実WiFiのSSID/パスワードで、AtomS3自身が`WiFi.begin()`
   してSTAとして接続する(SoftAPは維持したまま、AP+STA同時動作)。
3. 接続に成功すると、液晶にIPアドレスとTCPポート番号(既定`4000`)を表示
   する。失敗時(タイムアウト20秒)は理由を数秒表示後、自動的にQR画面へ
   戻り再入力できる。
4. PC側は下記の方法でこのTCPポートへ繋ぐと、RCB4の生シリアルポートに直接
   繋いでいるのと同じように使える。

## PC側からの繋ぎ方(socatで仮想ttyを作る)

```bash
socat TCP:<AtomS3のIP>:4000 PTY,link=/dev/ttyKXR0,raw,echo=0
```

`/dev/ttyKXR0`が実RCB4に繋いだ時と同じように振る舞う仮想シリアルポートに
なるので、euslisp側(`rcb4interface.l`/`uart.l`)は変更不要でこのポート名を
指定するだけでよい。`socat`はバックグラウンドで動かし続ける必要がある
(接続を維持するプロセスのため)。

## ピン配置

| 用途 | ピン | 備考 |
| --- | --- | --- |
| RCB4 UART TX | G2 | Grove(HY2.0-4P)コネクタ。`../../s3_echo_bridge/atoms3_simple_robot/`と同一配線 |
| RCB4 UART RX | G1 | 同上 |
| RCB4 UART ボーレート | 1,250,000bps | `SERIAL_8E1`、TX/RX論理反転(他構成と同じ理由・実装) |
| 内蔵IMU(MPU6886) I2C | G38(SDA)/G39(SCL) | 内蔵配線 |
| LCD | 内蔵 | QR/状態表示 |

## TCPブリッジと透過性

TCPクライアントから受けた生バイトは、RCB4の通常フレーミング
(`[length,opcode,...,checksum]`)に従って区切りを検出するだけで、内容を
検証・変換せずそのままRCB4 UARTへ書く。RCB4からの応答も同様にそのまま
TCPへ書き戻す。**例外は他構成と共通のIMU予約オペコード(0x90)** で、これは
実RCB4には転送されず、AtomS3が横取りしてIMU値を合成応答する。この横取りも
同じフレーミング規約に従っているだけなので、PC側から見れば通常のRCB4応答と
区別が付かず、透過ブリッジという前提は崩れない。

### 0x90: IMU読み出し(他構成と共通プロトコル)

- リクエスト: `[0x03, 0x90, 0x93]`
- 応答: `[0x0F, 0x90, ax,ay,az(各int16LE, milli-g), gx,gy,gz(各int16LE, 0.1deg/s), checksum]`

**単一クライアント運用**: TCP接続は同時1本のみ保持する(新しい接続が来ると
古い接続は切断される)。`socat`を使う限り通常は1本しか繋がないため問題ない。

## QRコードが読み取りづらい場合

`../../radxa/atoms3_radxa_setup/README.md`と同じ理由(小さい液晶ほど
QRバージョンが上がると読み取りづらい)で、SoftAPのSSID/パスワードは大文字
英数字のみでランダム生成している。

## 音声コマンド認識・ESP-NOWは無し

この構成はWiFi中継専任(2026.9決定)。PC側ATOM Echoによる音声コマンド→
Edge Impulse認識→call-motionの機能が必要な場合は`../../s3_echo_with_I2C/`
または`../../s3_echo_bridge/`(ESP-NOW経由)を使うこと。
