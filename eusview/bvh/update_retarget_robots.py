#!/usr/bin/env python3
"""retarget_tables.json の robots.supported を作り直す（BVH の画面で選べるロボットの一覧）。

  python3 eusview/bvh/update_retarget_robots.py

eusview/robots/<グループ>/*.json のうち、関節名が <limb>-<joint>-<r|p|y>（limb = larm, rarm, lleg, rleg, head, torso）で
両脚と片腕以上があるものを選ぶ（アプリの robotSupportsRetarget と同じ条件）。アプリは JSON を全部読まずにこの一覧を使う。
"""
import json, os, re
here = os.path.dirname(os.path.abspath(__file__))
robots = os.path.join(here, "..", "robots")
pat = re.compile(r'^(larm|rarm|lleg|rleg|head|torso)-[a-z0-9]+-[rpy]$')
sup = {}
for g in ["kxr", "khr", "jsk"]:
  names = []
  for f in sorted(os.listdir(os.path.join(robots, g))):
    if not f.endswith(".json"):
      continue
    d = json.load(open(os.path.join(robots, g, f)))
    have = {m.group(1) for j in d.get("joints", []) for m in [pat.match(j["name"])] if m}
    if {"lleg", "rleg"} <= have and ({"larm", "rarm"} & have):
      names.append(f[:-5])
  sup[g] = names
p = os.path.join(here, "retarget_tables.json")
t = json.load(open(p))
t["robots"]["supported"] = sup
s = json.dumps(t, ensure_ascii=False, indent=1)
open(p, "w").write(s + "\n")
print({g: len(v) for g, v in sup.items()})
