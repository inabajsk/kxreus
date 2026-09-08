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

    policy_teleop.py                    # find it on the network by mDNS
    policy_teleop.py 192.168.1.23       # or by address, from the LCD
    policy_teleop.py /dev/ttyACM0       # or over the USB cable

    r       start. The hand goes to the home stance first (about a
            second, shown as HOME), then the policy takes over standing
    g       rise: roll on the wheels -> stand on the fingertips
    h       sit:  fingertips -> back onto the wheels
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
import socket
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

FREE, RUN, HOLD, RISE, SIT = 0, 1, 2, 3, 4
STATE_NAMES = {0: "IDLE", 1: "RUN", 2: "HOLD", 3: "FAULT", 4: "HOME",
               5: "SEQ"}
MODE_NAMES = {0: "free", 1: "run", 2: "hold", 3: "rise", 4: "sit"}
# The order lib/policy compiles them in.
ACTOR_NAMES = {0: "crawl", 1: "omni", 2: "walk", 3: "legs", 4: "rise", 5: "sit"}
# The device sets bit 7 of the actor byte when it is NOT using the IMU.

# The same limits hand_deploy.py's teleop uses, so the stick feels the same.
VX_MIN, VX_MAX, VX_STEP = -0.3, 0.5, 0.05
WZ_MAX, WZ_STEP = 1.0, 0.1

# The device zeroes the command after this long without a frame, and frees the
# servos after longer still, so something has to keep arriving even when the
# operator is not touching anything.
SEND_INTERVAL_S = 0.1


def host_frame(mode, vx, vy, wz, use_imu=False):
    """Build the 9 byte command frame.

    Parameters
    ----------
    mode : int
        FREE, RUN or HOLD.
    vx, vy, wz : float
        Velocity command in m/s and rad/s.
    use_imu : bool
        Whether the device should take its attitude from the IMU. Default
        False, which is the policy's own stance constant. The IMU is the
        physically honest source, but the runs that actually worked on this
        hand were the ones without it, and the mounting rotation still has a
        ~10 degree residual that has not been separated into "board tilted"
        from "hand not level". Off until that is measured, not because the
        IMU is wrong.

    Returns
    -------
    bytes
    """
    body = struct.pack(
        "<BBhhh",
        HOST_MAGIC,
        mode if use_imu else (mode | 0x80),
        int(round(vx * VELOCITY_SCALE)),
        int(round(vy * VELOCITY_SCALE)),
        int(round(wz * VELOCITY_SCALE)),
    )
    return body + bytes([sum(body) & 0xFF])


