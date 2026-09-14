#!/bin/bash
# M5StickV(K210/MaixPy)へobject_detection_I2C_slave.pyをboot.pyとして書き込み、
# 発話用WAVクリップ(sd_clips/*.wav)をSDカード(/sd/)へ書き込む。
# 左目(I2C 0x24)・右目(I2C 0x25)は同じソースの1行(I2C_INDEX)だけが違うので、
# このスクリプトが書き込み直前にその行を書き換えてから転送する。
#
# 使い方: ./flash.sh <ポート> [0x24|0x25] [--skip-clips]
#   例: ./flash.sh /dev/ttyUSB3 0x24              # 左目、WAVクリップも書き込み
#       ./flash.sh /dev/ttyUSB4 0x25 --skip-clips # 右目、boot.pyのみ(クリップ済み前提)
#
# maixpy_upload.py はポートを開くたびに実機を再起動して割り込むため、
# WAVクリップ(17個)を毎回書き込むと1回のflashに数分かかる。SDカードに
# 一度書き込めば(SDカード自体を挿し替えない限り)以後は--skip-clipsで
# boot.pyだけを素早く書き込める。
set -e
PORT="$1"
EYE="${2:-0x24}"
SKIP_CLIPS=0
if [ "$3" = "--skip-clips" ]; then SKIP_CLIPS=1; fi
if [ -z "$PORT" ]; then
  echo "usage: $0 <port> [0x24|0x25] [--skip-clips]" >&2
  exit 1
fi
if [ "$EYE" != "0x24" ] && [ "$EYE" != "0x25" ]; then
  echo "error: 目の指定は 0x24(左目) か 0x25(右目) のみ" >&2
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp --suffix=.py)"
trap 'rm -f "$TMP"' EXIT

if [ "$SKIP_CLIPS" -eq 0 ]; then
  shopt -s nullglob
  CLIPS=("$DIR"/sd_clips/*.wav)
  shopt -u nullglob
  if [ "${#CLIPS[@]}" -eq 0 ]; then
    echo "warning: $DIR/sd_clips/ にWAVが見つかりません。発話機能が動作しません。" >&2
  fi
  n=0
  for clip in "${CLIPS[@]}"; do
    n=$((n + 1))
    name="$(basename "$clip")"
    echo "[flash] uploading clip ${n}/${#CLIPS[@]}: /sd/${name} ..."
    python3 "$DIR/maixpy_upload.py" "$PORT" "$clip" "/sd/${name}"
  done
fi

sed -E "s/^([[:space:]]*)I2C_INDEX = 0x[0-9A-Fa-f]+/\1I2C_INDEX = ${EYE}/" "$DIR/object_detection_I2C_slave.py" > "$TMP"
if ! grep -n "I2C_INDEX = 0x" "$TMP"; then
  echo "error: I2C_INDEXの行が置換できませんでした(object_detection_I2C_slave.pyの形式が変わった?)" >&2
  exit 1
fi

echo "[flash] uploading to $PORT as boot.py (I2C_INDEX=${EYE}) ..."
python3 "$DIR/maixpy_upload.py" "$PORT" "$TMP" boot.py
echo "[flash] done."
