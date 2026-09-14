#!/bin/bash
# Flash both halves of this project in one call: the M5StickC (RCB-4
# bridge/host, see m5stickc/) and the M5Stack UnitV (I2C camera, see
# m5unitv/) -- two separate boards on two separate USB ports, each with
# its own toolchain (PlatformIO for the ESP32 side, a raw MaixPy REPL
# upload for the K210 side). See README.md for wiring.
#
#   ./flash.sh <m5stickc port> <m5unitv port>
#   ./flash.sh /dev/ttyUSB0 /dev/ttyUSB1
#
# Both sides are pinned to I2C address 0x25: m5stickc/lib/rcb4_link/
# rcb4_link.h's own M5STICKV_DEFAULT_ADDR is a compile-time constant, so
# this always passes 0x25 to m5unitv/flash.sh too (that script already
# defaults to 0x25 on its own -- passed explicitly here anyway, so this
# stays correct if that default ever changes).
set -e
STICKC_PORT="$1"
UNITV_PORT="$2"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$STICKC_PORT" ] || [ -z "$UNITV_PORT" ]; then
  echo "usage: $0 <m5stickc port> <m5unitv port>" >&2
  exit 1
fi

echo "[flash] M5StickC ($STICKC_PORT) ..."
(cd "$DIR/m5stickc" && ./flash.sh "$STICKC_PORT")

echo "[flash] M5Stack UnitV ($UNITV_PORT, I2C 0x25) ..."
(cd "$DIR/m5unitv" && ./flash.sh "$UNITV_PORT" 0x25)

echo "[flash] both done."
