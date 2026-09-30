#!/bin/bash
# このロボット側ATOM Echo実機のMACアドレスをesptoolで読み取り、PC側ATOM Echo
# (../atom_echo_pc/のatom_echo_voice_cmd_pc.ino。AtomS3向けと共通のPC側
# ファームウェア)のPEER_MACとして使うヘッダファイルを
# ../atom_echo_pc/atom_echo_voice_cmd_pc/robot_mac.h に生成する。
#
# 使い方: ./get_my_mac.sh <ポート>   (他のATOM Echo/AtomS3と混同しやすいため
# 既定値は設けていない。必ず対象ポートを明示すること)
#
# ESPTOOL環境変数でesptool実行ファイルを指定できる(省略時はPATH上のesptool、
# 無ければarduino-cli付属のものを自動で探す)。
set -e
PORT="$1"
if [ -z "$PORT" ]; then
  echo "usage: $0 <port>" >&2
  exit 1
fi
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
  echo "error: MACアドレスの取得に失敗しました(ポート:$PORT)。ロボット側ATOM Echoが接続されているか確認してください。" >&2
  exit 1
fi
BYTES="$(echo "$MAC" | tr ':' '\n' | awk '{printf "0x%s, ", toupper($0)}' | sed 's/, $//')"

cat > "$OUT" <<EOF
// 自動生成ファイル: ../../atom_echo_robot/get_my_mac.sh でロボット側ATOM Echo
// (ポート $PORT)の実MACアドレスを読み取って生成した。手動編集しないこと。
// 生成元MAC: $MAC
#pragma once
#define ROBOT_MAC_BYTES { $BYTES }
EOF

echo "[get_my_mac] ロボット側ATOM Echo MAC=$MAC -> $OUT"
echo "[get_my_mac] PC側ATOM Echo(atom_echo_pc)の再コンパイルが必要です(../atom_echo_pc/flash.sh)。"
