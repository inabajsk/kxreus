#!/bin/bash
# PC側ATOM Echo(atom_echo_voice_cmd_pc.ino)をコンパイルして書き込む。
#
# 使い方: ./flash.sh [ポート]   (省略時 /dev/ttyUSB0)
#
# 事前準備は atom/README.md の「1回だけ行うホスト側セットアップ」を参照。
set -e
PORT="${1:-/dev/ttyUSB0}"
FQBN=m5stack:esp32:m5stack_atom
DIR="$(cd "$(dirname "$0")" && pwd)/atom_echo_voice_cmd_pc"

echo "[flash] compiling for $FQBN ..."
arduino-cli compile --fqbn "$FQBN" "$DIR"

echo "[flash] uploading to $PORT (UploadSpeed=115200, 純正FTDI経由のため既定の高速では不安定) ..."
arduino-cli upload -p "$PORT" --fqbn "${FQBN}:UploadSpeed=115200" "$DIR"

echo "[flash] done. robot_mac.h がロボット側M5StickCのAP MAC(ベースMAC+1)と一致しているか確認すること。"
