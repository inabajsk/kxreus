# kxrl4t — M5StickC + M5StickV RCB-4 bridge

Two boards, one project:

- `m5stickc/` — the RCB-4's COM adapter (PlatformIO/Arduino, ESP32). Relays
  the PC's RCB-4 protocol to the real RCB-4 over an inverted UART, answers
  the reserved IMU opcode (0x90) with its own sensor, and bridges an I2C
  opcode (0x91) through to the M5StickV. Runs kxrl4t's trained walk policy
  in POLICY mode. See `m5stickc/platformio.ini` for the full board writeup.
- `m5stickv/` — the camera (K210/MaixPy). Runs
  `object_detection_I2C_slave.py` as `boot.py`, doing AprilTag/object
  detection and answering the M5StickC as an I2C slave. See
  `m5stickv/README.md` for the register map and detection record layout.

## Wiring

- M5StickC's Grove port (G33 SCL / G32 SDA) -- Grove cable -- M5StickV's
  own Grove connector (its I2C0 slave, K210 SCL=34/SDA=35 internally).
  Both sides fixed at I2C address **0x25** (see below).
- M5StickC's bottom HAT pins (G26 TX / G36 RX) -- RCB-4's COM connector
  (GND - Rx - Tx from the GND end).
- Each board's own USB port, to the PC, for flashing and (for the
  M5StickC) the actual RCB-4 relay traffic.

## I2C address

atom/m5stickv's own firmware supports two slave addresses (0x24/0x25, for
a two-camera left/right-eye build). This project has exactly one M5StickV,
so both sides are pinned to **0x25**: `m5stickc/lib/rcb4_link/rcb4_link.h`'s
`M5STICKV_DEFAULT_ADDR` is a compile-time constant on the ESP32 side, and
`./flash.sh` below always passes `0x25` to `m5stickv/flash.sh` rather than
leaving it a free choice at flash time.

## Flashing

Both boards at once, once each is on its own USB port:

    ./flash.sh <m5stickc port> <m5stickv port>
    ./flash.sh /dev/ttyUSB0 /dev/ttyUSB1
    ./flash.sh /dev/ttyUSB0 /dev/ttyUSB1 --skip-clips   # boot.py only, no WAV re-upload

Or each side on its own:

    (cd m5stickc && ./flash.sh <port>)
    (cd m5stickv && ./flash.sh <port> 0x25)

## Building just the M5StickC side

    cd m5stickc && pio run -e m5stickc

Other envs: `bench`, `policy-boot`, `wifi-probe`, `imu-probe` (see
`m5stickc/platformio.ini`).
