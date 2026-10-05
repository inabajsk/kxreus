// BvhRetarget.kt : BVH の人の動きをロボット (eus2json.l の JSON, 関節名 <limb>-<joint>-<r|p|y>) に移す (iOS 版 BVHRetarget.swift と同じ)
//   仕様: eusview/bvh/RETARGET.md, 表: eusview/bvh/retarget_tables.json (APK の assets/bvh/retarget_tables.json)
//   方法 1 (関節名): kxreus eusview-retarget.l の :names (bvh/*-demo.l の :copy-state-to) と同じ
//   方法 2 (GMR): 部位の位置 (体節ごとのスケール) を目標に手足ごとに減衰付き最小二乗の IK, 胴と頭は向きだけ
//   android.opengl を使わない (JVM の単体テスト app/src/test/.../RetargetTest.kt で iOS 版・kxreus と照合する)
package jp.jsk.eusview

import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

// ---- 小さな数学 (3x3 行優先, 位置 3) ----

object V3 {
    fun add(a: FloatArray, b: FloatArray) = floatArrayOf(a[0] + b[0], a[1] + b[1], a[2] + b[2])
    fun sub(a: FloatArray, b: FloatArray) = floatArrayOf(a[0] - b[0], a[1] - b[1], a[2] - b[2])
    fun scale(a: FloatArray, s: Float) = floatArrayOf(a[0] * s, a[1] * s, a[2] * s)
    fun dot(a: FloatArray, b: FloatArray) = a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
    fun cross(a: FloatArray, b: FloatArray) = floatArrayOf(a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
    fun len(a: FloatArray) = sqrt(dot(a, a))
    fun norm(a: FloatArray): FloatArray { val l = len(a); return if (l > 0f) scale(a, 1f / l) else a.copyOf() }
    fun dist(a: FloatArray, b: FloatArray) = len(sub(a, b))
}

object M3 {
    val I get() = floatArrayOf(1f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, 1f)
    fun mul(a: FloatArray, b: FloatArray) = FloatArray(9) { k -> val r = k / 3; val c = k % 3; a[r * 3] * b[c] + a[r * 3 + 1] * b[3 + c] + a[r * 3 + 2] * b[6 + c] }
    fun mv(a: FloatArray, v: FloatArray) = floatArrayOf(a[0] * v[0] + a[1] * v[1] + a[2] * v[2], a[3] * v[0] + a[4] * v[1] + a[5] * v[2], a[6] * v[0] + a[7] * v[1] + a[8] * v[2])
    fun t(a: FloatArray) = floatArrayOf(a[0], a[3], a[6], a[1], a[4], a[7], a[2], a[5], a[8])
    /** 列ベクトル x, y, z から */
    fun cols(x: FloatArray, y: FloatArray, z: FloatArray) = floatArrayOf(x[0], y[0], z[0], x[1], y[1], z[1], x[2], y[2], z[2])
    fun col(a: FloatArray, c: Int) = floatArrayOf(a[c], a[3 + c], a[6 + c])
    /** 軸 (単位ベクトル) まわりに角度 (rad) */
    fun axisAngle(ax: FloatArray, ang: Float): FloatArray {
        val c = cos(ang); val s = sin(ang); val v = 1 - c
        val x = ax[0]; val y = ax[1]; val z = ax[2]
        return floatArrayOf(c + x * x * v, x * y * v - z * s, x * z * v + y * s,
            y * x * v + z * s, c + y * y * v, y * z * v - x * s,
            z * x * v - y * s, z * y * v + x * s, c + z * z * v)
    }
    /** 回転行列の対数 (回転ベクトル, rad). EusLisp の matrix-log と同じ ([-π, π]) */
    fun log(r: FloatArray): FloatArray {
        val m00 = r[0].toDouble(); val m11 = r[4].toDouble(); val m22 = r[8].toDouble()
        val tr = m00 + m11 + m22
        val w: Double; val x: Double; val y: Double; val z: Double
        if (tr > 0) {
            val s = sqrt(tr + 1.0) * 2; w = 0.25 * s
            x = (r[7] - r[5]) / s; y = (r[2] - r[6]) / s; z = (r[3] - r[1]) / s
        } else if (m00 > m11 && m00 > m22) {
            val s = sqrt(1.0 + m00 - m11 - m22) * 2; w = (r[7] - r[5]) / s
            x = 0.25 * s; y = (r[1] + r[3]) / s; z = (r[2] + r[6]) / s
        } else if (m11 > m22) {
            val s = sqrt(1.0 + m11 - m00 - m22) * 2; w = (r[2] - r[6]) / s
            x = (r[1] + r[3]) / s; y = 0.25 * s; z = (r[5] + r[7]) / s
        } else {
            val s = sqrt(1.0 + m22 - m00 - m11) * 2; w = (r[3] - r[1]) / s
            x = (r[2] + r[6]) / s; y = (r[5] + r[7]) / s; z = 0.25 * s
        }
        val n = sqrt(x * x + y * y + z * z)
        if (n < 1e-12) return FloatArray(3)
        var th = 2 * kotlin.math.atan2(n, w)
        if (th > Math.PI) th -= 2 * Math.PI else if (th < -Math.PI) th += 2 * Math.PI
        return floatArrayOf((x / n * th).toFloat(), (y / n * th).toFloat(), (z / n * th).toFloat())
    }
    fun rotZ(a: Float) = axisAngle(floatArrayOf(0f, 0f, 1f), a)
    fun rotY(a: Float) = axisAngle(floatArrayOf(0f, 1f, 0f), a)
}

/** 剛体の変換 (回転 3x3 行優先 + 位置 m) */
class Tf(val r: FloatArray, val p: FloatArray) {
    operator fun times(b: Tf) = Tf(M3.mul(r, b.r), V3.add(M3.mv(r, b.p), p))
    fun apply(v: FloatArray) = V3.add(M3.mv(r, v), p)
    /** [x y z r00..r22] (RobotMotion の root の形) */
    fun xyzRot() = floatArrayOf(p[0], p[1], p[2], r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8])
    /** 列優先 4x4 (描画用), 一様な拡大 s と平行移動 (ox, oy) を前から掛ける */
    fun toMat(s: Float = 1f, ox: Float = 0f, oy: Float = 0f): FloatArray {
        val m = FloatArray(16)
        for (row in 0..2) for (c in 0..2) m[c * 4 + row] = r[row * 3 + c] * s
        m[12] = p[0] * s + ox; m[13] = p[1] * s + oy; m[14] = p[2] * s; m[15] = 1f
        return m
    }
    companion object { fun id() = Tf(M3.I, FloatArray(3)) }
}

