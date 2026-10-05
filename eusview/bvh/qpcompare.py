#!/usr/bin/env python3
"""qpcompare.py : GMR + QP のコマごとの結果を 2 つの実装で比べる (同じ wbqp.cpp を Swift と Kotlin (JNI) から呼んだもの)
  python3 bvh/qpcompare.py ios/build/qpdump android/build/qptest
    ios/build/qpdump      : ios/tools/qptest -physics 0 -dump ios/build/qpdump  (Swift の GMR → wbqp)
    android/build/qptest  : android の make test-qp (QpTest.kt, Kotlin の GMR → JNI → wbqp)
  CSV の並び: frame,contact,support,status,coll_before,coll_after,min_dist_before,min_dist_after,com_margin_before,com_margin_after,
             root_ref(12),root(12),q_ref...,q...   (関節角は度, 直動は mm, 位置は m)
  出すもの: 参照 (GMR) と答え (QP) の関節角の差 (最大・平均, 度), ルートの位置の差 (mm), contact・衝突のコマの数の違い
"""
import math
import os
import sys


def load(p):
    rows = []
    for line in open(p):
        v = line.strip().split(",")
        if len(v) < 34:
            continue
        rows.append([float(x) for x in v])
    return rows


def main():
    a_dir, b_dir = sys.argv[1], sys.argv[2]
    names = sorted(set(os.listdir(a_dir)) & set(os.listdir(b_dir)))
    print("%-36s %5s %11s %11s %11s %11s %9s %9s %s" % ("file", "frames", "q_ref max", "q max", "q mean", "root mm", "contact≠", "coll≠", "coll (A/B)"))
    for n in names:
        A, B = load(os.path.join(a_dir, n)), load(os.path.join(b_dir, n))
        m = min(len(A), len(B))
        nj = (len(A[0]) - 34) // 2
        dref = dq = sq = dr = 0.0
        cnt = 0
        dc = dcoll = 0
        ca = cb = 0
        for i in range(m):
            a, b = A[i], B[i]
            if a[1] != b[1]:
                dc += 1
            if (a[5] > 0) != (b[5] > 0):
                dcoll += 1
            ca += a[5] > 0
            cb += b[5] > 0
            for k in range(nj):
                dref = max(dref, abs(a[34 + k] - b[34 + k]))
                d = abs(a[34 + nj + k] - b[34 + nj + k])
                dq = max(dq, d)
                sq += d
                cnt += 1
            dr = max(dr, 1000 * math.dist(a[22:25], b[22:25]))
        print("%-36s %5d %10.4f° %10.4f° %10.5f° %10.3f %9d %9d %d/%d" % (n, m, dref, dq, sq / max(cnt, 1), dr, dc, dcoll, ca, cb))


if __name__ == "__main__":
    main()
