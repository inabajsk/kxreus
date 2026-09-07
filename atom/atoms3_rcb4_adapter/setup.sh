#!/bin/bash
# atoms3_rcb4_adapter.ino(RCB4-mini用USB反転UARTブリッジ + 液晶表示付き、
# AtomS3専用)をコンパイルしてAtomS3へ書き込む。ESP-NOW/WiFiは使わず、
# PCとAtomS3をUSBケーブルで直結する構成のため、他構成のようなPEER_MAC
# ペアリングは無い(このAtomS3単体で完結する)。
#
# 液晶の無いプレーンなATOMには書き込めない。その場合は
# ../atom_rcb4_bridge/setup.sh (atom_rcb4_bridge.ino)を使うこと。
#
# 使い方: ./setup.sh [ポート]   (省略時 /dev/ttyACM0。ネイティブUSB-CDCのため
# ATOM Echoのような UploadSpeed 指定は不要)
set -e
PORT="${1:-/dev/ttyACM0}"
FQBN=m5stack:esp32:m5stack_atoms3
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[setup] compiling for $FQBN ..."
arduino-cli compile --fqbn "$FQBN" "$DIR/atoms3_rcb4_adapter.ino"

echo "[setup] uploading to $PORT ..."
arduino-cli upload -p "$PORT" --fqbn "$FQBN" "$DIR/atoms3_rcb4_adapter.ino"

echo "[setup] done."
