#!/usr/bin/env python3
"""Check an eusview robot JSON with the viewer's semantics (pure Python, no numpy):
   world(link) = world(parent) * T(pos) R(rot) * R(axis, angle)   (rotational, deg)
                                                * T(axis*mm/1000)   (linear)
   and compare with check.link_world_pos computed by EusLisp.
   usage: python3 eusview/verify.py eusview/robots/*.json"""
import json, sys, math, os


def mat(rot, pos):
    r = rot
    return [[r[0], r[1], r[2], pos[0]], [r[3], r[4], r[5], pos[1]],
            [r[6], r[7], r[8], pos[2]], [0, 0, 0, 1]]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def rot_axis(ax, deg):
    n = math.sqrt(sum(x * x for x in ax)); x, y, z = (v / n for v in ax)
    a = math.radians(deg); c, s, t = math.cos(a), math.sin(a), 1 - math.cos(a)
    return [t*x*x + c, t*x*y - s*z, t*x*z + s*y,
            t*x*y + s*z, t*y*y + c, t*y*z - s*x,
            t*x*z - s*y, t*y*z + s*x, t*z*z + c]


def fk(d, angles, root=None):
    jl = {j['link']: (j, a) for j, a in zip(d['joints'], angles)}
    W = []
    for i, l in enumerate(d['links']):
        T = mat(l['rot'], l['pos']) if not (i == 0 and root) else mat(root[3:], root[:3])
        if i in jl:
            j, a = jl[i]
            if j['type'] == 'rotational':
                T = mul(T, mat(rot_axis(j['axis'], a), [0, 0, 0]))
            else:
                T = mul(T, mat([1, 0, 0, 0, 1, 0, 0, 0, 1], [v * a / 1000.0 for v in j['axis']]))
        p = l['parent']
        assert p < i, 'parent must come before child'
        W.append(mul(W[p], T) if p >= 0 else T)
    return W


for f in sys.argv[1:]:
    d = json.load(open(f))
    c = d['check']
    W = fk(d, c['angles'])
    err = max(math.dist([W[i][k][3] for k in range(3)], c['link_world_pos'][i]) for i in range(len(W)))
    nv = sum(len(m['vertices']) // 3 for l in d['links'] for m in l['meshes'])
    nt = sum(len(m['indices']) // 3 for l in d['links'] for m in l['meshes'])
    bad = [m for l in d['links'] for m in l['meshes']
           if len(m['vertices']) % 3 or len(m['indices']) % 3
           or (m['indices'] and max(m['indices']) >= len(m['vertices']) // 3)]
    lens = {k: len(v) for k, v in d['poses'].items()}
    okp = all(n == len(d['joints']) for n in lens.values())
    print(f"{os.path.basename(f)}: {os.path.getsize(f)/1024:.0f} KB, links {len(d['links'])}, "
          f"joints {len(d['joints'])}, verts {nv}, tris {nt}, poses {list(d['poses'])}"
          f"{'' if okp else ' POSE-LENGTH-MISMATCH'}, check({c['pose']}) max err {err*1000:.3f} mm"
          f"{' BAD-MESH' if bad else ''}")
    for mo in d.get('motions', []):
        n = len(mo['frames']); ok = all(len(a) == len(d['joints']) for a in mo['frames']) and len(mo.get('root', mo['frames'])) == n
        msg = f"  motion {mo['name']}: {n} frames @ {mo['fps']} fps ({n/mo['fps']:.1f} s){'' if ok else ' LENGTH-MISMATCH'}"
        if 'check' in mo:
            k = mo['check']['frame']
            W = fk(d, mo['frames'][k], mo['root'][k] if 'root' in mo else None)
            e = max(math.dist([W[i][r][3] for r in range(3)], mo['check']['link_world_pos'][i]) for i in range(len(W)))
            msg += f", check frame {k} max err {e*1000:.3f} mm"
        if len(d['motions']) <= 20 or not ok: print(msg)
    if d.get('motions'):
        print(f"  motions {len(d['motions'])}, frames {sum(len(m['frames']) for m in d['motions'])}")
    ph = d.get('physics')
    if ph:
        okph = len(ph['links']) == len(d['links']) and len(ph['joints']) == len(d['joints'])
        print(f"  physics: total {ph['total_mass']} kg, shapes {sum(len(l['shapes']) for l in ph['links'])}, "
              f"initial root z {ph['initial']['root_pos'][2]} m{'' if okph else ' LENGTH-MISMATCH'}")
