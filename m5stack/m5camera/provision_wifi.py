#!/usr/bin/env python3
"""Store Wi-Fi credentials in the M5Camera's NVS over USB serial.

    ./provision_wifi.py /dev/ttyUSB1                # this PC's current Wi-Fi (via nmcli)
    ./provision_wifi.py /dev/ttyUSB1 SSID PASSWORD
"""
import subprocess
import sys
import time

import serial


def current_wifi():
    out = subprocess.check_output(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active"], text=True)
    for line in out.splitlines():
        name, _, typ = line.rpartition(":")
        if typ == "802-11-wireless":
            psk = subprocess.check_output(
                ["nmcli", "-s", "-g", "802-11-wireless-security.psk", "connection", "show", name], text=True).strip()
            ssid = subprocess.check_output(
                ["nmcli", "-g", "802-11-wireless.ssid", "connection", "show", name], text=True).strip()
            return ssid, psk
    sys.exit("no active Wi-Fi connection; pass SSID and PASSWORD explicitly")


def main():
    port = sys.argv[1] if len(sys.argv) > 1 else "/dev/ttyUSB1"
    ssid, psk = (sys.argv[2], sys.argv[3]) if len(sys.argv) > 3 else current_wifi()
    s = serial.Serial(port, 115200, timeout=0.2)
    s.dtr = False
    s.rts = False  # don't hold the ESP32 in reset
    time.sleep(0.3)
    s.reset_input_buffer()
    s.write(f"wifi {ssid} {psk}\n".encode())
    deadline = time.time() + 20
    buf = b""
    while time.time() < deadline:
        buf += s.read(1024)
        if b"streaming on" in buf:
            break
        if time.time() > deadline - 12 and b"ip=" not in buf:
            s.write(b"info\n")
            time.sleep(1)
    text = buf.decode(errors="replace").replace(psk, "********")
    print(text)


if __name__ == "__main__":
    main()
