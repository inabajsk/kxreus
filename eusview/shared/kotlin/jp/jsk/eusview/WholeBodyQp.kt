// WholeBodyQp.kt : 全身の QP (wbqp.h, C++) を Kotlin から使う (iOS 版 QP/WholeBodyQP.swift を移したもの). Android 版とデスクトップ版で共通
//   RobotModel と BvhRetargeter (GMR) から QP のモデルを作り, GMR の答えをコマごとに直す
//   (自己衝突なし・関節の可動範囲 (余裕つき) の中・重心が足の裏の中・床に着いた足を止める). 仕様: eusview/bvh/QP.md
//   C++ は odesim と同じ JNI のライブラリ (libeusviewode: android/app/src/main/cpp/wbqp.{h,cpp} = ios/EusView/QP/ のコピー, wbqp_jni.cpp)
package jp.jsk.eusview

/** wbqp.h の JNI (android/app/src/main/cpp/wbqp_jni.cpp) */
object WbqpNative {
    init { OdeLib.load() }
    @JvmStatic external fun create(): Long
    @JvmStatic external fun destroy(h: Long)
    @JvmStatic external fun addLink(h: Long, parent: Int, rest: DoubleArray): Int
    @JvmStatic external fun addLinkVertices(h: Long, link: Int, xyz: FloatArray)
    @JvmStatic external fun setLinkMass(h: Long, link: Int, mass: Double, com: DoubleArray)
    @JvmStatic external fun addJoint(h: Long, link: Int, type: Int, axis: DoubleArray, lo: Double, hi: Double, vmax: Double): Int
    @JvmStatic external fun addCapsule(h: Long, link: Int, p0: DoubleArray, p1: DoubleArray, radius: Double): Int
    @JvmStatic external fun setHand(h: Long, side: Int, link: Int, offset: DoubleArray)
    @JvmStatic external fun setFoot(h: Long, side: Int, link: Int)
    @JvmStatic external fun excludePair(h: Long, a: Int, b: Int)
    @JvmStatic external fun setParam(h: Long, name: String, value: Double): Int
    @JvmStatic external fun getParam(h: Long, name: String): Double
    @JvmStatic external fun finalizeModel(h: Long, poses: DoubleArray?, n: Int): Int
    @JvmStatic external fun numLinks(h: Long): Int
    @JvmStatic external fun numJoints(h: Long): Int
    @JvmStatic external fun numCapsules(h: Long): Int
    @JvmStatic external fun numPairs(h: Long): Int
    @JvmStatic external fun capsule(h: Long, i: Int, out: DoubleArray)
    @JvmStatic external fun pair(h: Long, i: Int, out: IntArray)
    @JvmStatic external fun sole(h: Long, side: Int, xyz: DoubleArray, max: Int): Int
    @JvmStatic external fun totalMass(h: Long): Double
    @JvmStatic external fun eval(h: Long, q: DoubleArray, root: DoubleArray, support: Int, ev: DoubleArray, flags: IntArray?, poly: DoubleArray?, max: Int): Int
    @JvmStatic external fun fk(h: Long, q: DoubleArray, root: DoubleArray, poses: DoubleArray)
    @JvmStatic external fun reset(h: Long)
    @JvmStatic external fun solve(h: Long, qRef: DoubleArray, rootRef: DoubleArray, contact: Int, support: Int, targets: DoubleArray?,
                                  qOut: DoubleArray, rootOut: DoubleArray, diag: DoubleArray?): Int
    @JvmStatic external fun contactOf(h: Long, q: DoubleArray, root: DoubleArray, prev: Int): Int
    @JvmStatic external fun planContacts(h: Long, n: Int, q: DoubleArray, root: DoubleArray, contact: IntArray, support: IntArray)
    /** GMR + QP + バランス: 全部のコマの参照から重心の軌道 (comOut: n × 5) と contact, support を決める. 戻り値: ZMP の制約を緩めたコマの数 */
    @JvmStatic external fun planBalance(h: Long, n: Int, q: DoubleArray, root: DoubleArray, contact: IntArray, support: IntArray, comOut: DoubleArray): Int
    /** 次の solve の重心の目標 (5 個: x y z, 左・右の足を上げる高さ). null で外す */
    @JvmStatic external fun setComTarget(h: Long, com: DoubleArray?)
    /** 閉ループの MPC (wbqp_mpc_step, planBalance のあとで毎コマ): 今の関節角 (rad / m) とルートのリンクの姿勢 (12 個), そのコマの計画 (QP + バランスの答え)
     *  から, サーボの目標 qOut (rad / m) を出す. info: 8 個 (null 可). 戻り値: 負なら qOut を使わない (-2 = 計画がない). i = 0 で MPC の状態を初期化 */
    @JvmStatic external fun mpcStep(h: Long, i: Int, qMeas: DoubleArray, rootMeas: DoubleArray, qPlan: DoubleArray, rootPlan: DoubleArray,
                                    qOut: DoubleArray, info: DoubleArray?): Int
}

