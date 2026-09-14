#!/usr/bin/env python3
"""PC発行のRCB4コマンドが往復するのにかかる時間を計測するツール。

ファームウェアには手を入れず、PC側から実際にRCB4のバージョン問い合わせを
送って応答が返るまでの時間を計測する。USB-CDC(PC<->ATOM) + ESP-NOW(ATOM間)
+ UART(ATOM<->RCB4-mini) を含む、本当の意味での「PCが送ってから返事が
戻るまで」の全経路の時間が分かる。ブリッジ常駐処理には影響を与えない
(必要な時だけ手動で実行するツール)。

使い方:
    python3 rcb4_roundtrip_test.py [デバイスパス] [--count N]
"""
import argparse
import statistics
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
    ap.add_argument("port", nargs="?", default="/dev/ttyACM0")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--count", type=int, default=20, help="計測回数")
    ap.add_argument("--interval", type=float, default=0.1, help="計測間隔[秒]")
    args = ap.parse_args()

    ser = serial.Serial(args.port, args.baud, timeout=1.0)
    time.sleep(0.2)
    ser.reset_input_buffer()

    cmd = bytes([0x03, 0xFD, 0x00])
    times_ms = []
    fails = 0

    for i in range(args.count):
        ser.reset_input_buffer()
        t0 = time.perf_counter()
        ser.write(cmd)
        resp = read_rcb4_frame(ser, timeout=1.0)
        t1 = time.perf_counter()
        if resp is None:
            fails += 1
            print(f"[{i+1:3d}] timeout")
        else:
            ms = (t1 - t0) * 1000
            times_ms.append(ms)
            print(f"[{i+1:3d}] {ms:6.2f} ms")
        time.sleep(args.interval)

    if times_ms:
        print()
        print(f"回数: {len(times_ms)} 成功 / {fails} 失敗")
        print(f"min: {min(times_ms):.2f} ms")
        print(f"avg: {statistics.mean(times_ms):.2f} ms")
        print(f"max: {max(times_ms):.2f} ms")
        if len(times_ms) > 1:
            print(f"stdev: {statistics.stdev(times_ms):.2f} ms")
    else:
        print("応答がありませんでした。")
        sys.exit(1)


if __name__ == "__main__":
    main()
