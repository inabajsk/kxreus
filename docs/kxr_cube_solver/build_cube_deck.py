# -*- coding: utf-8 -*-
"""Lecture deck on fkanehiro/kxr_cube_solver -> docs/kxr_cube_solver_lecture.pptx

    python3 docs/kxr_cube_solver/build_cube_deck.py

Media (media/) were produced by tools/: the public demo video (youtu.be/
CVYYmKJGDNQ) cut into clips, the vision code run on the repo's gui.png
(vis_fig.py), and robot.py's command stream for a kociemba solution
(gen_cmds.py) replayed on the kxreus kxrl2l2a6h2m model (sim.l).
"""
import json
import os
import re
import sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from pptx_helpers import *  # noqa: E402,F401,F403

M = os.path.join(HERE, "media")
OUT = os.environ.get("OUT", os.path.join(os.path.dirname(HERE), "kxr_cube_solver_lecture.pptx"))
CMDS = json.load(open(os.path.join(M, "cmds.json")))
VIS = json.load(open(os.path.join(M, "vision_result.json")))


def m(n):
  return os.path.join(M, n)


def mv(slide, name, x, y, w, h):
  return movie(slide, m(name + ".mp4"), m(name + ".png"), x, y, w, h)


D = Deck()

# 1 title --------------------------------------------------------------
s = D.slide(dark=True)
tb(s, 0.8, 1.0, 7, 0.4, [[{"t": "KXR × RUBIK'S CUBE", "bold": True, "color": ORANGE, "size": 14}]], margin=0)
tb(s, 0.8, 1.5, 7.2, 2.0, ["小型ヒューマノイドKXRで", "ルービックキューブを解く"], size=36, bold=True, color=WHITE, margin=0, line=1.1)
tb(s, 0.8, 3.45, 7.0, 1.4, ["kxr_cube_solver（金広文男 氏）の仕組み", "システム・ソフトウェア・画像認識・動作生成・ロボットモデル"],
   size=17, color=PALE, margin=0, spacing=5)
tb(s, 0.8, 6.3, 7.3, 0.5, "github.com/fkanehiro/kxr_cube_solver  ·  デモ動画 youtu.be/CVYYmKJGDNQ", size=12,
   color=RGBColor(0x9A, 0xA8, 0xBA), font=MONO, margin=0)
image(s, m("youtube_thumb.jpg"), 8.1, 1.6, 4.7)
tb(s, 8.1, 4.35, 4.7, 0.4, "2024年3月20日 稲葉雅幸教授 最終講義 第1部（JSK OB・OG会）でのデモ", size=11,
   color=PALE, margin=0, align=PP_ALIGN.CENTER)

# 2 background + full video ---------------------------------------------
s = D.slide()
title(s, "デモの概要", "OVERVIEW")
mv(s, "demo_full", 0.6, 1.55, 7.2, 4.05)
tb(s, 0.6, 5.7, 7.2, 0.4, "デモ全編（約2分40秒）。画面右はPCに表示された画像処理ウィンドウ", size=11.5, color=MUTED, margin=0)
bullets(s, 8.2, 1.6, 4.6, 5.2, [
  [{"t": "目的", "bold": True}, {"t": "：稲葉教授最終講義（2024/3/20）のOB・OG会で、KXRが両手でキューブを持ち替えながら解く"}],
  [{"t": "流れ", "bold": True}, {"t": "：手に置く → 6面を見回して色認識 → 解法計算（kociemba）→ 持ち替えと手首の回転で1手ずつ実行 → 完成を発話"}],
  [{"t": "規模", "bold": True}, {"t": "：ROSパッケージ1つ、Python 約740行 + Euslisp 約80行"}],
  [{"t": "特徴", "bold": True}, {"t": "：6自由度腕の手首回転だけで面を回し、足りない自由度は「持ち替え」で補う。視覚はRealSenseのカラー画像のみ"}],
], size=13.5, gap=9)

# 3 agenda ----------------------------------------------------------------
s = D.slide()
title(s, "本講義の構成", "AGENDA")
items = [("システム構成", "ハード・ROSノード・通信"), ("ソフトウェア構成", "ファイルと状態遷移"),
         ("ハードウェアの工夫", "グリッパ改造と初期姿勢"), ("画像認識", "ROI・k-means・CIEDE2000"),
         ("解法と動作生成", "kociemba → 持ち替え計画"), ("ロボットモデル", "kxrl2l2a6h2m と kxreus")]
