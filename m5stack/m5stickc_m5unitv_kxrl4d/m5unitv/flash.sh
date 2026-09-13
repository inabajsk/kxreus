#!/bin/bash
# M5Stack UnitV(K210/MaixPy)へobject_detection_I2C_slave.pyをboot.pyとして書き込む。
#
# object_detection_I2C_slave.py 自体は m5stickv/ のものと同一ファイル
# (シンボリックではなくコピー -- 2026.9時点で差分なし): 実機のI2Cバス
# (i2c_lcd, I2C1 scl=28/sda=29)をスキャンして応答がなければUnitVと自動判定し
# (is_m5unitv)、LCD初期化をスキップ・カメラの上下反転・起動時のWS2812 LED
# 点滅を切り替える。ホスト向けの外部I2Cスレーブ(I2C0, scl=34/sda=35, この
# アドレス)はStickV/UnitV共通で変わらない。
#
# UnitVには内蔵スピーカーが無いため、m5stickv/flash.shと違い音声クリップは
# 一切書き込まない(object_detection_I2C_slave.py自体はI2S初期化を無条件に
# 行うが、スピーカーが物理的に無いだけで無音になるだけでクラッシュはしない
# -- board_info自体はM5StickV系ファームウェア共通のものを使うため)。
#
# 使い方: ./flash.sh <ポート> [0x24|0x25]
#   例: ./flash.sh /dev/ttyUSB0 0x25
set -e
PORT="$1"
ADDR="${2:-0x25}"
if [ -z "$PORT" ]; then
  echo "usage: $0 <port> [0x24|0x25]" >&2
  exit 1
fi
if [ "$ADDR" != "0x24" ] && [ "$ADDR" != "0x25" ]; then
  echo "error: I2Cアドレスは 0x24 か 0x25 のみ" >&2
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp --suffix=.py)"
trap 'rm -f "$TMP"' EXIT

sed -E "s/^([[:space:]]*)I2C_INDEX = 0x[0-9A-Fa-f]+/\1I2C_INDEX = ${ADDR}/" "$DIR/object_detection_I2C_slave.py" > "$TMP"
if ! grep -n "I2C_INDEX = 0x" "$TMP" > /dev/null; then
  echo "error: I2C_INDEXの行が置換できませんでした(object_detection_I2C_slave.pyの形式が変わった?)" >&2
  exit 1
fi

echo "[flash] uploading to $PORT as boot.py (I2C_INDEX=${ADDR}) ..."
python3 "$DIR/maixpy_upload.py" "$PORT" "$TMP" boot.py
echo "[flash] done."
