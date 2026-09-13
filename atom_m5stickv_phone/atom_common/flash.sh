#!/bin/bash
# Build and upload this robot's firmware.
#
#   ./flash.sh [port]          (default /dev/ttyACM0)
#
# --no-stub (platformio.ini) is what makes this reliable on the S3's native
# USB: esptool's normal stub loader makes the CDC port drop and re-enumerate
# mid-upload, which on this board was an outright failure ("Stub running..."
# then no answer), not just a slow one. Talking to the ROM bootloader
# directly instead costs about 40 extra seconds and always works.
set -e
PORT="${1:-/dev/ttyACM0}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

if [ ! -e "$PORT" ]; then
  echo "[flash] $PORT not found -- plug in the AtomS3's USB cable first." >&2
  exit 1
fi

pio run -e m5stack-atoms3 -t upload --upload-port "$PORT"
