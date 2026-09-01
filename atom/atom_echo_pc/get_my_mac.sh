#!/bin/bash
# このATOM Echo実機のMACアドレスをesptoolで読み取り、ロボット側のPEER_MACとして
# 使うヘッダファイルを生成する。このPC側ファームウェア(atom_echo_voice_cmd_pc.ino)は
# ロボット側がAtomS3(../atom_s3_robot/)でもプレーンなATOM Echo(../atom_echo_robot/)
# でも共通で使えるため、第2引数でどちらの機体用か選ぶ。
#
# 使い方: ./get_my_mac.sh [ポート] [s3|echo]
#   (ポート省略時 /dev/ttyUSB2。機体種別省略時 s3(AtomS3、既定))
#   例: ./get_my_mac.sh /dev/ttyUSB2 s3    # -> ../atom_s3_robot/atoms3_i2c_robot/pc_mac.h
#       ./get_my_mac.sh /dev/ttyUSB2 echo  # -> ../atom_echo_robot/atom_echo_voice_cmd_robot/pc_mac.h
#
# ESPTOOL環境変数でesptool実行ファイルを指定できる(省略時はPATH上のesptool、
# 無ければarduino-cli付属のものを自動で探す)。
set -e
PORT="${1:-/dev/ttyUSB2}"
ROBOT_TYPE="${2:-s3}"
DIR="$(cd "$(dirname "$0")" && pwd)"
case "$ROBOT_TYPE" in
  s3) OUT="$DIR/../atom_s3_robot/atoms3_i2c_robot/pc_mac.h" ;;
  echo) OUT="$DIR/../atom_echo_robot/atom_echo_voice_cmd_robot/pc_mac.h" ;;
  *)
    echo "error: 機体種別は s3 か echo のみ(指定値: $ROBOT_TYPE)" >&2
    exit 1
    ;;
esac

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
if [ "$ROBOT_TYPE" = "s3" ]; then
  echo "[get_my_mac] ロボット側AtomS3の再コンパイルが必要です(../atom_s3_robot/flash.sh)。"
else
  echo "[get_my_mac] ロボット側ATOM Echoの再コンパイルが必要です(../atom_echo_robot/flash.sh)。"
fi