fun RobotLink.restTf() = Tf(rot.copyOf(), pos.copyOf())

/** ロボットの順運動学 (Tf, 関節角 度・mm) */
fun robotFK(m: RobotModel, a: FloatArray, root: Tf): List<Tf> {
    val local = m.links.map { it.restTf() }.toMutableList()
    for ((k, j) in m.joints.withIndex()) {
        if (k >= a.size) break
        val ax = V3.norm(j.axis)
        local[j.link] = if (j.linear) local[j.link] * Tf(M3.I, V3.scale(ax, a[k] / 1000f))
        else local[j.link] * Tf(M3.axisAngle(ax, Math.toRadians(a[k].toDouble()).toFloat()), FloatArray(3))
    }
    val w = ArrayList<Tf>(m.links.size)
    for ((i, l) in m.links.withIndex()) w.add(if (l.parent >= 0) w[l.parent] * local[i] else root * local[i])
    return w
}

/** 対称な n×n の連立一次方程式 (ガウスの消去法) */
private fun solveLinear(a: DoubleArray, b: DoubleArray, n: Int): Boolean {
    for (c in 0 until n) {
        var p = c
        for (r in c + 1 until n) if (abs(a[r * n + c]) > abs(a[p * n + c])) p = r
        if (abs(a[p * n + c]) < 1e-12) return false
        if (p != c) { for (k in 0 until n) { val t = a[c * n + k]; a[c * n + k] = a[p * n + k]; a[p * n + k] = t }; val t = b[c]; b[c] = b[p]; b[p] = t }
        for (r in 0 until n) if (r != c) {
            val f = a[r * n + c] / a[c * n + c]
            if (f == 0.0) continue
            for (k in c until n) a[r * n + k] -= f * a[c * n + k]
            b[r] -= f * b[c]
        }
    }
    for (c in 0 until n) b[c] /= a[c * n + c]
    return true
}

// ---- 表 (retarget_tables.json) ----

