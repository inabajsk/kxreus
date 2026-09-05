#!/usr/bin/env python3
"""Drive the hand while the policy runs on the AtomS3.

This is `hand_deploy.py teleop` with the loop taken out of it. The actor, the
observation, the servo reads and the servo writes all live on the AtomS3 now
(see lib/policy_mode); what is left here is a joystick and a telemetry
display. Nothing this sends is time-critical, and nothing the hand does waits
on it -- which is the point, because the PC's USB round trip was 2.7 ms of a
25 ms control step.

Put the AtomS3 in POLICY mode with the button first: BRIDGE -> STATUS ->
POLICY. The screen says which.

    policy_teleop.py [/dev/ttyACM0]

    r       start. The hand goes to the home stance first (about a
            second, shown as HOME), then the policy takes over standing
    w / s   forward speed up / down
    a / d   turn left / right
    space   hold: ramp back to the home pose, policy still running
    f       free every servo
    q       quit (frees the servos on the way out)

The protocol is two fixed-size binary frames, described in
lib/policy_mode/policy_mode.h. It is binary rather than text because the
device parses it inside its control loop.
"""

import argparse
import os
import select
import struct
import sys
import termios
import time
import tty

import serial

HOST_MAGIC = 0xA5
HOST_FRAME_SIZE = 9
DEVICE_MAGIC = 0x5A
DEVICE_FRAME_SIZE = 34

# Velocities travel as int16 thousandths, so 0.35 m/s is 350.
VELOCITY_SCALE = 1000.0

FREE, RUN, HOLD = 0, 1, 2
STATE_NAMES = {0: "IDLE", 1: "RUN", 2: "HOLD", 3: "FAULT", 4: "HOME"}
MODE_NAMES = {0: "free", 1: "run", 2: "hold"}

# The same limits hand_deploy.py's teleop uses, so the stick feels the same.
VX_MIN, VX_MAX, VX_STEP = -0.3, 0.5, 0.05
WZ_MAX, WZ_STEP = 1.0, 0.1

# The device zeroes the command after this long without a frame, and frees the
# servos after longer still, so something has to keep arriving even when the
# operator is not touching anything.
SEND_INTERVAL_S = 0.1


def host_frame(mode, vx, vy, wz):
    """Build the 9 byte command frame.

    Parameters
    ----------
    mode : int
        FREE, RUN or HOLD.
    vx, vy, wz : float
        Velocity command in m/s and rad/s.

    Returns
    -------
    bytes
    """
    body = struct.pack(
        "<BBhhh",
        HOST_MAGIC,
        mode,
        int(round(vx * VELOCITY_SCALE)),
        int(round(vy * VELOCITY_SCALE)),
        int(round(wz * VELOCITY_SCALE)),
    )
    return body + bytes([sum(body) & 0xFF])


def read_telemetry(ser):
    """Return the most recent telemetry frame, or None.

    Only the newest frame is kept: the device sends one per control step and
    this is a display, so an older one has nothing to add.
    """
    latest = None
    while ser.in_waiting >= DEVICE_FRAME_SIZE:
        if ser.read(1)[0] != DEVICE_MAGIC:
            continue
        rest = ser.read(DEVICE_FRAME_SIZE - 1)
        if len(rest) != DEVICE_FRAME_SIZE - 1:
            break
        (state, request, _pad, step, loop_us, overruns, errors,
         host_frames, peak, vx, wz, home_err, pose_err) = struct.unpack(
            "<BBBIIIIIhhhhh", rest[:DEVICE_FRAME_SIZE - 1]
        )
        latest = {
            "state": state,
            "request": request,
            "step": step,
            "loop_us": loop_us,
            "overruns": overruns,
            "errors": errors,
            # Frames the device accepted. If this is not climbing while this
            # program is running, nothing sent from here is arriving, and no
            # amount of pressing keys will change what the hand does.
            "host_frames": host_frames,
            "peak_action": peak / 1000.0,
            # The command as the DEVICE understood it, not as typed here.
            "vx": vx / 1000.0,
            "wz": wz / 1000.0,
            # Worst joint distance from the home stance, latched when homing
            # finished. This is what says the hand physically got there --
            # -1 means the read failed, and a large value on the floor is
            # usually the thumb stalling against it (calibration.yaml records
            # 34 deg), not a fault.
            "home_err_deg": None if home_err < 0 else home_err * 57.2958 / 1000.0,
            "pose_err_deg": pose_err * 57.2958 / 1000.0,
        }
    return latest


