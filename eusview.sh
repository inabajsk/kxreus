#!/bin/bash
# eusview.sh : EusView デモ（eusview.l）を起動する。デスクトップのアイコン（make eusview-desktop）から呼ばれる。
#   ./eusview.sh [robot-name]
# EusLisp を探す順: $EUSVIEW_EUS -> PATH の irteusgl -> ~/.bashrc の設定（bash -i）->
#   $JSKEUS_DIR/bashrc.eus（~/jskeus）-> roseus（~/roseus_ws/devel, /opt/ros/*）
# 端末から起動したときは REPL が使える。端末なし（アイコン）のときは ~/.cache/eusview.log に出力し、
# EusView の quit で終わる。
KXREUS_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$KXREUS_DIR" || exit 1

find_eus() {
  if [ -n "$EUSVIEW_EUS" ]; then echo "$EUSVIEW_EUS"; return 0; fi
  command -v irteusgl && return 0
  command -v roseus && return 0
  return 1
}

EUS=$(find_eus)
if [ -z "$EUS" ] && [ -f "$HOME/.bashrc" ]; then
  # ~/.bashrc は非対話シェルではすぐ return することが多いので、対話シェルで読んで環境を取り出す
  eval "$(bash -ic 'for v in PATH EUSDIR ARCHDIR LD_LIBRARY_PATH ROS_DISTRO ROS_ROOT ROS_PACKAGE_PATH ROS_MASTER_URI CMAKE_PREFIX_PATH PYTHONPATH ROSLISP_PACKAGE_DIRECTORIES; do [ -n "${!v}" ] && printf "export %s=%q\n" "$v" "${!v}"; done' 2>/dev/null </dev/null)"
  EUS=$(find_eus)
fi
if [ -z "$EUS" ]; then
  J=${JSKEUS_DIR:-$HOME/jskeus}
  [ -f "$J/bashrc.eus" ] && . "$J/bashrc.eus"
  if [ -z "$EUSDIR" ] && [ -d "$J/eus" ]; then
    export EUSDIR=$J/eus
    case "$(uname -s)-$(uname -m)" in
      Linux-x86_64) export ARCHDIR=Linux64 ;;
      Linux-*) export ARCHDIR=LinuxARM ;;
      Darwin-*) export ARCHDIR=Darwin ;;
    esac
    export PATH=$EUSDIR/$ARCHDIR/bin:$J/irteus/bin:$PATH
    export LD_LIBRARY_PATH=$EUSDIR/$ARCHDIR/bin:$LD_LIBRARY_PATH
  fi
  EUS=$(find_eus)
fi
if [ -z "$EUS" ]; then
  for s in "$HOME/roseus_ws/devel/setup.bash" /opt/ros/*/setup.bash; do
    if [ -f "$s" ]; then . "$s"; EUS=$(find_eus) && break; fi
  done
fi
# irteusgl needs EUSDIR (roseus sets it itself)
if [ -n "$EUS" ] && [ -z "$EUSDIR" ] && [ "$(basename "$EUS")" != roseus ]; then
  J=${JSKEUS_DIR:-$HOME/jskeus}
  [ -f "$J/bashrc.eus" ] && . "$J/bashrc.eus"
fi
if [ -z "$EUS" ]; then
  msg="EusView: irteusgl / roseus が見つかりません（jskeus か roseus を入れて PATH を通す, または EUSVIEW_EUS=... ）"
  echo "$msg" >&2
  command -v notify-send >/dev/null && notify-send "EusView" "$msg"
  command -v zenity >/dev/null && zenity --error --text="$msg" 2>/dev/null
  exit 1
fi

ROBOT=${1:-${EUSVIEW_ROBOT:-}}
ARG=${ROBOT:+\"$ROBOT\"}
if [ -t 0 ]; then
  echo ";; EusView: $EUS eusview.l (REPL: (eusview \"name\"), (eusview-quit))"
  exec "$EUS" eusview.l "(eusview $ARG)"
else
  LOG=${EUSVIEW_LOG:-$HOME/.cache/eusview.log}
  mkdir -p "$(dirname "$LOG")"
  echo ";; EusView $(date) $EUS" > "$LOG"
  exec "$EUS" eusview.l "(eusview-main $ARG)" </dev/null >>"$LOG" 2>&1
fi
