#!/usr/bin/env python3
"""ATOM ブリッジ経由で RCB4-mini とシリアル疎通確認を行うサンプル。

kxreus/uart.l の (rcb4-version fd) と同じバージョン問い合わせコマンドを送り、
RCB4形式のフレーム(先頭バイト=長さ, 続く 長さ-1 バイトが本体)を読み返す。

使い方:
    python3 rcb4_bridge_test.py [デバイスパス]

例:
    python3 rcb4_bridge_test.py /dev/ttyACM0
"""
import argparse
import sys
import time

import serial


def read_rcb4_frame(ser, timeout=1.0):
    ser.timeout = timeout
    length_byte = ser.read(1)
    if len(length_byte) == 0:
        return None
    length = length_byte[0]
    if length <= 0:
        return None
    rest = ser.read(length - 1)
    if len(rest) != length - 1:
        return None
    return length_byte + rest


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("port", nargs="?", default="/dev/ttyACM0",
                     help="ATOMのUSB-CDCデバイス (既定: /dev/ttyACM0)")
    ap.add_argument("--baud", type=int, default=115200,
                     help="USB-CDC側のbaud設定値。ATOM側の実UARTには影響しないが"
                          "pyserial仕様上の指定は必要")
    args = ap.parse_args()

    try:
        ser = serial.Serial(args.port, args.baud, timeout=1.0)
    except serial.SerialException as e:
        print(f"シリアルポートを開けません: {e}", file=sys.stderr)
        sys.exit(1)

    time.sleep(0.2)  # ATOM側の起動待ち
    ser.reset_input_buffer()

    # RCB4 バージョン問い合わせコマンド: [長さ=3, コマンド=0xFD, 0x00]
    cmd = bytes([0x03, 0xFD, 0x00])
    print("-> send:", cmd.hex(" "))
    ser.write(cmd)

    resp = read_rcb4_frame(ser)
    if resp is None:
        print("応答がありません。以下を確認してください:")
        print("  - RCB4-mini の電源(バッテリ)が入っているか")
        print("  - GND が共通になっているか")
        print("  - TXD/RXD が正しく交差配線されているか(逆なら入れ替える)")
        print("  - ATOM ファームウェアの反転(invert)設定が有効になっているか")
        sys.exit(1)

    print("<- recv:", resp.hex(" "))
    print("疎通確認 OK")


if __name__ == "__main__":
    main()