class KeyReader:
    """Single key presses from the terminal, without waiting for Enter.

    cbreak rather than raw on purpose: cbreak leaves ISIG alone, so Ctrl-C
    still works. In raw mode an operator watching the hand do something wrong
    would have no way to stop it.
    """

    def __enter__(self):
        if not sys.stdin.isatty():
            raise SystemExit("teleop reads keys: run it from a terminal")
        self.fd = sys.stdin.fileno()
        self.saved = termios.tcgetattr(self.fd)
        tty.setcbreak(self.fd)
        return self

    def __exit__(self, *exc):
        termios.tcsetattr(self.fd, termios.TCSADRAIN, self.saved)
        return False

    def keys(self):
        out = []
        while select.select([sys.stdin], [], [], 0)[0]:
            ch = os.read(self.fd, 1).decode("utf-8", "ignore")
            if not ch:
                break
            out.append(ch)
        return out


def clamp(value, low, high):
    return max(low, min(high, value))


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("port", nargs="?", default="/dev/ttyACM0")
    args = parser.parse_args()

    ser = serial.Serial(args.port, 115200, timeout=0.05)
    time.sleep(0.2)
    ser.reset_input_buffer()

    vx = wz = 0.0
    mode = FREE
    last_send = 0.0
    telemetry = None

    print(__doc__.split("Put the AtomS3")[0].strip())
    print("\n  r start (home, then stand)   w/s speed   a/d turn"
          "   space hold   f free   q quit")
    print("\n  Servos stay free until you press r or a movement key.")
    print("  'rx' below counts frames the AtomS3 accepted from here."
          " If it does not climb,")
    print("  nothing sent from this program is arriving and the button is"
          " probably not on POLICY.\n")

    with KeyReader() as keys:
        try:
            while True:
                quit_now = False
                for key in keys.keys():
                    if key in "wW":
                        vx = clamp(vx + VX_STEP, VX_MIN, VX_MAX)
                        mode = RUN
                    elif key in "sS":
                        vx = clamp(vx - VX_STEP, VX_MIN, VX_MAX)
                        mode = RUN
                    elif key in "aA":
                        wz = clamp(wz + WZ_STEP, -WZ_MAX, WZ_MAX)
                        mode = RUN
                    elif key in "dD":
                        wz = clamp(wz - WZ_STEP, -WZ_MAX, WZ_MAX)
                        mode = RUN
                    elif key in "rR":
                        # Start driving without asking for any motion: the
                        # policy runs, the command is zero, so it stands. The
                        # first key an operator should press.
                        mode = RUN
                        vx = wz = 0.0
                    elif key == " ":
                        mode = HOLD
                    elif key in "fF":
                        mode = FREE
                        vx = wz = 0.0
                    elif key in "qQ":
                        quit_now = True
                if quit_now:
                    break

                now = time.time()
                if now - last_send >= SEND_INTERVAL_S:
                    last_send = now
                    ser.write(host_frame(mode, vx, 0.0, wz))

                fresh = read_telemetry(ser)
                if fresh is not None:
                    telemetry = fresh
                if telemetry is not None:
                    # vx/wz are printed as the DEVICE reports them, not as
                    # typed here, so a command that never arrived shows as a
                    # command that never arrived.
                    print(
                        "\r  vx {:+.2f} wz {:+.2f} | {:<5s} req {:<4s}"
                        " rx {:<6d} step {:<7d} loop {:5.1f}ms"
                        " over {:<4d} err {:<3d} |act| {:.2f}"
                        " home {:>6s} pose {:4.1f}d   ".format(
                            telemetry["vx"],
                            telemetry["wz"],
                            STATE_NAMES.get(telemetry["state"], "?"),
                            MODE_NAMES.get(telemetry["request"], "?"),
                            telemetry["host_frames"],
                            telemetry["step"],
                            telemetry["loop_us"] / 1000.0,
                            telemetry["overruns"],
                            telemetry["errors"],
                            telemetry["peak_action"],
                            "-" if telemetry["home_err_deg"] is None
                            else "{:.1f}d".format(telemetry["home_err_deg"]),
                            telemetry["pose_err_deg"],
                        ),
                        end="",
                        flush=True,
                    )
                time.sleep(0.01)
        finally:
            # Leaving a hand held by a program that has stopped watching it is
            # the one outcome worth writing a finally block for.
            for _ in range(3):
                ser.write(host_frame(FREE, 0.0, 0.0, 0.0))
                time.sleep(0.02)
            ser.close()
            print("\nfreed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