/** 1 つのロボットの評価 (wbqp.h の WbqpEval) */
class WbqpEval(
    val minDist: Double, val pair: IntArray, val nCollide: Int, val nLimit: Int, val nAtLimit: Int, val maxLimitExcess: Double,
    val com: DoubleArray, val comMargin: Double, val footHeight: DoubleArray,
) {
    companion object {
        const val N = 14
        fun of(a: DoubleArray, o: Int = 0) = WbqpEval(a[o], intArrayOf(a[o + 1].toInt(), a[o + 2].toInt()), a[o + 3].toInt(), a[o + 4].toInt(),
            a[o + 5].toInt(), a[o + 6], doubleArrayOf(a[o + 7], a[o + 8], a[o + 9]), a[o + 10], doubleArrayOf(a[o + 11], a[o + 12]))
    }
}

/** wbqp.h の WbqpDiag: 参照 (QP の前) と QP の答えの評価など */
class WbqpDiag(
    val before: WbqpEval, val after: WbqpEval, val contact: Int, val support: Int, val status: Int, val sqpIters: Int, val qpIters: Int,
    val nConstraints: Int, val nCollisionRows: Int, val slackMax: Double, val timeMs: Double,
) {
    companion object {
        const val N = 2 * WbqpEval.N + 9
        fun of(a: DoubleArray): WbqpDiag {
            val o = 2 * WbqpEval.N
            return WbqpDiag(WbqpEval.of(a, 0), WbqpEval.of(a, WbqpEval.N), a[o].toInt(), a[o + 1].toInt(), a[o + 2].toInt(), a[o + 3].toInt(),
                a[o + 4].toInt(), a[o + 5].toInt(), a[o + 6].toInt(), a[o + 7], a[o + 8])
        }
    }
}

/** 1 コマ: 参照 (GMR) と QP の答え (関節角は度・mm, 姿勢はルートのリンクのワールドの姿勢) と評価 */
class QpFrame(val qRef: FloatArray, val rootRef: Tf, val q: FloatArray, val root: Tf, val diag: WbqpDiag)

/** 評価 (表示用): flags はリンクごと (bit0 衝突, bit1 可動範囲の端, bit2 衝突の手前), polygon は支持多角形 (x y の並び, 縮める前) */
class QpView(val eval: WbqpEval, val flags: IntArray, val polygon: FloatArray)

class WholeBodyQp(val model: RobotModel, rt: BvhRetargeter, fps: Double, params: Map<String, Double> = emptyMap()) {
    val h: Long = WbqpNative.create()
    val rootLink = model.links.indexOfFirst { it.parent < 0 }.coerceAtLeast(0)
    private val rootRestInv: Tf
    private val linear = BooleanArray(model.joints.size) { model.joints[it].linear }
    @Volatile private var destroyed = false

