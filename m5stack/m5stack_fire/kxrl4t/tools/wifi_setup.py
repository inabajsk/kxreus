#!/usr/bin/env python3
"""Tell the AtomS3 which access point to join.

The credentials live in the device's NVS, not in this repository and not in a
build flag -- so a firmware image can be shared and a network cannot be leaked
by sharing it. They are written once, over the USB cable, and survive
reflashing.

    wifi_setup.py --ssid lab-wifi --password '...' [/dev/ttyACM0]
    wifi_setup.py                         # from .env, see below
    wifi_setup.py --show                  # what is stored now
    wifi_setup.py --clear                 # forget it

Retyping the network every time is the reason a `.env` beside this script is
read, if there is one:

    KXR_WIFI_SSID=lab-wifi
    KXR_WIFI_PASSWORD=hunter2

It is gitignored, and it changes nothing about where the secret ends up on the
DEVICE: by default that is the AtomS3's NVS, which is not encrypted, so anyone
holding the board can read the password back out with esptool. What `.env`
saves is the typing -- and it keeps the password out of shell history, which a
command line does not.

`--once` is the other trade: the credentials are held in the device's RAM,
nothing is written, and any stored copy is erased. Then nothing on the board
can be read back -- but it forgets the network at every power cycle and has to
be told again over USB, which defeats most of the point of being wireless.

Something on the device has to hold the key for it to join a network on its
own; that is not an implementation choice. The only real questions are how
many copies there are and whether they can be read back.

A command-line flag beats an environment variable, which beats `.env`. With a
network named and no password anywhere, this asks for one without echoing it.

The AtomS3 must be in BRIDGE mode (the mode it boots into): this speaks a
short text protocol on the USB serial port, which POLICY mode would read as
malformed command frames and ignore.

After it reconnects, hold the button to reach STATUS and click once: the
screen shows the address as a QR code, which is what a phone scans.
"""

import argparse
import getpass
import os
import pathlib
import sys
import time

import serial

# Beside this script rather than in the working directory: it belongs to this
# firmware, and running the tool from elsewhere should not silently pick up a
# different network.
ENV_PATH = pathlib.Path(__file__).resolve().parent / ".env"

# A text protocol, unlike everything else here, because it is typed by a
# person once rather than parsed in a control loop.
PROMPT_TIMEOUT_S = 5.0


def read_env(path):
    """Parse a minimal KEY=VALUE file.

    Deliberately not python-dotenv: one dependency for twelve lines, on a tool
    whose whole job is to avoid being complicated. Blank lines and `#`
    comments are skipped; a value may be quoted, which is how a password with
    spaces gets through.
    """
    values = {}
    if not path.exists():
        return values
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        values[key.strip()] = value
    return values


def resolve(args, env_file):
    """Settle the network to use, most specific source first.

    Returns
    -------
    ssid : str or None
    password : str
    source : str
        Where the SSID came from, so the user can see which of three places
        was actually used.
    """
    if args.ssid:
        password = args.password
        if password is None:
            password = os.environ.get("KXR_WIFI_PASSWORD")
        if password is None:
            password = env_file.get("KXR_WIFI_PASSWORD")
        return args.ssid, password, "--ssid"
    ssid = os.environ.get("KXR_WIFI_SSID")
    if ssid:
        return (ssid,
                args.password if args.password is not None
                else os.environ.get("KXR_WIFI_PASSWORD"),
                "KXR_WIFI_SSID")
    ssid = env_file.get("KXR_WIFI_SSID")
    if ssid:
        return (ssid,
                args.password if args.password is not None
                else env_file.get("KXR_WIFI_PASSWORD"),
                str(ENV_PATH))
    return None, None, ""


def send_line(ser, line):
    ser.write((line + "\n").encode("utf-8"))
    ser.flush()


def read_reply(ser, timeout=PROMPT_TIMEOUT_S):
    """Collect lines until the device stops talking or answers."""
    end = time.time() + timeout
    out = []
    while time.time() < end:
        line = ser.readline()
        if not line:
            continue
        text = line.decode("utf-8", "replace").rstrip()
        out.append(text)
        if text.startswith("OK") or text.startswith("ERR"):
            break
    return out


def parse_args():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("port", nargs="?", default="/dev/ttyACM0")
    parser.add_argument("--ssid", help="overrides KXR_WIFI_SSID and .env")
    parser.add_argument("--password", default=None,
                        help="omit to be asked for it without echo")
    parser.add_argument(
        "--once",
        action="store_true",
        help="connect without storing anything: the credentials live in the"
             " device's RAM and are gone at the next power cycle, and any"
             " previously stored copy is erased. The cost is that the robot"
             " can no longer join the network by itself -- it needs this run"
             " again after every boot, over USB, which for a machine meant to"
             " run untethered is usually the wrong trade.",
    )
    parser.add_argument("--show", action="store_true",
                        help="print what the device has stored")
    parser.add_argument("--scan", action="store_true",
                        help="list the access points the radio can see. The"
                             " ESP32-S3 has no 5 GHz radio, so a network"
                             " missing from this list cannot be joined at all")
    parser.add_argument("--clear", action="store_true",
                        help="forget the stored network")
    return parser.parse_args()


def main():
    args = parse_args()
    ssid = password = None
    if not (args.show or args.clear or args.scan):
        ssid, password, source = resolve(args, read_env(ENV_PATH))
        if not ssid:
            print(
                "no network given. Pass --ssid, set KXR_WIFI_SSID, or put"
                " KXR_WIFI_SSID and KXR_WIFI_PASSWORD in {}".format(ENV_PATH),
                file=sys.stderr,
            )
            return 2
        if password is None:
            password = getpass.getpass("password for {} (empty for open): "
                                       .format(ssid))
        print("network {} (from {})".format(ssid, source))

    ser = serial.Serial(args.port, 115200, timeout=0.5)
    time.sleep(0.3)
    ser.reset_input_buffer()

    if args.scan:
        send_line(ser, "net scan")
    elif args.show:
        send_line(ser, "net?")
    elif args.clear:
        send_line(ser, "net!")
    else:
        # The SSID and password are separated by a tab, which neither can
        # contain, rather than by a space, which both can.
        line = "net {}\t{}".format(ssid, password)
        if args.once:
            line += "\tvolatile"
        send_line(ser, line)

    # A scan takes a couple of seconds of radio time.
    for line in read_reply(ser, timeout=15.0 if args.scan else PROMPT_TIMEOUT_S):
        print(line)
    ser.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
