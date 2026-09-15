# atom_echo_pc — PC側ATOM Echo(ESP-NOW中継、RCB4専用)

ファイル: `atom_echo_espnow_bridge.ino`
書き込み: `./flash.sh [ポート]`(既定 `/dev/ttyUSB2`)

`~/kxreus/atom/s3_echo_bridge/atom_echo_pc/atom_echo_voice_cmd_pc.ino` の
RCB4中継部分だけを取り出したもの(このロボット(kxrl4t)には音声認識機能
が無いため削除)。プロトコル(PKT_DATA+seq+ACK、PKT_PING/PONGハートビート)
は完全に同一 -- 詳細な設計理由はそちらのコメント参照。

## 役割

PC(`kxreus/atominterface.l`)とUSBシリアルで繋がるATOM Echo。PCがUSB
シリアルへ送ったRCB4バイト列を、そのままESP-NOW経由でロボット側
(M5StickC、`../m5stickc/`)へ転送し、応答も同じ経路でPCへ返す。ロボット側
から見るとRCB4が直結されているのと同じに見える透過ブリッジ -- ロボット側
の`BridgeMode::relay()`がSerialとESP-NOWのどちらから来たバイトも同じ
ように扱う(`BridgeMode::HostSource`参照)ので、`atominterface.l`側は
`:com-open`の接続先をこのATOM Echoのttyに変えるだけで、コード変更は一切
不要。

USBケーブルでM5StickCへ直結する従来の使い方と、このATOM Echo経由の使い方は
共存できる(BridgeModeは両方から同時にバイトを受け付ける -- ただし実際に
制御しているプロセスは常に一つだけである前提)。

## セットアップ(初回のみ)

1. このATOM Echoをこのファームウェアで書き込む: `./flash.sh <ポート>`
   (この時点ではrobot_mac.hはプレースホルダーのままで構わない)
2. M5StickC(`../m5stickc/`)を接続した状態で、ロボット側のMACアドレスを
   取得してこちら側へ書き込む:
   ```
   cd ..
   ./get_m5stickc_mac.sh <M5StickCのポート>
   ```
   → `atom_echo_espnow_bridge/robot_mac.h` が更新される。
3. このATOM Echoを接続した状態で、こちらのMACアドレスを取得してM5StickC側
   へ書き込む:
   ```
   ./get_pc_atom_echo_mac.sh <このATOM Echoのポート>
   ```
   → `../m5stickc/lib/espnow_link/pc_mac.h` が更新される。
4. 両方を再ビルド・書き込みする:
   ```
   ./flash.sh <このATOM Echoのポート>
   (cd ../m5stickc && ./flash.sh <M5StickCのポート>)
   ```

以降、どちらかの実機を交換した場合のみ、該当する`get_*_mac.sh`をやり直せば
よい。

## チャンネルについて

ESP-NOWは通信中のWiFiチャンネルが両者で一致している必要がある。M5StickC側
は`net.cpp`のWiFi.softAP()の既定チャンネル(1)に固定して動作する前提
(`../m5stickc/lib/espnow_link/espnow_link.h`参照)。M5StickCが実際の
WiFiルーターへ接続するモード(STA)になった場合、そのルーターのチャンネルは
1とは限らないため、このバージョンではまだ追従できない(既知の制限)。

## atominterface.lからの接続

```lisp
;; USB直結の代わりに、このATOM Echoのttyへ接続する。
(send *ri* :com-open :devname "ttyUSB2" :baud 500000)
```

`find-atom-echo-devname`(atominterface.l参照)を使う場合は、このATOM Echo
の実機シリアル番号を`*atom-echo-serials*`へ追加しておくこと。
