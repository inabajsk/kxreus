#!/bin/bash
# 「ロボット側もATOM Echo」構成(atom_echo_pc <-> atom_echo_robot)の
# 2台のATOM Echoを、両方PCに接続した状態で実行すると、
#   1) 双方の実MACアドレスを取得してPEER_MACヘッダ(robot_mac.h/pc_mac.h)を生成
#   2) 双方のファームウェアをコンパイルして書き込み
# までを一括して行う(setup_s3_echo.shのEcho-Echo版)。
#
# 【この構成の位置づけ・setup_s3_echo.sh(AtomS3+ATOM Echo)との違い】
#   - setup_s3_echo.sh: ロボット側にAtomS3を搭載。IMU内蔵・M5StickV用I2C・
#     Edge Impulseによる高精度な音声認識を使える。腕やM5StickVを搭載する
#     機体(本プロジェクトのメイン機体)向け。
#   - setup_echo_echo.sh(このファイル): ロボット側にもうひとつのATOM Echoを
#     搭載。IMUもM5StickV用I2Cも無い代わりに安価・小型で、4脚・6脚など
#     「腕もM5StickVも載せず、とにかく無線でRCB4を操作したい」ロボット向け。
#     音声認識もロボット側ATOM Echo単体で完結する自作の軽量テンプレート
#     マッチング方式(Edge Impulse不要、ニューラルネット不使用)で行っており、
#     「マイコン単体でも音声で動かせる」ことを示す軽量なサンプルになっている
#     (詳細はatom_echo_robot/README.md参照)。
#   - 注意: 腕やM5StickVを載せない機体であっても、IMUが要る(姿勢による
#     転倒検知・傾き補正等をしたい)場合はAtomS3+ATOM Echo構成
#     (setup_s3_echo.sh)の方が適している。ATOM EchoにはIMUが無いため。
#
# 【PC側ファームウェアはAtomS3構成と共通(2026.8統一)】
#   PC側は`atom_echo_pc/`(atom_echo_voice_cmd_pc.ino)を使う。以前はRCB4中継が
#   シーケンス番号+ACKの無いプレーン版(atom_echo_pc_bridge/、廃止済み)だったが、
#   ACK付き再送プロトコルの方が実機で信頼性が高いことが分かっていたため、
#   ロボット側(atom_echo_voice_cmd_robot.ino)もACK対応に更新し、PC側を
#   AtomS3構成と同じ1種類のファームウェアに統一した。
#
# 使い方: ./setup_echo_echo.sh <ロボット側ATOM Echoのポート> <PC側ATOM Echoのポート>
#   (setup_s3_echo.shと引数順序を揃えている。他のATOM Echo/AtomS3と混同しやすい
#   ため既定値は設けていない。必ず両方のポートを明示すること。どちらが物理的に
#   どちらの個体かはLED色や`esptool --port <port> read-mac`で事前に確認しておくこと)
#
# 両方のMAC取得を先に済ませてから両方を書き込むため、書き込みは1回ずつで済む
# (先に書き込んでしまうとPEER_MACが相手の生成前の値のままになるため順序が重要)。
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
ROBOT_PORT="$1"
PC_PORT="$2"
if [ -z "$ROBOT_PORT" ] || [ -z "$PC_PORT" ]; then
  echo "usage: $0 <ロボット側ATOM Echoのポート> <PC側ATOM Echoのポート>" >&2
  exit 1
fi

echo "=== [1/4] ロボット側ATOM Echo(${ROBOT_PORT})の実MACアドレスを取得 ==="
"$DIR/atom_echo_robot/get_my_mac.sh" "$ROBOT_PORT"

echo "=== [2/4] PC側ATOM Echo(${PC_PORT})の実MACアドレスを取得 ==="
"$DIR/atom_echo_pc/get_my_mac.sh" "$PC_PORT" echo

echo "=== [3/4] ロボット側ATOM Echo(${ROBOT_PORT})へコンパイル・書き込み ==="
"$DIR/atom_echo_robot/flash.sh" "$ROBOT_PORT"

echo "=== [4/4] PC側ATOM Echo(${PC_PORT})へコンパイル・書き込み ==="
"$DIR/atom_echo_pc/flash.sh" "$PC_PORT"

echo "=== 完了: 2台のATOM Echoが互いの実MACをPEER_MACとして持つ状態で書き込み済み ==="
