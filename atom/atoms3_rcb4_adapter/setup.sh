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

  # このスケッチは液晶表示にM5Unifiedを使う(依存のM5GFXも自動で入る)。
  # ライブラリ索引(library_index.json)を明示的に更新してからinstallする。
  # 索引が無い/古い状態でいきなりlib installすると、環境によっては
  # (無関係なライブラリも大量に列挙されるなど)出力が非常に冗長になることが
  # あるため、先にupdate-indexだけ済ませておく。
  if ! arduino-cli lib list 2>/dev/null | grep -q '^M5Unified'; then
    echo "[setup] updating library index ..."
    arduino-cli lib update-index
    echo "[setup] installing M5Unified library ..."
    arduino-cli lib install M5Unified
  fi
}

ensure_arduino_cli

echo "[setup] compiling for $FQBN ..."
arduino-cli compile --fqbn "$FQBN" "$DIR/atoms3_rcb4_adapter.ino"

echo "[setup] uploading to $PORT ..."
arduino-cli upload -p "$PORT" --fqbn "$FQBN" "$DIR/atoms3_rcb4_adapter.ino"

echo "[setup] done."
