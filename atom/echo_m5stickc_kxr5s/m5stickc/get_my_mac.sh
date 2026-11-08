#!/bin/bash
# このM5StickC実機のMACアドレスをesptoolで読み取り、PC側ATOM Echo
# (../atom_echo_pc)のPEER_MACとして使うヘッダファイル
# (../atom_echo_pc/atom_echo_voice_cmd_pc/robot_mac.h)を生成する。
#
# 【重要】M5StickC側のespnow_linkはESP-NOWをWIFI_IF_AP(SoftAP)で送受信する
# (lib/espnow_link/espnow_link.cpp の peer.ifidx = WIFI_IF_AP)。ESP32では
# SoftAPのMACはベースMAC(esptoolが表示するSTA MAC)の最下位バイト+1になり、
# ATOM Echoは送信元MACがPEER_MACと一致しないパケットを捨てるため、
# ここではベースMAC+1を書き出す。
#
# 使い方: ./get_my_mac.sh [ポート]   (省略時 /dev/ttyUSB1)
set -e
PORT="${1:-/dev/ttyUSB1}"
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/../atom_echo_pc/atom_echo_voice_cmd_pc/robot_mac.h"

if [ -n "$ESPTOOL" ]; then
  :
elif command -v esptool >/dev/null 2>&1; then
  ESPTOOL=esptool
elif command -v esptool.py >/dev/null 2>&1; then
  ESPTOOL=esptool.py
else
  ESPTOOL="$(find "$HOME/.platformio/packages" "$HOME/.arduino15/packages" -maxdepth 6 -type f -iname "esptool" 2>/dev/null | sort -V | tail -1)"
fi
if [ -z "$ESPTOOL" ]; then
  echo "error: esptoolが見つかりません。ESPTOOL環境変数で実行ファイルを指定してください。" >&2
  exit 1
fi

BASE="$("$ESPTOOL" --port "$PORT" read-mac 2>&1 | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | head -1)"
if [ -z "$BASE" ]; then
  echo "error: MACアドレスの取得に失敗しました(ポート:$PORT)。M5StickCが接続されているか確認してください。" >&2
  exit 1
fi
AP_MAC="$(python3 -c "import sys; b=[int(x,16) for x in sys.argv[1].split(':')]; v=(int.from_bytes(bytes(b),'big')+1)&0xFFFFFFFFFFFF; print(':'.join(f'{x:02x}' for x in v.to_bytes(6,'big')))" "$BASE")"
BYTES="$(echo "$AP_MAC" | tr ':' '\n' | awk '{printf "0x%s, ", toupper($0)}' | sed 's/, $//')"

cat > "$OUT" <<EOT
// 自動生成ファイル: m5stickc/get_my_mac.sh でこのM5StickC(ポート $PORT)の
// MACアドレスを読み取って生成した。手動編集しないこと。
// ベースMAC: $BASE / SoftAP MAC(ESP-NOW送信元, ベース+1): $AP_MAC
#pragma once
#define ROBOT_MAC_BYTES { $BYTES }
EOT

echo "[get_my_mac] M5StickC base=$BASE AP=$AP_MAC -> $OUT"
echo "[get_my_mac] PC側ATOM Echoの再コンパイル・書き込みが必要です(../atom_echo_pc/flash.sh)。"
