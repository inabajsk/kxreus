// BvhPlayer.kt : BVH（モーションキャプチャ）の骨格の再生の状態 (iOS 版 BVHView.swift の BVHPlayer と同じ). Android 版とデスクトップ版で共通
//   ・表示: 骨 (細い箱) と関節 (球) を RobotModel のメッシュにして RobotGLView で描く. カメラは腰の水平の動きを追う
//   ・ロボット (KXR / KHR / JSK) に移して並べる: 棒人形 (左)・関節名で対応 (kxreus の :names と同じ)・GMR・GMR + QP (右) (BvhRetarget.kt)
//     GMR + QP は全身 QP (WholeBodyQp.kt / wbqp.cpp, eusview/bvh/QP.md) で自己衝突・関節の可動範囲・重心を直したもの (裏で全部のコマを計算)
//     棒人形と 3 体のロボットのリンクを 1 つの RobotModel (どのリンクも親なし) にまとめ, ワールドの変換をそのまま入れる
//   ・違反の表示 (GMR と GMR + QP): 衝突しているリンクを赤, 可動範囲の端のリンクを橙, 重心 (球) と床への投影, 支持多角形 (緑 = 中, 赤 = 外)
//   起動の引数 -robot kxr|khr|jsk|<名前> -method all|both|names|gmr|qp|gmrqp -violations 0|1 -stick 0 -speed 2 -frame <n> (止めて表示)
//   画面は BvhScreens.kt
package jp.jsk.eusview

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

fun bvhDuration(s: Double) = when {
    s >= 3600 -> String.format("%.1f 時間", s / 3600)
    s >= 60 -> String.format("%.1f 分", s / 60)
    else -> String.format("%.1f 秒", s)
}

// ---- 骨格のメッシュ ----

private val boneColor = floatArrayOf(0.93f, 0.60f, 0.40f, 1f)
private val jointColor = floatArrayOf(0.22f, 0.42f, 0.80f, 1f)

/** 原点から to までの細い四角柱 (半分の幅 h) */
private fun boneMesh(to: FloatArray, h: Float): RobotMesh? {
    val l = sqrt(to[0] * to[0] + to[1] * to[1] + to[2] * to[2])
    if (l < 0.005f) return null
    val u = floatArrayOf(to[0] / l, to[1] / l, to[2] / l)
    val a = if (kotlin.math.abs(u[2]) < 0.9f) floatArrayOf(0f, 0f, 1f) else floatArrayOf(1f, 0f, 0f)
    fun cross(p: FloatArray, q: FloatArray) = floatArrayOf(p[1] * q[2] - p[2] * q[1], p[2] * q[0] - p[0] * q[2], p[0] * q[1] - p[1] * q[0])
    var v = cross(a, u); val vl = sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]); v = floatArrayOf(v[0] / vl, v[1] / vl, v[2] / vl)
    val w = cross(u, v)
    val vs = FloatArray(24)
    var o = 0
    for (end in 0..1) for ((sv, sw) in listOf(-1f to -1f, 1f to -1f, 1f to 1f, -1f to 1f)) {
        for (d in 0..2) vs[o++] = to[d] * end + (sv * v[d] + sw * w[d]) * h
    }
    val idx = intArrayOf(0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7,
        0, 1, 5, 0, 5, 4, 1, 2, 6, 1, 6, 5, 2, 3, 7, 2, 7, 6, 3, 0, 4, 3, 4, 7)
    return RobotMesh(boneColor, vs, idx)
}

/** 半径 r の球 (緯度 6 × 経度 10) */
private fun sphereMesh(r: Float): RobotMesh {
    val nl = 6; val nm = 10
    val vs = ArrayList<Float>()
    for (i in 0..nl) {
        val th = Math.PI * i / nl
        for (k in 0 until nm) {
            val ph = 2 * Math.PI * k / nm
            vs.add((r * sin(th) * cos(ph)).toFloat()); vs.add((r * sin(th) * sin(ph)).toFloat()); vs.add((r * cos(th)).toFloat())
        }
    }
    val idx = ArrayList<Int>()
    for (i in 0 until nl) for (k in 0 until nm) {
        val a = i * nm + k; val b = i * nm + (k + 1) % nm; val c = a + nm; val d = b + nm
        if (i > 0) { idx.add(a); idx.add(c); idx.add(b) }
        if (i < nl - 1) { idx.add(b); idx.add(c); idx.add(d) }
    }
    return RobotMesh(jointColor, vs.toFloatArray(), idx.toIntArray())
}