    init {
        val ph = model.physics
        for ((i, l) in model.links.withIndex()) {
            WbqpNative.addLink(h, l.parent, pose12(l.restTf()))
            for (me in l.meshes) if (me.vertices.size >= 9) WbqpNative.addLinkVertices(h, i, me.vertices)
            val p = ph?.links?.getOrNull(i)
            val m = p?.mass; val c = p?.com
            if (m != null && c != null && m > 0 && c.size == 3) WbqpNative.setLinkMass(h, i, m, c)
        }
        for ((k, j) in model.joints.withIndex()) {
            val s = if (j.linear) 0.001 else Math.PI / 180
            val vmax = ph?.joints?.getOrNull(k)?.vmax ?: 0.0
            WbqpNative.addJoint(h, j.link, if (j.linear) 1 else 0, DoubleArray(3) { j.axis[it].toDouble() },
                (j.min ?: -180f) * s, (j.max ?: 180f) * s, vmax)
        }
        for ((side, n) in listOf("larm", "rarm").withIndex()) rt.limbs[n]?.let { L ->
            WbqpNative.setHand(h, side, L.endLink, DoubleArray(3) { L.endOffset[it].toDouble() })
        }
        for ((side, n) in listOf("lleg", "rleg").withIndex()) rt.limbs[n]?.let { L -> WbqpNative.setFoot(h, side, L.footLink ?: L.endLink) }
        WbqpNative.setParam(h, "dt", 1.0 / maxOf(fps, 1.0))
        for ((k, v) in params) WbqpNative.setParam(h, k, v)
        // 衝突を調べない組: 関節角 0 と reset-pose で当たっている組
        val r = model.poses?.get("reset-pose")
        if (r != null && r.size == model.joints.size) WbqpNative.finalizeModel(h, toQ(r), 1) else WbqpNative.finalizeModel(h, null, 0)
        val rr = model.links[rootLink].restTf()
        rootRestInv = Tf(M3.t(rr.r), V3.scale(M3.mv(M3.t(rr.r), rr.p), -1f))
    }

    /** C++ の記憶を放す (使い終わったら. 2 度呼んでもよい. ほかのスレッドが使っている間は呼ばない) */
    @Synchronized fun destroy() { if (!destroyed) { destroyed = true; WbqpNative.destroy(h) } }

    val scale get() = WbqpNative.getParam(h, "scale")
    val pairs get() = WbqpNative.numPairs(h)
    val capsules get() = WbqpNative.numCapsules(h)
    val totalMass get() = WbqpNative.totalMass(h)
    fun param(name: String) = WbqpNative.getParam(h, name)

    fun toQ(a: FloatArray) = DoubleArray(a.size) { a[it] * if (linear.getOrElse(it) { false }) 0.001 else Math.PI / 180 }
    fun toAngles(q: DoubleArray) = FloatArray(q.size) { (q[it] * if (linear[it]) 1000.0 else 180 / Math.PI).toFloat() }

    /** 前のコマの答え・MPC の状態を忘れる (計画 (planBalance) は消えない). 閉ループの MPC: 最初に戻す・起き上がりから続けるとき */
    fun reset() = WbqpNative.reset(h)

    /** GMR + MPC (閉ループ): runGmrQpBalance で計画したあと, 物理 (sim) の今の関節角とルートのリンクの姿勢から, コマ i のサーボの目標 (度・mm) を出す.
     *  plan: QP + バランスのコマ i の答え. 解けなければ計画の関節角. info (null 可, 8 個): wbqp.h の wbqp_mpc_step */
    fun mpcStep(i: Int, sim: PhysicsSim, plan: QpFrame, info: DoubleArray? = null): FloatArray {
        val P = sim.linkPoses()[rootLink]
        val rm = pose12(Tf(BalanceStabilizer.rot3(P), floatArrayOf(P[12], P[13], P[14])))
        val qo = DoubleArray(model.joints.size)
        val st = WbqpNative.mpcStep(h, i, toQ(sim.jointValues()), rm, toQ(plan.q), pose12(plan.root), qo, info)
        return if (st >= 0 && qo.all { it.isFinite() }) toAngles(qo) else plan.q
    }
    fun contact(angles: FloatArray, rootLinkPose: Tf, prev: Int) = WbqpNative.contactOf(h, toQ(angles), pose12(rootLinkPose), prev)

