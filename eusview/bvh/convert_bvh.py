#!/usr/bin/env python3
"""BVH（モーションキャプチャ）を EusView アプリ用の小さな形式に変換する（Python 標準ライブラリだけ）。

  python3 eusview/bvh/convert_bvh.py                       # ~/kxreus/bvh → eusview/bvh/cache/
  python3 eusview/bvh/convert_bvh.py --src DIR --out DIR   # 場所を変える
  python3 eusview/bvh/convert_bvh.py --kinds mocopi sfu    # 種類を選ぶ
  python3 eusview/bvh/convert_bvh.py --check FILE.bvh      # 1 ファイルの関節のワールド位置を出す（アプリとの照合用）

BVH のデータ（LAFAN1, SFU などは非商用・改変禁止のライセンス）は git に入れないので、cache/ も git に入れない。

出力（cache/）:
  index.json                       種類ごとのファイルの一覧（コマ数, fps, 秒数, 関節数, バイト数）
  <種類>/<名前>.ebvh               1 ファイル = 1 モーション
.ebvh の形式（リトルエンディアン）:
  "EBVH" + uint32 ヘッダの長さ L + ヘッダ（UTF-8 の JSON, L バイト） + コマのデータ
  ヘッダ: joints [{name, parent(-1 か親の番号, 親が先), offset [x,y,z] mm（BVH の軸）, channels ["Xposition", ..]}],
          ends [{parent, offset}]（End Site）, fps, frames, base [x y z r00..r22]（BVH の座標 mm → アプリの世界 m, z が上）,
          bounds [minx miny minz maxx maxy maxz]（世界 m, 全コマ）, check {frame, joints [[x,y,z] m]}（照合用）など
  コマのデータ: コマごとに, チャンネルの順（joints の順, 各関節の channels の順）に
          位置のチャンネル int32（0.1 mm 単位）, 回転のチャンネル int16（0.01 度単位, -180〜180 に折り返し）
関節のローカルの変換 = T(位置) · R(ch1) · R(ch2) · R(ch3)（回転のチャンネルの並び順に掛ける, BVH の決まり）。
位置 = 位置のチャンネルがあればその値（ROOT と mocopi の全関節。OFFSET の代わり）, なければ OFFSET。
世界の座標 = base · （BVH の座標で求めた関節の位置）。
"""
import argparse, json, math, os, struct, sys, time

# 種類ごとの設定: up = BVH の上の軸, fps = Frame Time が正しくないときの値, title = 一覧の説明
KINDS = {
  "lafan1": dict(up="y", title="LAFAN1（Ubisoft, 歩く・走る・踊る・格闘など）"),
  "mocopi": dict(up="y", title="mocopi（Sony, 工場・あいさつ）"),
  "rikiya": dict(up="y", title="rikiya（歩く・転ぶ・運ぶなど）"),
  "sfu": dict(up="y", title="SFU（ジョギング・スキップ・跳び越えなど）"),
  "tum-kitchen": dict(up="z", fps=25.0, title="TUM Kitchen（台所で食器を並べる）"),
}
MAX_FPS = 30.0
TARGET_HEIGHT = 1700.0          # mm: 人の背の高さの目安
UNITS = [("mm", 1.0), ("cm", 10.0), ("inch", 25.4), ("m", 1000.0)]