/** BVH の関節を 1 つずつリンクにした RobotModel (骨は親の関節のリンクに付ける) */
fun bvhSkeletonModel(m: BvhMotion): RobotModel {
    val meshes = m.joints.map { mutableListOf(sphereMesh(0.022f)) }
    for (j in m.joints) if (j.parent >= 0) boneMesh(FloatArray(3) { j.offset[it] / 1000f }, 0.014f)?.let { meshes[j.parent].add(it) }
    for (e in m.ends) boneMesh(FloatArray(3) { e.offset[it] / 1000f }, 0.012f)?.let { meshes[e.parent].add(it) }
    val links = m.joints.mapIndexed { i, j ->
        RobotLink(j.name, j.parent, floatArrayOf(0f, 0f, 0f), floatArrayOf(1f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, 1f), meshes[i])
    }
    return RobotModel("${m.kind}/${m.name}", "bvh", links, emptyList(), null, null, null)
}

// ---- 再生の状態 ----

/** 見せないリンク: 大きさ 0 (BvhPlayer の init から show を呼ぶので, クラスの外に置く) */
private val hidden = FloatArray(16).also { it[15] = 1f }

/** BVH の画面で選べるロボット (group が空ならなし) */
data class RetargetChoice(val group: String, val name: String)

fun loadRetargetTables(): RetargetTables? = try {
    RetargetTables.parse(Platform.store.open("bvh/retarget_tables.json").use { it.readBytes().toString(Charsets.UTF_8) })
} catch (e: Exception) { null }

class BvhPlayer(val list: List<BvhEntry>, start: Int, val auto: Boolean) {
    var current by mutableIntStateOf(start); private set
    var motion by mutableStateOf<BvhMotion?>(null); private set
    var scene by mutableStateOf<RobotScene?>(null); private set
    var frame by mutableIntStateOf(0); private set
    var playing by mutableStateOf(true)
    var speed by mutableDoubleStateOf(1.0)
    var follow by mutableStateOf(true)
    var error by mutableStateOf<String?>(null); private set
    var checkInfo by mutableStateOf(""); private set
    // ロボットに移す
    val tables = loadRetargetTables()
    var robot by mutableStateOf(RetargetChoice("", "")); private set
    var showStick by mutableStateOf(true); private set
    var showNames by mutableStateOf(true); private set
    var showGmr by mutableStateOf(true); private set
    var showQp by mutableStateOf(true); private set
    var showViolations by mutableStateOf(true); private set
    var lifeSize by mutableStateOf(true); private set
    var robotInfo by mutableStateOf(""); private set
    var gmrMs by mutableDoubleStateOf(0.0); private set
    var qpProgress by mutableStateOf<Double?>(null); private set
    var qpInfo by mutableStateOf(""); private set
    var frameInfo by mutableStateOf(""); private set
    private var robotModel: RobotModel? = null
    private var rt: BvhRetargeter? = null
    private var nStick = 0
    private var hasNames = false; private var hasGmr = false
    // GMR + QP: 裏で計算したコマ (別のスレッドが足す) と, 表示の評価用の QP (計算用とは別)
    private var qpFrames: MutableList<QpFrame>? = null
    private var qpEval: WholeBodyQp? = null
    private var qpJob: Job? = null
    var glView: SceneView? = null
    private var time = 0.0
    private var lastRoot: FloatArray? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    val entry get() = list[current]

    init {
        load()
        Launch.get("robot")?.let { chooseRobot(launchChoice(it)) }
        when (Launch.get("method")) {
            "names" -> { showGmr = false; showQp = false }
            "gmr" -> { showNames = false; showQp = false }
            "qp" -> { showNames = false; showGmr = false }
            "gmrqp" -> showNames = false
            "both" -> showQp = false
        }
        if (Launch.get("violations") == "0") showViolations = false
        if (Launch.get("stick") == "0") showStick = false
        Launch.get("speed")?.toDoubleOrNull()?.let { speed = it }
        Launch.get("frame")?.toIntOrNull()?.let { playing = false; seek(it) }   // このコマで止める (確認用)
        scope.launch {
            var last = System.nanoTime()
            while (isActive) {
                delay(16)
                val now = System.nanoTime()
                val dt = minOf((now - last) / 1e9, 0.1); last = now
                tick(dt)
            }
        }
    }

    /** グループごとの選べるロボット (表の supported, 既定を先頭に) */
    fun choices(group: String): List<RetargetChoice> {
        val t = tables ?: return emptyList()
        val def = t.defaults[group]
        val names = (t.supported[group] ?: emptyList()).filter { it != def }
        return (listOfNotNull(def) + names).map { RetargetChoice(group, it) }
    }