class M1Rule(val src: Map<String, Int>, val axisSign: String, val signs: Map<String, Float>, val calibrate: Boolean)
class RetargetDataset(val method1: Map<String, String>, val rule: M1Rule?, val gmr: Map<String, String>)
class GmrParams(val lambda: Float, val iterations: Int, val wEnd: Float, val wMid: Float, val wFootRot: Float, val wTorsoRot: Float, val wHeadRot: Float, val wRest: Float)
class RetargetTables(
    val defaults: Map<String, String>, val mirrored: Set<String>, val supported: Map<String, List<String>>,
    val order: List<Pair<String, String>>, val axes: Map<String, Int>, val datasets: Map<String, RetargetDataset>, val gmr: GmrParams,
) {
    companion object {
        fun parse(text: String): RetargetTables {
            val o = JSONObject(text)
            fun JSONObject.strMap() = keys().asSequence().associateWith { getString(it) }
            fun JSONObject.intMap() = keys().asSequence().associateWith { getInt(it) }
            val rb = o.getJSONObject("robots")
            val sup = rb.optJSONObject("supported")?.let { s -> s.keys().asSequence().associateWith { g -> s.getJSONArray(g).let { a -> (0 until a.length()).map { a.getString(it) } } } } ?: emptyMap()
            val m1 = o.getJSONObject("method1")
            val ord = m1.getJSONArray("order").let { a -> (0 until a.length()).map { a.getJSONArray(it).let { p -> p.getString(0) to p.getString(1) } } }
            val ds = o.getJSONObject("datasets").let { d ->
                d.keys().asSequence().associateWith { k ->
                    val x = d.getJSONObject(k)
                    val r = x.optJSONObject("method1Rule")?.let { r ->
                        M1Rule(r.getJSONObject("src").intMap(), r.getString("axisSign"),
                            r.getJSONObject("signs").let { s -> s.keys().asSequence().associateWith { s.getDouble(it).toFloat() } }, r.getBoolean("calibrate"))
                    }
                    RetargetDataset(x.optJSONObject("method1")?.strMap() ?: emptyMap(), r, x.getJSONObject("gmr").strMap())
                }
            }
            val g = o.getJSONObject("gmrParams")
            return RetargetTables(rb.getJSONObject("defaults").strMap(),
                rb.getJSONArray("mirrored").let { a -> (0 until a.length()).map { a.getString(it) }.toSet() }, sup,
                ord, m1.getJSONObject("axes").intMap(), ds,
                GmrParams(g.getDouble("lambda").toFloat(), g.getInt("iterations"), g.getDouble("wEnd").toFloat(), g.getDouble("wMid").toFloat(),
                    g.getDouble("wFootRot").toFloat(), g.getDouble("wTorsoRot").toFloat(), g.getDouble("wHeadRot").toFloat(), g.getDouble("wRest").toFloat()))
        }
    }
}

enum class RetargetMethod(val title: String) { NAMES("関節名"), GMR("GMR"), GMRQP("GMR + QP") }

/** 関節名が <limb>-<joint>-<r|p|y> の決まりのロボットか (両脚と片腕以上) */
fun robotSupportsRetarget(m: RobotModel): Boolean {
    val limbs = setOf("larm", "rarm", "lleg", "rleg", "head", "torso")
    val have = HashSet<String>()
    for (j in m.joints) { val p = j.name.split("-"); if (p.size == 3 && p[0] in limbs && p[2] in setOf("r", "p", "y")) have.add(p[0]) }
    return "lleg" in have && "rleg" in have && ("larm" in have || "rarm" in have)
}

// ---- 移し替え ----

class BvhRetargeter(val model: RobotModel, val motion: BvhMotion, val tables: RetargetTables) {
    class Limb(val name: String, val chain: IntArray, val first: Int, val mid: Int?, val endLink: Int, val endOffset: FloatArray, val footLink: Int?) {
        var len1 = 0f; var len2 = 0f
    }
    private class M1(val bvh: Int, val joint: Int, val axis: Int, val sign: Float)
    private sealed class Task { class Pos(val link: Int, val off: FloatArray, val target: FloatArray, val w: Float) : Task(); class Rot(val link: Int, val target: FloatArray, val w: Float) : Task() }

    val dataset = tables.datasets[motion.kind]
    val mirrored = model.name in tables.mirrored
    private val jointIndex = model.joints.withIndex().associate { it.value.name to it.index }
    private val rootLink = model.links.indexOfFirst { it.parent < 0 }.coerceAtLeast(0)
    private val m1 = ArrayList<M1>()
    val limbs = HashMap<String, Limb>()
    private var chestLink = rootLink; private var headLink: Int? = null
    private var torsoChain = IntArray(0); private var headChain = IntArray(0)
    private val zeroW: List<Tf>
    private val restAngles: FloatArray
    private var ankleHeight = 0f; private var rootHeight = 0f
    private val h = HashMap<String, Int>(); private val hEnd = HashMap<String, Int>()
    private var F0 = M3.I
    private val restW: List<Tf>
    private val hLen = HashMap<String, Float>()
    private var h0 = 0.08f
    private val footSlope = hashMapOf("l" to 0.3f, "r" to 0.3f)
    var restUpright = true; private set
    var sLeg = 1f; private set
    var sArm = 1f; private set
    private var calib: FloatArray? = null
    private var root0 = FloatArray(3); private var rot0 = M3.I; private var C = M3.I
    /** GMR の最後のコマの, 手首・足首の目標とのずれ (m, 確認用) */
    val residual = HashMap<String, Float>()
    private var q: FloatArray
    private var lastFrame = -10
    val method1OK: Boolean
    val gmrOK: Boolean

