#!/bin/bash
# Build and upload this robot's firmware to an M5Stack FIRE or GRAY.
#
#   ./flash.sh [port] [env]    (default /dev/ttyUSB0, m5stack-fire)
#
#   ./flash.sh /dev/ttyUSB0 m5stack-gray
#
# Both boards enumerate through a CP2104 USB-UART bridge chip as
# /dev/ttyUSBn -- the number can shift on replug, so check `ls /dev/ttyUSB*`
# if this fails -- and take esptool's normal stub loader just fine.
set -e
PORT="${1:-/dev/ttyUSB0}"
ENV="${2:-m5stack-fire}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

if [ ! -e "$PORT" ]; then
  echo "[flash] $PORT not found -- plug in the board's USB cable first." >&2
  exit 1
fi

pio run -e "$ENV" -t upload --upload-port "$PORT"
