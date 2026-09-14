# kxrl4t — M5StickC + M5Stack UnitV RCB-4 bridge

Two boards, one project:

- `m5stickc/` — the RCB-4's COM adapter (PlatformIO/Arduino, ESP32). Relays
  the PC's RCB-4 protocol to the real RCB-4 over an inverted UART, answers
  the reserved IMU opcode (0x90) with its own sensor, and bridges an I2C
  opcode (0x91) through to the UnitV. Runs kxrl4t's trained walk policy in
  POLICY mode. See `m5stickc/platformio.ini` for the full board writeup.
- `m5unitv/` — the camera (K210/MaixPy, `is_m5unitv = True`). Runs
  `object_detection_I2C_slave.py` as `boot.py`, doing AprilTag/object
  detection and answering the M5StickC as an I2C slave -- the SAME
  register map and protocol as the M5StickV sibling tree
  (`~/kxreus/m5stack/m5stickc_m5stickv_kxrl4t`), just a different camera
  board. See `m5unitv/README.md` for UnitV-specific differences (no LCD,
  no speaker) and the detection record layout.

## Wiring

- M5StickC's Grove port (G33 SCL / G32 SDA) -- Grove cable -- UnitV's own
  Grove connector (its I2C0 slave, K210 SCL=34/SDA=35 internally). Both
  sides fixed at I2C address **0x25** (see below).
- M5StickC's bottom HAT pins (G26 TX / G36 RX) -- RCB-4's COM connector
  (GND - Rx - Tx from the GND end).
- Each board's own USB port, to the PC, for flashing and (for the
  M5StickC) the actual RCB-4 relay traffic.

## I2C address

`m5stickc/lib/rcb4_link/rcb4_link.h`'s `M5STICKV_DEFAULT_ADDR` is a
compile-time constant, **0x25**, on the ESP32 side. `m5unitv/flash.sh`
already defaults to 0x25 too; `./flash.sh` below still passes it
explicitly so this stays correct if that default ever changes.

## Flashing

Both boards at once, once each is on its own USB port:

    ./flash.sh <m5stickc port> <m5unitv port>
    ./flash.sh /dev/ttyUSB0 /dev/ttyUSB1

Or each side on its own:

    (cd m5stickc && ./flash.sh <port>)
    (cd m5unitv && ./flash.sh <port> 0x25)

## Building just the M5StickC side

    cd m5stickc && pio run -e m5stickc

Other envs: `bench`, `policy-boot`, `wifi-probe`, `imu-probe` (see
`m5stickc/platformio.ini`).