for i, (a, b) in enumerate(items):
  x = 0.6 + (i % 3) * 4.1
  y = 1.7 + (i // 3) * 2.55
  rect(s, x, y, 3.8, 2.2, TILE)
  tb(s, x + 0.3, y + 0.22, 1.3, 0.8, [[{"t": "%02d" % (i + 1), "bold": True, "color": ORANGE, "size": 32}]], margin=0)
  tb(s, x + 0.3, y + 1.0, 3.3, 0.5, [[{"t": a, "bold": True, "size": 18}]], margin=0)
  tb(s, x + 0.3, y + 1.5, 3.3, 0.6, b, size=13, color=MUTED, margin=0)

# 4 system configuration ------------------------------------------------
s = D.slide()
title(s, "システム構成図", "SYSTEM")
box(s, 0.6, 1.7, 3.0, 1.4, "RealSense カメラ", ["KXRの頭部に搭載", "カラー 848×480 @30fps"], fill=SOFTTL)
rect(s, 4.3, 1.55, 4.6, 4.9, TILE)
tb(s, 4.5, 1.65, 4.2, 0.4, [[{"t": "PC（Debian 10 + ROS + rcb4eus）", "bold": True, "size": 14, "color": TEAL}]], margin=0)
box(s, 4.55, 2.15, 4.1, 0.95, "realsense2_camera", ["/camera/color/image_raw を出版"], fill=WHITE)
box(s, 4.55, 3.25, 4.1, 1.15, "cubeSolver.py（rospy）", ["状態遷移・画像認識・解法・持ち替え計画", "OpenCVウィンドウ（キー操作）"], fill=WHITE)
box(s, 4.55, 4.55, 4.1, 0.95, "roseus_command_server", ["cubeSolver.l：Euslisp文字列を実行"], fill=WHITE)
box(s, 4.55, 5.6, 4.1, 0.7, "open_jtalk + aplay", ["音声合成で進行を話す"], fill=WHITE, s1=12, s2=10)
box(s, 9.6, 1.7, 3.1, 1.3, "KXR 本体", ["kxrl2l2a6h2m", "RCB-4 + KRSサーボ 20個"], fill=SOFTOR)
box(s, 9.6, 3.45, 3.1, 1.1, "USB Dual Adapter", ["シリアル通信 (rcb4eus)"], fill=WHITE, line=LINE)
box(s, 9.6, 5.0, 3.1, 1.1, "スピーカ・モニタ", ["発話と認識結果表示"], fill=WHITE, line=LINE)
arrow(s, 3.6, 2.4, 4.55, 2.6, ORANGE)
arrow(s, 6.6, 3.1, 6.6, 3.25)
arrow(s, 6.6, 4.4, 6.6, 4.55)
arrow(s, 8.65, 5.0, 9.6, 4.1, ORANGE)
arrow(s, 11.15, 3.45, 11.15, 3.0)
tb(s, 0.6, 3.5, 3.4, 2.8, ["カメラは両手の間のキューブを正面から見る。", "キューブは頂点をカメラに向けて斜め45°に持つため、", "画像上では菱形に見える"],
   size=12, color=MUTED, margin=0, spacing=3)

# 5 software stack ------------------------------------------------------
s = D.slide()
title(s, "ソフトウェア構成図：Python が考え、Euslisp が動かす", "SOFTWARE")
layers = [("cubeSolver.py", "状態遷移 cubeSolverFSM：init → start → scan → solve → end", SOFTOR),
          ("vision.py / helpers.py / config.py", "9つのROIの色認識、面・キューブ状態の検証、GUI描画", TILE),
          ("kociemba（pip）", "54文字の状態文字列 → 20手前後の解法（二段階アルゴリズム）", SOFTTL),
          ("robot.py", "解法の1手を「掴む・離す・手首角度」のコマンド列に変換（持ち替え計画）", TILE),
          ("SendCommand.srv", "string command → bool success（Euslispの式を文字列で送る）", SOFTTL),
          ("cubeSolver.l / config.l", "grasp・release・angle・init-pose を定義し、受け取った式を eval", SOFTOR),
          ("rcb4rosinterface.l（rcb4eus）", "*robot*（モデル）と *ri*（実機）、:angle-vector で RCB-4 へ", TILE)]
for i, (a, b, fill) in enumerate(layers):
  y = 1.5 + i * 0.73
  rect(s, 0.6, y, 12.1, 0.64, fill, radius=0.12)
  tb(s, 0.8, y, 3.6, 0.64, [[{"t": a, "bold": True, "size": 12.5, "font": MONO}]], anchor=MSO_ANCHOR.MIDDLE, margin=0)
  tb(s, 4.5, y, 8.1, 0.64, b, size=12.5, anchor=MSO_ANCHOR.MIDDLE, margin=0)
tb(s, 0.6, 6.7, 12, 0.5, "画像のコールバックごとに状態遷移を1回進め、ロボットへのコマンド送信と発話は別スレッドで実行して画像処理を止めない",
   size=12, color=MUTED, margin=0)

# 6 files ------------------------------------------------------------------
s = D.slide()
title(s, "ファイル構成", "FILES")
rows = [["ファイル", "行数", "役割"],
        ["scripts/cubeSolver.py", "242", "ROSノード本体。状態遷移、発話、キー操作、kociemba呼び出し"],
        ["scripts/vision.py", "168", "ROI計算、支配色抽出（k-means）、最近傍色、面とキューブの検証・描画"],
        ["scripts/helpers.py", "134", "BGR→L*a*b*変換と CIEDE2000 色差（qbr から流用）"],
        ["scripts/robot.py", "186", "グリッパの状態、面の回転・キューブの回転・面を見る動作の計画"],
        ["scripts/config.py", "11", "ROI中心座標と6色の基準色（BGR）"],
        ["euslisp/cubeSolver.l", "58", "ROSサービスサーバ、grasp/release/angle、受信した式の eval"],
        ["euslisp/config.l", "21", "init-pose と手首オフセット（個体差の吸収）"],
        ["launch/cubeSolver.launch", "10", "画像トピックを ~image_in にリマップして起動"],
        ["srv/SendCommand.srv", "4", "string command / bool success"],
        ["（ローカル追加）d405_camera_node.py", "61", "D405 を pyrealsense2 で直接読む代替カメラノード"]]
table(s, 0.6, 1.5, 12.1, rows, [4.2, 0.9, 7.0], size=12, rowh=0.45, mono_col0=True)
tb(s, 0.6, 6.6, 12, 0.5, "最後の2ファイルは本リポジトリ公開後に手元で追加したもの（apt版 realsense2_camera が D405 を認識しないため）", size=11.5, color=MUTED, margin=0)

# 7 state machine ------------------------------------------------------------
s = D.slide()
title(s, "状態遷移（cubeSolverFSM）", "STATE MACHINE")
states = [("init", "init-pose に移行\n「手の上に置いて」"), ("start", "両手で把持\n「状態を見てみます」"),
          ("scan", "6面×2ステップ\n見る動作 → 色が10回一致"), ("solve", "kociemba の手順を\n1手ずつ実行・雑学を話す"),
          ("end", "「完成しました」\n持ち直して init-pose")]
for i, (a, b) in enumerate(states):
  x = 0.6 + i * 2.5
  r = rect(s, x, 1.8, 2.2, 1.9, SOFTOR if a in ("scan", "solve") else TILE)
  tb(s, x, 1.95, 2.2, 0.5, [[{"t": a, "bold": True, "size": 20, "font": MONO, "color": INK}]], align=PP_ALIGN.CENTER, margin=0)
  tb(s, x + 0.1, 2.55, 2.0, 1.1, b.split("\n"), size=11.5, color=MUTED, align=PP_ALIGN.CENTER, margin=0, spacing=2)
  if i < 4:
    arrow(s, x + 2.22, 2.75, x + 2.48, 2.75, ORANGE)
arrow(s, 11.2, 3.7, 3.4, 3.7, MUTED, 1.5)
tb(s, 5.5, 3.72, 4, 0.3, "end → start：次のキューブへ", size=10.5, color=MUTED, margin=0)
tb(s, 3.2, 3.95, 5, 0.3, "scan 失敗（色の数が合わない）→ scan をやり直し", size=10.5, color=RED, margin=0)
rows = [["キー", "動作"], ["a", "自動遷移のON/OFF（ONで次々に状態が進む）"], ["n", "手動モードで次の状態へ"],
        ["e", "中断して init-pose へ戻る（把持がずれたとき）"], ["x", "neutral姿勢にしてサーボOFF"]]
table(s, 0.6, 4.6, 6.4, rows, [0.8, 5.6], size=12, rowh=0.44, mono_col0=True)
bullets(s, 7.4, 4.6, 5.3, 2.3, [
  "画像コールバック（30Hz）の中で run(frame) を呼び、状態ごとの処理を1回ずつ進める",
  "ロボット動作・発話はスレッドで実行し、isMoving()/isSpeaking() で完了を見る",
  "finish フラグが立つと stateTransition() が次の状態・次の index へ",
], size=12.5, gap=6)

# 8 hardware modification -------------------------------------------------
s = D.slide()
title(s, "ハードウェアの工夫：グリッパの改造", "HARDWARE")
for i, (f, cap) in enumerate([("neutral.jpg", "グリッパの取付を90°変更（ニュートラル姿勢）"),
                              ("gripper2.jpg", "3Dプリントした指先（Tinkercad公開）"),
                              ("gripper1.jpg", "100円ショップの滑り止めシートを貼付")]):
  x = 0.6 + i * 4.1
  if f == "neutral.jpg":  # portrait photo
    image(s, m(f), x + 0.8, 1.5, 2.2, 2.93)
  else:
    image(s, m(f), x, 1.5, 3.8, 2.85)
  tb(s, x, 4.75, 3.8, 0.6, cap, size=12, align=PP_ALIGN.CENTER, margin=0)
rect(s, 0.6, 5.55, 12.1, 1.35, TILE)
bullets(s, 0.85, 5.65, 11.7, 1.2, [
  [{"t": "キューブ", "bold": True}, {"t": "：一辺56 mm、軽い力で回る MonsterGo MG3x3 を使用（色認識もこの配色に合わせて調整）"}],
  [{"t": "ねらい", "bold": True}, {"t": "：KXRの弱いサーボ（0.66 N·m）でも滑らずに層を回せる把持力と、手首回転軸がキューブ中心を通る幾何"}],
], size=12.5, gap=4)

# 9 init pose ---------------------------------------------------------------
s = D.slide()
title(s, "初期姿勢と個体差の調整", "INIT POSE")
image(s, m("init-pose1.jpg"), 0.6, 1.5, 3.9, 2.93)
image(s, m("init-pose2.jpg"), 4.7, 1.5, 3.9, 2.93)
code(s, 0.6, 4.6, 8.0, 2.35, ["(setq *rwr-offset* 11)  (setq *lwr-offset* -7)",
                              "(defun init-pose ()",
                              "  (send *robot* :rarm :shoulder-p :joint-angle -95)",
                              "  (send *robot* :rarm :shoulder-y :joint-angle  45) ...",
                              "  (send *robot* :rarm :wrist-r :joint-angle *rwr-offset*)",
                              "  (gripper-angle :rarm 30) (gripper-angle :larm 30)",
                              "  (send *ri* :angle-vector (send *robot* :angle-vector) 3000))"], size=11)
bullets(s, 8.9, 1.6, 3.9, 5.3, [
  "両腕で肩ヨー±45°、キューブを胸の前で斜めに挟む",
  [{"t": "条件1", "bold": True}, {"t": "：手首ロールの回転軸がキューブ中心を通る"}],
  [{"t": "条件2", "bold": True}, {"t": "：指先がキューブの面と平行"}],
  "機体ごとの誤差は init-pose の関節角と手首オフセット *rwr-offset* / *lwr-offset* で吸収",
  "調整は Ctrl-C → config.l を編集 → (load \"config.l\") → (init-pose) の繰り返し",
], size=12.5, gap=7)

# 10 vision ROI --------------------------------------------------------------
s = D.slide()
title(s, "画像認識 (1)：45°回転した9つのROI", "VISION")
image(s, m("gui_rois.png"), 0.6, 1.5, 6.6, 3.73)
tb(s, 0.6, 5.3, 6.6, 0.6, "リポジトリの gui.png に、vision.py の computeROIs() が返すROIを描画（橙の枠）", size=11, color=MUTED, margin=0)
code(s, 7.5, 1.5, 5.3, 3.1, ["roi_size = 70; roi_gap = 40",
                             "roi_rotation = pi/4",
                             "for i in (-1,0,1):      # 行",
                             "  for j in (-1,0,1):    # 列",
                             "    dx, dy = 110*j, 110*i",
                             "    x = cx + cos*dx - sin*dy - 35",
                             "    y = cy + sin*dx + cos*dy - 35"], size=11.5)
bullets(s, 7.5, 4.8, 5.3, 2.1, [
  "キューブは頂点をカメラに向けて持つので、面は画像上で菱形",
  "中心 (cx, cy) = (450, 265) は config.py で機体ごとに調整（GUI左下にマウス座標を表示）",
  "指に隠れるブロックもある → 見る動作で面を変えて全54個を集める",
], size=12, gap=5)

# 11 vision color ------------------------------------------------------------
s = D.slide()
title(s, "画像認識 (2)：支配色と CIEDE2000 による色判定", "VISION")
steps = [("ROI 70×70", "BGR画素"), ("k-means (k=1)", "支配色 BGR"), ("sRGB→XYZ→L*a*b*", "D65, 2°視野"),
         ("CIEDE2000", "6基準色との色差"), ("最小距離の色", "面の9要素")]
for i, (a, b) in enumerate(steps):
  x = 0.6 + i * 2.5
  r = rect(s, x, 1.55, 2.2, 1.05, SOFTOR if i == 3 else TILE)
  shape_text(r, [[{"t": a, "bold": True, "size": 12}], [{"t": b, "size": 10.5, "color": MUTED}]])
  if i < 4:
    arrow(s, x + 2.22, 2.07, x + 2.48, 2.07, ORANGE)
pal = [("green", (65, 135, 25)), ("orange", (30, 75, 250)), ("white", (150, 155, 160)),
       ("blue", (125, 75, 0)), ("red", (40, 20, 180)), ("yellow", (25, 165, 175))]
tb(s, 0.6, 2.9, 5, 0.4, [[{"t": "基準色（config.py、BGR）", "bold": True, "size": 13.5, "color": TEAL}]], margin=0)
for i, (n, (b, g, r_)) in enumerate(pal):
  x = 0.6 + i * 1.02
  sw = rect(s, x, 3.35, 0.9, 0.7, RGBColor(r_, g, b), shape=MSO_SHAPE.RECTANGLE)
  tb(s, x - 0.05, 4.1, 1.0, 0.5, [n, "{},{},{}".format(b, g, r_)], size=9, align=PP_ALIGN.CENTER, margin=0)
rows = [["ROI", "支配色 BGR", "L*a*b*", "判定", "色差", "2位", "色差"]]
for k, v in enumerate(VIS):
  rows.append([str(k), ",".join(str(round(x)) for x in v["bgr"]), ",".join("{:.0f}".format(x) for x in v["lab"]),
               v["best"][0], "{:.1f}".format(v["best"][1]), v["second"][0], "{:.1f}".format(v["second"][1])])
table(s, 6.9, 2.9, 5.9, rows, [0.5, 1.2, 1.1, 0.8, 0.7, 0.9, 0.7], size=9.5, rowh=0.33)
bullets(s, 0.6, 4.75, 6.0, 2.2, [
  "RGBの距離ではなく、人の見え方に近い CIEDE2000 で最も近い基準色を選ぶ（qbr の実装を流用）",
  "右表：gui.png（白面）での実測。1位の色差 3–12 に対し2位は 22–26 と十分な余裕",
  "基準色はGUI左下に出る画素値を転記して調整。背景が暗すぎ・明るすぎるとホワイトバランスで失敗",
], size=12, gap=5)

# 12 vision validation -------------------------------------------------------
s = D.slide()
title(s, "画像認識 (3)：安定化と状態の検証", "VISION")
cards = [("10フレーム一致", "見る動作の後、同じ9色が10フレーム連続で得られたら確定（maxFaceDetectionCount = 10）。動作直後の揺れや反射による誤りを除く"),
         ("面の検証", "9要素すべてが6色のどれかに判定されていること（checkFace）"),
         ("キューブの検証", "6面54個で各色がちょうど9個（checkCube）。合わなければ「見間違えたみたいです」と話して scan をやり直す"),
         ("状態文字列", "各面の中心の色 → その面の記号（U,R,F,D,L,B）。U R F D L B の順に並べた54文字を kociemba に渡す")]
for i, (a, b) in enumerate(cards):
  x = 0.6 + (i % 2) * 6.15
  y = 1.6 + (i // 2) * 2.2
  rect(s, x, y, 5.95, 2.0, TILE)
  tb(s, x + 0.3, y + 0.18, 5.4, 0.45, [[{"t": a, "bold": True, "size": 16, "color": TEAL}]], margin=0)
  tb(s, x + 0.3, y + 0.7, 5.4, 1.25, b, size=12.5, margin=0, line=1.15)
code(s, 0.6, 6.05, 12.1, 0.9, ["state = " + CMDS["state"] + "     # 例：U面9個・R面9個 … の順"], size=11.5)

# 13 vision video --------------------------------------------------------------
s = D.slide()
title(s, "動画：6面を見回して色を集める（画像処理ウィンドウ）", "VISION")
mv(s, "crop_scan", 0.6, 1.5, 7.0, 4.32)
tb(s, 0.6, 5.9, 7.0, 0.9, ["左上：現在の9マスの判定、左下：確定したキューブ展開図、右下：状態（scan:i/12）",
                           "デモ動画のモニタ部分を拡大（0:03–0:45）"], size=11, color=MUTED, margin=0, spacing=2)
for i, t in enumerate((5, 12, 18, 25, 31, 38)):
  x = 7.9 + (i % 2) * 2.45
  y = 1.5 + (i // 2) * 1.75
  image(s, m("crop_{}.png".format(t)), x, y, 2.35, 1.45)
  tb(s, x, y + 1.45, 2.35, 0.25, "{} s".format(t), size=9.5, color=MUTED, align=PP_ALIGN.CENTER, margin=0)

# 14 kociemba --------------------------------------------------------------------
s = D.slide()
title(s, "解法：kociemba の二段階アルゴリズム", "SOLVER")
bullets(s, 0.6, 1.6, 6.2, 4.0, [
  [{"t": "入力", "bold": True}, {"t": "：54文字の面配置（URFDLB順）"}],
  [{"t": "第1段階", "bold": True}, {"t": "：任意の状態から部分群 G1 =〈U, D, R2, L2, F2, B2〉へ（辺・角の向きと中層の辺をそろえる）"}],
  [{"t": "第2段階", "bold": True}, {"t": "：G1 の中だけで完成まで。枝刈り表を使った IDA* 探索"}],
  [{"t": "出力", "bold": True}, {"t": "：面記号＋回転（例 R, R', R2）。多くの場合20手前後。どんな状態も20手以内で解ける（神の数）"}],
  "pip の kociemba（C実装）で PC 上では一瞬で解が出る",
], size=13.5, gap=9)
rect(s, 7.1, 1.6, 5.6, 2.35, SOFTOR)
tb(s, 7.35, 1.75, 5.1, 0.4, [[{"t": "例（本資料の動作シミュレーション）", "bold": True, "size": 13.5, "color": ORANGE}]], margin=0)
tb(s, 7.35, 2.2, 5.1, 1.7, [[{"t": " ".join(CMDS["solution"]), "font": MONO, "size": 15, "bold": True}],
                            "{} 手".format(len(CMDS["solution"]))], size=13, margin=0, spacing=4)
rect(s, 7.1, 4.2, 5.6, 2.7, TILE)
tb(s, 7.35, 4.35, 5.1, 0.4, [[{"t": "ロボットにとっての難しさ", "bold": True, "size": 13.5, "color": TEAL}]], margin=0)
tb(s, 7.35, 4.8, 5.1, 2.0, "手順は面の記号で与えられるが、KXRが直接回せるのは「今つかんでいる2面」だけ。残りの面を回すには、キューブ全体を持ち替えて向きを変える必要がある → 次の動作生成",
   size=12.5, margin=0, line=1.15)

# 15 grasp model ----------------------------------------------------------------
s = D.slide()
title(s, "動作生成 (1)：両手の把持モデル", "MOTION")
bullets(s, 0.6, 1.6, 6.3, 5.3, [
  [{"t": "graspingFaces", "bold": True, "font": MONO}, {"t": "：左手が D 面、右手が R 面を把持（初期）。手首ロールを回すと、その手が持つ面が回る"}],
  [{"t": "gripper クラス", "bold": True}, {"t": "：手首の角度（-90 / 0 / +90）を覚えていて、"}, {"t": "grasp / release / setAngle / regrasp / rotate", "font": MONO}],
  [{"t": "regrasp(a)", "bold": True, "font": MONO}, {"t": "：離す → 手首を a にする → 掴む（キューブは他方の手が保持）"}],
  [{"t": "rotate(Δ)", "bold": True, "font": MONO}, {"t": "：可動範囲を超えそうなら先に反対側へ持ち直してから回す（例：+90°の位置で+90°回すなら、先に-90°へ持ち直す）"}],
  "面を回すとき、もう一方の手は0°に持ち直してキューブ本体を保持する",
], size=13, gap=9)
image(s, m("sim_grasp.png"), 7.2, 1.55, 5.5, 4.13)
tb(s, 7.2, 5.75, 5.5, 0.5, "kxreus の kxrl2l2a6h2m モデルで再現した把持（両手で56 mmのキューブを斜めに保持）", size=11, color=MUTED, margin=0, align=PP_ALIGN.CENTER)

# 16 rotateFace cases -------------------------------------------------------------
s = D.slide()
title(s, "動作生成 (2)：回したい面ごとの場合分け（rotateFace）", "MOTION")
rows = [["回したい面", "動作", "つかむ面の更新"],
        ["右手が持つ面", "左手を0°に持ち直し → 右手首を回す", "なし"],
        ["左手が持つ面", "右手を0°に持ち直し → 左手首を回す", "なし"],
        ["右手の面の反対側", "左手でキューブを180°回して向きを変え → 右手首を回す", "右 ← その面"],
        ["左手の面の反対側", "右手でキューブを180°回す → 左手首を回す", "左 ← その面"],
        ["両手の面に挟まれた面（前）", "右手でキューブを −90°回す → 左手首を回す", "左 ← その面"],
        ["両手の面に挟まれた面（後）", "右手でキューブを +90°回す → 左手首を回す", "左 ← その面"]]
table(s, 0.6, 1.5, 12.1, rows, [3.2, 6.4, 2.5], size=12.5, rowh=0.5)
code(s, 0.6, 5.2, 12.1, 1.7, ["# solve R'（右手の面を -90°）→ robot.py が出力するコマンド列",
                              "(release :larm)(angle :larm 0)(grasp :larm)(angle :rarm -90)",
                              "# rotateCube：一方の手で全体を回す間、もう一方は離して0°へ戻し、回し終わったら掴み直す"], size=12)

# 17 lookAt ----------------------------------------------------------------------
s = D.slide()
title(s, "動作生成 (3)：6面を見る動作（lookAt）", "MOTION")
look = [p for p in CMDS["phases"] if p[0].startswith("lookAt") or p[0] == "finishScan"]
rows = [["段階", "コマンド列（robot.py の出力）"]]
for n, c in look:
  rows.append([n, c])
table(s, 0.6, 1.5, 12.1, rows, [1.8, 10.3], size=11, rowh=0.5, mono_col0=True)
tb(s, 0.6, 5.7, 12.1, 1.2, ["順序 D → U → L → R → B → F。1面ごとに「見る動作」と「色が10回一致するまで待つ」の2ステップ（scan は計12ステップ）",
                            "手首を ±90°〜180°回してカメラ側に目的の面を向け、必要なら反対の手へ持ち替える"], size=12.5, margin=0, spacing=4)

# 18 euslisp side ----------------------------------------------------------------
s = D.slide()
title(s, "動作生成 (4)：Euslisp 側の実行", "MOTION")
code(s, 0.6, 1.5, 7.1, 5.4, ["(defun grasp (arm)                ; 指を閉じる",
                             "  (gripper-angle arm 23)",
                             "  (send *ri* :angle-vector (send *robot* :angle-vector) 500))",
                             "(defun release (arm)              ; 指を開く",
                             "  (gripper-angle arm 55)",
                             "  (send *ri* :angle-vector (send *robot* :angle-vector) 200))",
                             "(defun angle (arm angle)          ; 手首ロール",
                             "  (let* ((angle (+ angle offset))",
                             "         (n (round (/ |Δ| 30))))",
                             "    (send wr :joint-angle angle)",
                             "    (send *ri* :angle-vector ... (* n 200))))",
                             "(defun command-callback (req)     ; ROSサービス",
                             "  (eval (read-from-string (send req :command))) ...)"], size=11)
bullets(s, 8.0, 1.6, 4.8, 5.3, [
  "Python は「(progn (release :larm)(angle :larm 0) …)」という Euslisp の式を文字列で送るだけ",
  "roseus 側は受け取った式を eval。*ri* :angle-vector は補間時間が終わるまで返らないので、サービスの応答＝動作完了",
  [{"t": "時間", "bold": True}, {"t": "：把持 0.5 s、解放 0.2 s、手首は30°あたり0.2 s（90°で0.6 s）"}],
  "モデル *robot* の関節角を変えてから実機へ送る、rcb4eus の標準的な書き方",
], size=12.5, gap=8)

# 19 statistics ----------------------------------------------------------------------
s = D.slide()
title(s, "動作の内訳：1手あたりのコマンド数", "MOTION")
solve = [(p[0].split()[1], p[1]) for p in CMDS["phases"] if p[0].startswith("solve")]
counts = [len(re.findall(r"\((?:grasp|release|angle)", c)) for _, c in solve]
bar_chart(s, 0.5, 1.45, 8.3, 5.4, ["{}:{}".format(i + 1, op) for i, (op, _) in enumerate(solve)],
          [("コマンド数", counts)], colors=["1F7A8C"], title_text="{}手の解法を実行する各手のプリミティブ数（掴む・離す・手首）".format(len(solve)),
          number_format="0", legend=False, font_size=9)
allc = Counter(re.findall(r"\((grasp|release|angle|init-pose)", "".join(p[1] for p in CMDS["phases"])))
bullets(s, 9.1, 1.6, 3.7, 5.3, [
  "見回し＋解法全体で {} コマンド".format(sum(v for k, v in allc.items() if k != "init-pose")),
  "内訳：手首 {}、掴む {}、離す {}".format(allc["angle"], allc["grasp"], allc["release"]),
  "手首だけで済む手（1コマンド）もあれば、キューブの向きを変える手は10前後になる",
  "動作時間の大半は持ち替え。解法の手数だけでなく「持ち替えの少ない解」を選べば速くなる余地がある",
], size=12.5, gap=8)

# 20 motion video ---------------------------------------------------------------------
s = D.slide()
title(s, "動画：持ち替え計画の再現と実機", "MOTION")
tb(s, 0.6, 1.45, 6.0, 0.35, [[{"t": "robot.py の出力をモデル上で再生（見回し → 19手）", "bold": True, "size": 12.5, "color": TEAL}]], margin=0)
mv(s, "sim_motion", 0.6, 1.85, 6.0, 4.5)
tb(s, 6.9, 1.45, 5.9, 0.35, [[{"t": "実機（デモ動画 1:10–1:50）", "bold": True, "size": 12.5, "color": TEAL}]], margin=0)
mv(s, "clip_solve", 6.9, 1.85, 5.9, 3.32)
tb(s, 0.6, 6.45, 12.1, 0.6, "左は gen_cmds.py → sim.l：kxr_cube_solver と同じ grasp/release/angle の時間でモデルを補間。キューブは把持している手に付随させ、面の回転（層）は描画を省略",
   size=11, color=MUTED, margin=0)
bullets(s, 6.9, 5.3, 5.9, 1.1, ["上部にいま実行中の手とコマンドを表示", "シミュレーションの所要時間：約97秒（発話待ちなし）"], size=11.5, gap=3)

# 21 robot model -------------------------------------------------------------------------
s = D.slide()
title(s, "ロボットモデル：kxrl2l2a6h2m", "ROBOT MODEL")
image(s, m("model_neutral.png"), 0.6, 1.5, 2.9, 2.9, tile=True)
image(s, m("model_init.png"), 3.6, 1.5, 2.9, 2.9, tile=True)
tb(s, 0.6, 4.45, 2.9, 0.3, "ニュートラル", size=11, align=PP_ALIGN.CENTER, margin=0)
tb(s, 3.6, 4.45, 2.9, 0.3, "init-pose（config.l の角度）", size=11, align=PP_ALIGN.CENTER, margin=0)
code(s, 0.6, 4.9, 5.9, 2.0, ["((\"kxrl2l2a6h2m\")",
                             " (:body :l2l6m :type :l2 :head :d405eyes",
                             "  :shoulder :pry-cross :elbow :angle",
                             "  :wrist :cross-pr :leg :j2-pr",
                             "  :gripper t :gripper-straight t ...)"], size=11)
rows = [["部位", "自由度", "関節"],
        ["腕（左右）", "6 + 指", "肩 p・r・y、肘 p、手首 p・r、グリッパ（1サーボで2指）"],
        ["脚（左右）", "2", "股 y・r（キューブ操作中は固定）"],
        ["首", "2", "neck-y・neck-p（p=15°でキューブを見下ろす）"],
        ["頭部", "—", "RealSense D405 ＋ M5系の目（:d405eyes）"],
        ["合計", "20サーボ", "モデル上は22関節（指の従動関節を含む）"]]
table(s, 6.8, 1.5, 6.0, rows, [1.3, 1.1, 3.6], size=11, rowh=0.52)
tb(s, 6.8, 4.75, 6.0, 2.1, ["名前の意味：l2（2脚）l2（脚2自由度）a6（腕6自由度）h2（首2自由度）m（マグネット着脱部品）",
                            "kxreus の rcb4robotconfig.l に登録。サーボID 2–7, 16–19, 22–29, 32, 34"],
   size=12, margin=0, spacing=5)

# 22 joint roles --------------------------------------------------------------------------
s = D.slide()
title(s, "デモで使う関節と、その役割", "ROBOT MODEL")
image(s, m("model_init_front.png"), 0.6, 1.5, 4.2, 4.2, tile=True)
rows = [["関節", "デモでの役割"],
        ["rarm/larm-wrist-r", "面を回す・キューブを回す（唯一動かし続ける軸）"],
        ["rarm/larm-gripper-r", "掴む 23° / 離す 55°（2指は同じ角度）"],
        ["肩・肘・手首ピッチ", "init-pose で固定。手首ロール軸をキューブ中心に通す"],
        ["head-neck-p", "15°下向きでキューブを正面に捉える"],
        ["脚", "立つだけ（動かさない）"]]
table(s, 5.1, 1.5, 7.7, rows, [2.6, 5.1], size=12, rowh=0.55, mono_col0=True)
bullets(s, 5.1, 5.0, 7.7, 1.9, [
  "腕の自由度は多いが、実際の操作は2本の手首ロールと指だけ：自由度を絞ることで精度と再現性を確保",
  "逆運動学は使わず、関節角を直接指定する（手で調整した init-pose ＋ 手首角度）",
], size=12.5, gap=6)

# 23 kxreus development -----------------------------------------------------------------------
s = D.slide()
title(s, "kxreus での発展", "FOLLOW-UP IN KXREUS")
rows = [["ファイル", "内容"],
        ["rubikcube.l", "robot.py の持ち替え計画を Euslisp に移植（仮想グリッパ vg-*、アクション列）。init-pose をRCB-4のROM動作90番に書き込み"],
        ["cubeSolver.l / config.l", "kxr_cube_solver の Euslisp 側をそのまま kxreus で利用"],
        ["d405rubikcube.l", "RealSense D405（カラー＋距離）で9マスを認識するPythonプロセスの結果を読み込み、解法へ渡す"],
        ["m5rubikcube.l", "M5StickV のカメラで色認識（I2C経由）し、PCなしの構成へ"],
        ["Steps.md", "実機での段階的テスト手順（グリッパ角度の較正 → 手首 → 1面ずつ → 通し）"],
        ["d405_camera_node.py", "新しい D405 を ROS で使うための代替カメラノード"]]
table(s, 0.6, 1.5, 12.1, rows, [3.0, 9.1], size=12, rowh=0.62, mono_col0=True)
tb(s, 0.6, 6.0, 12, 0.9, "PC＋ROS＋Python で実現されたデモを、Euslisp だけ、あるいはロボット上のマイコンだけで動かす方向へ展開している",
   size=12.5, color=MUTED, margin=0)

# 24 exercises --------------------------------------------------------------------------------
s = D.slide()
title(s, "考察と演習のヒント", "DISCUSSION")
cards = [("持ち替えの削減", "kociemba は手数最小を目指すが、ロボットのコストは持ち替え回数。手首の角度状態も含めたコストで解を選び直すと速くなる"),
         ("色認識の頑健化", "固定の基準色とホワイトバランスに依存。照明変化に対して基準色を自動更新する、面の中心色を基準にする、などの工夫"),
         ("失敗からの回復", "把持のずれは e キーで人が戻している。指の角度（トルク）や画像から把持の失敗を検出して自動で持ち直す"),
         ("モデルの活用", "現在は関節角の直接指定。kxreus のモデルと逆運動学で、キューブの大きさや機体差に合わせて init-pose を計算する")]
for i, (a, b) in enumerate(cards):
  x = 0.6 + (i % 2) * 6.15
  y = 1.6 + (i // 2) * 2.65
  rect(s, x, y, 5.95, 2.4, TILE)
  tb(s, x + 0.3, y + 0.2, 5.4, 0.45, [[{"t": a, "bold": True, "size": 17, "color": TEAL}]], margin=0)
  tb(s, x + 0.3, y + 0.8, 5.4, 1.5, b, size=13, margin=0, line=1.15)

# 25 references ---------------------------------------------------------------------------------
s = D.slide()
title(s, "参考", "REFERENCES")
bullets(s, 0.6, 1.6, 12.1, 5.3, [
  [{"t": "kxr_cube_solver", "bold": True}, {"t": "：github.com/fkanehiro/kxr_cube_solver（金広文男、2024年3月）"}],
  [{"t": "デモ動画", "bold": True}, {"t": "：youtu.be/CVYYmKJGDNQ"}],
  [{"t": "kociemba", "bold": True}, {"t": "：github.com/muodov/kociemba（Kociemba の二段階アルゴリズム）"}],
  [{"t": "qbr", "bold": True}, {"t": "：github.com/kkoomen/qbr（支配色抽出と CIEDE2000 色差の実装を流用）"}],
  [{"t": "指先の形状", "bold": True}, {"t": "：thingiverse.com/thing:3826740、Tinkercad「KXR fingertip」"}],
  [{"t": "kxreus", "bold": True}, {"t": "：github.com/inabajsk/kxreus（rcb4robotconfig.l の kxrl2l2a6h2m、rubikcube.l ほか）"}],
  [{"t": "本資料の動画・図の作り方", "bold": True}, {"t": "：docs/kxr_cube_solver/tools/（gen_cmds.py、sim.l、vis_fig.py）"}],
], size=13.5, gap=10)

D.save(OUT)
print("saved", OUT, D.page, "slides")
