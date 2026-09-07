#!/usr/bin/env python3
"""Radxa Zero側で、AtomS3(i2c_atoms3_G6G5_rcb4_adapter.ino)とI2C経由で
RCB4-mini向けUARTを中継するデーモン。

PTYを1つ作り、そのスレーブ側のデバイス名へシンボリックリンクを張ることで、
euslisp側(kxreus/rcb4interface.l の :rcb4-open :devname)がそのまま
生ttyとして開けるようにする(s3_wifi_captivのsocat PTY,linkと同じ考え方だが、
相手がI2Cなのでsocatではなくこの独自デーモンで直接PTYを作っている)。

【Radxa側のI2Cバス番号についての注意】
「I2C_EE_M1」はRadxa Zeroのピンヘッダ上のラベルで、実際にLinux上で
/dev/i2c-何番に対応するかは機体・OSイメージ(カーネルのdevice tree設定)
次第で変わりうる(未検証)。実機で

    i2cdetect -l

を実行し、該当するバス番号を--busに指定すること。ファームウェア書き込み後、

    i2cdetect -y <bus番号>

でAtomS3のアドレス(既定0x08)が実際に見えるかも確認するとよい。

ワイヤプロトコル(i2c_atoms3_G6G5_rcb4_adapter.ino と対になっている):
  書き込み(Radxa -> AtomS3 -> RCB4): I2Cの1回の書き込みトランザクションに
    RCB4向け生フレーム([length,opcode,...,checksum])をラッパー無しで
    そのまま乗せる。
  読み出し(RCB4 -> AtomS3 -> Radxa): I2Cの1回の読み出しトランザクションは
    常に固定FIXED_READ_LEN(64)バイト。内訳は
      byte[0]   = 有効バイト数(0〜FIXED_READ_LEN-2)
      byte[1..] = データ(有効バイト数ぶんのみ意味を持つ、残りは0埋め)

SMBusのブロック転送(i2c_smbus_write/read_block_data)は1回32byteまでという
制限があり、RCB4フレーム(最大255byte)を丸ごとは乗せられないため、
smbus2のi2c_msg(生のI2Cメッセージ、SMBusを介さない)を使っている。
"""
import argparse
import os
import pty
import select
import sys
import time

try:
    from smbus2 import SMBus, i2c_msg
except ImportError:
    print("smbus2が必要です: pip3 install smbus2", file=sys.stderr)
    sys.exit(1)

FIXED_READ_LEN = 64
POLL_INTERVAL_SEC = 0.02  # RCB4からの応答を取りこぼさない程度の間隔
MAX_WRITE_CHUNK = 255     # RCB4フレーム自体の最大長(LENバイト1byteの上限)


def write_raw(bus: SMBus, addr: int, data: bytes):
    msg = i2c_msg.write(addr, list(data))
    bus.i2c_rdwr(msg)


def read_raw(bus: SMBus, addr: int, length: int):
    msg = i2c_msg.read(addr, length)
    bus.i2c_rdwr(msg)
    return list(msg)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--bus", type=int, required=True,
                     help="I2Cバス番号(/dev/i2c-N のN。i2cdetect -l で確認すること)")
    ap.add_argument("--addr", type=lambda s: int(s, 0), default=0x08,
                     help="AtomS3のI2Cスレーブアドレス(既定0x08、.ino側のI2C_SLAVE_ADDRと合わせる)")
    ap.add_argument("--link", default="/dev/ttyRCB4-i2c",
                     help="PTYへのシンボリックリンク先パス(既定/dev/ttyRCB4-i2c。"
                          "/dev/配下でないとeuslisp側の:devnameでは開けない点に注意)")
    args = ap.parse_args()

    bus = SMBus(args.bus)

    master_fd, slave_fd = pty.openpty()
    slave_name = os.ttyname(slave_fd)
    try:
        os.unlink(args.link)
    except FileNotFoundError:
        pass
    os.symlink(slave_name, args.link)
    print(f"[i2c-rcb4-bridge] i2c bus={args.bus} addr=0x{args.addr:02x} "
          f"pty={slave_name} link={args.link}", flush=True)

    last_poll = 0.0
    try:
        while True:
            readable, _, _ = select.select([master_fd], [], [], POLL_INTERVAL_SEC)
            if master_fd in readable:
                try:
                    data = os.read(master_fd, 4096)
                except OSError:
                    data = b""
                if data:
                    for i in range(0, len(data), MAX_WRITE_CHUNK):
                        chunk = data[i:i + MAX_WRITE_CHUNK]
                        try:
                            write_raw(bus, args.addr, chunk)
                        except OSError as e:
                            print(f"[i2c-rcb4-bridge] write error: {e}", flush=True)

            now = time.time()
            if now - last_poll >= POLL_INTERVAL_SEC:
                last_poll = now
                try:
                    resp = read_raw(bus, args.addr, FIXED_READ_LEN)
                except OSError as e:
                    print(f"[i2c-rcb4-bridge] read error: {e}", flush=True)
                    continue
                count = resp[0]
                if count > FIXED_READ_LEN - 1:
                    count = FIXED_READ_LEN - 1  # 壊れた値からの防御(本来起きないはず)
                if count > 0:
                    os.write(master_fd, bytes(resp[1:1 + count]))
    except KeyboardInterrupt:
        pass
    finally:
        try:
            os.unlink(args.link)
        except FileNotFoundError:
            pass
        os.close(master_fd)
        os.close(slave_fd)
        bus.close()


if __name__ == "__main__":
    main()
