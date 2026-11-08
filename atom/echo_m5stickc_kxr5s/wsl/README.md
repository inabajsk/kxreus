# wsl/ — AtomS3 / ATOM Echo を WSL に接続する Windows 用スクリプト

| ファイル | 役割 |
|---|---|
| `M5-WSL-attach.cmd` | ダブルクリック用ランチャ (`.ps1` を ExecutionPolicy Bypass で起動) |
| `M5-WSL-attach.ps1` | 本体 (UTF-8 BOM 付き。Windows PowerShell 5.1 で日本語が化けないため) |

使い方: 2つのファイルを Windows の同じフォルダ (例: デスクトップ) に置き、USB を挿し直したら
`M5-WSL-attach.cmd` をダブルクリックする。
```
cp M5-WSL-attach.* /mnt/c/Users/$USER/Desktop/
```

動作 (前提: usbipd-win をインストール済み `winget install usbipd`):
1. `usbipd state` から対象を探す。
   - AtomS3: VID:PID `303a:1001` → WSL では `/dev/ttyACM*`
   - ATOM Echo: FTDI `0403:6001` かつシリアル番号 `4D5217E152` → WSL では `/dev/ttyUSB*`
     (M5StickC も同じ FTDI なので VID:PID では区別できない)
   挿さっていない方は「未接続」と表示して飛ばす。
2. 未共有 (bind されていない) ものがあれば、まとめて1回の管理者権限確認で bind する。
3. `usbipd attach --wsl` で接続し、WSL 側の `/dev/ttyACM*` `/dev/ttyUSB*` を表示する。

別の個体を使う場合や機器を足す場合は、`M5-WSL-attach.ps1` 先頭の `$TARGETS` を編集する
(Match は `usbipd state` の InstanceId に対する正規表現。FTDI のシリアル番号は
`udevadm info -a -n /dev/ttyUSB0 | grep serial` や Windows のデバイスマネージャで確認できる)。

WSL 側でシリアルを読み書きするには、ユーザーが dialout グループに入っている必要がある
(`sudo usermod -aG dialout $USER` の後 `wsl --shutdown`)。
