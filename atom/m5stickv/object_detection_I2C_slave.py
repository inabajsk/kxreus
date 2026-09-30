import sensor, image, time, lcd, math, gc
from fpioa_manager import *
from machine import I2C
import KPU as kpu
from Maix import I2S, GPIO
import uos
from modules import ws2812
import audio

green_threshold   = (0,   80,  -70,   -10,   -0,   30)
yellow_threshold   = (0,   80,  -20,   20,   40,   90)
red_threshold   = (0,   80,  30,   90,   0,   60)

monitor_red = (25, 100, 17, 105, 8, 70)
monitor_green = (25, 100, -100, -18, 8, 77)
monitor_cyan = (25, 100, -67, -10, -66,-10)
monitor_magenta = (25, 100, 14, 127, -83, 4)

# ---- ルービックキューブ「発見」実験(段階1: 固定ROIを使わず、6色の塊が
# 密集している領域を探すことでキューブらしきものの有無・位置を推定する) ----
# しきい値は kxreus/rcb4interface.l の *m5stickv-cube-colors* (実機校正済みの
# Lab中心値)を元に、周辺トレランスを付けて作った初期値。実機で見え方を
# 見ながら調整すること(トレランスが狭すぎると検出漏れ、広すぎると誤検出)。
# 有効/無効はApp.__init__のself.ADDR_CUBE_DISCOVERY_ENABLE(0xFD)で
# 実行時にI2C経由でON/OFFできる(デフォルト有効)。

CUBE_COLOR_CENTROIDS = [
    ("white",  67,  -7, -17),
    ("yellow", 81, -24,  25),
    ("red",    37,  55,  49),
    ("orange", 59,  38,  50),
    ("blue",   35,  57, -90),
    ("green",  63, -49,  15),
]
_CUBE_TOL_L = 16
_CUBE_TOL_AB = 18
CUBE_COLOR_THRESHOLDS = [
    (name, (l - _CUBE_TOL_L, l + _CUBE_TOL_L,
            a - _CUBE_TOL_AB, a + _CUBE_TOL_AB,
            b - _CUBE_TOL_AB, b + _CUBE_TOL_AB))
    for (name, l, a, b) in CUBE_COLOR_CENTROIDS
]
_CUBE_COLOR_LAB = dict((name, (l, a, b)) for (name, l, a, b) in CUBE_COLOR_CENTROIDS)

# 肌色除外用。手で持っているとred/orange/yellowのしきい値に肌色が
# ひっかかりやすい(実機で確認)。単純な彩度足切りだと元々低彩度なwhite
# ステッカーまで巻き込むため、代わりに「そのブロブの実際の平均Labが、
# 引っかかった色の中心と肌色の中心のどちらに近いか」で相対判定する。
#
# 【重要】SKIN_LABは未校正の一般的な目安値だったため、実機で試したところ
# 肌が無い状態でも本物のステッカー(特にorange)まで誤って肌色判定されて
# 検出漏れが増える逆効果が出た(orangeの中心(59,38,50)がこの目安の肌色
# (60,15,20)と意外に近く、実測値が少しでも揺れると肌色寄りと誤判定
# されやすかったため)。校正前の暫定対策として、「肌色の方が明確に近い
# (_SKIN_MARGIN倍以上近い)場合のみ」除外するようにし、際どい場合は
# 誤検出(肌を拾う)より検出漏れ(本物を消す)を避ける方向に倒している。
# 実機の肌をカメラに映して得られる実測Lab値(下のmaybe_print_skin_debug
# 参照)でSKIN_LABを置き換えれば、マージン無しでも安全になるはず。
# 【実測値で更新済み、2026.8】このM5StickV実機・この照明下では、肌色は
# 想定と違って彩度がほぼ0の無彩色に近い値だった(L=55〜61, a=0〜1, b=3〜4、
# 3回の実測平均)。彩度の高いred/orange/yellowの中心値とは元々かなり
# 離れているため、誤って本物のステッカーを肌と判定するリスクは低い
# (白は元々低彩度なので依然やや近いが、マージンで安全側に倒している)。
SKIN_LAB = (57, 0, 3)
_SKIN_MARGIN = 0.8  # d_skin < d_color * _SKIN_MARGIN の時だけ肌と判定(小さいほど慎重)


def _lab_dist2(l1, a1, b1, l2, a2, b2):
    return (l1 - l2) ** 2 + (a1 - a2) ** 2 + (b1 - b2) ** 2


def _looks_like_skin(img, name, blob):
    st = img.get_statistics(roi=blob.rect())
    l, a, b = st.l_mean(), st.a_mean(), st.b_mean()
    cl, ca, cb = _CUBE_COLOR_LAB[name]
    d_color = _lab_dist2(l, a, b, cl, ca, cb)
    d_skin = _lab_dist2(l, a, b, SKIN_LAB[0], SKIN_LAB[1], SKIN_LAB[2])
    return d_skin < d_color * _SKIN_MARGIN


# 肌色校正用: SKIN_DEBUG_PRINT=Trueの間、画面全体の平均Lab値を約1秒おきに
# シリアルへ出力する。カメラに肌だけ(キューブ無し)を映した状態でこれを
# 読み、実測値でSKIN_LABを置き換えること。
SKIN_DEBUG_PRINT = True
_skin_debug_counter = [0]


def maybe_print_skin_debug(img):
    _skin_debug_counter[0] += 1
    if _skin_debug_counter[0] % 30 == 0:
        st = img.get_statistics()
        print("[skin-debug] whole-frame avg Lab = (%d, %d, %d)" %
              (st.l_mean(), st.a_mean(), st.b_mean()))

# ステッカー1個として妥当なブロブ面積の範囲(QVGA=320x240前提、実機で要調整)。
CUBE_BLOB_MIN_AREA = 30
CUBE_BLOB_MAX_AREA = 3000
# 「密集している」と判定するブロブ間の中心距離しきい値(px)。
CUBE_CLUSTER_GAP = 45
# 密集クラスタをキューブ候補とみなすために必要な最低ブロブ数
# (1面9個は隠れ指等で欠けることもあるので、6個以上を候補の目安とする)。
CUBE_CLUSTER_MIN_BLOBS = 6


def build_cube_color_thresholds(tol_l, tol_ab):
    return [
        (name, (l - tol_l, l + tol_l, a - tol_ab, a + tol_ab, b - tol_ab, b + tol_ab))
        for (name, l, a, b) in CUBE_COLOR_CENTROIDS
    ]


def _cube_fill_ratio(bbox, blobs):
    bbox_area = float(bbox[2] * bbox[3])
    if bbox_area <= 0:
        return 0.0
    blob_area = sum(b.area() for _, b in blobs)
    return blob_area / bbox_area


# 段階1改良: 見つかっている面(色数c・ブロブ数n)が少ない機体・照明条件が
# あったため、最初は狭いLab許容幅で試し、色数が目標に届かなければ段階的に
# 許容幅を広げて再検出する。ただし単純に広げるだけでは背景の色まで拾って
# しまうため、「bbox内でブロブが実際に占めている面積の割合(fill_ratio)」も
# 併せて見て、広げた結果が本当にキューブの格子模様らしい(隙間なく色が
# 詰まっている)かを確認してから採用する(実機で色数が少なかった機体への
# 対策、2026.8)。
CUBE_ADAPTIVE_TOL_STEPS = [(16, 18), (22, 24), (28, 30), (34, 36)]
CUBE_ADAPTIVE_TARGET_COLORS = 4
CUBE_ADAPTIVE_MIN_FILL_RATIO = 0.25


def find_cube_candidate_adaptive(img):
    """許容幅を段階的に広げながらfind_cube_candidateを試し、色数
    (distinct colors)がCUBE_ADAPTIVE_TARGET_COLORS以上かつbbox内の
    ブロブ占有率がCUBE_ADAPTIVE_MIN_FILL_RATIO以上になった時点の結果を
    採用する。最後まで条件を満たさなければ、最後に試した(最も広い
    許容幅での)結果をそのまま返す(Noneの可能性もある)。"""
    result = None
    for tol_l, tol_ab in CUBE_ADAPTIVE_TOL_STEPS:
        colors = build_cube_color_thresholds(tol_l, tol_ab)
        result = find_cube_candidate(img, colors=colors)
        if result is None:
            continue
        bbox, count, blobs = result
        ndist = len(set(name for name, b in blobs))
        fill = _cube_fill_ratio(bbox, blobs)
        if ndist >= CUBE_ADAPTIVE_TARGET_COLORS and fill >= CUBE_ADAPTIVE_MIN_FILL_RATIO:
            return result
    return result

