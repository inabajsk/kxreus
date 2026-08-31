#!/bin/bash
# このAtomS3実機のMACアドレスをesptoolで読み取り、PC側ATOM Echo
# (atom_echo_voice_cmd_pc.ino)のPEER_MACとして使うヘッダファイルを
# ../atom_echo_pc/atom_echo_voice_cmd_pc/robot_mac.h に生成する。
#
# 使い方: ./get_my_mac.sh [ポート]   (省略時 /dev/ttyACM0)
#
# ESPTOOL環境変数でesptool実行ファイルを指定できる(省略時はPATH上のesptool、
# 無ければarduino-cli付属のものを自動で探す)。
set -e
PORT="${1:-/dev/ttyACM0}"
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/../atom_echo_pc/atom_echo_voice_cmd_pc/robot_mac.h"

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

MAC="$("$ESPTOOL" --port "$PORT" read-mac 2>&1 | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | head -1)"
if [ -z "$MAC" ]; then
  echo "error: MACアドレスの取得に失敗しました(ポート:$PORT)。AtomS3が接続されているか確認してください。" >&2
  exit 1
fi
BYTES="$(echo "$MAC" | tr ':' '\n' | awk '{printf "0x%s, ", toupper($0)}' | sed 's/, $//')"

cat > "$OUT" <<EOF
// 自動生成ファイル: get_my_mac.sh でこのAtomS3(ポート $PORT)の実MAC
// アドレスを読み取って生成した。手動編集しないこと。
// 生成元MAC: $MAC
#pragma once
#define ROBOT_MAC_BYTES { $BYTES }
EOF

echo "[get_my_mac] AtomS3 MAC=$MAC -> $OUT"
echo "[get_my_mac] PC側ATOM Echoの再コンパイルが必要です(../atom_echo_pc/flash.sh)。"