    private fun launchChoice(s: String): RetargetChoice {
        val t = tables ?: return RetargetChoice("", "")
        if (s in robotGroups) t.defaults[s]?.let { return RetargetChoice(s, it) }
        for (g in robotGroups) if (s in (t.supported[g] ?: emptyList())) return RetargetChoice(g, s)
        return RetargetChoice("", "")
    }

    /** ロボットを選ぶ (JSON は別のスレッドで読む) */
    fun chooseRobot(c: RetargetChoice) {
        robot = c; robotModel = null; rebuild()
        if (c.group.isEmpty()) return
        robotInfo = "${c.name} を読み込み中…"
        scope.launch {
            val m = try {
                withContext(Dispatchers.IO) { Platform.store.open("robots/${c.group}/${c.name}.json").use { RobotModel.parse(it) } }
            } catch (e: Throwable) { null }
            if (robot != c) return@launch
            if (m != null && robotSupportsRetarget(m)) { robotModel = m; rebuild() }
            else robotInfo = "${c.name}: 関節名が <limb>-<joint>-<r|p|y> ではないので移せません"
        }
    }

    fun setShow(stick: Boolean = showStick, names: Boolean = showNames, gmr: Boolean = showGmr, qp: Boolean = showQp,
                violations: Boolean = showViolations, life: Boolean = lifeSize) {
        showStick = stick; showNames = names; showGmr = gmr; showQp = qp; showViolations = violations; lifeSize = life; show()
    }

    private fun load() {
        try {
            val m = BvhMotion.load(entry.file.file)
            time = 0.0; frame = 0; lastRoot = null
            m.checkError()?.let { e ->
                checkInfo = String.format("照合 %.2f mm", e)
                Platform.log(String.format("BVH %s/%s check: max error %.3f mm (frame %d)", entry.kind, entry.file.name, e, m.checkFrame))
            }
            motion = m; error = null
            rebuild()
        } catch (e: Throwable) {
            error = "${entry.file.file} を読めません: $e"; motion = null; scene = null
            Platform.logError("BVH load", e)
        }
    }

    /** モーションかロボットが変わったとき: 棒人形 + (関節名のロボット) + (GMR のロボット) + (GMR + QP のロボット) を 1 つの場面にする */
    private fun rebuild() {
        stopQp()
        val m = motion ?: return
        rt = null; hasNames = false; hasGmr = false
        val sk = bvhSkeletonModel(m)
        val links = ArrayList<RobotLink>()
        for (l in sk.links) links.add(RobotLink(l.name, -1, l.pos, l.rot, l.meshes))
        nStick = links.size
        val rm = robotModel; val t = tables
        if (robot.group.isEmpty()) robotInfo = ""
        if (rm != null && t != null) {
            val r = BvhRetargeter(rm, m, t)
            rt = r
            hasNames = r.method1OK; hasGmr = r.gmrOK
            val n = (if (hasNames) 1 else 0) + (if (hasGmr) 2 else 0)
            repeat(n) { for (l in rm.links) links.add(RobotLink(l.name, -1, l.pos, l.rot, l.meshes)) }
            if (hasGmr) {
                qpEval = try { WholeBodyQp(rm, r, m.fps) } catch (e: Throwable) { Platform.logError("WholeBodyQp", e); null }
                if (qpEval != null) startQp(rm, m, t)
            }
            robotInfo = String.format("%s・脚の比 %.2f・腕の比 %.2f%s", rm.name, r.sLeg, r.sArm, if (r.method1OK) "" else "・関節名の表がない種類")
            Platform.log("BVH retarget ${entry.kind}/${entry.file.name} -> ${rm.name}: $robotInfo")
        } else if (rm != null) robotInfo = "retarget_tables.json がありません"
        val s = RobotScene(RobotModel("${m.kind}/${m.name}", "bvh", links, emptyList(), null, null, null))
        scene = s
        glView = null
        show(s)
    }

    private fun stopQp() {
        qpJob?.cancel(); qpJob = null; qpFrames = null
        qpEval?.destroy(); qpEval = null
        qpProgress = null; qpInfo = ""; frameInfo = ""
    }

