#!/usr/bin/env python3
"""ロボットの一覧の分類 catalog.json を作る (iPhone・Mac・Android・デスクトップの一覧が使う)

  python3 eusview/robots/make_catalog.py
  KXR・KHR は名前と関節の構成で身体の形ごとに分ける。JSK は 1 つ。
  一覧の画像 <グループ>/<名前>.png は desktop の make thumbs で作る。
"""
import glob, json, os, re

D = os.path.dirname(os.path.abspath(__file__))

# (id, 見出し, 説明, 名前が合うか)
KXR = [
    ("biped6", "二足・脚 6 軸", "l6 = 脚 6 軸, a = 腕の軸, h2 = 首 2 軸",
     lambda n: re.match(r"kxrl2l6", n) or n == "kxrl4l2a6h2m"),
    ("biped5", "二足・脚 5 軸", "l5 = 脚 5 軸", lambda n: n.startswith("kxrl2l5")),
    ("wheelfoot", "二足 + 足の車輪", "w2 = 足の裏に車輪", lambda n: n.startswith("kxrl2w2")),
    ("upper", "上半身・台車", "短い脚 (2 軸) か台車の上に腕と頭。t1 = 腰 1 軸", lambda n: re.match(r"kxr(a6g|l2l2|mw4|t1)", n)),
    ("quad", "四足", "4 本脚", lambda n: n.startswith("kxrl4")),
    ("hexa", "六足", "6 本脚", lambda n: n.startswith("kxrl6")),
]
KHR = [
    ("khr2", "KHR-2 系", "khr20〜khr24", lambda n: re.match(r"khr2\d", n)),
    ("khr3", "KHR-3 系", "khr3〜", lambda n: n.startswith("khr3")),
    ("l5", "脚 5 軸", "l5 = 脚 5 軸, a = 腕の軸, h2 = 首 2 軸, g = 手", lambda n: n.startswith("khrl5")),
    ("l6", "脚 6 軸", "l6 = 脚 6 軸", lambda n: n.startswith("khrl6")),
    ("t1", "腰つき", "t1 = 腰 1 軸", lambda n: n.startswith("khrt1")),
    ("other", "その他", "", lambda n: True),
]


def group(g, rules):
    names = sorted(os.path.basename(f)[:-5] for f in glob.glob(os.path.join(D, g, "*.json")))
    joints = {n: len(json.load(open(os.path.join(D, g, n + ".json")))["joints"]) for n in names}
    cats, used = [], set()
    for cid, title, note, ok in rules:
        rs = [n for n in names if n not in used and ok(n)]
        used.update(rs)
        if rs:
            cats.append({"id": cid, "title": title, "note": note, "robots": rs})
    return cats, joints


def main():
    out = {"version": 1, "groups": {}, "joints": {}}
    for g, rules in (("kxr", KXR), ("khr", KHR), ("jsk", [("all", "JSK のロボット", "", lambda n: True)])):
        cats, joints = group(g, rules)
        out["groups"][g] = cats
        out["joints"].update(joints)
        print(g, ", ".join(f"{c['title']} {len(c['robots'])}" for c in cats))
    with open(os.path.join(D, "catalog.json"), "w") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
