#!/bin/bash
# ロボット側M5StickC実機のMACアドレスをesptoolで読み取り、PC側ATOM Echo
# (atom_echo_pc/)のESP-NOWピア設定
# (atom_echo_pc/atom_echo_espnow_bridge/robot_mac.h)を生成する。
#
# 使い方: ./get_m5stickc_mac.sh [ポート]   (省略時 /dev/ttyUSB0)
#
# 【重要】esptoolのread-macが返すのはこのチップのベース(STA)MACだが、
# M5StickC側のESP-NOWはSoftAPインターフェース経由で送受信している
# (net.cppがWiFi.mode(WIFI_AP)のみを使うため -- espnow_link.cppの
# peer.ifidx = WIFI_IF_AP参照)。ESP32はSoftAPのMACをベースMAC+1として
# 生成する仕様(実機確認、2026.9: ベースMACの末尾が...E8のとき、実際に
# ESP-NOWパケットの送信元として観測されたのは...E9だった)なので、
# 読み取った値に+1してから書き込む。
#
# ESPTOOL環境変数でesptool実行ファイルを指定できる(省略時はPATH上のesptool、
# 無ければarduino-cli付属のものを自動で探す)。
set -e
PORT="${1:-/dev/ttyUSB0}"
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/atom_echo_pc/atom_echo_espnow_bridge/robot_mac.h"

if [ -n "$ESPTOOL" ]; then
  :
elif command -v esptool >/dev/null 2>&1; then
  ESPTOOL=esptool
elif command -v esptool.py >/dev/null 2>&1; then
  ESPTOOL=esptool.py
else
  ESPTOOL="$(find "$HOME/.arduino15/packages" -maxdepth 6 -type f -iname "esptool" 2>/dev/null | sort -V | tail -1)"
fi
if [ -z "$ESPTOOL" ]; then
  echo "error: esptoolが見つかりません。ESPTOOL環境変数で実行ファイルを指定してください。" >&2
  exit 1
fi

BASE_MAC="$("$ESPTOOL" --port "$PORT" read-mac 2>&1 | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | head -1)"
if [ -z "$BASE_MAC" ]; then
  echo "error: MACアドレスの取得に失敗しました(ポート:$PORT)。M5StickCが接続されているか確認してください。" >&2
  exit 1
fi

# ベース(STA)MAC + 1 = SoftAP MAC。bashの算術展開(0x..)でバイト毎に10進化し、
# 最後のバイトから繰り上がりを見ながら+1して、MAC表記へ戻す(pure bash --
# strtonumはgawk専用でmawk等には無いため使わない)。
IFS=':' read -r -a OCT <<< "$BASE_MAC"
carry=1
for i in 5 4 3 2 1 0; do
  v=$(( 0x${OCT[$i]} + carry ))
  if [ "$v" -gt 255 ]; then
    OCT[$i]=00
    carry=1
  else
    OCT[$i]=$(printf '%02X' "$v")
    carry=0
  fi
done
AP_MAC="$(IFS=:; echo "${OCT[*]}")"
BYTES="$(echo "$AP_MAC" | tr ':' '\n' | awk '{printf "0x%s, ", toupper($0)}' | sed 's/, $//')"

cat > "$OUT" <<EOF
// 自動生成ファイル: get_m5stickc_mac.sh でこのM5StickC(ポート $PORT)の実MAC
// アドレスを読み取って生成した。手動編集しないこと。
// 生成元MAC(STA/ベース): $BASE_MAC
// SoftAP MAC(+1、実際にESP-NOWで使われるのはこちら): $AP_MAC
#pragma once
#define ROBOT_MAC_BYTES { $BYTES }
EOF

echo "[get_m5stickc_mac] M5StickC base MAC=$BASE_MAC -> SoftAP MAC=$AP_MAC -> $OUT"
echo "[get_m5stickc_mac] PC側ATOM Echoの再コンパイル・書き込みが必要です(atom_echo_pc/flash.sh)。"