# 段階2b: find_rects()(AprilTagと同じ矩形検出アルゴリズム)で、色のブロブ
# クラスタリングとは別に、黒い枠で囲まれた矩形(面の外枠や個々のステッカー
# の境界)を直接探す。thresholdは公式サンプルの初期値をそのまま使っている
# ので実機で要調整(値を上げると検出が厳しくなり誤検出が減るが検出漏れも
# 増える)。
CUBE_RECT_THRESHOLD = 8000


def find_cube_candidate(img, colors=CUBE_COLOR_THRESHOLDS,
                         min_area=CUBE_BLOB_MIN_AREA, max_area=CUBE_BLOB_MAX_AREA,
                         gap=CUBE_CLUSTER_GAP, min_blobs=CUBE_CLUSTER_MIN_BLOBS):
    """6色それぞれでfind_blobsし、サイズが妥当なブロブだけを集めた上で、
    互いにgap px以内で繋がっているブロブ同士を同じクラスタにまとめる
    (Union-Find)。最大のクラスタがmin_blobs個以上ならキューブ候補とみなし、
    (bbox, ブロブ数, ブロブ一覧)を返す。見つからなければNone。
    """
    # 【重要】適応的な許容幅の広い段階(CUBE_ADAPTIVE_TOL_STEPS参照)では
    # 背景まで色が一致してブロブ数が急増することがあり、(1) ブロブごとの
    # 肌色判定(_looks_like_skin、img.get_statisticsを呼ぶので軽くない)と
    # (2) 後段のクラスタリング(ブロブ数の2乗に比例するUnion-Find)の両方が
    # 極端に重くなって実機で「ハングしたように見えるほど遅い」フレームに
    # なることを確認した(2026.8)。ブロブ総数に上限を設け、超えた場合は
    # 「そもそも許容幅が広すぎて背景まで拾っている(=キューブ候補として
    # 信用できない)」とみなして即座に諦める(Noneを返す)ことで、
    # 重い処理に入る前に打ち切る。上限値27はルービックキューブが最大でも
    # 3面(3x9=27マス)しか同時に見えないという物理的な上限そのものだが、
    # 反射等で1マスが2ブロブに分裂することもあるため少し余裕を持たせる。
    MAX_TOTAL_BLOBS = 32
    all_blobs = []
    too_many = False
    for name, th in colors:
        for b in img.find_blobs([th], area_threshold=min_area, pixels_threshold=min_area, merge=False):
            if b.area() <= max_area and not _looks_like_skin(img, name, b):
                all_blobs.append((name, b))
                if len(all_blobs) > MAX_TOTAL_BLOBS:
                    too_many = True
                    break
        if too_many:
            break
    if too_many:
        return None

    n = len(all_blobs)
    if n < min_blobs:
        return None

    parent = list(range(n))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    def union(i, j):
        pi, pj = find(i), find(j)
        if pi != pj:
            parent[pi] = pj

    for i in range(n):
        xi, yi = all_blobs[i][1].cx(), all_blobs[i][1].cy()
        for j in range(i + 1, n):
            xj, yj = all_blobs[j][1].cx(), all_blobs[j][1].cy()
            if ((xi - xj) ** 2 + (yi - yj) ** 2) ** 0.5 < gap:
                union(i, j)

    groups = {}
    for i in range(n):
        groups.setdefault(find(i), []).append(all_blobs[i])

    best = max(groups.values(), key=len)
    if len(best) < min_blobs:
        return None

    xs0 = [b.x() for _, b in best]
    ys0 = [b.y() for _, b in best]
    xs1 = [b.x() + b.w() for _, b in best]
    ys1 = [b.y() + b.h() for _, b in best]
    bbox = (min(xs0), min(ys0), max(xs1) - min(xs0), max(ys1) - min(ys0))
    return (bbox, len(best), best)


# ---- 段階2: 密集ブロブ群を面ごとに分ける(最大3面) ----
# 台の上のキューブを普通に(角から)見ると、見えている2〜3面はそれぞれ
# 画面上で別々の領域にまとまって見えるはず、という前提で、ブロブの
# 画面上の位置だけを使った簡易k-means(k=3)でグループ分けする。
# 透視変換や輪郭検出はしない(このプロジェクトの一貫した簡易主義)。
FACE_GROUP_COLORS = [(0, 255, 255), (255, 0, 255), (255, 255, 0)]  # cyan/magenta/yellow


