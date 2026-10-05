#!/usr/bin/env python3
# make-videos.py : スライド用の動画 (rendervideo) をまとめて作る.
#   tools/build-rendervideo.sh で rendervideo を作ってから:  python3 tools/make-videos.py [名前 ...]
#   出力: eusview/docs/eusview_media/<名前>.mp4 と .png (ポスター)。ログ (物理の位置) は eusview/docs/logs/eusview_media/<名前>.log
import json, os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
EV = os.path.abspath(os.path.join(HERE, "../.."))                # eusview (kxreus/eusview)
R = os.path.join(EV, "robots")
OUT = os.environ.get("OUT", os.path.join(EV, "docs/eusview_media"))
LOG = os.environ.get("LOG", os.path.join(EV, "docs/logs/eusview_media"))
BIN = os.environ.get("RENDERVIDEO", os.path.join(EV, "ios/build/rendervideo/rendervideo"))
KXR = R + "/kxr/kxrl2l6a6h2.json"

def gallery(group, names, title):
    return dict(width=1280, height=720, seconds=12, poster=0.0, cols=3, rows=2, title=title,
                panels=[dict(robot=f"{R}/{group}/{n}.json", mode="pose", label=n, cam=dict(az=30, el=12, orbit=30, zoom=0.95)) for n in names])