    /** 1 コマを解く (前のコマの答えから続ける). contact / support: bit0 左, bit1 右 (-1 = 足の高さで決める) */
    fun solve(angles: FloatArray, rootLinkPose: Tf, contact: Int = -1, support: Int = -1): QpFrame {
        val qo = DoubleArray(model.joints.size); val ro = DoubleArray(12); val d = DoubleArray(WbqpDiag.N)
        WbqpNative.solve(h, toQ(angles), pose12(rootLinkPose), contact, support, null, qo, ro, d)
        return QpFrame(angles, rootLinkPose, toAngles(qo), tf(ro), WbqpDiag.of(d))
    }

    /** 評価 (状態を変えない). support: bit0 左, bit1 右 (-1 = 足の高さで決める) */
    fun view(angles: FloatArray, rootLinkPose: Tf, support: Int = -1): QpView {
        val flags = IntArray(model.links.size); val poly = DoubleArray(64); val ev = DoubleArray(WbqpEval.N)
        val n = WbqpNative.eval(h, toQ(angles), pose12(rootLinkPose), support, ev, flags, poly, 32).coerceIn(0, 32)
        return QpView(WbqpEval.of(ev), flags, FloatArray(2 * n) { poly[it].toFloat() })
    }

    /** ルートのリンクの姿勢 → robotFK の root (BvhRetargeter の T) */
    fun rootT(rootLinkPose: Tf) = rootLinkPose * rootRestInv

    companion object {
        /** 姿勢 → 12 個 (位置, 回転 行優先) */
        fun pose12(t: Tf) = DoubleArray(12) { if (it < 3) t.p[it].toDouble() else t.r[it - 3].toDouble() }
        fun tf(a: DoubleArray) = Tf(FloatArray(9) { a[3 + it].toFloat() }, FloatArray(3) { a[it].toFloat() })
    }
}

/** GMR → QP を全部のコマで計算する (iOS 版 runGMRQP と同じ). 足の先読み (preview コマ) のため GMR を少し先まで解く.
 *  emit(i, frame) をコマごとに呼ぶ. cancelled() が true ならやめる. 戻り値: 最後まで計算したか */
fun runGmrQp(rt: BvhRetargeter, qp: WholeBodyQp, progress: ((Double) -> Unit)? = null, cancelled: (() -> Boolean)? = null,
             emit: (Int, QpFrame) -> Unit): Boolean {
    val n = rt.motion.frames
    val P = maxOf(0, qp.param("preview").toInt())
    val refs = ArrayList<Pair<FloatArray, Tf>>(n); val contacts = ArrayList<Int>(n)
    rt.resetGMR()
    repeat(8) { rt.gmr(0) }   // 初めのコマの IK を収束させる (reset-pose から数コマで大きく動くのを避ける)
    qp.reset()
    var prev = 0
    fun ref(i: Int) {
        while (refs.size <= minOf(i, n - 1)) {
            val (a, T) = rt.gmr(refs.size)
            val pose = rt.rootLinkPose(T)
            prev = qp.contact(a, pose, prev)
            refs.add(a to pose); contacts.add(prev)
        }
    }
    for (i in 0 until n) {
        if (i % 50 == 0) { if (cancelled?.invoke() == true) return false; progress?.invoke(i.toDouble() / maxOf(1, n)) }
        ref(i + P)
        var s = contacts[i]
        for (k in i + 1..minOf(n - 1, i + P)) { val t = s and contacts[k]; if (t == 0) break; s = t }
        emit(i, qp.solve(refs[i].first, refs[i].second, contacts[i], s))
    }
    progress?.invoke(1.0)
    return true
}

/** GMR + QP + バランス (iOS 版 runGMRQPBalance と同じ): GMR を全部のコマで解き, 重心の軌道を先読みの MPC で決めて
 *  (wbqp_plan_balance), その重心を最優先にしてコマごとに解く. emit(i, frame) をコマごとに呼ぶ (計算は 0.6 から先で出てくる).
 *  zmpSlack: ZMP の制約を緩めたコマの数を入れる (null 可). 戻り値: 最後まで計算したか */
