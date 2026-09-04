#!/bin/bash
# このATOM Echo実機のMACアドレスをesptoolで読み取り、ロボット側AtomS3
# (../atom_s3_robot/atoms3_i2c_robot.ino)のPEER_MACとして使うヘッダファイル
# (../atom_s3_robot/atoms3_i2c_robot/pc_mac.h)を生成する。
#
# 使い方: ./get_my_mac.sh [ポート]   (省略時 /dev/ttyUSB0)
#
# ESPTOOL環境変数でesptool実行ファイルを指定できる(省略時はPATH上のesptool、
# 無ければarduino-cli付属のものを自動で探す)。
set -e
PORT="${1:-/dev/ttyUSB0}"
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/../atom_s3_robot/atoms3_i2c_robot/pc_mac.h"

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
  echo "error: MACアドレスの取得に失敗しました(ポート:$PORT)。ATOM Echoが接続されているか確認してください。" >&2
  exit 1
fi
BYTES="$(echo "$MAC" | tr ':' '\n' | awk '{printf "0x%s, ", toupper($0)}' | sed 's/, $//')"

cat > "$OUT" <<EOF
// 自動生成ファイル: get_my_mac.sh でこのATOM Echo(ポート $PORT)の実MAC
// アドレスを読み取って生成した。手動編集しないこと。
// 生成元MAC: $MAC
#pragma once
#define PC_MAC_BYTES { $BYTES }
EOF

echo "[get_my_mac] ATOM Echo MAC=$MAC -> $OUT"
echo "[get_my_mac] ロボット側AtomS3の再コンパイルが必要です(../atom_s3_robot/flash.sh)。"
