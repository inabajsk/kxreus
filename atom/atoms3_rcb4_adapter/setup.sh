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
  # install.sh自体は~/.local/binを恒久的なPATHに追加してくれない。
  # ここでPATHへ入れておかないと、前回インストール済みでも次回このスクリプトを
  # 実行した時に(このスクリプト自身のPATHには入っていないので)「見つからない」
  # と判定され、毎回ダウンロードし直すことになってしまう。
  export PATH="$HOME/.local/bin:$PATH"

  # command -vだけだと「ファイルはあるが中身が壊れている(0バイト等)」
  # 状態を見抜けない(空ファイルは実行しても即成功・無出力で終わるため、
  # 以降のすべてのarduino-cli呼び出しが無反応で成功したように見えてしまう
  # …という実際の不具合があった)。arduino-cli versionの出力が空でないか
  # まで確認する。
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

  # --no-color: 対話端末で色付きになった行が先頭アンカー(^)のgrepに
  # 引っかからなくなる(ANSIエスケープシーケンスが行頭に付く)のを防ぐ。
  if ! arduino-cli --no-color config get board_manager.additional_urls 2>/dev/null | grep -q m5stack; then
    echo "[setup] adding M5Stack board manager URL ..."
    # 以前はここで`arduino-cli config init --overwrite`を呼んでいたが、
    # 設定ファイル全体をデフォルトへ書き戻してしまい、他の設定(既に
    # 導入済みのURL等)を消して以後の実行のたびに再インストールが走る
    # 原因になっていたため廃止。config addは設定ファイルが無くても
    # 動作する。
    arduino-cli config add board_manager.additional_urls "$M5STACK_URL"
  fi
  if ! arduino-cli --no-color core list 2>/dev/null | grep -q '^m5stack:esp32'; then
    echo "[setup] installing m5stack:esp32 board package (this can take a while) ..."
    arduino-cli core update-index
    arduino-cli core install m5stack:esp32
  fi

  # このスケッチは液晶表示にM5Unifiedを使う(依存のM5GFXも自動で入る)。
  # ライブラリ索引(library_index.json)を明示的に更新してからinstallする。
  # 索引が無い/古い状態でいきなりlib installすると、環境によっては
  # (無関係なライブラリも大量に列挙されるなど)出力が非常に冗長になることが
  # あるため、先にupdate-indexだけ済ませておく。
  if ! arduino-cli --no-color lib list 2>/dev/null | grep -q '^M5Unified'; then
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
# -v: esptoolの接続・書き込みログを必ず表示する(見た目上何も起きずに
# 終わったように見える不具合の切り分けのため)。
arduino-cli upload -v -p "$PORT" --fqbn "$FQBN" "$DIR/atoms3_rcb4_adapter.ino"
echo "[setup] upload exit code: $?"

echo "[setup] done."
