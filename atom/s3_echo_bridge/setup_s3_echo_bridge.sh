#!/bin/bash
# AtomS3(ロボット側、簡易版atoms3_simple_robot)とATOM Echo(PC側)の両方をPCに
# 接続した状態で実行すると、
#   1) 双方の実MACアドレスを取得してPEER_MACヘッダ(robot_mac.h/pc_mac.h)を生成
#   2) 双方のファームウェアをコンパイルして書き込み
# までを一括して行う(../s3_echo_with_I2C/setup_s3_echo.shの簡易版)。
#
# 使い方: ./setup_s3_echo_bridge.sh [AtomS3のポート] [ATOM Echoのポート]
#   (省略時 AtomS3=/dev/ttyACM0, ATOM Echo=/dev/ttyUSB0)
#
# 両方のMAC取得を先に済ませてから両方を書き込むため、書き込みは1回ずつで済む
# (先に書き込んでしまうとPEER_MACが相手の生成前の値のままになるため順序が重要)。
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
S3_PORT="${1:-/dev/ttyACM0}"
ECHO_PORT="${2:-/dev/ttyUSB0}"

echo "=== [1/4] AtomS3(${S3_PORT})の実MACアドレスを取得 ==="
"$DIR/atoms3_simple_robot/get_my_mac.sh" "$S3_PORT"

echo "=== [2/4] ATOM Echo(${ECHO_PORT})の実MACアドレスを取得 ==="
"$DIR/atom_echo_pc/get_my_mac.sh" "$ECHO_PORT"

echo "=== [3/4] AtomS3(${S3_PORT})へコンパイル・書き込み ==="
"$DIR/atoms3_simple_robot/flash.sh" "$S3_PORT"

echo "=== [4/4] ATOM Echo(${ECHO_PORT})へコンパイル・書き込み ==="
"$DIR/atom_echo_pc/flash.sh" "$ECHO_PORT"

echo "=== 完了: AtomS3とATOM Echoが互いの実MACをPEER_MACとして持つ状態で書き込み済み ==="