    private fun depth(link: Int): Int { var d = 0; var l = link; while (l >= 0) { l = model.links[l].parent; d++ }; return d }
    private fun isAncestorOrSelf(a: Int, l0: Int): Boolean { var x = l0; while (x >= 0) { if (x == a) return true; x = model.links[x].parent }; return false }
    private fun chain(prefix: String, to: Int) = model.joints.indices.filter { model.joints[it].name.startsWith(prefix) && !model.joints[it].linear && isAncestorOrSelf(model.joints[it].link, to) }
        .sortedBy { depth(model.joints[it].link) }.toIntArray()

    init {
        q = FloatArray(model.joints.size)
        val bvhIndex = HashMap<String, Int>()
        for ((i, j) in motion.joints.withIndex()) bvhIndex.putIfAbsent(j.name, i)
        // 方法 1 (kxreus eusview-retarget.l の :names と同じ)
        val ds = dataset
        val rule = ds?.rule
        if (ds != null && rule != null) {
            for ((limb, joint) in tables.order) {
                val key = "$limb-$joint"
                val b = ds.method1[key]?.let { bvhIndex[it] } ?: continue
                var s = rule.signs[key] ?: 1f
                if (mirrored && (limb == "rarm" || limb == "rleg")) s = -s
                for (c in listOf("r", "p", "y")) {
                    val ax = tables.axes[c] ?: continue; val src = rule.src[c] ?: continue
                    val k = jointIndex["$key-$c"] ?: continue
                    if (model.joints[k].linear) continue
                    if (rule.axisSign == "cumulative" && model.joints[k].axis[ax] < 0) s = -s
                    m1.add(M1(b, k, src, s))
                }
            }
        }
        method1OK = m1.isNotEmpty()
        if (ds != null) for ((k, n) in ds.gmr) {
            if (n.startsWith("end:")) {
                val p = bvhIndex[n.removePrefix("end:")]
                val e = motion.ends.indexOfFirst { it.parent == p }
                if (p != null && e >= 0) hEnd[k] = e
            } else bvhIndex[n]?.let { h[k] = it }
        }
        // ロボットの部位
        zeroW = robotFK(model, q, Tf.id())
        restAngles = model.poses?.get("reset-pose")?.takeIf { it.size == q.size }?.copyOf() ?: q.copyOf()
        val resetW = robotFK(model, restAngles, Tf.id())   // 床からの高さは reset-pose で (kxreus と同じ)
        var zmin = Float.MAX_VALUE
        for ((i, l) in model.links.withIndex()) for (me in l.meshes) {
            var k = 0; val v = me.vertices
            while (k + 2 < v.size) { zmin = min(zmin, resetW[i].apply(floatArrayOf(v[k], v[k + 1], v[k + 2]))[2]); k += 3 }
        }
        if (zmin == Float.MAX_VALUE) zmin = 0f
        rootHeight = resetW[rootLink].p[2] - zmin
        for (limb in listOf("larm", "rarm", "lleg", "rleg")) makeLimb(limb)?.let { limbs[limb] = it }
        (limbs["lleg"] ?: limbs["rleg"])?.let { ankleHeight = resetW[it.endLink].apply(it.endOffset)[2] - zmin }
        val arm = limbs["larm"] ?: limbs["rarm"]
        chestLink = if (arm != null) model.links[arm.first].parent.let { if (it >= 0) it else rootLink } else rootLink
        torsoChain = chain("torso-", chestLink)
        model.joints.indices.filter { model.joints[it].name.startsWith("head-") }.maxByOrNull { depth(model.joints[it].link) }?.let { d ->
            headLink = model.joints[d].link; headChain = chain("head-", model.joints[d].link)
        }
        val needed = listOf("pelvis", "chest", "neck", "lhip", "rhip", "lknee", "rknee", "lankle", "rankle")
        gmrOK = ds != null && needed.all { h[it] != null } && limbs["lleg"] != null && limbs["rleg"] != null
        restW = motion.restPose()
        val lh = h["lhip"]; val rh = h["rhip"]; val pv = h["pelvis"]; val nk = h["neck"]
        if (lh != null && rh != null && pv != null && nk != null) F0 = frameFromYZ(V3.sub(restW[lh].p, restW[rh].p), V3.sub(restW[nk].p, restW[pv].p))
        val lk = h["lknee"]
        if (lh != null && lk != null) restUpright = F0[8] > 0.9f && V3.norm(V3.sub(restW[lk].p, restW[lh].p))[2] < -0.9f
        if (gmrOK) prepareHuman()
        q = restAngles.copyOf()
        // 方法 1 のルート: コマ 0 の腰の向き (yaw) を除く回転 C (kxreus と同じ)
        val p0 = motion.pose(0)
        val pr = h["pelvis"] ?: 0
        root0 = p0.world[pr].p; rot0 = p0.world[pr].r
        val v = M3.mv(M3.mul(rot0, M3.t(motion.baseRot)), floatArrayOf(1f, 0f, 0f))
        C = M3.rotZ(-atan2(v[1], v[0]))
        if (ds?.rule?.calibrate == true) {
            val a0 = method1Raw(p0.local)
            calib = FloatArray(a0.size) { a0[it] - restAngles[it] }
        }
    }