def parse_bvh(path):
  with open(path, "r", encoding="utf-8", errors="replace") as f:
    text = f.read()
  head, sep, motion = text.partition("MOTION")
  if not sep:
    raise ValueError("MOTION がありません")
  tok = head.replace("{", " { ").replace("}", " } ").split()
  joints, ends, stack = [], [], []
  i, pending = 0, None
  while i < len(tok):
    t = tok[i]
    if t in ("ROOT", "JOINT"):
      pending = dict(name=tok[i + 1], parent=stack[-1] if stack else -1, offset=[0.0, 0.0, 0.0], channels=[])
      i += 2
    elif t == "End":            # End Site
      pending = dict(end=True, parent=stack[-1], offset=[0.0, 0.0, 0.0])
      i += 2
    elif t == "{":
      if pending is None:
        raise ValueError("{ の前に関節がありません")
      if pending.get("end"):
        ends.append(pending); stack.append(None)
      else:
        joints.append(pending); stack.append(len(joints) - 1)
      pending = None; i += 1
    elif t == "}":
      stack.pop(); i += 1
    elif t == "OFFSET":
      cur = ends[-1] if stack and stack[-1] is None else joints[stack[-1]]
      cur["offset"] = [float(tok[i + 1]), float(tok[i + 2]), float(tok[i + 3])]
      i += 4
    elif t == "CHANNELS":
      n = int(tok[i + 1])
      joints[stack[-1]]["channels"] = tok[i + 2:i + 2 + n]
      i += 2 + n
    else:
      i += 1
  for e in ends:
    del e["end"]
  lines = motion.split("\n")
  nframes, ftime, k = None, None, 0
  while k < len(lines) and (nframes is None or ftime is None):
    s = lines[k].strip()
    if s.startswith("Frames:"):
      nframes = int(s.split(":")[1])
    elif s.startswith("Frame Time:"):
      ftime = float(s.split(":")[1])
    k += 1
  nch = sum(len(j["channels"]) for j in joints)
  frames = []
  for s in lines[k:]:
    v = s.split()
    if len(v) < nch:
      continue
    frames.append([float(x) for x in v[:nch]])
  return dict(joints=joints, ends=ends, frame_time=ftime, frames=frames, nframes_header=nframes)


def rot(axis, deg):
  c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
  if axis == "X": return ((1, 0, 0), (0, c, -s), (0, s, c))
  if axis == "Y": return ((c, 0, s), (0, 1, 0), (-s, 0, c))
  return ((c, -s, 0), (s, c, 0), (0, 0, 1))


def mm(a, b):
  return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))


def mv(a, v):
  return (a[0][0] * v[0] + a[0][1] * v[1] + a[0][2] * v[2], a[1][0] * v[0] + a[1][1] * v[1] + a[1][2] * v[2],
          a[2][0] * v[0] + a[2][1] * v[1] + a[2][2] * v[2])


def fk(bvh, values, scale=1.0):
  """1 コマの関節と End Site の位置（BVH の座標, 単位 × scale）"""
  R, P, k = [], [], 0
  for j in bvh["joints"]:
    pos = [o * scale for o in j["offset"]]
    r = ((1, 0, 0), (0, 1, 0), (0, 0, 1))
    for c in j["channels"]:
      v = values[k]; k += 1
      if c.endswith("position"):
        pos["XYZ".index(c[0])] = v * scale
      else:
        r = mm(r, rot(c[0], v))
    if j["parent"] < 0:
      R.append(r); P.append(tuple(pos))
    else:
      pr, pp = R[j["parent"]], P[j["parent"]]
      R.append(mm(pr, r)); q = mv(pr, pos); P.append((pp[0] + q[0], pp[1] + q[1], pp[2] + q[2]))
  E = []
  for e in bvh["ends"]:
    pr, pp = R[e["parent"]], P[e["parent"]]
    q = mv(pr, [o * scale for o in e["offset"]]); E.append((pp[0] + q[0], pp[1] + q[1], pp[2] + q[2]))
  return P, E


def base_rot(up):
  """BVH の軸 → EusLisp の世界（z が上, 人は +x を向く）の回転（行優先）"""
  if up == "y":   # jskeus の rikiya-bvh-robot-model と同じ rpy (pi/2 0 pi/2): 世界 = (bz, bx, by)
    return ((0, 0, 1), (1, 0, 0), (0, 1, 0))
  return ((0, -1, 0), (1, 0, 0), (0, 0, 1))   # z が上: rpy (pi/2 0 0)（tum-bvh-robot-model と同じ）


def sample_idx(n, maxn):
  if n <= maxn:
    return list(range(n))
  return sorted(set(int(i * (n - 1) / (maxn - 1)) for i in range(maxn)))


def wrap(d):
  d = math.fmod(d, 360.0)
  if d > 180.0: d -= 360.0
  if d <= -180.0: d += 360.0
  return d


def name_of(rel):
  n = rel[:-4] if rel.lower().endswith(".bvh") else rel
  if n.endswith("/poses"):
    n = n[:-6]
  return n


