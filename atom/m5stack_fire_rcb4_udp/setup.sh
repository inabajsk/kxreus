#!/bin/bash
# m5stack_fire_rcb4_udp.ino(RCB4-mini用WiFi/UDP反転UARTブリッジ、
# M5Stack FIRE専用)をコンパイルしてFIREへ書き込む。
#
# FIREはAtomS3と違いネイティブUSB-CDCではなく、USBシリアル変換チップ
# (CP2104等)経由でPCから見えるので、書き込みポートは通常 /dev/ttyUSB0。
#
# 使い方: ./setup.sh [ポート]   (省略時 /dev/ttyUSB0)
set -e
PORT="${1:-/dev/ttyUSB0}"
FQBN=m5stack:esp32:m5stack-fire
DIR="$(cd "$(dirname "$0")" && pwd)"
M5STACK_URL=https://static-cdn.m5stack.com/resource/arduino/package_m5stack_index.json

# ../atoms3_rcb4_adapter/setup.sh と同じ仕組み(そちらの詳細コメント参照)。
ensure_arduino_cli() {
  export PATH="$HOME/.local/bin:$PATH"
  if ! command -v arduino-cli >/dev/null 2>&1 || [ -z "$(arduino-cli version 2>/dev/null)" ]; then
    echo "[setup] arduino-cli not found or broken. (re)installing to \$HOME/.local/bin ..."
    rm -f "$HOME/.local/bin/arduino-cli"
    mkdir -p "$HOME/.local/bin"
    curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh \
      | BINDIR="$HOME/.local/bin" sh
  fi
  if [ -z "$(arduino-cli version 2>/dev/null)" ]; then
    echo "[setup] arduino-cli install failed (still broken/empty). install it manually and re-run." >&2
    exit 1
  fi

  if ! arduino-cli --no-color config get board_manager.additional_urls 2>/dev/null | grep -q m5stack; then
    echo "[setup] adding M5Stack board manager URL ..."
    arduino-cli config add board_manager.additional_urls "$M5STACK_URL"
  fi
  if ! arduino-cli --no-color core list 2>/dev/null | grep -q '^m5stack:esp32'; then
    echo "[setup] installing m5stack:esp32 board package (this can take a while) ..."
    arduino-cli core update-index
    arduino-cli core install m5stack:esp32
  fi

  if ! arduino-cli --no-color lib list 2>/dev/null | grep -q '^M5Unified'; then
    echo "[setup] updating library index ..."
    arduino-cli lib update-index
    echo "[setup] installing M5Unified library ..."
    arduino-cli lib install M5Unified
  fi

  # FQBNが実際にこの名前かは未確認(この環境にarduino-cliが無いため
  # コンパイル自体を試せていない) -- 違っていたら以下で正しい名前を探す。
  if ! arduino-cli --no-color board listall 2>/dev/null | grep -qi "m5stack-fire\|m5stack:esp32:m5stack-fire"; then
    echo "[setup] WARNING: '$FQBN' not found in 'arduino-cli board listall'." >&2
    echo "[setup]   Run: arduino-cli board listall | grep -i fire" >&2
    echo "[setup]   and fix FQBN at the top of this script if the name differs." >&2
  fi
}

ensure_arduino_cli

echo "[setup] compiling for $FQBN ..."
arduino-cli compile --fqbn "$FQBN" "$DIR/m5stack_fire_rcb4_udp.ino"

echo "[setup] uploading to $PORT ..."
arduino-cli upload -v -p "$PORT" --fqbn "$FQBN" "$DIR/m5stack_fire_rcb4_udp.ino"
echo "[setup] upload exit code: $?"

echo "[setup] done."
