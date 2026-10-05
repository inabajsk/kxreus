#!/usr/bin/env python3
"""
live.py : EusLisp から iPhone の EusView へ関節角を中継する (標準ライブラリだけ)
  EusLisp → TCP 8767 に JSON を 1 行ずつ送る   {"angles": [...]} / {"pose": "reset-pose"} / {"root": [...]}
  iPhone  ← WebSocket 8766 (EusView の「接続」で ws://<この Mac の IP>:8766/ )
  $ python3 eusview/live.py
"""
import asyncio, base64, hashlib, json, struct, sys

clients = set()


async def ws_handler(reader, writer):
    # WebSocket のハンドシェイク (RFC 6455)
    head = (await reader.readuntil(b'\r\n\r\n')).decode(errors='replace')
    key = [l.split(':', 1)[1].strip() for l in head.split('\r\n') if l.lower().startswith('sec-websocket-key')]
    if not key:
        writer.close(); return
    acc = base64.b64encode(hashlib.sha1((key[0] + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode()
    writer.write(('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n'
                  f'Sec-WebSocket-Accept: {acc}\r\n\r\n').encode())
    await writer.drain()
    clients.add(writer)
    print('iPhone connected', writer.get_extra_info('peername'), flush=True)
    try:
        while True:  # iPhone から来るフレームは読み捨てる (切断の検出のため)
            h = await reader.readexactly(2)
            n = h[1] & 127
            if n == 126: n = struct.unpack('>H', await reader.readexactly(2))[0]
            elif n == 127: n = struct.unpack('>Q', await reader.readexactly(8))[0]
            mask = await reader.readexactly(4) if h[1] & 128 else b''
            data = await reader.readexactly(n)
            if h[0] & 15 == 8: break
            if mask:
                print('from iPhone:', bytes(b ^ mask[i % 4] for i, b in enumerate(data)).decode(errors='replace'), flush=True)
    except Exception:
        pass
    clients.discard(writer)
    print('iPhone disconnected', flush=True)


def frame(text):
    b = text.encode()
    n = len(b)
    hdr = bytes([0x81, n]) if n < 126 else bytes([0x81, 126]) + struct.pack('>H', n) if n < 65536 else bytes([0x81, 127]) + struct.pack('>Q', n)
    return hdr + b


async def eus_handler(reader, writer):
    print('EusLisp connected', flush=True)
    while line := await reader.readline():
        s = line.decode(errors='replace').strip()
        if not s: continue
        try: json.loads(s)
        except Exception: print('not JSON:', s[:80], flush=True); continue
        for c in list(clients):
            try: c.write(frame(s)); await c.drain()
            except Exception: clients.discard(c)
    print('EusLisp disconnected', flush=True)


async def main():
    ws = int(sys.argv[1]) if len(sys.argv) > 1 else 8766
    tcp = int(sys.argv[2]) if len(sys.argv) > 2 else 8767
    a = await asyncio.start_server(ws_handler, '0.0.0.0', ws)
    b = await asyncio.start_server(eus_handler, '0.0.0.0', tcp)
    print(f'WebSocket (iPhone) :{ws}   TCP (EusLisp) :{tcp}', flush=True)
    async with a, b:
        await asyncio.gather(a.serve_forever(), b.serve_forever())

asyncio.run(main())
