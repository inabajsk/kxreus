#!/bin/bash
# 有線USBブリッジ(atom_rcb4_bridge.ino)をAtomS3へ書き込む。
#
# 使い方: ./flash.sh [ポート]   (省略時 /dev/ttyACM0。ネイティブUSB-CDCのため
# ATOM Echoのような UploadSpeed 指定は不要)
#
# IMU予約OPCODE(0x90)の応答にM5Unifiedを使うため、未導入なら arduino-cli で
# 入れる。事前準備は atom/README.md の「1回だけ行うホスト側セットアップ」参照。
set -e
PORT="${1:-/dev/ttyACM0}"
FQBN=m5stack:esp32:m5stack_atoms3
DIR="$(cd "$(dirname "$0")" && pwd)"

if ! arduino-cli lib list M5Unified 2>/dev/null | grep -qi M5Unified; then
  echo "[flash] M5Unified が無いので導入します..."
  arduino-cli lib install M5Unified
fi

echo "[flash] compiling for $FQBN ..."
arduino-cli compile --fqbn "$FQBN" "$DIR"

echo "[flash] uploading to $PORT ..."
arduino-cli upload -p "$PORT" --fqbn "$FQBN" "$DIR"

echo "[flash] done."