    private fun frameFromYZ(y: FloatArray, up: FloatArray): FloatArray {
        val yy = V3.norm(y); val x = V3.norm(V3.cross(yy, up)); val z = V3.cross(x, yy)
        return M3.cols(x, yy, z)
    }

    private fun makeLimb(limb: String): Limb? {
        val js = model.joints.indices.filter { model.joints[it].name.startsWith("$limb-") && !model.joints[it].linear }
        if (js.isEmpty()) return null
        fun minDepth(c: List<Int>) = c.minByOrNull { depth(model.joints[it].link) }
        val firstJ = minDepth(js)!!
        val arm = limb.endsWith("arm")
        val midJ = minDepth(js.filter { model.joints[it].name.contains(if (arm) "-elbow-" else "-knee-") })
        val endJ = minDepth(js.filter { model.joints[it].name.contains(if (arm) "-wrist-" else "-ankle-") })
        var endLink: Int; var endOff = FloatArray(3)
        if (endJ != null) endLink = model.joints[endJ].link
        else {
            // 手首の関節がない (KHR など): 肘から先のリンクのいちばん低い点 (関節角 0 で腕は下を向く)
            val base = midJ?.let { model.joints[it].link } ?: model.joints[js.maxByOrNull { depth(model.joints[it].link) }!!].link
            var best: Triple<Float, Int, FloatArray>? = null
            for ((i, l) in model.links.withIndex()) if (isAncestorOrSelf(base, i)) for (me in l.meshes) {
                var k = 0; val v = me.vertices
                while (k + 2 < v.size) {
                    val p = floatArrayOf(v[k], v[k + 1], v[k + 2]); val z = zeroW[i].apply(p)[2]
                    if (best == null || z < best.first) best = Triple(z, i, p); k += 3
                }
            }
            val b = best
            if (b != null) { endLink = b.second; endOff = b.third } else endLink = base
        }
        var foot: Int? = null
        if (!arm) foot = js.filter { isAncestorOrSelf(endLink, model.joints[it].link) || isAncestorOrSelf(model.joints[it].link, endLink) }
            .maxByOrNull { depth(model.joints[it].link) }?.let { model.joints[it].link }
        val tip = foot?.let { if (depth(it) > depth(endLink)) it else endLink } ?: endLink
        val L = Limb(limb, chain("$limb-", tip), model.joints[firstJ].link, midJ?.let { model.joints[it].link }, endLink, endOff, foot)
        val p0 = zeroW[L.first].p; val pe = zeroW[endLink].apply(endOff)
        val mid = L.mid
        if (mid != null) { val pm = zeroW[mid].p; L.len1 = V3.dist(p0, pm); L.len2 = V3.dist(pm, pe) }
        else { L.len1 = V3.dist(p0, pe) / 2; L.len2 = L.len1 }
        return L
    }

    // ---- 人の準備 (GMR) ----

    private fun hp(w: List<Tf>, ends: List<FloatArray>?, k: String): FloatArray? {
        h[k]?.let { return w[it].p }
        val e = hEnd[k]
        return if (e != null && ends != null) ends[e] else null
    }