    /** GMR + QP を裏で全部のコマ計算する (計算したコマから表示する. iOS 版 startQP と同じ) */
    private fun startQp(model: RobotModel, mo: BvhMotion, t: RetargetTables) {
        val frames = java.util.Collections.synchronizedList(ArrayList<QpFrame>(mo.frames))
        qpFrames = frames
        qpProgress = 0.0
        val name = "${entry.kind}/${entry.file.name}"
        qpJob = scope.launch {
            val job = coroutineContext[Job]
            val t0 = System.nanoTime()
            val done = withContext(Dispatchers.Default) {
                val rt2 = BvhRetargeter(model, mo, t)
                val qp = WholeBodyQp(model, rt2, mo.fps)
                var lastP = -1.0
                try {
                    runGmrQp(rt2, qp, { p -> if (p - lastP >= 0.02) { lastP = p; scope.launch { if (job?.isActive == true) qpProgress = p } } },
                        { job?.isActive != true }) { _, f -> frames.add(f) }
                } finally { qp.destroy() }
            }
            if (!done || job?.isActive != true) return@launch
            val sec = (System.nanoTime() - t0) / 1e9
            val s = synchronized(frames) { qpSummary(ArrayList(frames)) }
            Platform.log(String.format("GMR+QP %s %s: %d frames in %.2f s, QP %.3f ms/frame, collide %.1f%% -> %.1f%%, COM out %.1f%% -> %.1f%%",
                name, model.name, frames.size, sec, s[0], s[1], s[2], s[3], s[4]))
            qpProgress = null
            show()   // 止めているときも計算したコマで描き直す
            qpInfo = String.format("GMR+QP %.2f ms/コマ・衝突 %.0f%%→%.0f%%・重心が外 %.0f%%→%.0f%%", s[0], s[1], s[2], s[3], s[4])
        }
    }

    /** 関節の球が床に埋まらないように, 球の半径くらい上げる */
    private fun lifted(w: List<FloatArray>) = w.onEach { it[14] += 0.02f }

    private fun tick(dt: Double) {
        val m = motion ?: return
        if (!playing || m.frames <= 0) return
        time += dt * speed
        val n = (time * m.fps).toInt()
        if (n >= m.frames) {
            if (auto && list.size > 1) { next(); return }
            time = 0.0; frame = 0   // 1 本だけのときは止めるまで繰り返す
        } else frame = n
        show()
    }


    private fun show(s0: RobotScene? = null) {
        val m = motion ?: return; val s = s0 ?: scene ?: return
        val r = rt
        // 並べ方: 見えているものを (棒人形, 関節名, GMR, GMR + QP) の順に人の左右 (EusLisp の y) に. 前 (+x) から見て左から右
        val vis = visible()
        val nv = vis.count { it }
        val d = if (lifeSize) 1.2f else 0.6f
        val offs = FloatArray(4); var k = 0
        for (i in 0..3) if (vis[i]) { offs[i] = (k - (nv - 1) / 2f) * d; k++ }
        val sc = if (lifeSize && r != null) 1f / maxOf(r.sLeg, 0.05f) else 1f
        val w = ArrayList<FloatArray>(s.model.links.size)
        val sk = lifted(m.frame(frame))
        for (x in sk) { if (showStick) { val c = x.copyOf(); c[13] += offs[0]; w.add(c) } else w.add(hidden) }
        val tints = IntArray(s.model.links.size)
        val overlays = ArrayList<Overlay>()
        var info = ""
        if (r != null) {
            val nl = r.model.links.size
            fun add(a: FloatArray, T: Tf, on: Boolean, off: Float) {
                val W = robotFK(r.model, a, T)
                for (t in W) w.add(if (on) t.toMat(sc, 0f, off) else hidden)
            }
            if (hasNames) { if (showNames) { val (a, T) = r.method1(frame); add(a, T, true, offs[1]) } else repeat(nl) { w.add(hidden) } }
            if (hasGmr) {
                // GMR + QP を計算したコマは, GMR もその計算に使った参照を出す (同じもの同士で比べる)
                val cached = qpFrames?.let { f -> synchronized(f) { f.getOrNull(frame) } }
                val ev = qpEval
                val size = (ev?.scale ?: 0.3).toFloat()
                var vG: QpView? = null; var vQ: QpView? = null
                val baseG = w.size
                val gmr by lazy {
                    val t0 = System.nanoTime()
                    val g = r.gmr(frame)
                    val ms = (System.nanoTime() - t0) / 1e6
                    gmrMs = if (gmrMs == 0.0) ms else gmrMs * 0.95 + ms * 0.05
                    g
                }
                if (showGmr) {
                    val a: FloatArray; val T: Tf
                    if (cached != null && ev != null) { a = cached.qRef; T = ev.rootT(cached.rootRef) } else { a = gmr.first; T = gmr.second }
                    add(a, T, true, offs[2])
                    if (showViolations && ev != null) {
                        vG = ev.view(a, r.rootLinkPose(T), cached?.diag?.contact ?: -1)
                        marks(vG, tints, baseG, overlays, sc, offs[2], size)
                    }
                } else repeat(nl) { w.add(hidden) }
                val baseQ = w.size
                if (showQp) {
                    if (cached != null && ev != null) {
                        add(cached.q, ev.rootT(cached.root), true, offs[3])
                        if (showViolations) {
                            vQ = ev.view(cached.q, cached.root, cached.diag.contact)
                            marks(vQ, tints, baseQ, overlays, sc, offs[3], size)
                        }
                    } else {
                        // まだ計算していないコマ: GMR の姿勢を薄く
                        add(gmr.first, gmr.second, true, offs[3])
                        for (i in 0 until nl) tints[baseQ + i] = Tint.FADED
                    }
                } else repeat(nl) { w.add(hidden) }
                // このコマの違反 (GMR → GMR + QP)
                fun dsc(v: QpView?): String {
                    if (v == null) return "—"
                    val e = v.eval
                    var t = if (e.nCollide > 0) String.format("衝突 %d (%.0f mm)", e.nCollide, e.minDist * 1000) else String.format("衝突なし (%.0f mm)", minOf(e.minDist, 9.999) * 1000)
                    if (e.nAtLimit > 0) t += "・範囲の端 ${e.nAtLimit}"
                    t += if (e.comMargin.isNaN()) "・足が浮く" else String.format("・重心 %s%.0f mm", if (e.comMargin < 0) "外 " else "", kotlin.math.abs(e.comMargin) * 1000)
                    return t
                }
                if (showViolations && (vG != null || vQ != null)) info = "GMR: ${dsc(vG)}\nQP: ${dsc(vQ)}"
            }
        }
        frameInfo = info
        s.tints = tints
        s.overlays = overlays
        s.setWorldPoses(w)
        // カメラが腰の水平の動きについていく
        val root = floatArrayOf(sk[0][12], sk[0][13])
        val lr = lastRoot; val v = glView
        if (follow && lr != null && v != null) v.follow(root[0] - lr[0], root[1] - lr[1], 0f)
        lastRoot = root
    }