def height_of(bvh, up, n=60):
  """その動作の背の高さ（BVH の単位）: コマの縦の広がりの 90 パーセンタイル"""
  ax = "xyz".index(up)
  hs = []
  for i in sample_idx(len(bvh["frames"]), n):
    P, E = fk(bvh, bvh["frames"][i])
    zs = [p[ax] for p in P + E]
    hs.append(max(zs) - min(zs))
  hs.sort()
  return hs[int(0.9 * (len(hs) - 1))] if hs else 0.0


def convert(bvh, kind, rel, unit_mm, up, fps_override, out_path):
  src_fps = fps_override or (1.0 / bvh["frame_time"] if bvh["frame_time"] else 30.0)
  step = max(1, math.ceil(src_fps / MAX_FPS - 0.01))   # 30.0003 fps などを 2 にしない
  frames = bvh["frames"][::step]
  fps = src_fps / step
  B = base_rot(up)
  # 床と中心: 間引いたコマから最低点と腰の水平の範囲を求める
  mins, bmin, bmax, rx, ry = [], [1e18] * 3, [-1e18] * 3, [], []
  for i in sample_idx(len(frames), 1500):
    P, E = fk(bvh, frames[i], unit_mm)
    W = [mv(B, p) for p in P + E]
    for w in W:
      for d in range(3):
        bmin[d] = min(bmin[d], w[d]); bmax[d] = max(bmax[d], w[d])
    rx.append(W[0][0]); ry.append(W[0][1])
  shift = (-(min(rx) + max(rx)) / 2, -(min(ry) + max(ry)) / 2, -bmin[2])
  bounds = [round((bmin[d] + shift[d]) / 1000, 4) for d in range(3)] + [round((bmax[d] + shift[d]) / 1000, 4) for d in range(3)]
  base = [round(s / 1000, 6) for s in shift] + [B[i][j] for i in range(3) for j in range(3)]
  # base の位置は m, 回転は BVH(mm) → 世界: 世界(m) = R · p(mm) / 1000 + t。アプリでは位置を mm → m にしてから掛ける
  chans = [c for j in bvh["joints"] for c in j["channels"]]
  ispos = [c.endswith("position") for c in chans]
  fmt = "<" + "".join("i" if p else "h" for p in ispos)
  st = struct.Struct(fmt)
  data = bytearray()
  for fr in frames:
    v = [int(round(x * unit_mm * 10)) if p else int(round(wrap(x) * 100)) for x, p in zip(fr, ispos)]
    for k, p in enumerate(ispos):
      if not p:
        v[k] = max(-18000, min(18000, v[k]))
    data += st.pack(*v)
  cf = len(frames) // 2
  vals = [round(x * unit_mm * 10) / 10 / unit_mm if p else round(wrap(x) * 100) / 100 for x, p in zip(frames[cf], ispos)]
  P, E = fk(bvh, vals, unit_mm)
  check = [[round((mv(B, p)[d] + shift[d]) / 1000, 5) for d in range(3)] for p in P]
  joints = [dict(name=j["name"], parent=j["parent"], offset=[round(o * unit_mm, 3) for o in j["offset"]], channels=j["channels"])
            for j in bvh["joints"]]
  ends = [dict(parent=e["parent"], offset=[round(o * unit_mm, 3) for o in e["offset"]]) for e in bvh["ends"]]
  head = dict(format="ebvh", version=1, kind=kind, name=name_of(rel), source=rel, fps=round(fps, 4), frames=len(frames),
              sourceFps=round(src_fps, 4), sourceFrames=len(bvh["frames"]), step=step, unitMM=unit_mm, up=up,
              posScale=0.1, rotScale=0.01, joints=joints, ends=ends, base=base, bounds=bounds,
              check=dict(frame=cf, joints=check))
  hb = json.dumps(head, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
  os.makedirs(os.path.dirname(out_path), exist_ok=True)
  with open(out_path, "wb") as f:
    f.write(b"EBVH" + struct.pack("<I", len(hb)) + hb + bytes(data))
  return head, 8 + len(hb) + len(data)


def main():
  ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
  here = os.path.dirname(os.path.abspath(__file__))
  ap.add_argument("--src", default=os.path.normpath(os.path.join(here, "../../bvh")))   # kxreus/bvh (eusview/bvh/ の 2 つ上)
  ap.add_argument("--out", default=os.path.join(here, "cache"))
  ap.add_argument("--kinds", nargs="*", default=list(KINDS))
  ap.add_argument("--check", help="1 ファイルを読んで, 照合用の関節の位置を出す")
  a = ap.parse_args()
  if a.check:
    bvh = parse_bvh(a.check)
    P, E = fk(bvh, bvh["frames"][0])
    for j, p in zip(bvh["joints"], P):
      print(j["name"], ["%.4f" % x for x in p])
    return
  index = dict(format="ebvh-index", version=1, source=a.src, maxFps=MAX_FPS, kinds=[])
  oldidx = os.path.join(a.out, "index.json")
  if os.path.exists(oldidx):    # 一部の種類だけ作り直すときは, ほかの種類の一覧を残す
    try:
      index["kinds"] = [k for k in json.load(open(oldidx))["kinds"] if k["name"] not in a.kinds]
    except Exception:
      pass
  total = 0
  for kind in a.kinds:
    cfg = KINDS.get(kind, dict(up="y"))
    kdir = os.path.join(a.src, kind)
    rels = sorted(os.path.relpath(os.path.join(r, f), kdir) for r, _, fs in os.walk(kdir) for f in fs if f.lower().endswith(".bvh"))
    if not rels:
      print("!!", kind, "BVH がありません:", kdir); continue
    t0 = time.time()
    heights = []   # 単位は最初の 5 ファイルの背の高さから決める（全部を一度に読むとメモリが足りない）
    for rel in rels[:5]:
      try:
        heights.append(height_of(parse_bvh(os.path.join(kdir, rel)), cfg["up"]))
      except Exception as e:
        print("!!", kind, rel, e)
    heights.sort()
    h = heights[len(heights) // 2]
    unit, umm = min(UNITS, key=lambda u: abs(math.log(max(h, 1e-9) * u[1] / TARGET_HEIGHT)))
    if not 1300 <= h * umm <= 2100:
      unit, umm = "normalized", TARGET_HEIGHT / h
    print("%-12s %3d files  height %.1f (BVH) -> unit %s (%.3g mm) -> %.0f mm" % (kind, len(rels), h, unit, umm, h * umm))
    files, kbytes = [], 0
    for rel in rels:
      try:
        b = parse_bvh(os.path.join(kdir, rel))
        if not b["frames"]:
          raise ValueError("コマがありません")
      except Exception as e:
        print("!!", kind, rel, e); continue
      fn = name_of(rel).replace("/", "_") + ".ebvh"
      head, nb = convert(b, kind, rel, umm, cfg["up"], cfg.get("fps"), os.path.join(a.out, kind, fn))
      files.append(dict(name=head["name"], file=kind + "/" + fn, frames=head["frames"], fps=head["fps"],
                        duration=round(head["frames"] / head["fps"], 2), joints=len(head["joints"]), bytes=nb))
      kbytes += nb
    total += kbytes
    k = dict(name=kind, title=cfg.get("title", kind), up=cfg["up"], unit=unit, unitMM=umm, height=round(h * umm / 1000, 3),
             files=files, bytes=kbytes, duration=round(sum(f["duration"] for f in files), 1))
    index["kinds"] = [x for x in index["kinds"] if x["name"] != kind] + [k]
    print("%-12s %.1f MB, %.0f s of motion, %.0f s" % (kind, kbytes / 1e6, k["duration"], time.time() - t0))
  order = list(KINDS)
  index["kinds"].sort(key=lambda k: order.index(k["name"]) if k["name"] in order else 99)
  index["bytes"] = sum(k["bytes"] for k in index["kinds"])
  os.makedirs(a.out, exist_ok=True)
  with open(oldidx, "w") as f:
    json.dump(index, f, ensure_ascii=False, indent=1)
  print("total %.1f MB (%d files) → %s" % (index["bytes"] / 1e6, sum(len(k["files"]) for k in index["kinds"]), a.out))


if __name__ == "__main__":
  main()