    private fun prepareHuman() {
        val w0 = motion.pose(0).world
        fun d(a: String, b: String): Float { val pa = hp(w0, null, a) ?: return 0f; val pb = hp(w0, null, b) ?: return 0f; return V3.dist(pa, pb) }
        for (s in listOf("l", "r")) {
            hLen["${s}arm1"] = d("${s}shoulder", "${s}elbow"); hLen["${s}arm2"] = d("${s}elbow", "${s}wrist")
            hLen["${s}leg1"] = d("${s}hip", "${s}knee"); hLen["${s}leg2"] = d("${s}knee", "${s}ankle")
        }
        val hl = (hLen["lleg1"]!! + hLen["lleg2"]!! + hLen["rleg1"]!! + hLen["rleg2"]!!) / 2
        val rl = ((limbs["lleg"]?.let { it.len1 + it.len2 } ?: 0f) + (limbs["rleg"]?.let { it.len1 + it.len2 } ?: 0f)) / 2
        sLeg = if (hl > 0.01f && rl > 0f) rl / hl else 1f
        val ha = (hLen["larm1"]!! + hLen["larm2"]!! + hLen["rarm1"]!! + hLen["rarm2"]!!) / 2
        val na = listOfNotNull(limbs["larm"], limbs["rarm"]).size
        val ra = ((limbs["larm"]?.let { it.len1 + it.len2 } ?: 0f) + (limbs["rarm"]?.let { it.len1 + it.len2 } ?: 0f)) / max(1, na)
        sArm = if (ha > 0.01f && ra > 0f) ra / ha else sLeg
        // 足首の立っているときの高さと, 足が床にあるときの足首 → つま先の傾き
        val zs = ArrayList<Float>()
        val sl = hashMapOf("l" to ArrayList<Float>(), "r" to ArrayList<Float>())
        val samples = ArrayList<FloatArray>()   // [l=0/r=1, az, tz, slope]
        val n = motion.frames; val step = max(1, n / 300)
        var i = 0
        while (i < n) {
            val w = motion.pose(i).world; val e = motion.endPositions(w)
            for ((si, s) in listOf("l", "r").withIndex()) {
                val a = hp(w, e, "${s}ankle") ?: continue
                zs.add(a[2])
                val t = hp(w, e, "${s}toe") ?: continue
                val dxy = sqrt((t[0] - a[0]) * (t[0] - a[0]) + (t[1] - a[1]) * (t[1] - a[1]))
                samples.add(floatArrayOf(si.toFloat(), a[2], t[2], atan2(a[2] - t[2], max(dxy, 1e-4f))))
            }
            i += step
        }
        zs.sort()
        if (zs.isNotEmpty()) h0 = zs[zs.size / 10]
        for (x in samples) if (x[1] < h0 + 0.03f && x[2] < 0.05f) sl[if (x[0] == 0f) "l" else "r"]!!.add(x[3])
        for (s in listOf("l", "r")) { val v = sl[s]!!; if (v.isNotEmpty()) { v.sort(); footSlope[s] = v[v.size / 2] } }
    }

    /** 体節の今の向き = G · G_rest^T · F0 */
    private fun segFrame(w: List<Tf>, k: String): FloatArray? { val j = h[k] ?: return null; return M3.mul(M3.mul(w[j].r, M3.t(restW[j].r)), F0) }

    // ---- 方法 1 (関節名) ----

    private fun method1Raw(local: Array<FloatArray>): FloatArray {
        val a = restAngles.copyOf()
        val cache = HashMap<Int, FloatArray>()
        for (e in m1) {
            val w = cache.getOrPut(e.bvh) { V3.scale(M3.log(local[e.bvh]), (180.0 / Math.PI).toFloat()) }
            val j = model.joints[e.joint]
            a[e.joint] = (e.sign * w[e.axis]).coerceIn(j.min ?: -1e9f, j.max ?: 1e9f)
        }
        return a
    }

    fun method1(i: Int): Pair<FloatArray, Tf> {
        val p = motion.pose(i)
        val a = method1Raw(p.local)
        calib?.let { c -> for ((k, j) in model.joints.withIndex()) a[k] = (a[k] - c[k]).coerceIn(j.min ?: -1e9f, j.max ?: 1e9f) }
        val pr = h["pelvis"] ?: 0
        val R = M3.mul(M3.mul(C, M3.mul(p.world[pr].r, M3.t(rot0))), M3.t(C))
        val pv = p.world[pr].p
        val T = Tf(R, floatArrayOf(sLeg * pv[0], sLeg * pv[1], 0f))
        T.p[2] = placeHeight(a, T, p.world)
        return a to T
    }

    private fun footPoint(W: List<Tf>, L: Limb) = W[L.endLink].apply(L.endOffset)

    private fun placeHeight(a: FloatArray, T: Tf, w: List<Tf>): Float {
        val W = robotFK(model, a, T)
        var z = -Float.MAX_VALUE
        val ends = motion.endPositions(w)
        for (s in listOf("l", "r")) {
            val L = limbs["${s}leg"] ?: continue
            val hz = hp(w, ends, "${s}ankle")?.get(2) ?: h0
            val want = ankleHeight + sLeg * max(0f, hz - h0)
            z = max(z, want - (footPoint(W, L)[2] - T.p[2]))   // T の今の高さによらない (GMR は T.z を入れてから呼ぶ)
        }
        return if (z > -Float.MAX_VALUE) z else rootHeight
    }

    // ---- 方法 2 (GMR) ----

    fun resetGMR() { q = restAngles.copyOf(); lastFrame = -10 }