def group_blobs_into_faces(blobs, k=3, iters=8):
    """blobs: [(name, blobオブジェクト), ...]。ブロブの中心座標だけを使い、
    最大k個のグループにクラスタリングする(blobsの要素数がk未満なら
    それぞれ単独グループにする)。グループごとのインデックスリストを返す。
    """
    n = len(blobs)
    k = min(k, n)
    if k <= 1:
        return [list(range(n))]

    pts = [(b.cx(), b.cy()) for _, b in blobs]
    order = sorted(range(n), key=lambda i: pts[i][0])
    step = max(1, n // k)
    centroids = [pts[order[min(i * step, n - 1)]] for i in range(k)]

    assign = [0] * n
    for _ in range(iters):
        changed = False
        for i in range(n):
            best_j, best_d = 0, None
            for j in range(k):
                dx = pts[i][0] - centroids[j][0]
                dy = pts[i][1] - centroids[j][1]
                d = dx * dx + dy * dy
                if best_d is None or d < best_d:
                    best_d, best_j = d, j
            if assign[i] != best_j:
                assign[i] = best_j
                changed = True
        for j in range(k):
            members = [pts[i] for i in range(n) if assign[i] == j]
            if members:
                cx = sum(p[0] for p in members) / len(members)
                cy = sum(p[1] for p in members) / len(members)
                centroids[j] = (cx, cy)
        if not changed:
            break

    groups = [[] for _ in range(k)]
    for i in range(n):
        groups[assign[i]].append(i)
    return [g for g in groups if g]


# ---- 段階4: EusLisp側でのステレオ姿勢推定用に、外接bboxと簡易ヨー角を出す ----
# 個々のステッカーの対応点マッチング(左右カメラでどのステッカーが同じか)は
# まだ実装していないため、まずは:
#   - bbox(軸並行)の4隅 -> 位置のステレオ三角測量に使う(回転の情報は無い)
#   - ブロブ群の主軸角度(2次モーメントの固有ベクトル、単眼・簡易) -> 大まかな
#     ヨー角の手がかりとして片目分だけ送る(ステレオでの裏付けはまだ無い)
def cube_principal_axis_deg(blobs):
    pts = [(b.cx(), b.cy()) for _, b in blobs]
    n = len(pts)
    if n < 2:
        return 0.0
    mx = sum(p[0] for p in pts) / n
    my = sum(p[1] for p in pts) / n
    sxx = sum((p[0] - mx) ** 2 for p in pts)
    syy = sum((p[1] - my) ** 2 for p in pts)
    sxy = sum((p[0] - mx) * (p[1] - my) for p in pts)
    theta = 0.5 * math.atan2(2 * sxy, sxx - syy)
    return math.degrees(theta)  # -90〜90度程度(軸の向きなので180度周期の曖昧さがある)


def draw_cube_candidate(img, result=None):
    """resultが与えられればそれを描画する(呼び出し側が既に
    find_cube_candidate_adaptiveを実行済みの場合、二重計算を避けるため
    こちらを使う)。与えられなければこの場でfind_cube_candidate_adaptiveを
    実行する(単体テスト用)。見つかった各ブロブ(面ごとに色分け)と
    クラスタ全体の外接矩形をimgに描き込む(実機での見え方確認・
    しきい値調整用)。"""
    if result is None:
        result = find_cube_candidate_adaptive(img)
    if result is None:
        return
    bbox, count, blobs = result
    face_groups = group_blobs_into_faces(blobs)
    for gi, idxs in enumerate(face_groups):
        color = FACE_GROUP_COLORS[gi % len(FACE_GROUP_COLORS)]
        for i in idxs:
            _, b = blobs[i]
            img.draw_rectangle(b.rect(), color=color, thickness=1)
    img.draw_rectangle(bbox, color=(255, 0, 0), thickness=2)
    ndist = len(set(name for name, b in blobs))
    # 発見場所(bboxの上)に出すと画面をはみ出しやすく分かりにくいため、
    # 画面下端・左端の固定位置に表示する(QVGA=320x240前提)。
    img.draw_string(0, 240 - 44, "n=%d c=%d" % (count, ndist), color=(255, 0, 0), scale=4)

    # 段階2b: 色クラスタで絞ったbbox内だけでfind_rects()を試す
    # (AprilTagと同じ矩形検出。面の外枠や個々のステッカーの黒枠が
    # きれいな矩形として見つかるか実機で確認するための可視化)。
    rect_roi = (max(0, bbox[0] - 5), max(0, bbox[1] - 5), bbox[2] + 10, bbox[3] + 10)
    try:
        rects = img.find_rects(threshold=CUBE_RECT_THRESHOLD, roi=rect_roi)
    except Exception:
        rects = []
    for r in rects:
        for p in r.corners():
            img.draw_circle(p[0], p[1], 3, color=(0, 255, 0), fill=True)
    img.draw_string(bbox[0], bbox[1] + bbox[3] + 4, "rects=%d" % len(rects), color=(0, 255, 0), scale=2)

    # 段階3(格子線のHough変換検出)は実機でK210の処理能力を超えて
    # ハングしたため一旦削除。find_line_segments()はこのROIサイズでは
    # 重すぎる可能性が高く、ROIをステッカー1個分程度まで絞る、
    # x_stride/y_strideを大きくする等の軽量化が必要(次回再挑戦時に検討)。

class App:
    def __init__(self):
        I2C_INDEX = 0x24
        print("I2C ID ", hex(I2C_INDEX))

        dirs = uos.listdir()
        n_img_dir = 0
        for d in dirs:
            if 'img' in d:
                n_img_dir += 1

        self.save_dir_name = '/sd/' + 'img' + str(n_img_dir)
        uos.mkdir(self.save_dir_name)

        camera_calib_file_path = '/sd/camera_calib.txt'
        try:
            with open(camera_calib_file_path) as f:
                s = f.readline()
                ss = s.split()
                print(ss)
                self.fx = float(ss[0])/2
                self.fy = float(ss[1])/2
                self.cx = float(ss[2])/2
                self.cy = float(ss[3])/2
        except OSError:
            self.fx = 170
            self.fy = 170
            self.cx = 80
            self.cy = 60

        print(self.fx, self.fy, self.cx, self.cy)

        fm.register(35, fm.fpioa.I2C0_SDA, force=True)
        fm.register(34, fm.fpioa.I2C0_SCLK, force=True)
        fm.register(board_info.BUTTON_B, fm.fpioa.GPIO2) # Aボタンを使う設定
        self.but_b=GPIO(GPIO.GPIO2, GPIO.IN, GPIO.PULL_UP)    # Aボタンのプルアップ設定
        self.prev_but_b_state = 1

        fm.register(board_info.LED_W, fm.fpioa.GPIO3) #LED white
        self.led_w = GPIO(GPIO.GPIO3, GPIO.OUT)
        self.led_w.value(1) #off

        # ---- スピーカー(発話。m5stickv_speak_demo/boot.pyで実機検証済みの
        # 設定をそのまま使う。決め手はDEVICE_1とI2S1_OUT_D1(D0ではない)) ----
        fm.register(board_info.SPK_SD, fm.fpioa.GPIO0, force=True)
        self.spk_sd = GPIO(GPIO.GPIO0, GPIO.OUT)
        self.spk_sd.value(1)
        fm.register(board_info.SPK_DIN, fm.fpioa.I2S1_OUT_D1, force=True)
        fm.register(board_info.SPK_BCLK, fm.fpioa.I2S1_SCLK, force=True)
        fm.register(board_info.SPK_LRCLK, fm.fpioa.I2S1_WS, force=True)
        self.wav_dev = I2S(I2S.DEVICE_1)
        self.cube_speak_state = {}
        self.face_speak_state = {}
        self.apriltag_speak_state = {}
        self._gc_frame_counter = 0

        # 【重要】on_receive/on_transmit/on_eventはI2C(...)を生成した瞬間から
        # 割り込みで呼ばれうるため、それらが参照するself.state等は必ず
        # I2C(...)の生成より前に初期化しておくこと。以前はこの初期化が
        # I2C(...)の後にあり、AtomS3側からのI2Cアクセスが初期化完了前に
        # 到達すると`AttributeError: 'App' object has no attribute 'state'`で
        # 起動時にクラッシュすることがあった(カメラが認識できず起動が
        # ここまで到達しなかった間は表面化していなかった不具合)。
        self.INITIAL_STATE = 0
        self.ADDRESS_RECEIVE_COMPLETE_STATE = 1
        self.WRITE_STATE = 2
        self.READ_STATE = 3

        self.state = self.INITIAL_STATE
        self.address = 0x00
        self.register_count = 0
        self.i2c_register = [0]*256 #64 byte register 0: object num 1: 1x 2: 1y 3: 1w 4: 1h 5: 2x 6: 2y

        self.i2c = I2C(I2C.I2C0, mode = I2C.MODE_SLAVE, scl = 34, sda = 35, addr = I2C_INDEX, addr_size = 7, on_receive = self.on_receive, on_transmit = self.on_transmit, on_event = self.on_event)
        self.i2c_lcd = I2C(I2C.I2C1, freq=400000, scl=28, sda=29)

        is_m5unitv = True
        devices = self.i2c_lcd.scan()
        if devices:
            is_m5unitv = False
        if is_m5unitv:
            print("device: unitv")
        else:
            print("device: stickv")

        self.ADDR_CTRL_REG = 0x00 #1byte
        self.ADDR_OBJ_DATA_LEN = 0x01 #1byte
        self.ADDR_OBJ_DATA = 0x02 #253byte max(0xFFは下のADDR_SPEAK_CMD用に予約)
        # ホスト(RCB4拡張命令経由)からここへ(1始まりの)発話クリップ番号を
        # 書き込むと、その回のメインループでそのクリップを再生し、消費後に
        # 0へ戻す(0=何もしない)。ADDR_OBJ_DATAの254byte領域は毎フレーム
        # 検出結果で上書きされるため、そこに重ねずレジスタ空間の末尾1byteを
        # 専用に確保している。
        self.ADDR_SPEAK_CMD = 0xFF
        # bit0=キューブ発見の発話, bit1=顔発見(こんにちは)の発話,
        # bit2=AprilTag発見の発話。RCB4拡張命令でホストからON/OFFできる
        # (デフォルトは3つとも有効=0x07)。
        self.ADDR_SPEAK_ENABLE = 0xFE
        self.i2c_register[self.ADDR_SPEAK_ENABLE] = 0x07
        # ルービックキューブ「発見」処理(色ブロブ検出・bbox計算・LCDの
        # n=/c=表示・見つかった時の発話)をまとめてON/OFFするマスタースイッチ。
        # 0x00(制御レジスタ)は8bit全部埋まっている(nn_en/apriltag_en/
        # red_en/green_en/april3d_en/cube_face_en/LED/画像保存)ため、
        # 空いている別のレジスタ番地を使う。デフォルトは有効(1)。
        self.ADDR_CUBE_DISCOVERY_ENABLE = 0xFD
        self.i2c_register[self.ADDR_CUBE_DISCOVERY_ENABLE] = 1

        self.TYPE_NN = 0
        self.TYPE_APRILTAG = 1
        self.TYPE_RED = 2
        self.TYPE_GREEN = 3
        self.TYPE_APRIL3D = 4
        self.TYPE_APRIL3D_COLOR = 5
        self.TYPE_CUBE_FACE = 6
        self.TYPE_CUBE_BBOX = 7
        #256 byte register
        # address 0: control registor
        # 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0
        # object type: Apriltag 3D and display color | object type: AprilTag 3D | object type : Green | object type : Red | object type : AprilTag | object type : NN | led | oneshot_record
        # NOTE(2026.8, kxr_cube_solver参考のルービックキューブ面認識機能を追加):
        # bit7の"Apriltag 3D and display color"は本プロジェクトでは未使用のため、
        # cube_face_en(ルービックキューブ面の3x3グリッド9箇所の平均色を返す)
        # として再定義する。

        # address 1: object data len
        # address 2: object data

        # ルービックキューブ面の3x3グリッドROI(kxr_cube_solverのcomputeROIs相当)。
        # ロボットが両手でキューブを両目の中央で構える都合上、キューブ面はカメラに
        # 対して45度回転して映る(3x3グリッドが上から1,2,3,2,1個の菱形/市松模様
        # 配置に見える)。CUBE_ROI_ROTATIONでこれを補正する(kxr_cube_solverの
        # roi_rotation=math.pi/4と同じ考え方)。またキューブは常に両目の中央に
        # あるため、左目(0x24)からは画面右寄り、右目(0x25)からは画面左寄りに見える
        # (実機確認、2026.8)。CENTER_X/Yはこれを踏まえた目安値で、実機で
        # M5StickVをキューブに対して固定した後、現物合わせでさらに調整すること
        # (kxr_cube_solverのREADMEと同じ手動キャリブレーション)。
        self.CUBE_ROI_SIZE = 24
        # 実機確認(2026.8)を踏まえて何度か調整済み: GAP=68(対角オフセット
        # gap*sqrt(2)≈96px)でも外側の点がキューブ面からはみ出す(特に左端が
        # 隙間/影にかかる)ため、各点を中心の四角に向けてROIサイズ1個ぶん
        # (24px)近づくよう、オフセットを72px相当(GAP=51)に縮小した。
        self.CUBE_ROI_GAP = 51
        self.CUBE_ROI_ROTATION = math.pi / 4
        # 右目(0x25)は左目(0x24)に対して機体取り付けが180度回転しており、
        # カメラ座標系のx,yがそれぞれ逆方向を向く(実機確認、2026.8)。菱形
        # 自体は180度回転対称な形なのでCUBE_ROI_ROTATIONは共通のままでよいが、
        # 中心位置はミラーする必要がある。
        if I2C_INDEX == 0x24:
            # 左目: 右目からも同じキューブが見えるよう、実機確認(2026.8)で
            # さらにROIサイズ1個ぶん(24px)右へ移動(200→224)。
            self.CUBE_ROI_CENTER_X = 224
        else:
            # 右目: x軸もミラーされているため、画面上で左へ動かすには
            # 生ピクセル座標では逆に+方向(右)へ動かす必要がある(実機確認、2026.8)。
            # 176にすると画面上では右へ動いてしまった(逆方向)ため224に戻し、
            # さらにもう一辺分(24px)左へ動かすために248にする。
            self.CUBE_ROI_CENTER_X = 248
        self.CUBE_ROI_CENTER_Y = 120
        self.cube_rois = self.computeCubeROIs()

        # 認識結果スウォッチ表示用。色の分類自体は本来ホスト側
        # (kxreus, *m5stickv-cube-colors*)で行うが、実機で見て確認しやすい
        # よう、キャリブレーション値のコピーをここにも持たせて簡易分類する
        # (デバッグ表示専用。キャリブレーションをやり直したらここも
        # 手動で合わせること。ホスト側の判定には影響しない)。
        # 表示位置は左目(0x24)は画面左上、右目(0x25)は画面右上になるよう
        # 意図しているが、右目は180度回転の影響でx,yとも反転して表示される
        # ため、コード上はその逆(左・下寄り)の値を使う(実機確認、2026.8)。
        self.CUBE_SWATCH_SIZE = 24
        self.CUBE_SWATCH_FLIP_Y = False
        if I2C_INDEX == 0x24:
            self.CUBE_SWATCH_BASE_X = 0
            self.CUBE_SWATCH_BASE_Y = 0
        else:
            # 右目は実機確認(2026.8)で、行順(FLIP_Y)を反転すると実物と同じ
            # 色配置になる。またブロック全体は左下→右上寄りに見えていたため
            # BASE_Yを画面下端側の値にして反転後に画面上端へ来るようにする。
            self.CUBE_SWATCH_BASE_X = 0
            self.CUBE_SWATCH_BASE_Y = 240 - 3 * self.CUBE_SWATCH_SIZE
            self.CUBE_SWATCH_FLIP_Y = False

        # 発話の冒頭に「左目で」/「右目で」を付ける(0x24=左目, 0x25=右目、
        # rcb4interface.lの:draw-m5stickv-apriltag-cube等と同じ慣例)。
        if I2C_INDEX == 0x24:
            self.EYE_PREFIX_CLIP = "/sd/eye_left_44100.wav"
        else:
            self.EYE_PREFIX_CLIP = "/sd/eye_right_44100.wav"

        self.CUBE_COLOR_PALETTE = [
            ('white',  67,  -7, -17, (255, 255, 255)),
            ('yellow', 81, -24,  25, (255, 255,   0)),
            ('red',    37,  55,  49, (255,   0,   0)),
            ('orange', 59,  38,  50, (255, 140,   0)),
            ('blue',   35,  57, -90, (  0,   0, 255)),
            ('green',  63, -49,  15, (  0, 200,   0)),
        ]

        #self.i2c_register[self.ADDR_CTRL_REG] |= (1 << 2) | (1 << 3) | (1 << 4) | (1 << 5) # enable face detection
        #self.i2c_register[self.ADDR_CTRL_REG] |= (1 << 7)
        self.DATA_MAX_SIZE = 252  # 0xFE(ADDR_SPEAK_ENABLE)/0xFF(ADDR_SPEAK_CMD)を上書きしないよう2byte減らした
        self.QVGA_SCALE = 200
        self.QQVGA_SCALE = 400

        self.MONITOR_UNKNOWN = 0
        self.MONITOR_RED = 1
        self.MONITOR_GREEN = 2
        self.MONITOR_CYAN = 3
        self.MONITOR_MAGENTA = 4

        self.lcd_on = False
        if not is_m5unitv:
            self.lcd_on = True
            lcd.init(freq=15000000)
            lcd.rotation(2)

        sensor.reset()                      # Reset and initialize the sensor. It will
                                    ## run automatically, call sensor.run(0) to stop
        sensor.set_pixformat(sensor.RGB565) # Set pixel format to RGB565 (or GRAYSCALE)
        sensor.set_framesize(sensor.QVGA)   # Set frame size to QVGA (320x240)
        sensor.skip_frames(time = 2000)     # Wait for settings take effect.
        sensor.run(1)
        if is_m5unitv:
            sensor.set_vflip(1)

        self.task = kpu.load(0x300000) # Load Model File from Flash
        self.anchor = (1.889, 2.5245, 2.9465, 3.94056, 3.99987, 5.3658, 5.155437, 6.92275, 6.718375, 9.01025)
        # Anchor data is for bbox, extracted from the training sets.
        kpu.init_yolo2(self.task, 0.5, 0.3, 5, self.anchor)

        self.fps_clock = time.clock()

        if is_m5unitv:
            self.class_ws2812 = ws2812(8,100)
            self.class_ws2812.set_led(0,(0,0,128))
            self.class_ws2812.display()
            time.sleep_ms(300)
            self.class_ws2812.set_led(0,(0,0,0))
            self.class_ws2812.display()

    # ルービックキューブ面の3x3グリッドROI座標を計算する
    # (kxr_cube_solver/scripts/vision.pyのcomputeROI相当)。CUBE_ROI_ROTATION分
    # グリッドを回転させることで、45度傾いたキューブ面に対して菱形/市松模様
    # (上から1,2,3,2,1個)のROI配置になる。
    def computeCubeROIs(self):
        rois = []
        size = self.CUBE_ROI_SIZE
        gap = self.CUBE_ROI_GAP
        cx = self.CUBE_ROI_CENTER_X
        cy = self.CUBE_ROI_CENTER_Y
        cos_r = math.cos(self.CUBE_ROI_ROTATION)
        sin_r = math.sin(self.CUBE_ROI_ROTATION)
        for row in range(3):
            for col in range(3):
                dx = (col - 1) * gap
                dy = (row - 1) * gap
                rx = dx * cos_r - dy * sin_r
                ry = dx * sin_r + dy * cos_r
                x = int(cx + rx - size // 2)
                y = int(cy + ry - size // 2)
                rois.append((x, y, size, size))
        return rois

    # 画面左上スウォッチ表示用の簡易分類(ユークリッド距離の最近傍)。
    # ホスト側:m5stickv-classify-cube-colorと同じ考え方。
    def classifyCubeColorRGB(self, l, a, b):
        best_rgb = (128, 128, 128)
        best_d = None
        for (name, cl, ca, cb, rgb) in self.CUBE_COLOR_PALETTE:
            d = (l - cl) * (l - cl) + (a - ca) * (a - ca) + (b - cb) * (b - cb)
            if best_d is None or d < best_d:
                best_d = d
                best_rgb = rgb
        return best_rgb

    # 発話クリップ(SDカード上のWAV、44100Hzでの再生を実機検証済み)。
    # 番号(RCB4拡張命令のADDR_SPEAK_CMDで指定する1始まりの番号-1に対応)。
    # 追加したい場合はWAVをアップロードしてこのリストに足すだけでよい。
    SPEAK_CLIPS = [
        "/sd/cube_speak0_44100.wav",  # 0: ルービックキューブが見つかりました
        "/sd/hello_44100.wav",        # 1: こんにちは
    ]

    # AprilTag番号読み上げ用の数字クリップ(1〜9、十、百の11個の断片を
    # 組み合わせて1〜100を発話する。100個個別に録音するより遥かに少ない
    # ファイル数で済む、日本語の数の数え方の規則をそのまま使う方式)。
    DIGIT_CLIPS = {
        1: "/sd/d1_44100.wav", 2: "/sd/d2_44100.wav", 3: "/sd/d3_44100.wav",
        4: "/sd/d4_44100.wav", 5: "/sd/d5_44100.wav", 6: "/sd/d6_44100.wav",
        7: "/sd/d7_44100.wav", 8: "/sd/d8_44100.wav", 9: "/sd/d9_44100.wav",
    }
    JUU_CLIP = "/sd/juu_44100.wav"
    HYAKU_CLIP = "/sd/hyaku_44100.wav"
    APRILTAG_FOUND_CLIP = "/sd/apriltag_found_44100.wav"
    BAN_DESU_CLIP = "/sd/ban_desu_44100.wav"

    def _play_clip_path(self, path):
        # 【重要】1回の発話(例: AprilTag番号の読み上げ)で複数個の
        # audio.Audioオブジェクトを連続生成することがあり、これを長時間
        # (一晩など)動かし続けると、内部のオーディオ用リソースが徐々に
        # 解放しきれずハングする不具合を実機で確認した(2026.8)。finish()
        # 後に明示的にplayerへの参照を切り、gc.collect()も呼んで、
        # できるだけ確実にリソースが解放されるようにする。
        player = None
        try:
            player = audio.Audio(path=path)
            player.volume(100)
            wav_info = player.play_process(self.wav_dev)
            self.wav_dev.channel_config(self.wav_dev.CHANNEL_1, I2S.TRANSMITTER,
                                         resolution=I2S.RESOLUTION_16_BIT,
                                         align_mode=I2S.STANDARD_MODE)
            self.wav_dev.set_sample_rate(wav_info[1])
            while True:
                ret = player.play()
                if ret is None or ret == 0:
                    break
            player.finish()
        except Exception as e:
            print("_play_clip_path error:", path, e)
        finally:
            player = None
            gc.collect()

    def play_speak_clip(self, idx):
        if idx < 0 or idx >= len(self.SPEAK_CLIPS):
            print("play_speak_clip: index out of range", idx)
            return
        self._play_clip_path(self.EYE_PREFIX_CLIP)  # 「左目で」/「右目で」
        self._play_clip_path(self.SPEAK_CLIPS[idx])

    # 1〜100を日本語の数え方の規則(一〜九、十、百の組み合わせ)で発話する。
    def speak_number(self, n):
        if n <= 0 or n > 100:
            print("speak_number: out of range", n)
            return
        if n == 100:
            self._play_clip_path(self.HYAKU_CLIP)
            return
        tens = n // 10
        ones = n % 10
        if tens >= 2:
            self._play_clip_path(self.DIGIT_CLIPS[tens])
            self._play_clip_path(self.JUU_CLIP)
        elif tens == 1:
            self._play_clip_path(self.JUU_CLIP)
        if ones >= 1:
            self._play_clip_path(self.DIGIT_CLIPS[ones])

    # 「エイプリルタグ見つけました。(番号)番です。」と発話する
    # (番号部分はspeak_numberで動的に組み立てる)。
    def speak_apriltag_found(self, tag_id):
        self._play_clip_path(self.EYE_PREFIX_CLIP)  # 「左目で」/「右目で」
        self._play_clip_path(self.APRILTAG_FOUND_CLIP)
        self.speak_number(tag_id)
        self._play_clip_path(self.BAN_DESU_CLIP)

    # ---- 発話の時間・空間デバウンス ----
    # 「ある程度の時間・空間幅の間、安定して検出できていたら発話し、場所が
    # 変わる(または対象のIDが変わる)まで繰り返さない」という要件のための
    # 汎用状態機械。stateは呼び出し側がdictを1つ持ち回ることで、キューブ・
    # 顔・AprilTagそれぞれ独立した状態を管理する。
    # 【調整】当初SPATIAL_TOL=40, STABLE_MS=1000だったが、実機で「検出は
    # できているのに発話されないことが多い」ことが確認された。原因は、
    # 色ブロブベースのbbox中心が照明・手ブレ等のノイズだけで毎フレーム
    # 数十px単位で揺れ動き、「同じ場所」判定(旧40px)を安定して満たせず、
    # 1秒経過する前にタイマーがリセットされ続けていたため(実機確認、
    # 2026.8)。許容幅を広げ安定時間を短縮した上で、_speak_debounce_update
    # 側でも候補位置を現在地へ緩やかに追従させ(急な移動だけリセットする)、
    # 検出ノイズへの耐性を上げている。
    SPEAK_SPATIAL_TOL = 70  # px。これ以上動いたら「別の場所」とみなす
    SPEAK_STABLE_MS = 600   # この時間以上同じ場所で安定して見えたら発話する

    def _speak_pos_same(self, p1, i1, p2, i2):
        if i1 != i2:
            return False
        if p1 is None or p2 is None:
            return False
        dx = p1[0] - p2[0]
        dy = p1[1] - p2[1]
        return (dx * dx + dy * dy) ** 0.5 < self.SPEAK_SPATIAL_TOL

    def _speak_debounce_update(self, state, detected, pos, ident=None):
        if not detected:
            # 短時間の検出漏れでは状態をリセットしない(ノイズ耐性のため)。
            return False
        if state.get("announced_pos") is not None and \
           self._speak_pos_same(pos, ident, state["announced_pos"], state.get("announced_id")):
            state["candidate_pos"] = None
            state["candidate_start_ms"] = None
            return False
        if state.get("candidate_pos") is None or \
           not self._speak_pos_same(pos, ident, state["candidate_pos"], state.get("candidate_id")):
            state["candidate_pos"] = pos
            state["candidate_id"] = ident
            state["candidate_start_ms"] = time.ticks_ms()
            return False
        # 許容範囲内の細かいドリフトは、候補位置(アンカー)を現在地へ緩やかに
        # 追従させることで吸収する(検出ノイズで毎回タイマーが実質リセット
        # されるのを防ぐ。大きく動いた場合は上のnot _speak_pos_sameで
        # そもそもリセットされるので、これは小さいドリフトの吸収専用)。
        acx, acy = state["candidate_pos"]
        pcx, pcy = pos
        state["candidate_pos"] = (acx * 0.7 + pcx * 0.3, acy * 0.7 + pcy * 0.3)
        elapsed = time.ticks_diff(time.ticks_ms(), state["candidate_start_ms"])
        if elapsed >= self.SPEAK_STABLE_MS:
            state["announced_pos"] = pos
            state["announced_id"] = ident
            state["candidate_pos"] = None
            state["candidate_start_ms"] = None
            return True
        return False

    def toggle_lcd_backlight(self):
        if self.lcd_on:
            self.i2c_lcd.writeto_mem(0x34, 0x91,b'\x70')
            self.lcd_on = False
        else:
            self.i2c_lcd.writeto_mem(0x34, 0x91,b'\xf0')
            self.lcd_on = True

    def on_receive(self, data):
        #this print is necessary. you can replace it with time.sleep_us(10)
        print ("on_receive:", data, self.state)

        if self.state == self.INITIAL_STATE:
            self.state = self.ADDRESS_RECEIVE_COMPLETE_STATE
        elif self.state == self.ADDRESS_RECEIVE_COMPLETE_STATE:
            self.state = self.WRITE_STATE
        elif self.state == self.WRITE_STATE:
            self.state = self.WRITE_STATE
        elif self.state == self.READ_STATE:
            self.state = self.INITIAL_STATE

        if self.state != self.WRITE_STATE: #set address
            self.address = data
            self.register_count = 0
        else: #write data
            self.i2c_register[self.address + self.register_count] = data
            self.register_count += 1

    def on_transmit(self):
        print("on transmit", self.state)

        if self.state == self.INITIAL_STATE:
            self.state = self.INITIAL_STATE
        elif self.state == self.ADDRESS_RECEIVE_COMPLETE_STATE:
            self.state = self.READ_STATE
        elif self.state == self.WRITE_STATE:
            self.state = self.INITIAL_STATE
        elif self.state == self.READ_STATE:
            self.state = self.READ_STATE

        if self.state == self.READ_STATE:
            ret = self.i2c_register[self.address + self.register_count]
            #you shouldn't comment in below. there will be a bug.
            #print("address ", address)
            #print("register_count ", register_count)
            #print ("ret ", ret)
            self.register_count += 1
            return ret
        else:
            return 255

    def on_event(self, event):
        if event == I2C.I2C_EV_START:
            print("on_event START", self.state)
        elif event == I2C.I2C_EV_RESTART:
            print("on_event RESTART", self.state)
        elif event ==  I2C.I2C_EV_STOP:
            print("on_event STOP", self.state)

        if event ==  I2C.I2C_EV_START:
            self.state = self.INITIAL_STATE
        elif event == I2C.I2C_EV_STOP:
            if self.state == self.INITIAL_STATE:
                self.state = self.INITIAL_STATE
            elif self.state == self.ADDRESS_RECEIVE_COMPLETE_STATE:
                self.state = self.WRITE_STATE
            elif self.state == self.WRITE_STATE:
                self.state = self.INITIAL_STATE
            elif self.state == self.READ_STATE:
                self.state = self.INITIAL_STATE

    def main(self):
        img_cnt = 0
        try:
            while(True):
                self.fps_clock.tick()
                img = sensor.snapshot() # Take an image from sensor

                nn_en = (self.i2c_register[self.ADDR_CTRL_REG] >> 2) & 0x01
                apriltag_en = (self.i2c_register[self.ADDR_CTRL_REG] >> 3) & 0x01
                red_en = (self.i2c_register[self.ADDR_CTRL_REG] >> 4) & 0x01
                green_en = (self.i2c_register[self.ADDR_CTRL_REG] >> 5) & 0x01
                april3d_en = (self.i2c_register[self.ADDR_CTRL_REG] >> 6) & 0x01
                # bit7はこのプロジェクトではcube_face_enとして再定義(上のNOTE参照)。
                cube_face_en = (self.i2c_register[self.ADDR_CTRL_REG] >> 7) & 0x01

                speak_enable_reg = self.i2c_register[self.ADDR_SPEAK_ENABLE]
                speak_cube_en = speak_enable_reg & 0x01
                speak_face_en = (speak_enable_reg >> 1) & 0x01
                speak_apriltag_en = (speak_enable_reg >> 2) & 0x01

                detection_data = []
                skip_flag = False
                nn_bbox = None
                apriltag_bbox = None
                april3d_bbox = None
                red_bbox = None
                green_bbox = None
                april3d_color_bbox = None
                cube_result = None  # 今回のフレームで未計算なら必ずNone(前フレームの使い回し防止)

                # 発話用に顔/AprilTagを検出したい場合は、ホストがnn_en/apriltag_en
                # を明示的にONにしていなくても検出自体は実行する(データ送信は
                # 従来通りnn_en/apriltag_enの時だけ。ONにしていないのに検出結果が
                # 送られてくることはあるが、host側は既に複数種類混在に対応済み
                # なので実害は無い)。
                if nn_en == 1 or speak_face_en == 1:
                    nn_bbox = kpu.run_yolo2(self.task, img)
                if apriltag_en == 1 or speak_apriltag_en == 1:
                    img_qqvga = img.resize(int(img.width()/2), int(img.height()/2))
                    apriltag_bbox = img_qqvga.find_apriltags(fx=self.fx, fy=self.fy, cx=self.cx, cy=self.cy)
                if april3d_en == 1:
                    img_qqvga = img.resize(int(img.width()/2), int(img.height()/2))
                    april3d_bbox = img_qqvga.find_apriltags(fx=self.fx, fy=self.fy, cx=self.cx, cy=self.cy)
                if red_en == 1:
                    red_bbox = img.find_blobs([red_threshold],area_threshold=900)
                if green_en == 1:
                    green_bbox = img.find_blobs([green_threshold],area_threshold=900)
                if False:  # 旧機能(bit7)。cube_face_enとして再定義したため無効化。
                    img_qqvga = img.resize(int(img.width()/2), int(img.height()/2))
                    april3d_color_bbox = img_qqvga.find_apriltags(fx=self.fx, fy=self.fy, cx=self.cx, cy=self.cy)

                if nn_bbox:
                    for b in nn_bbox:
                        #print(b)
                        img.draw_rectangle(b.rect(), color=(255, 255, 0), thickness=2)

                        detection_data.append(self.TYPE_NN)
                        detection_data.append((b.x() * self.QVGA_SCALE) & 0xFF)
                        detection_data.append(((b.x() * self.QVGA_SCALE) >> 8) & 0xFF)
                        detection_data.append((b.y() * self.QVGA_SCALE) & 0xFF)
                        detection_data.append(((b.y() * self.QVGA_SCALE) >> 8) & 0xFF)
                        detection_data.append((b.w() * self.QVGA_SCALE) & 0xFF)
                        detection_data.append(((b.w() * self.QVGA_SCALE) >> 8) & 0xFF)
                        detection_data.append((b.h() * self.QVGA_SCALE) & 0xFF)
                        detection_data.append(((b.h() * self.QVGA_SCALE) >> 8) & 0xFF)
                        detection_data.append(int(b.value() * 0xFF)) #confidence
                        detection_data.append(b.classid())

                        if len(detection_data) > self.DATA_MAX_SIZE:
                            detection_data = detection_data[:-11]
                            skip_flag = True
                            break

                if apriltag_bbox and skip_flag == False:
                    for b in apriltag_bbox:
                        c = b.corners()
                        #print(c)
                        for i in range(4):
                            j = 0
                            if i != 3:
                                j = i + 1
                            img.draw_line(c[i][0]*2, c[i][1]*2, c[j][0]*2, c[j][1]*2, color=(0, 0, 255), thickness=2)
                        img.draw_string(c[0][0]*2, max(0, c[0][1]*2 - 36), "%d" % b.id(),
                                         color=(0, 0, 255), scale=4)

                        detection_data.append(self.TYPE_APRILTAG)
                        detection_data.append((c[0][0] * self.QQVGA_SCALE) & 0xFF)
                        detection_data.append(((c[0][0] * self.QQVGA_SCALE) >> 8) & 0xFF)
                        detection_data.append((c[0][1] * self.QQVGA_SCALE) & 0xFF)
                        detection_data.append(((c[0][1] * self.QQVGA_SCALE) >> 8) & 0xFF)
                        detection_data.append((c[1][0] * self.QQVGA_SCALE) & 0xFF)
                        detection_data.append(((c[1][0] * self.QQVGA_SCALE) >> 8) & 0xFF)
                        detection_data.append((c[1][1] * self.QQVGA_SCALE) & 0xFF)
                        detection_data.append(((c[1][1] * self.QQVGA_SCALE) >> 8) & 0xFF)
                        detection_data.append((c[2][0] * self.QQVGA_SCALE) & 0xFF)
                        detection_data.append(((c[2][0] * self.QQVGA_SCALE) >> 8) & 0xFF)
                        detection_data.append((c[2][1] * self.QQVGA_SCALE) & 0xFF)
                        detection_data.append(((c[2][1] * self.QQVGA_SCALE) >> 8) & 0xFF)
                        detection_data.append((c[3][0] * self.QQVGA_SCALE) & 0xFF)
                        detection_data.append(((c[3][0] * self.QQVGA_SCALE) >> 8) & 0xFF)
                        detection_data.append((c[3][1] * self.QQVGA_SCALE) & 0xFF)
                        detection_data.append(((c[3][1] * self.QQVGA_SCALE) >> 8) & 0xFF)
                        detection_data.append(b.id() & 0xFF)
                        detection_data.append((b.id() >> 8) & 0xFF)
                        detection_data.append(int(b.decision_margin() * 0xFF)) #confidence

                        if len(detection_data) > self.DATA_MAX_SIZE:
                            detection_data = detection_data[:-20]
                            skip_flag = True
                            break

                if april3d_bbox and skip_flag == False:
                    for b in april3d_bbox:
                        c = b.corners()
                        print(b)
                        for i in range(4):
                            j = 0
                            if i != 3:
                                j = i + 1
                            img.draw_line(c[i][0]*2, c[i][1]*2, c[j][0]*2, c[j][1]*2, color=(0, 0, 255), thickness=2)

                        detection_data.append(self.TYPE_APRIL3D)
                        detection_data.append(int(b.x_translation() * 1000) & 0xFF)
                        detection_data.append((int(b.x_translation() * 1000) >> 8) & 0xFF)
                        detection_data.append(int(b.y_translation() * 1000) & 0xFF)
                        detection_data.append((int(b.y_translation() * 1000) >> 8) & 0xFF)
                        detection_data.append(int(b.z_translation() * 1000) & 0xFF)
                        detection_data.append((int(b.z_translation() * 1000) >> 8) & 0xFF)
                        detection_data.append(int(b.rotation() * 1000) & 0xFF)
                        detection_data.append((int(b.rotation() * 1000) >> 8) & 0xFF)
                        detection_data.append(int(b.x_rotation() * 1000) & 0xFF)
                        detection_data.append((int(b.x_rotation() * 1000) >> 8) & 0xFF)
                        detection_data.append(int(b.y_rotation() * 1000) & 0xFF)
                        detection_data.append((int(b.y_rotation() * 1000) >> 8) & 0xFF)
                        detection_data.append(int(b.z_rotation() * 1000) & 0xFF)
                        detection_data.append((int(b.z_rotation() * 1000) >> 8) & 0xFF)
                        for k in range(2):
                            detection_data.append(0)
                        detection_data.append(b.id() & 0xFF)
                        detection_data.append((b.id() >> 8) & 0xFF)
                        detection_data.append(int(b.decision_margin() * 0xFF)) #confidence

                        if len(detection_data) > self.DATA_MAX_SIZE:
                            detection_data = detection_data[:-20]
                            skip_flag = True
                            break

                if red_bbox and skip_flag == False:
                    for b in red_bbox:
                        img.draw_rectangle(b.rect(), color=(255, 0, 0), thickness=2)

                        detection_data.append(self.TYPE_RED)
                        detection_data.append((b.x() * self.QVGA_SCALE) & 0xFF)
                        detection_data.append(((b.x() * self.QVGA_SCALE) >> 8) & 0xFF)
                        detection_data.append((b.y() * self.QVGA_SCALE) & 0xFF)
                        detection_data.append(((b.y() * self.QVGA_SCALE) >> 8) & 0xFF)
                        detection_data.append((b.w() * self.QVGA_SCALE) & 0xFF)
                        detection_data.append(((b.w() * self.QVGA_SCALE) >> 8) & 0xFF)
                        detection_data.append((b.h() * self.QVGA_SCALE) & 0xFF)
                        detection_data.append(((b.h() * self.QVGA_SCALE) >> 8) & 0xFF)

                        if len(detection_data) > self.DATA_MAX_SIZE:
                            detection_data = detection_data[:-9]
                            skip_flag = True
                            break

                if green_bbox and skip_flag == False:
                    for b in green_bbox:
                        img.draw_rectangle(b.rect(), color=(0, 255, 0), thickness=2)

                        detection_data.append(self.TYPE_GREEN)
                        detection_data.append((b.x() * self.QVGA_SCALE) & 0xFF)
                        detection_data.append(((b.x() * self.QVGA_SCALE) >> 8) & 0xFF)
                        detection_data.append((b.y() * self.QVGA_SCALE) & 0xFF)
                        detection_data.append(((b.y() * self.QVGA_SCALE) >> 8) & 0xFF)
                        detection_data.append((b.w() * self.QVGA_SCALE) & 0xFF)
                        detection_data.append(((b.w() * self.QVGA_SCALE) >> 8) & 0xFF)
                        detection_data.append((b.h() * self.QVGA_SCALE) & 0xFF)
                        detection_data.append(((b.h() * self.QVGA_SCALE) >> 8) & 0xFF)

                        if len(detection_data) > self.DATA_MAX_SIZE:
                            detection_data = detection_data[:-9]
                            skip_flag = True
                            break

                if april3d_color_bbox and skip_flag == False:
                    for b in april3d_color_bbox:
                        c = b.corners()
                        #print(b)
                        sorted_corners = sorted(c, key=lambda x: x[1])

                        height = sorted_corners[3][1] + sorted_corners[2][1] - sorted_corners[1][1] - sorted_corners[0][1] #/2*2
                        monitor_center = (b.cx() * 2, b.cy() * 2 - int(height * 145.0 / 160.0))
                        monitor_height = int(height / 3.0)
                        monitor_width = int(height / 2.0)
                        monitor_bbox = (int(monitor_center[0] - monitor_width/2), int(monitor_center[1] - monitor_height/2), monitor_width, monitor_height)
                        #img.draw_rectangle(monitor_bbox, color=(255, 255, 0), thickness=2)

                        red_bbox = None
                        green_bbox = None
                        cyan_bbox = None
                        magenta_bbox = None
                        roi_not_overlap = False
                        try:
                            red_bbox = img.find_blobs([monitor_red], roi=monitor_bbox, area_threshold=10)
                            green_bbox = img.find_blobs([monitor_green], roi=monitor_bbox, area_threshold=10)
                            cyan_bbox = img.find_blobs([monitor_cyan], roi=monitor_bbox, area_threshold=10)
                            magenta_bbox = img.find_blobs([monitor_magenta], roi=monitor_bbox, area_threshold=10)
                        except OSError as e:
                            roi_not_overlap = True

                        if red_bbox:
                            for bb in red_bbox:
                                img.draw_rectangle(bb.rect(), color=(255, 255, 0), thickness=1)
                        if green_bbox:
                            for bb in green_bbox:
                                img.draw_rectangle(bb.rect(), color=(255, 255, 0), thickness=1)
                        if cyan_bbox:
                            for bb in cyan_bbox:
                                img.draw_rectangle(bb.rect(), color=(255, 255, 0), thickness=1)
                        if magenta_bbox:
                            for bb in magenta_bbox:
                                img.draw_rectangle(bb.rect(), color=(255, 255, 0), thickness=1)

                        for i in range(4):
                            j = 0
                            if i != 3:
                                j = i + 1
                            img.draw_line(c[i][0]*2, c[i][1]*2, c[j][0]*2, c[j][1]*2, color=(0, 0, 255), thickness=2)

                        monitor_status = self.MONITOR_UNKNOWN

                        if roi_not_overlap:
                            monitor_status = self.MONITOR_UNKNOWN
                        else:
                            red_bbox = sorted(red_bbox, key=lambda x: x.pixels(), reverse=True)
                            green_bbox = sorted(green_bbox, key=lambda x: x.pixels(), reverse=True)
                            cyan_bbox = sorted(cyan_bbox, key=lambda x: x.pixels(), reverse=True)
                            magenta_bbox = sorted(magenta_bbox, key=lambda x: x.pixels(), reverse=True)
                            max_area = 0
                            if red_bbox:
                                if red_bbox[0].pixels() > max_area:
                                    max_area = red_bbox[0].pixels()
                                    monitor_status = self.MONITOR_RED

                            if green_bbox:
                                if green_bbox[0].pixels() > max_area:
                                    max_area = green_bbox[0].pixels()
                                    monitor_status = self.MONITOR_GREEN

                            if cyan_bbox:
                                if cyan_bbox[0].pixels() > max_area:
                                    max_area = cyan_bbox[0].pixels()
                                    monitor_status = self.MONITOR_CYAN

                            if magenta_bbox:
                                if magenta_bbox[0].pixels() > max_area:
                                    max_area = magenta_bbox[0].pixels()
                                    monitor_status = self.MONITOR_MAGENTA

                            #print(red_bbox)
                            #print(green_bbox)
                            #print(cyan_bbox)
                            #print(magenta_bbox)

                        print(monitor_status)
                        detection_data.append(self.TYPE_APRIL3D_COLOR)
                        detection_data.append(int(b.x_translation() * 1000) & 0xFF)
                        detection_data.append((int(b.x_translation() * 1000) >> 8) & 0xFF)
                        detection_data.append(int(b.y_translation() * 1000) & 0xFF)
                        detection_data.append((int(b.y_translation() * 1000) >> 8) & 0xFF)
                        detection_data.append(int(b.z_translation() * 1000) & 0xFF)
                        detection_data.append((int(b.z_translation() * 1000) >> 8) & 0xFF)
                        detection_data.append(int(b.rotation() * 1000) & 0xFF)
                        detection_data.append((int(b.rotation() * 1000) >> 8) & 0xFF)
                        detection_data.append(int(b.x_rotation() * 1000) & 0xFF)
                        detection_data.append((int(b.x_rotation() * 1000) >> 8) & 0xFF)
                        detection_data.append(int(b.y_rotation() * 1000) & 0xFF)
                        detection_data.append((int(b.y_rotation() * 1000) >> 8) & 0xFF)
                        detection_data.append(int(b.z_rotation() * 1000) & 0xFF)
                        detection_data.append((int(b.z_rotation() * 1000) >> 8) & 0xFF)
                        detection_data.append(int(monitor_status))
                        detection_data.append(0) #dummy
                        detection_data.append(b.id() & 0xFF)
                        detection_data.append((b.id() >> 8) & 0xFF)
                        detection_data.append(int(b.decision_margin() * 0xFF)) #confidence

                        if len(detection_data) > self.DATA_MAX_SIZE:
                            detection_data = detection_data[:-20]
                            skip_flag = True
                            break

                if cube_face_en == 1 and skip_flag == False:
                    # ルービックキューブ面の3x3グリッド、9箇所それぞれの平均色を
                    # Lab(L,a,b各1byte)で返す。輪郭検出・透視変換はせず、
                    # kxr_cube_solver同様「固定位置に決め打ちしたROI」を前提とする
                    # (M5StickVをキューブに対して固定距離・角度で構える必要がある)。
                    # 色の分類(何色か)はホスト側(kxreus)で行う。
                    detection_data.append(self.TYPE_CUBE_FACE)
                    for i, (rx, ry, rw, rh) in enumerate(self.cube_rois):
                        st = img.get_statistics(roi=(rx, ry, rw, rh))
                        l = int(st.l_mean())
                        a = int(st.a_mean())
                        b = int(st.b_mean())
                        detection_data.append(l & 0xFF)
                        detection_data.append(a & 0xFF)  # 2の補数バイトとして送る(-128〜127)
                        detection_data.append(b & 0xFF)
                        img.draw_rectangle((rx, ry, rw, rh), color=(255, 255, 255), thickness=1)
                        # 認識結果(簡易分類色)のスウォッチを3x3で並べて表示
                        # (左目は左上、右目は右上。右目はCUBE_SWATCH_FLIP_Yで
                        # 行順を反転することで、180度回転後に右上に見えるようにする)。
                        sw = self.CUBE_SWATCH_SIZE
                        sx = self.CUBE_SWATCH_BASE_X + (i % 3) * sw
                        row = (2 - i // 3) if self.CUBE_SWATCH_FLIP_Y else (i // 3)
                        sy = self.CUBE_SWATCH_BASE_Y + row * sw
                        swatch_rgb = self.classifyCubeColorRGB(l, a, b)
                        img.draw_rectangle((sx, sy, sw, sw), color=swatch_rgb, fill=True)

                    if len(detection_data) > self.DATA_MAX_SIZE:
                        detection_data = detection_data[:-28]
                        skip_flag = True

                cube_discovery_en = self.i2c_register[self.ADDR_CUBE_DISCOVERY_ENABLE]
                if cube_discovery_en and skip_flag == False:
                  try:
                    # 段階4: EusLisp側のステレオ姿勢推定用に、キューブ候補領域の
                    # bbox4隅(軸並行、回転情報は無い)+片目簡易ヨー角を送る。
                    cube_result = find_cube_candidate_adaptive(img)
                    if cube_result is not None:
                        bbox, cube_n, cube_blobs = cube_result
                        yaw_deg = cube_principal_axis_deg(cube_blobs)
                        bx, by, bw, bh = bbox
                        corners = [(bx, by), (bx + bw, by), (bx + bw, by + bh), (bx, by + bh)]
                        detection_data.append(self.TYPE_CUBE_BBOX)
                        for (cx, cy) in corners:
                            detection_data.append((cx * self.QVGA_SCALE) & 0xFF)
                            detection_data.append(((cx * self.QVGA_SCALE) >> 8) & 0xFF)
                            detection_data.append((cy * self.QVGA_SCALE) & 0xFF)
                            detection_data.append(((cy * self.QVGA_SCALE) >> 8) & 0xFF)
                        yaw_i8 = max(-127, min(127, int(yaw_deg)))
                        detection_data.append(yaw_i8 & 0xFF)  # 2の補数バイト
                        if len(detection_data) > self.DATA_MAX_SIZE:
                            detection_data = detection_data[:-18]
                            skip_flag = True

                        # 段階1で4色以上見えていれば「ルービックキューブが
                        # 見つかりました」を発話する。ただし同じ場所に置かれた
                        # ままなら繰り返さず、1秒以上安定して見えた新しい場所
                        # (または再出現)の時だけ発話する(_speak_debounce_update)。
                        # 【重要】発話トリガーは想定外の値で例外を起こすと
                        # メインループ全体が完全停止し、sensor.snapshot()すら
                        # 呼ばれなくなって実機で「画面が固まる」症状になる
                        # (実機で確認、2026.8)。try/exceptで囲み、例外は
                        # シリアルに出すだけで次フレームへ進める。
                        try:
                            distinct_colors = len(set(name for name, b in cube_blobs))
                            cube_pos = (bx + bw / 2.0, by + bh / 2.0)
                            if speak_cube_en and self._speak_debounce_update(
                                    self.cube_speak_state, distinct_colors >= 4, cube_pos):
                                self.play_speak_clip(0)
                            # [診断表示] シリアル確認のたびにリセットされてしまい
                            # ログが取れない機体があったため、発話デバウンスの
                            # 状態を常時LCDに出す(リセット不要で目視できる)。
                            st = self.cube_speak_state
                            if st.get("candidate_start_ms") is not None:
                                dbg = "wait %dms" % time.ticks_diff(time.ticks_ms(), st["candidate_start_ms"])
                            elif st.get("announced_pos") is not None:
                                dbg = "done"
                            else:
                                dbg = "idle"
                            img.draw_string(0, 240 - 68, "spk_en=%d %s" % (speak_cube_en, dbg),
                                             color=(255, 0, 0), scale=3)
                        except Exception as e:
                            print("cube speak trigger error:", e)
                  except Exception as e:
                    print("cube bbox detection error:", e)

                # 顔(NN検出classid=0)を見つけたら「こんにちは」。キューブと同じ
                # 時間・空間デバウンスを使う(同じ人がそこにい続けても繰り返さない)。
                try:
                    face_det = None
                    if nn_bbox:
                        for b in nn_bbox:
                            if b.classid() == 0:
                                face_det = b
                                break
                    face_pos = None
                    if face_det is not None:
                        face_pos = (face_det.x() + face_det.w() / 2.0, face_det.y() + face_det.h() / 2.0)
                    if speak_face_en and self._speak_debounce_update(
                            self.face_speak_state, face_det is not None, face_pos):
                        self.play_speak_clip(1)
                except Exception as e:
                    print("face speak trigger error:", e)

                # AprilTagを見つけたら「エイプリルタグ見つけました。N番です。」。
                # IDが変わるか場所が変わったら再度発話する(_speak_debounce_updateの
                # ident引数でID変化も検知)。複数タグが同時に見えている場合は
                # 先頭の1個だけを対象にする(簡易実装)。
                try:
                    tag_det = apriltag_bbox[0] if apriltag_bbox else None
                    tag_pos = None
                    tag_id = None
                    if tag_det is not None:
                        tag_pos = (tag_det.x() + tag_det.w() / 2.0, tag_det.y() + tag_det.h() / 2.0)
                        tag_id = tag_det.id()
                    if speak_apriltag_en and self._speak_debounce_update(
                            self.apriltag_speak_state, tag_det is not None, tag_pos, ident=tag_id):
                        self.speak_apriltag_found(tag_id)
                except Exception as e:
                    print("apriltag speak trigger error:", e)

                self.i2c_register[self.ADDR_OBJ_DATA_LEN] = len(detection_data)
                self.i2c_register[self.ADDR_OBJ_DATA:self.ADDR_OBJ_DATA+len(detection_data)] = detection_data

                # RCB4拡張命令経由での発話指示: ホストがADDR_SPEAK_CMDへ
                # (1始まりの)クリップ番号を書き込んだら再生し、消費後は0に戻す。
                speak_cmd = self.i2c_register[self.ADDR_SPEAK_CMD]
                if speak_cmd != 0:
                    self.i2c_register[self.ADDR_SPEAK_CMD] = 0
                    self.play_speak_clip(speak_cmd - 1)

                if self.prev_but_b_state == 0 and self.but_b.value() == 1:
                    self.toggle_lcd_backlight()

                self.prev_but_b_state = self.but_b.value()

                if cube_discovery_en:
                    try:
                        draw_cube_candidate(img, result=cube_result)
                    except Exception as e:
                        print("draw_cube_candidate error:", e)
                    if SKIN_DEBUG_PRINT:
                        maybe_print_skin_debug(img)

                if self.lcd_on:
                    img_lcd = img.resize(lcd.width(), lcd.height())
                    lcd.display(img_lcd)

                if self.i2c_register[self.ADDR_CTRL_REG] & 0x02 != 0:
                    self.led_w.value(0) #on
                else:
                    self.led_w.value(1) #off

                if self.i2c_register[self.ADDR_CTRL_REG] & 0x01 != 0:
                    #save image
                    img_name = self.save_dir_name + '/' + str(img_cnt) + '.bmp'
                    img.save(img_name)
                    img_cnt += 1
                    self.i2c_register[self.ADDR_CTRL_REG] &= ~0x01 #off flag

                # 長時間(一晩など)動かし続けるとハングする不具合が実機で
                # あったため、定期的にgc.collect()を呼んでメモリ断片化・
                # 蓄積を抑える保険を入れておく(毎フレームだと重いので
                # 数百フレームに1回程度)。空きヒープもシリアルへ出しておき、
                # 今後同様の症状が出た時に減り続けていないか確認できるようにする。
                self._gc_frame_counter += 1
                if self._gc_frame_counter % 300 == 0:
                    gc.collect()
                    print("[gc] free heap =", gc.mem_free())

                time.sleep_ms(1)
                #print(self.fps_clock.fps())

        except KeyboardInterrupt:
            sys.exit()

app = App()
time.sleep_ms(500)
app.main()
