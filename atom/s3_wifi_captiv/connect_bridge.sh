#!/bin/bash
# atoms3_wifi_captiv.ino のTCPブリッジ(既定ポート4000)へsocatで接続し、
# /dev/ttyKXR0 という固定名の仮想シリアルポートとして開けるようにする。
# /dev/直下へのシンボリックリンク作成が必要なため root権限で実行すること。
#
# 使い方: sudo ./connect_bridge.sh <AtomS3のIPアドレス> [ポート、既定4000]
#   IPアドレス・ポートはAtomS3本体の液晶(接続成功画面)に表示されている。
#
# 接続中はフォアグラウンドで動き続ける(Ctrl+Cで終了、/dev/ttyKXR0も消える)。
# バックグラウンドで動かし続けたい場合は末尾に "&" を付けて実行すること。
#
# 接続後、euslisp側からは以下で開ける:
#   (send *ri* :rcb4-open :exec t :devname "ttyKXR0" :baud 1250000)
set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "error: rootで実行してください(sudo ./connect_bridge.sh <IP> [ポート])" >&2
  exit 1
fi

IP="$1"
PORT="${2:-4000}"
LINK="/dev/ttyKXR0"

if [ -z "$IP" ]; then
  echo "使い方: sudo $0 <AtomS3のIPアドレス> [ポート、既定4000]" >&2
  exit 1
fi

# 前回の接続が残した古いシンボリックリンクだけを掃除する(symlink以外の
# 実ファイルが同名で存在する場合は誤って消さないよう対象外にする)。
if [ -L "$LINK" ]; then
  rm -f "$LINK"
fi

echo "[connect_bridge] ${IP}:${PORT} <-> ${LINK} を中継します(Ctrl+Cで終了)"
exec socat "TCP:${IP}:${PORT}" "PTY,link=${LINK},raw,echo=0,mode=666"