    fun gmr(i: Int): Pair<FloatArray, Tf> {
        if (!gmrOK) return method1(i)
        if (abs(i - lastFrame) > 30) q = restAngles.copyOf()
        lastFrame = i
        val prm = tables.gmr
        val w = motion.pose(i).world; val ends = motion.endPositions(w)
        val P = segFrame(w, "pelvis")!!
        val Cc = segFrame(w, "chest") ?: P
        val Hd = segFrame(w, "head")
        val pv = w[h["pelvis"]!!].p
        val T = Tf(P, floatArrayOf(sLeg * pv[0], sLeg * pv[1], 0f))
        if (torsoChain.isNotEmpty()) solve(torsoChain, T, listOf(Task.Rot(chestLink, M3.mul(Cc, zeroW[chestLink].r), prm.wTorsoRot)), 1f)
        val hl = headLink
        if (hl != null && headChain.isNotEmpty() && Hd != null) solve(headChain, T, listOf(Task.Rot(hl, M3.mul(Hd, zeroW[hl].r), prm.wHeadRot)), 1f)
        // 腕: 胸から見た人の肘・手首の向き (体節ごとにスケール) を, ロボットの肩から
        var W = robotFK(model, q, T)
        val Cr = M3.mul(W[chestLink].r, M3.t(zeroW[chestLink].r))
        val CrCt = M3.mul(Cr, M3.t(Cc))
        for (s in listOf("l", "r")) {
            val L = limbs["${s}arm"] ?: continue
            val hs = hp(w, ends, "${s}shoulder") ?: continue; val he = hp(w, ends, "${s}elbow") ?: continue; val hw = hp(w, ends, "${s}wrist") ?: continue
            val l1 = hLen["${s}arm1"] ?: 0f; val l2 = hLen["${s}arm2"] ?: 0f
            if (l1 <= 1e-4f || l2 <= 1e-4f) continue
            val ps = W[L.first].p
            val el = V3.add(ps, M3.mv(CrCt, V3.scale(V3.sub(he, hs), L.len1 / l1)))
            val wr = V3.add(el, M3.mv(CrCt, V3.scale(V3.sub(hw, he), L.len2 / l2)))
            val tasks = arrayListOf<Task>(Task.Pos(L.endLink, L.endOffset, wr, prm.wEnd))
            L.mid?.let { tasks.add(Task.Pos(it, FloatArray(3), el, prm.wMid)) }
            residual["${s}arm"] = solveLimb(L, T, tasks, wr)
        }
        // 脚: 股から人の膝・足首の向き (体節ごとにスケール). 高さは足首が床より下にならないように決める
        W = robotFK(model, q, T)
        val targets = HashMap<String, Triple<FloatArray, FloatArray, FloatArray?>>()
        var rootZ = -Float.MAX_VALUE
        for (s in listOf("l", "r")) {
            val L = limbs["${s}leg"] ?: continue
            val hh = hp(w, ends, "${s}hip") ?: continue; val hk = hp(w, ends, "${s}knee") ?: continue; val ha = hp(w, ends, "${s}ankle") ?: continue
            val l1 = hLen["${s}leg1"] ?: 0f; val l2 = hLen["${s}leg2"] ?: 0f
            if (l1 <= 1e-4f || l2 <= 1e-4f) continue
            val ph = W[L.first].p
            val kn = V3.add(ph, V3.scale(V3.sub(hk, hh), L.len1 / l1))
            val an = V3.add(kn, V3.scale(V3.sub(ha, hk), L.len2 / l2))
            val want = ankleHeight + sLeg * max(0f, ha[2] - h0)
            rootZ = max(rootZ, want - an[2])
            var fr: FloatArray? = null
            val ft = L.footLink
            if (ft != null) {
                val F = if (restUpright) segFrame(w, "${s}ankle") else null
                if (F != null) fr = M3.mul(F, zeroW[ft].r)
                else hp(w, ends, "${s}toe")?.let { toe ->
                    val d = V3.sub(toe, ha)
                    val dxy = sqrt(d[0] * d[0] + d[1] * d[1])
                    if (dxy > 1e-3f) {
                        val yaw = atan2(d[1], d[0])
                        val pitch = (atan2(-d[2], dxy) - (footSlope[s] ?: 0f)).coerceIn(-0.8f, 0.8f)
                        fr = M3.mul(M3.mul(M3.rotZ(yaw), M3.rotY(pitch)), zeroW[ft].r)
                    }
                }
            }
            targets[s] = Triple(kn, an, fr)
        }
        if (rootZ == -Float.MAX_VALUE) rootZ = rootHeight
        T.p[2] = rootZ
        for (s in listOf("l", "r")) {
            val L = limbs["${s}leg"] ?: continue
            val t = targets[s] ?: continue
            val dz = floatArrayOf(0f, 0f, rootZ)
            val an = V3.add(t.second, dz)
            val tasks = arrayListOf<Task>(Task.Pos(L.endLink, L.endOffset, an, prm.wEnd))
            L.mid?.let { tasks.add(Task.Pos(it, FloatArray(3), V3.add(t.first, dz), prm.wMid)) }
            val fr = t.third; val ft = L.footLink
            if (fr != null && ft != null) tasks.add(Task.Rot(ft, fr, prm.wFootRot))
            residual["${s}leg"] = solveLimb(L, T, tasks, an)
        }
        T.p[2] = placeHeight(q, T, w)
        return q.copyOf() to T
    }

