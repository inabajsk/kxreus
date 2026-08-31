#!/bin/bash
# M5StickV(K210/MaixPy)へobject_detection_I2C_slave.pyをboot.pyとして書き込む。
# 左目(I2C 0x24)・右目(I2C 0x25)は同じソースの1行(I2C_INDEX)だけが違うので、
# このスクリプトが書き込み直前にその行を書き換えてから転送する。
#
# 使い方: ./flash.sh <ポート> [0x24|0x25]   (目の指定省略時は左目 0x24)
#   例: ./flash.sh /dev/ttyUSB3 0x24   # 左目
#       ./flash.sh /dev/ttyUSB4 0x25   # 右目
set -e
PORT="$1"
EYE="${2:-0x24}"
if [ -z "$PORT" ]; then
  echo "usage: $0 <port> [0x24|0x25]" >&2
  exit 1
fi
if [ "$EYE" != "0x24" ] && [ "$EYE" != "0x25" ]; then
  echo "error: 目の指定は 0x24(左目) か 0x25(右目) のみ" >&2
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp --suffix=.py)"
trap 'rm -f "$TMP"' EXIT

sed "s/^I2C_INDEX = 0x[0-9A-Fa-f]*/I2C_INDEX = ${EYE}/" "$DIR/object_detection_I2C_slave.py" > "$TMP"
grep -n "^I2C_INDEX" "$TMP"

echo "[flash] uploading to $PORT as boot.py (I2C_INDEX=${EYE}) ..."
python3 "$DIR/maixpy_upload.py" "$PORT" "$TMP" boot.py
echo "[flash] done."