fun runGmrQpBalance(rt: BvhRetargeter, qp: WholeBodyQp, progress: ((Double) -> Unit)? = null, cancelled: (() -> Boolean)? = null,
                    zmpSlack: IntArray? = null, emit: (Int, QpFrame) -> Unit): Boolean {
    val n = rt.motion.frames
    if (n <= 0) return true
    val nj = rt.model.joints.size
    val angles = ArrayList<FloatArray>(n); val poses = ArrayList<Tf>(n)
    val qRef = DoubleArray(n * nj); val rootRef = DoubleArray(n * 12)
    rt.resetGMR()
    repeat(8) { rt.gmr(0) }
    for (i in 0 until n) {
        if (i % 100 == 0) { if (cancelled?.invoke() == true) return false; progress?.invoke(0.3 * i / n) }
        val (a, T) = rt.gmr(i)
        val pose = rt.rootLinkPose(T)
        angles.add(a); poses.add(pose)
        qp.toQ(a).copyInto(qRef, i * nj)
        WholeBodyQp.pose12(pose).copyInto(rootRef, i * 12)
    }
    val contact = IntArray(n); val support = IntArray(n); val com = DoubleArray(n * 5)
    val ns = WbqpNative.planBalance(qp.h, n, qRef, rootRef, contact, support, com)
    zmpSlack?.let { if (it.isNotEmpty()) it[0] = ns }
    progress?.invoke(0.6)
    qp.reset()
    try {
        for (i in 0 until n) {
            if (i % 50 == 0) { if (cancelled?.invoke() == true) return false; progress?.invoke(0.6 + 0.4 * i / n) }
            WbqpNative.setComTarget(qp.h, com.copyOfRange(i * 5, i * 5 + 5))
            emit(i, qp.solve(angles[i], poses[i], contact[i], support[i]))
        }
    } finally { WbqpNative.setComTarget(qp.h, null) }
    progress?.invoke(1.0)
    return true
}

/** 計算したコマの集計: (QP の ms/コマ, 衝突の割合 前・後 %, 重心が外の割合 前・後 % (足が着いたコマのうち)) */
fun qpSummary(fr: List<QpFrame>): DoubleArray {
    val n = maxOf(1, fr.size).toDouble()
    val wc = maxOf(1, fr.count { it.diag.contact != 0 }).toDouble()
    return doubleArrayOf(fr.sumOf { it.diag.timeMs } / n,
        100 * fr.count { it.diag.before.nCollide > 0 } / n, 100 * fr.count { it.diag.after.nCollide > 0 } / n,
        100 * fr.count { it.diag.contact != 0 && it.diag.before.comMargin < 0 } / wc,
        100 * fr.count { it.diag.contact != 0 && it.diag.after.comMargin < 0 } / wc)
}

/** GMR + QP (balance なら GMR + QP + バランス) の全部のコマを動作 (RobotMotion) にする (ロボットの画面の「動作」用). やめたら null.
 *  keep (balance のとき): 計算が終わったら計画を持った WholeBodyQp を渡す (閉ループの MPC 用. 使い終わったら受け取った側が destroy) */
fun makeGmrQpMotion(rt: BvhRetargeter, name: String, progress: ((Double) -> Unit)? = null, cancelled: (() -> Boolean)? = null,
                    balance: Boolean = false, keep: ((WholeBodyQp) -> Unit)? = null): Pair<RobotMotion, List<QpFrame>>? {
    val qp = WholeBodyQp(rt.model, rt, rt.motion.fps)
    var kept = false
    try {
        val out = ArrayList<QpFrame>(rt.motion.frames)
        val ok = if (balance) runGmrQpBalance(rt, qp, progress, cancelled) { _, f -> out.add(f) }
                 else runGmrQp(rt, qp, progress, cancelled) { _, f -> out.add(f) }
        if (!ok) return null
        val x0 = out.firstOrNull()?.root?.p?.get(0) ?: 0f; val y0 = out.firstOrNull()?.root?.p?.get(1) ?: 0f
        val roots = out.map { f -> f.root.xyzRot().also { it[0] -= x0; it[1] -= y0 } }
        if (keep != null) { kept = true; keep(qp) }
        return RobotMotion(name, rt.motion.fps.toFloat(), out.map { it.q }, roots) to out
    } finally { if (!kept) qp.destroy() }
}