    /** 手足の IK. 局所解 (目標から手足の長さの 15% より離れた) なら reset-pose から解き直して近い方 */
    private fun solveLimb(L: Limb, root: Tf, tasks: List<Task>, target: FloatArray): Float {
        val len = L.len1 + L.len2
        val q0 = q.copyOf()
        solve(L.chain, root, tasks, len)
        val e1 = V3.dist(footPoint(robotFK(model, q, root), L), target)
        if (e1 < 0.15f * len) return e1
        val q1 = q.copyOf()
        q = q0
        for (k in L.chain) q[k] = restAngles[k]
        solve(L.chain, root, tasks, len)
        val e2 = V3.dist(footPoint(robotFK(model, q, root), L), target)
        if (e2 < e1) return e2
        q = q1
        return e1
    }

    private fun solve(chain: IntArray, root: Tf, tasks: List<Task>, scale: Float) {
        val n = chain.size
        if (n == 0) return
        val prm = tables.gmr
        val sc = max(scale, 1e-3f)
        val lam2 = (prm.lambda * prm.lambda).toDouble(); val wr = prm.wRest.toDouble()
        repeat(max(1, prm.iterations)) {
            val W = robotFK(model, q, root)
            val Hm = DoubleArray(n * n); val g = DoubleArray(n)
            var err = 0f
            val axes = chain.map { k -> val j = model.joints[k]; V3.norm(M3.mv(W[j.link].r, j.axis)) to W[j.link].p }
            for (t in tasks) {
                val e: FloatArray; val w: Float
                val J = Array(n) { FloatArray(3) }
                when (t) {
                    is Task.Pos -> {
                        val p = W[t.link].apply(t.off)
                        e = V3.scale(V3.sub(t.target, p), 1f / sc); w = t.w
                        for ((c, k) in chain.withIndex()) if (isAncestorOrSelf(model.joints[k].link, t.link)) J[c] = V3.scale(V3.cross(axes[c].first, V3.sub(p, axes[c].second)), 1f / sc)
                    }
                    is Task.Rot -> {
                        e = M3.log(M3.mul(t.target, M3.t(W[t.link].r))); w = t.w
                        for ((c, k) in chain.withIndex()) if (isAncestorOrSelf(model.joints[k].link, t.link)) J[c] = axes[c].first
                    }
                }
                err = max(err, V3.len(e) * w)
                val w2 = (w * w).toDouble()
                for (a in 0 until n) {
                    g[a] += w2 * V3.dot(J[a], e)
                    for (b in a until n) Hm[a * n + b] += w2 * V3.dot(J[a], J[b])
                }
            }
            if (err < 1e-4f) return
            for (a in 0 until n) {
                for (b in 0 until a) Hm[a * n + b] = Hm[b * n + a]
                Hm[a * n + a] += lam2 + wr
                g[a] -= wr * Math.toRadians((q[chain[a]] - restAngles[chain[a]]).toDouble())
            }
            if (!solveLinear(Hm, g, n)) return
            for ((c, k) in chain.withIndex()) {
                val j = model.joints[k]
                val v = q[k] + Math.toDegrees(g[c]).toFloat().coerceIn(-20f, 20f)   // 1 回に 20° まで
                q[k] = v.coerceIn(j.min ?: -180f, j.max ?: 180f)
            }
        }
    }

    /** ルートの変換 (robotFK の root) → ルートのリンクのワールドの変換 */
    fun rootLinkPose(T: Tf) = T * model.links[rootLink].restTf()

    /** 全部のコマの関節角とルート (RobotMotion). 初めのコマの腰の水平の位置を 0 にする. cancelled() が true なら null */
    fun makeMotion(method: RetargetMethod, name: String, progress: ((Double) -> Unit)? = null, cancelled: (() -> Boolean)? = null): RobotMotion? {
        val frames = ArrayList<FloatArray>(motion.frames); val roots = ArrayList<FloatArray>(motion.frames)
        resetGMR()
        var x0: Float? = null; var y0 = 0f
        for (i in 0 until motion.frames) {
            if (i % 200 == 0) { if (cancelled?.invoke() == true) return null; progress?.invoke(i.toDouble() / max(1, motion.frames)) }
            val (a, T) = if (method != RetargetMethod.NAMES) gmr(i) else method1(i)   // GMR + QP は makeGmrQpMotion (WholeBodyQp.kt)
            if (x0 == null) { x0 = T.p[0]; y0 = T.p[1] }
            T.p[0] -= x0; T.p[1] -= y0
            frames.add(a); roots.add(rootLinkPose(T).xyzRot())
        }
        progress?.invoke(1.0)
        return RobotMotion(name, motion.fps.toFloat(), frames, roots)
    }
}
