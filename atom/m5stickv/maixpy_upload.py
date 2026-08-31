#!/usr/bin/env python3
"""Minimal MicroPython/MaixPy raw-REPL file uploader over serial (no ampy/mpremote needed).
Usage: maixpy_upload.py <port> <local_file> [remote_name]
Writes <local_file> to the device's filesystem as <remote_name> (default: boot.py).

Notes (M5StickV/K210 MaixPy, 2026.8):
- Opening the serial port toggles DTR and reboots the board every time. Each
  run of this script is its own fresh reboot -> boot -> interrupt cycle; you
  cannot "continue" a raw-REPL session across separate process invocations.
- After upload, do a clean reset to actually run the new boot.py: open the
  port, wait ~5s without sending any bytes, then read what came back (should
  show the normal boot banner + your script's own startup prints). Sending
  bytes (e.g. Ctrl-C) during that same connection is fine for inspection but
  will itself interrupt whatever's running.
- Set MAIXPY_UPLOAD_DEBUG=1 to print raw ack/out/err bytes for each exec_raw
  call (useful if upload hangs or raises unexpectedly).
"""
import os
import sys
import time
import serial

# シリアルは応答境界(マーカー)ちょうどで区切って読みたいが、1回のread()で
# マーカーの後ろの余分なバイトまで一緒に届くことがあるため、残りを次回の
# read_until呼び出しに持ち越す小さなバッファを持たせる。
_residual = {"buf": b""}

def read_until(ser, marker, timeout=10):
    data = _residual["buf"]
    _residual["buf"] = b""
    end = time.time() + timeout
    while marker not in data:
        if time.time() >= end:
            raise TimeoutError("timed out waiting for %r, got %r" % (marker, data))
        chunk = ser.read(ser.in_waiting or 1)
        if chunk:
            data += chunk
        else:
            time.sleep(0.02)
    idx = data.index(marker) + len(marker)
    _residual["buf"] = data[idx:]
    return data[:idx]

DEBUG = bool(os.environ.get("MAIXPY_UPLOAD_DEBUG"))

def exec_raw(ser, code_bytes, timeout=15):
    ser.write(code_bytes)
    ser.write(b"\x04")  # Ctrl-D: execute
    ack = read_until(ser, b"OK", timeout=timeout)
    out = read_until(ser, b"\x04", timeout=timeout)
    err = read_until(ser, b"\x04", timeout=timeout)
    if DEBUG:
        print("  [debug] ack=%r out=%r err=%r" % (ack, out, err))
    out = out[:-1] if out.endswith(b"\x04") else out
    err = err[:-1] if err.endswith(b"\x04") else err
    if err:
        raise RuntimeError("device error: %s" % err.decode(errors="replace"))
    return out

def main():
    port, local_path = sys.argv[1], sys.argv[2]
    remote_name = sys.argv[3] if len(sys.argv) > 3 else "boot.py"

    with open(local_path, "rb") as f:
        content = f.read()
    print("local file: %d bytes" % len(content))

    # ポートを開くとDTRトグルで実機がリセットされる。以前は「起動シーケンス
    # (ブートログ→メインスクリプト起動)が終わるまで3秒待ってから1回だけ
    # Ctrl-Cを送る」という方式だったが、既存のboot.py/main.pyがカメラ検出
    # (sensor.init()等)のようなC言語レベルでブロックする処理に入って
    # しまっていると、その1回のCtrl-Cが完全に無視されて延々とハングする
    # ことを実機で確認した(2026.8、カメラ未接続の新品M5StickVで発生)。
    # ブロックする処理に入る前の一瞬(起動直後、_boot.py実行中など)は
    # 割り込み可能なため、ポートを開いた直後からCtrl-Cを連続送信し続け、
    # 友好的REPL(>>>)が出てくるまで粘る方式に変更した。
    # _boot.pyを止めた直後の">>>"に飛びついてすぐraw REPLへ移行すると、
    # その後システムが続けてboot.py/main.py(カメラ検出等でハングしうる)を
    # 自動起動してしまい、REPLが再びハングして見えることを実機で確認した。
    # 最初の">>>"が出てからも数秒間Ctrl-Cを送り続け、後続の自動起動分も
    # 一緒に止めてから初めてraw REPLへ移行するようにする。
    ser = serial.Serial(port, 115200, timeout=0.2)
    print("opened port (device will reboot), interrupting aggressively until REPL appears...")
    buf = b""
    last_send = 0.0
    end = time.time() + 15
    first_prompt_at = None
    while time.time() < end:
        chunk = ser.read(500)
        if chunk:
            buf += chunk
        now = time.time()
        if now - last_send > 0.15:
            ser.write(b"\x03")
            last_send = now
        if first_prompt_at is None and b">>>" in buf:
            first_prompt_at = now
            end = max(end, now + 4)
    if first_prompt_at is None:
        raise TimeoutError("timed out waiting for friendly REPL, got %r" % buf)
    banner = buf
    print("interrupted to friendly REPL")
    ser.timeout = 1

    # raw REPLに入る(Ctrl-A)
    ser.reset_input_buffer()
    ser.write(b"\x01")
    banner = read_until(ser, b">", timeout=10)
    if b"raw REPL" not in banner:
        print("warning: unexpected banner: %r" % banner)
    print("entered raw REPL")

    exec_raw(ser, b"f = open('%s', 'wb')\r\n" % remote_name.encode())

    chunk_size = 4000
    for i in range(0, len(content), chunk_size):
        chunk = content[i:i + chunk_size]
        exec_raw(ser, b"f.write(" + repr(chunk).encode() + b")\r\n")
        print("wrote %d/%d bytes" % (min(i + chunk_size, len(content)), len(content)))

    exec_raw(ser, b"f.close()\r\n")
    print("closed file, verifying...")

    out = exec_raw(ser, b"import os\r\nprint(os.stat('%s'))\r\n" % remote_name.encode())
    print("remote stat:", out.decode(errors="replace").strip())

    # raw REPLを抜けて通常モードに戻す(Ctrl-B)
    ser.write(b"\x02")
    time.sleep(0.2)
    ser.close()
    print("done")

if __name__ == "__main__":
    main()
