#!/bin/bash
# atom_rcb4_bridge.ino(RCB4-mini用USB反転UARTブリッジ)をコンパイルして
# AtomS3へ書き込む。ESP-NOW/WiFiは使わず、PCとAtomS3をUSBケーブルで直結する
# 構成のため、他構成のようなPEER_MACペアリングは無い(このAtomS3単体で完結する)。
#
# 使い方: ./setup.sh [ポート]   (省略時 /dev/ttyACM0。ネイティブUSB-CDCのため
# ATOM Echoのような UploadSpeed 指定は不要)
set -e
PORT="${1:-/dev/ttyACM0}"
FQBN=m5stack:esp32:m5stack_atoms3
DIR="$(cd "$(dirname "$0")" && pwd)"
M5STACK_URL=https://static-cdn.m5stack.com/resource/arduino/package_m5stack_index.json

# arduino-cliが無ければ~/.local/binへインストールし、M5Stackボード定義URL・
# m5stack:esp32コアが未導入ならそれも入れる(初めてこのフォルダをcloneした
# マシンでも、このスクリプト単体でそのまま書き込みまで進められるように)。
ensure_arduino_cli() {
  if ! command -v arduino-cli >/dev/null 2>&1; then
    echo "[setup] arduino-cli not found. installing to \$HOME/.local/bin ..."
    mkdir -p "$HOME/.local/bin"
    curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh \
      | BINDIR="$HOME/.local/bin" sh
    export PATH="$HOME/.local/bin:$PATH"
  fi
  if ! command -v arduino-cli >/dev/null 2>&1; then
    echo "[setup] arduino-cli install failed. install it manually and re-run." >&2
    exit 1
  fi

  if ! arduino-cli config get board_manager.additional_urls 2>/dev/null | grep -q m5stack; then
    echo "[setup] adding M5Stack board manager URL ..."
    arduino-cli config init --overwrite >/dev/null 2>&1 || true
    arduino-cli config add board_manager.additional_urls "$M5STACK_URL"
  fi
  if ! arduino-cli core list 2>/dev/null | grep -q '^m5stack:esp32'; then
    echo "[setup] installing m5stack:esp32 board package (this can take a while) ..."
    arduino-cli core update-index
    arduino-cli core install m5stack:esp32
  fi
}

ensure_arduino_cli

echo "[setup] compiling for $FQBN ..."
arduino-cli compile --fqbn "$FQBN" "$DIR/atom_rcb4_bridge.ino"

echo "[setup] uploading to $PORT ..."
arduino-cli upload -p "$PORT" --fqbn "$FQBN" "$DIR/atom_rcb4_bridge.ino"

echo "[setup] done."
