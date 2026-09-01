#!/bin/bash
# AtomS3(ロボット側)とATOM Echo(PC側)の両方をPCに接続した状態で実行すると、
#   1) 双方の実MACアドレスを取得してPEER_MACヘッダ(robot_mac.h/pc_mac.h)を生成
#   2) 双方のファームウェアをコンパイルして書き込み
# までを一括して行う。新品の機体に交換した直後や、初めてこのリポジトリを
# cloneして実機セットアップする時に使う想定(個々の手順は
# atom_s3_robot/get_my_mac.sh・atom_s3_robot/flash.sh・
# atom_echo_pc/get_my_mac.sh・atom_echo_pc/flash.sh を参照)。
#
# 使い方: ./setup_s3_echo.sh [AtomS3のポート] [ATOM Echoのポート]
#   (省略時 AtomS3=/dev/ttyACM0, ATOM Echo=/dev/ttyUSB0)
#
# 両方のMAC取得を先に済ませてから両方を書き込むため、書き込みは1回ずつで済む
# (先に書き込んでしまうとPEER_MACが相手の生成前の値のままになるため順序が重要)。
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
S3_PORT="${1:-/dev/ttyACM0}"
ECHO_PORT="${2:-/dev/ttyUSB0}"

echo "=== [1/4] AtomS3(${S3_PORT})の実MACアドレスを取得 ==="
"$DIR/atom_s3_robot/get_my_mac.sh" "$S3_PORT"

echo "=== [2/4] ATOM Echo(${ECHO_PORT})の実MACアドレスを取得 ==="
"$DIR/atom_echo_pc/get_my_mac.sh" "$ECHO_PORT"

echo "=== [3/4] AtomS3(${S3_PORT})へコンパイル・書き込み ==="
"$DIR/atom_s3_robot/flash.sh" "$S3_PORT"

echo "=== [4/4] ATOM Echo(${ECHO_PORT})へコンパイル・書き込み ==="
"$DIR/atom_echo_pc/flash.sh" "$ECHO_PORT"

echo "=== 完了: AtomS3とATOM Echoが互いの実MACをPEER_MACとして持つ状態で書き込み済み ==="
