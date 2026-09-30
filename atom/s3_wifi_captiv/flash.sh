#!/bin/bash
# RCB4無線ブリッジAtomS3(atoms3_wifi_captiv.ino)をコンパイルして書き込む。
# ESP-NOW/ATOM Echoは使わないため、他構成のようなPEER_MACペアリング・
# setup_*.shは無い(このAtomS3単体で完結する)。
#
# 使い方: ./flash.sh [ポート]   (省略時 /dev/ttyACM0。ネイティブUSB-CDCのため
# ATOM Echoのような UploadSpeed 指定は不要)
set -e
PORT="${1:-/dev/ttyACM0}"
FQBN=m5stack:esp32:m5stack_atoms3
DIR="$(cd "$(dirname "$0")" && pwd)/atoms3_wifi_captiv"

echo "[flash] compiling for $FQBN ..."
arduino-cli compile --fqbn "$FQBN" "$DIR"

echo "[flash] uploading to $PORT ..."
arduino-cli upload -p "$PORT" --fqbn "$FQBN" "$DIR"

echo "[flash] done."