    fun seek(f: Int) { val m = motion ?: return; frame = f.coerceIn(0, m.frames - 1); time = frame / m.fps; show() }
    fun next() { current = (current + 1) % list.size; load() }
    fun prev() { current = (current - 1 + list.size) % list.size; load() }
    /** カメラ: 人の腰のまわりを, 並べたものが収まるように前から */
    fun resetCamera() {
        val m = motion ?: return
        val p = m.frame(frame)[0]
        val nv = visible().count { it }
        val hw = 0.5f + 0.6f * maxOf(0, nv - 1)
        glView?.frontView(floatArrayOf(p[12] - 0.4f, p[13] - hw, 0f, p[12] + 0.4f, p[13] + hw, 2.3f))
        lastRoot = floatArrayOf(p[12], p[13])
    }
    fun shutdown() { stopQp(); scope.cancel() }

    private fun visible() = listOf(showStick, hasNames && showNames, hasGmr && showGmr, hasGmr && showQp)

    /** 違反の印: リンクの色 (base からのロボットのリンク) と, 重心の球・床への投影・支持多角形 (緑 = 中, 赤 = 外). 表示の拡大 sc と横のずれ off に合わせる */
    private fun marks(v: QpView, tints: IntArray, base: Int, out: MutableList<Overlay>, sc: Float, off: Float, size: Float) {
        for (i in v.flags.indices) {
            val f = v.flags[i]
            tints[base + i] = if (f and 1 != 0) Tint.COLLIDE else if (f and 2 != 0) Tint.LIMIT else Tint.NONE
        }
        val e = v.eval
        val ok = !(e.comMargin < 0)          // 支える足がない (NaN) ときは緑
        val col = if (ok) floatArrayOf(0.20f, 0.78f, 0.35f, 1f) else floatArrayOf(1f, 0.23f, 0.19f, 1f)
        if (v.polygon.size >= 6) {
            val xy = FloatArray(v.polygon.size) { if (it % 2 == 0) v.polygon[it] * sc else v.polygon[it] * sc + off }
            out.add(Overlay(floatArrayOf(col[0], col[1], col[2], 0.45f), OverlayShapes.polygon(xy, 0.0008f)))
        }
        val cx = e.com[0].toFloat() * sc; val cy = e.com[1].toFloat() * sc + off; val cz = e.com[2].toFloat() * sc
        out.add(Overlay(col, OverlayShapes.disk(cx, cy, 0.0012f, 0.03f * size * sc)))
        out.add(Overlay(col, OverlayShapes.sphere(floatArrayOf(cx, cy, cz), 0.035f * size * sc), onTop = true))
    }
}

