#!/bin/bash
# ロボット側AtomS3(atoms3_i2c_robot.ino)をコンパイルして書き込む。
#
# 使い方: ./flash.sh [ポート]   (省略時 /dev/ttyACM0。ネイティブUSB-CDCのため
# ATOM Echoのような UploadSpeed 指定は不要)
#
# Edge Impulseの推論ライブラリ(../../edge_impulse/kxr-voice-commands_inferencing)は
# ~/Arduino/libraries/ に無ければ初回のみ自動コピーしてから使う。--library で
# 直接指定すると、既に~/Arduino/libraries/に同名ライブラリがある場合に
# 「Multiple libraries were found」となりESP-NNのビルドキャッシュが壊れて
# リンクエラーになることを実機確認したため、通常のライブラリ検索に任せる。
#
# 事前準備は atom/README.md の「1回だけ行うホスト側セットアップ」を参照。
set -e
PORT="${1:-/dev/ttyACM0}"
FQBN=m5stack:esp32:m5stack_atoms3
BASE="$(cd "$(dirname "$0")" && pwd)"
DIR="$BASE/atoms3_i2c_robot"
EI_LIB_SRC="$BASE/../../edge_impulse/kxr-voice-commands_inferencing"
EI_LIB_DST="$HOME/Arduino/libraries/kxr-voice-commands_inferencing"

if [ ! -e "$EI_LIB_DST" ]; then
  echo "[flash] Edge Impulseライブラリを $EI_LIB_DST へ初回コピーします..."
  mkdir -p "$HOME/Arduino/libraries"
  cp -r "$EI_LIB_SRC" "$EI_LIB_DST"
fi

echo "[flash] compiling for $FQBN ..."
arduino-cli compile --fqbn "$FQBN" "$DIR"

echo "[flash] uploading to $PORT ..."
arduino-cli upload -p "$PORT" --fqbn "$FQBN" "$DIR"

echo "[flash] done. PEER_MAC がPC側ATOM Echoの実MACと一致しているか .ino 冒頭を確認すること。"
