#!/usr/bin/env python3
"""atom_echo_voice_datacollect_robot.ino が吐き出す生PCMフレームを受信し、
Edge Impulseへアップロードしやすいラベル別フォルダのWAVファイルとして保存する。

フレーミング: 0xAA 0x55 [label:1byte] [n_samples:uint16 LE] [PCM16 LE * n_samples]
ロボット側のログ文字列(ASCII、全バイト<0x80)と同じSerialに混在しているが、
0xAAは印字可能ASCIIに出現しないため、この2バイト同期列で安全に検出できる。

使い方:
    python3 collect_edge_impulse_data.py [--port /dev/ttyUSB1] [--outdir data]

起動後、ロボット側に '0'~'5' を送ってラベルを切り替えたい場合は、別途
`printf '1' > /dev/ttyUSB1` 等で行う(このスクリプトは受信専用)。
"""

import argparse
import os
import struct
import sys
import wave

import serial

LABEL_NAMES = ["aisatsu", "mae", "ushiro", "hidari", "migi", "noise"]
SAMPLE_RATE = 8000

SYNC0 = 0xAA
SYNC1 = 0x55


def next_index(label_dir, label):
    existing = [f for f in os.listdir(label_dir) if f.startswith(label + "_") and f.endswith(".wav")]
    nums = []
    for f in existing:
        try:
            nums.append(int(f[len(label) + 1 : -4]))
        except ValueError:
            pass
    return (max(nums) + 1) if nums else 1


def save_wav(outdir, label, samples):
    label_dir = os.path.join(outdir, label)
    os.makedirs(label_dir, exist_ok=True)
    idx = next_index(label_dir, label)
    path = os.path.join(label_dir, f"{label}_{idx:03d}.wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(struct.pack(f"<{len(samples)}h", *samples))
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="/dev/ttyUSB1")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--outdir", default=os.path.join(os.path.dirname(__file__), "..", "ei_data"))
    ap.add_argument(
        "--cmdfile",
        default=os.path.join(os.path.dirname(__file__), "..", "ei_label_cmd.txt"),
        help="このファイルに '0'-'5' 等の1文字を書き込むとラベルを切り替えられる"
        "(ポートを別プロセスから開き直すとATOM Echoがリセットされてしまうため、"
        "既に開いている同じシリアル接続経由で転送する)",
    )
    args = ap.parse_args()

    outdir = os.path.abspath(args.outdir)
    os.makedirs(outdir, exist_ok=True)
    print(f"[collect] output directory: {outdir}")

    cmdfile = os.path.abspath(args.cmdfile)
    # 起動時点で既に存在する内容は無視する(古いコマンドの誤爆防止)
    last_cmd_mtime = os.path.getmtime(cmdfile) if os.path.exists(cmdfile) else None
    print(f"[collect] label control file: {cmdfile} (write a single digit 0-5 here to switch label)")

    print(f"[collect] listening on {args.port} @ {args.baud}bps ... Ctrl+C to stop")

    buf = bytearray()
    ser = None
    try:
        while True:
            if ser is None:
                try:
                    ser = serial.Serial(args.port, args.baud, timeout=1)
                    buf.clear()
                    print(f"[collect] (re)connected to {args.port}")
                except (serial.SerialException, OSError) as e:
                    print(f"[collect] connect failed ({e}); retrying in 2s...")
                    import time as _time

                    _time.sleep(2)
                    continue

            if os.path.exists(cmdfile):
                mtime = os.path.getmtime(cmdfile)
                if mtime != last_cmd_mtime:
                    last_cmd_mtime = mtime
                    with open(cmdfile, "r") as f:
                        content = f.read().strip()
                    if content:
                        ch = content[-1]
                        try:
                            ser.write(ch.encode("ascii", errors="ignore"))
                        except (serial.SerialException, OSError):
                            pass  # 次のループの再接続処理に任せる

            try:
                chunk = ser.read(4096)
            except (serial.SerialException, OSError) as e:
                print(f"[collect] USB disconnected ({e}); will retry...")
                try:
                    ser.close()
                except Exception:
                    pass
                ser = None
                import time as _time

                _time.sleep(1)
                continue
            if not chunk:
                continue
            buf.extend(chunk)

            while True:
                sync_pos = buf.find(bytes([SYNC0, SYNC1]))
                if sync_pos < 0:
                    # 同期バイトが見つからない場合、ログ文字列として標準出力に流す
                    if len(buf) > 1:
                        try:
                            text = buf[:-1].decode("ascii", errors="replace")
                            if text.strip():
                                sys.stdout.write(text)
                                sys.stdout.flush()
                        except Exception:
                            pass
                        del buf[:-1]
                    break

                # 同期バイトより前の部分はログとして表示
                if sync_pos > 0:
                    try:
                        text = buf[:sync_pos].decode("ascii", errors="replace")
                        if text.strip():
                            sys.stdout.write(text)
                            sys.stdout.flush()
                    except Exception:
                        pass
                    del buf[:sync_pos]
                    sync_pos = 0

                # ヘッダ(sync 2byte + label 1byte + n 2byte = 5byte)が揃っているか
                if len(buf) < 5:
                    break
                label_idx = buf[2]
                n_samples = buf[3] | (buf[4] << 8)
                total_len = 5 + n_samples * 2
                if label_idx >= len(LABEL_NAMES) or n_samples == 0 or n_samples > 8000:
                    # 壊れたフレーム(同期バイトの偶然の一致など)。1byte進めて再走査。
                    del buf[:1]
                    continue
                if len(buf) < total_len:
                    break  # まだ全部届いていない

                payload = buf[5:total_len]
                samples = struct.unpack(f"<{n_samples}h", bytes(payload))
                label = LABEL_NAMES[label_idx]
                path = save_wav(outdir, label, samples)
                print(f"[collect] saved {path} (label={label}, n={n_samples})")

                del buf[:total_len]

    except KeyboardInterrupt:
        print("\n[collect] stopped.")
    finally:
        if ser is not None:
            ser.close()


if __name__ == "__main__":
    main()
