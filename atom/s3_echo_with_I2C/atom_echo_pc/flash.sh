#!/bin/bash
# PC側ATOM Echo(atom_echo_voice_cmd_pc.ino)をコンパイルして書き込む。
#
# 使い方: ./flash.sh [ポート]   (省略時 /dev/ttyUSB2)
#
# 事前準備は atom/README.md の「1回だけ行うホスト側セットアップ」を参照。
set -e
PORT="${1:-/dev/ttyUSB2}"
FQBN=m5stack:esp32:m5stack_atom
DIR="$(cd "$(dirname "$0")" && pwd)/atom_echo_voice_cmd_pc"

echo "[flash] compiling for $FQBN ..."
arduino-cli compile --fqbn "$FQBN" "$DIR"

echo "[flash] uploading to $PORT (UploadSpeed=115200, 純正FTDI経由のため既定の高速では不安定) ..."
arduino-cli upload -p "$PORT" --fqbn "${FQBN}:UploadSpeed=115200" "$DIR"

echo "[flash] done. PEER_MAC がロボット側AtomS3の実MACと一致しているか .ino 冒頭を確認すること。"
