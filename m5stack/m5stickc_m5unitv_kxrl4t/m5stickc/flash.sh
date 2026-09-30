#!/bin/bash
# Build and upload this robot's firmware to an M5StickC.
#
#   ./flash.sh [port]          (default /dev/ttyUSB0)
#
# Enumerates through its CP2104 USB-UART bridge chip as /dev/ttyUSBn -- the
# number can shift on replug, so check `ls /dev/ttyUSB*` if this fails.
set -e
PORT="${1:-/dev/ttyUSB0}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

if [ ! -e "$PORT" ]; then
  echo "[flash] $PORT not found -- plug in the M5StickC's USB cable first." >&2
  exit 1
fi

pio run -e m5stickc -t upload --upload-port "$PORT"