SIDE = dict(az=90, el=8, zoom=0.85, targetZ=0.5)
J = {
 "gallery_kxr": gallery("kxr", ["kxrl2l6a6h2", "kxra6g", "kxrl4d", "kxrl4r", "kxrmw4a6h2m", "kxrt1l2l2d7h2m"],
                        "KXR（kxreus）のロボット  36 体から 6 体（reset-pose）"),
 "gallery_khr": gallery("khr", ["khr3", "khr20h2", "khr23oh", "khrnishio", "khrl6a4h2wg", "khranzaifly"],
                        "KHR（kxreus）のロボット  43 体から 6 体（reset-pose）"),
 "gallery_jsk": gallery("jsk", ["sample-robot", "h7", "darwin", "hanzou", "akira", "macra"],
                        "jskeus のロボット（irteus/demo, eus/models）  42 体から 6 体"),
 "motion_kxr_walk": dict(width=1280, height=720, seconds=13, poster=2.0,
   title="kxrl2l6a6h2 「ゆっくり歩行前（5回）」\n関節角をそのまま表示（物理なし, RCB4 エミュレーション 50 fps, いちばん低い点を床に合わせて表示）",
   panels=[dict(robot=KXR, mode="kinematic", ground=True, motions=["ゆっくり歩行前"] * 3, gap=0.3, cam=dict(az=35, el=12, orbit=6))]),
 "motion_khr_greet": dict(width=1280, height=720, seconds=12, poster=1.2,
   title="khr20h2 「押忍」「手を振る」「エイエイオー」\nHello_KHR3(V2.3) のモーション（物理なし）",
   panels=[dict(robot=f"{R}/khr/khr20h2.json", mode="kinematic", ground=True, motions=["押忍", "手を振る", "エイエイオー"], gap=0.5,
                label="{motion}", cam=dict(az=25, el=12))]),
 "motion_kxr_rcb4": dict(width=1280, height=720, seconds=13, poster=3.0,
   title="kxra6g  プロジェクトのモーションを続けて再生（物理なし）",
   panels=[dict(robot=f"{R}/kxr/kxra6g.json", mode="kinematic", ground=True, motions=["挨拶", "手を振る", "喜ぶ", "パンチ前左", "パンチ前右", "防御", "がっかり"],
                gap=0.3, label="{motion}", cam=dict(az=30, el=12))]),
 "sample-robot-walk": dict(width=1280, height=720, seconds=11.5, poster=4.0,
   title="sample-robot の歩行（irteus の歩行生成 go-pos 500 150 45°）\nルートの位置も JSON に入っている（物理なし）",
   panels=[dict(robot=f"{R}/jsk/sample-robot-walk.json", mode="kinematic", motion="walk", cam=dict(az=40, el=20, zoom=0.8, follow=True))]),
 "physics_walk": dict(width=1280, height=720, seconds=13, poster=6.0, log=0.5,
   title="物理（ODE）で歩く  kxrl2l6a6h2 「ゆっくり歩行前（5回）」×2\n動作の関節角 = サーボの目標（kp 10, mu 0.8, 接触 4 点, dt 0.01 s）",
   panels=[dict(robot=KXR, mode="physics", motions=["ゆっくり歩行前", "ゆっくり歩行前"], gap=0.3, motionStart=1.0,
                label="前へ x {dx} mm（{t} 秒）", cam=dict(az=60, el=12, zoom=0.9, follow=True))]),
 "cmp_friction": dict(width=1280, height=720, seconds=13, poster=8.0, log=0.5,
   title="床の摩擦と接触点  立つ 3 秒 → ゆっくり歩行前 → 立つ",
   panels=[dict(robot=KXR, mode="physics", motion="ゆっくり歩行前", motionStart=3, mu=0.1, contacts=1, softCFM=0.01,
                label="mu 0.1 / 接触 1 点 / soft_cfm 0.01（kxr-dyna の値）\nx {dx} mm   {t} 秒", cam=SIDE),
           dict(robot=KXR, mode="physics", motion="ゆっくり歩行前", motionStart=3,
                label="mu 0.8 / 接触 4 点 / soft_cfm 0.001（今の既定）\nx {dx} mm   {t} 秒", cam=SIDE)]),
 "cmp_cfm": dict(width=1280, height=720, seconds=8, poster=4.0, log=0.5,
   title="関節の CFM（拘束の柔らかさ）  reset-pose で立つ",
   panels=[dict(robot=KXR, mode="physics", pose="reset-pose", worldCFM=0.01, label="world CFM 0.01（JSON の値そのまま）\n腰の高さ z {z} mm",
                cam=dict(az=90, el=4, zoom=0.45, targetZ=0.3)),
           dict(robot=KXR, mode="physics", pose="reset-pose", label="world CFM 1e-5（今の既定）\n腰の高さ z {z} mm",
                cam=dict(az=90, el=4, zoom=0.45, targetZ=0.3))]),
 "cmp_servo": dict(width=1280, height=720, seconds=8, poster=4.0, log=0.5,
   title="サーボ オン / オフ（2 秒で脱力）  KRS の公称トルク 1.36 N·m",
   panels=[dict(robot=KXR, mode="physics", pose="reset-pose", realServo=True, label="サーボ {servo}\n腰の高さ z {z} mm", cam=dict(az=40, el=12)),
           dict(robot=KXR, mode="physics", pose="reset-pose", realServo=True, servoOffAt=2.0, label="サーボ {servo}\n腰の高さ z {z} mm", cam=dict(az=40, el=12))]),
 "cmp_torque": dict(width=1280, height=720, seconds=10, poster=5.0, log=0.5,
   title="サーボの力の上限  kxrl2l6a6h2 「逆立ち」（物理）",
   panels=[dict(robot=KXR, mode="physics", motion="逆立ち", label="fmax 500000 N·m（eusdyna, 実質無制限）\nx {dx} mm", cam=dict(az=60, el=15, zoom=1.0, follow=True)),
           dict(robot=KXR, mode="physics", motion="逆立ち", realServo=True, label="1.36 N·m, 8.06 rad/s（KRS-3304 の公称値）\nx {dx} mm", cam=dict(az=60, el=15, zoom=1.0, follow=True))]),
 "physics_fall_getup": dict(width=1280, height=720, seconds=10, poster=6.0, log=0.5,
   title="khr20h2  うつぶせ / 仰向けになって起きあがる（物理）",
   panels=[dict(robot=f"{R}/khr/khr20h2.json", mode="physics", motions=["うつぶせになる", "起きあがり(うつぶせ)"], gap=1.0,
                label="{motion}", cam=dict(az=70, el=15, zoom=1.0, follow=True)),
           dict(robot=f"{R}/khr/khr20h2.json", mode="physics", motions=["仰向けになる", "起きあがり(仰向け)"], gap=1.0,
                label="{motion}", cam=dict(az=110, el=15, zoom=1.0, follow=True))]),
 "physics_jsk_h7": dict(width=1280, height=720, seconds=9, poster=3.0, log=0.5,
   title="h7（jskeus, 約 {mass} kg）が物理で立つ  reset-pose, サーボ kp 10",
   panels=[dict(robot=f"{R}/jsk/h7.json", mode="physics", pose="reset-pose", label="腰の高さ z {z} mm   接触 {c} 点   {t} 秒",
                cam=dict(az=30, el=12, orbit=12))]),
 "physics_kxrl4d": dict(width=1280, height=720, seconds=10, poster=4.0, log=0.5,
   title="4 脚 kxrl4d 「一定歩行前（3歩）」×3（物理）",
   panels=[dict(robot=f"{R}/kxr/kxrl4d.json", mode="physics", motions=["一定歩行前"] * 3, gap=0.2, motionStart=1.0,
                label="前へ x {dx} mm（{t} 秒）", cam=dict(az=55, el=18, zoom=1.0, follow=True))]),
}

def total_mass(path):
    try: return json.load(open(path))["physics"]["total_mass"]
    except Exception: return None

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[1:] or list(J)
    for n in names:
        job = dict(J[n]); job["out"] = f"{OUT}/{n}.mp4"
        if "{mass}" in job.get("title", ""):
            job["title"] = job["title"].replace("{mass}", "%.0f" % total_mass(job["panels"][0]["robot"]))
        jp = f"{OUT}/{n}.job.json"
        json.dump(job, open(jp, "w"), ensure_ascii=False, indent=1)
        os.makedirs(LOG, exist_ok=True)
        with open(f"{LOG}/{n}.log", "w") as lg:
            subprocess.run([BIN, jp], stdout=lg, check=True)
        os.remove(jp)
        print(n, os.path.getsize(job["out"]) // 1024, "KB")