def read_telemetry(link):
    """Return the most recent telemetry frame, or None.

    Only the newest frame is kept: the device sends one per control step and
    this is a display, so an older one has nothing to add.
    """
    latest = None
    for rest in link.frames():
        (state, request, actor, step, loop_us, overruns, errors,
         host_frames, peak, vx, wz, home_err, pose_err) = struct.unpack(
            "<BBBIIIIIhhhhh", rest[:DEVICE_FRAME_SIZE - 1]
        )
        latest = {
            "state": state,
            "request": request,
            "actor": actor,
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


# The device advertises this over mDNS once it has joined an AP.
MDNS_HOSTNAME = "kxr-hand.local"
UDP_PORT = 9000


class SerialTransport:
    """The USB cable."""

    def __init__(self, port):
        self.ser = serial.Serial(port, 115200, timeout=0.05)
        time.sleep(0.2)
        self.ser.reset_input_buffer()
        self.name = port

    def send(self, frame):
        self.ser.write(frame)

    def frames(self):
        out = []
        while self.ser.in_waiting >= DEVICE_FRAME_SIZE:
            if self.ser.read(1)[0] != DEVICE_MAGIC:
                continue
            rest = self.ser.read(DEVICE_FRAME_SIZE - 1)
            if len(rest) == DEVICE_FRAME_SIZE - 1:
                out.append(rest)
        return out

    def close(self):
        self.ser.close()


class UdpTransport:
    """The lab network.

    Deliberately connectionless in both directions: the device answers to
    whatever address last sent it a command, so nothing has to be told where
    this program is, and moving to another machine needs no restart on the
    robot.
    """

    def __init__(self, host):
        self.addr = (host, UDP_PORT)
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setblocking(False)
        self.name = "{}:{}".format(host, UDP_PORT)

    def send(self, frame):
        try:
            self.sock.sendto(frame, self.addr)
        except OSError:
            pass  # a lost command is repeated 100 ms later by design

    def frames(self):
        out = []
        while True:
            try:
                data, _ = self.sock.recvfrom(256)
            except (BlockingIOError, OSError):
                break
            if len(data) == DEVICE_FRAME_SIZE and data[0] == DEVICE_MAGIC:
                out.append(data[1:])
        return out

    def close(self):
        self.sock.close()


def open_transport(target):
    """Pick a transport from what the target looks like.

    A path is the USB cable; anything else is a host on the network; nothing
    at all means ask mDNS, which is what the device advertises itself over.
    """
    if target is None:
        try:
            host = socket.gethostbyname(MDNS_HOSTNAME)
        except OSError:
            raise SystemExit(
                "could not resolve {}. The AtomS3 advertises that name only"
                " once it has joined an AP -- check the LCD (hold the button"
                " for STATUS), or pass its address or /dev/ttyACM0"
                " explicitly.".format(MDNS_HOSTNAME)
            )
        print("found {} at {}".format(MDNS_HOSTNAME, host))
        return UdpTransport(host)
    if target.startswith("/") or target.startswith("COM"):
        return SerialTransport(target)
    return UdpTransport(target)


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "target",
        nargs="?",
        default=None,
        help="a serial port (/dev/ttyACM0), an address (192.168.1.23), or"
             " nothing to look the robot up by mDNS",
    )
    args = parser.parse_args()

    link = open_transport(args.target)

    vx = wz = 0.0
    mode = FREE
    # Matches the device's own default and the web page's, so the first frame
    # this program sends does not silently switch the attitude source out from
    # under a hand that was working.
    use_imu = False
    last_send = 0.0
    telemetry = None

    print(__doc__.split("Put the AtomS3")[0].strip())
    print("\n  connected via {}".format(link.name))
    print("\n  g rise   h sit   i attitude: stance constant <-> IMU"
          " (a * after the policy name means constant)")
    print("  Attitude starts at the stance constant; press i for the IMU.")
    print("  r start (home, then stand)   w/s speed   a/d turn"
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
                    elif key in "iI":
                        # A/B the attitude source. The wheeled policy was
                        # first driven with a constant gravity and a zero
                        # gyro, and worked; the live IMU arrived at the same
                        # time as the move onto the AtomS3, so this is the
                        # only way to tell the two apart on the hand.
                        use_imu = not use_imu
                    elif key in "gG":
                        # Wheels -> fingertips. The device owns the sequence
                        # from here; it ramps, runs rise, and hands straight
                        # over to the walking policy without a ramp between.
                        mode = RISE
                    elif key in "hH":
                        mode = SIT
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
                    link.send(host_frame(mode, vx, 0.0, wz, use_imu))

                fresh = read_telemetry(link)
                if fresh is not None:
                    telemetry = fresh
                if telemetry is not None:
                    # vx/wz are printed as the DEVICE reports them, not as
                    # typed here, so a command that never arrived shows as a
                    # command that never arrived.
                    print(
                        "\r  vx {:+.2f} wz {:+.2f} | {:<5s} req {:<4s}"
                        " {:<5s} rx {:<6d} step {:<7d} loop {:5.1f}ms"
                        " over {:<4d} err {:<3d} |act| {:.2f}"
                        " home {:>6s} pose {:4.1f}d   ".format(
                            telemetry["vx"],
                            telemetry["wz"],
                            STATE_NAMES.get(telemetry["state"], "?"),
                            MODE_NAMES.get(telemetry["request"], "?"),
                            ACTOR_NAMES.get(telemetry["actor"] & 0x7F, "?")
                            + ("" if not telemetry["actor"] & 0x80 else "*"),
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
                link.send(host_frame(FREE, 0.0, 0.0, 0.0, use_imu))
                time.sleep(0.02)
            link.close()
            print("\nfreed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
