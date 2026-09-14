#!/bin/bash
# Flash both halves of this project in one call: the M5StickC (RCB-4
# bridge/host, see m5stickc/) and the M5StickV (I2C camera, see m5stickv/)
# -- two separate boards on two separate USB ports, each with its own
# toolchain (PlatformIO for the ESP32 side, a raw MaixPy REPL upload for
# the K210 side). See README.md for wiring.
#
#   ./flash.sh <m5stickc port> <m5stickv port> [--skip-clips]
#
#   ./flash.sh /dev/ttyUSB0 /dev/ttyUSB1
#   ./flash.sh /dev/ttyUSB0 /dev/ttyUSB1 --skip-clips   # boot.py only, no WAVs
#
# Both sides are pinned to I2C address 0x25: m5stickc/lib/rcb4_link/
# rcb4_link.h's own M5STICKV_DEFAULT_ADDR is a compile-time constant, so
# this always passes 0x25 to m5stickv/flash.sh too rather than exposing
# atom/m5stickv's own left/right-eye (0x24/0x25) choice -- there is exactly
# one M5StickV in this project, and it must match the ESP32 side's own
# constant, not be a free choice made at flash time.
set -e
STICKC_PORT="$1"
STICKV_PORT="$2"
SKIP_CLIPS="$3"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$STICKC_PORT" ] || [ -z "$STICKV_PORT" ]; then
  echo "usage: $0 <m5stickc port> <m5stickv port> [--skip-clips]" >&2
  exit 1
fi

echo "[flash] M5StickC ($STICKC_PORT) ..."
(cd "$DIR/m5stickc" && ./flash.sh "$STICKC_PORT")

echo "[flash] M5StickV ($STICKV_PORT, I2C 0x25) ..."
(cd "$DIR/m5stickv" && ./flash.sh "$STICKV_PORT" 0x25 $SKIP_CLIPS)

echo "[flash] both done."
