#!/bin/bash
# ロボット側ATOM Echo(atom_echo_voice_cmd_robot.ino)をコンパイルして書き込む。
# AtomS3ではなく、腕やM5StickVを持たない機体(4脚・6脚等)を無線化するための
# プレーンなATOM Echo版(詳細は README.md 参照)。Edge Impulseの音声認識
# モデル(../edge_impulse/)を使うため、atom_s3_robot/flash.shと同様、
# ~/Arduino/libraries/に無ければ初回のみ自動コピーしてから使う
# (--libraryで直接指定するとビルドキャッシュが壊れることがあるため)。
#
# 使い方: ./flash.sh <ポート>   (他のATOM Echo/AtomS3と混同しやすいため既定値は
# 設けていない。必ず対象ポートを明示すること)
set -e
PORT="$1"
if [ -z "$PORT" ]; then
  echo "usage: $0 <port>" >&2
  exit 1
fi
FQBN=m5stack:esp32:m5stack_atom
BASE="$(cd "$(dirname "$0")" && pwd)"
DIR="$BASE/atom_echo_voice_cmd_robot"
EI_LIB_SRC="$BASE/../edge_impulse/kxr-voice-commands_inferencing"
EI_LIB_DST="$HOME/Arduino/libraries/kxr-voice-commands_inferencing"

if [ ! -e "$EI_LIB_DST" ]; then
  echo "[flash] Edge Impulseライブラリを $EI_LIB_DST へ初回コピーします..."
  mkdir -p "$HOME/Arduino/libraries"
  cp -r "$EI_LIB_SRC" "$EI_LIB_DST"
fi

echo "[flash] compiling for $FQBN ..."
arduino-cli compile --fqbn "$FQBN" "$DIR"

echo "[flash] uploading to $PORT (UploadSpeed=115200, 純正FTDI経由のため既定の高速では不安定) ..."
arduino-cli upload -p "$PORT" --fqbn "${FQBN}:UploadSpeed=115200" "$DIR"

echo "[flash] done. PEER_MAC がPC側ATOM Echoの実MACと一致しているか pc_mac.h を確認すること。"
