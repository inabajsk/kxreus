// PhysicsSim.kt : RobotModel から ODE の物理モデルを作って動かす (eusdyna と同じ: 剛体リンク + サーボ + 床)
//   iOS 版 eusview/ios/EusView/Physics/PhysicsSim.swift を移したもの (式と既定値は同じにしておく)
//   JSON に "physics" (eus2physics.l が書く質量・重心・慣性・サーボ) があれば使い, なければ形から見積もる
package jp.jsk.eusview

import kotlin.math.max
import kotlin.math.min

/** JNI のライブラリを読む (デスクトップ版は OdeNative を使う前に置き換える) */
object OdeLib {
    var load: () -> Unit = { System.loadLibrary("eusviewode") }
}

/** odesim.h の JNI (android/app/src/main/cpp/odesim_jni.cpp) */
object OdeNative {
    init { OdeLib.load() }
    @JvmStatic external fun create(g: DoubleArray, erp: Double, cfm: Double, mu: Double, softErp: Double, softCfm: Double, bounce: Double, iterations: Int): Long
    @JvmStatic external fun destroy(h: Long)
    @JvmStatic external fun setOptions(h: Long, quick: Int, maxContacts: Int, bounceVel: Double)
    @JvmStatic external fun addLink(h: Long, mass: Double, com: DoubleArray, inertia: DoubleArray, pos: DoubleArray, rot: DoubleArray): Int
    @JvmStatic external fun addMesh(h: Long, link: Int, vertices: FloatArray, indices: IntArray)
    @JvmStatic external fun addBox(h: Long, link: Int, size: DoubleArray, pos: DoubleArray, rot: DoubleArray)
    @JvmStatic external fun addCylinder(h: Long, link: Int, radius: Double, length: Double, pos: DoubleArray, rot: DoubleArray)
    @JvmStatic external fun addJoint(h: Long, parent: Int, child: Int, type: Int, anchor: DoubleArray, axis: DoubleArray, lo: Double, hi: Double, fmax: Double, vmax: Double, kp: Double): Int
    @JvmStatic external fun setJointOffset(h: Long, joint: Int, q0: Double, lo: Double, hi: Double)
    @JvmStatic external fun setJointMode(h: Long, joint: Int, mode: Int)
    @JvmStatic external fun setTargets(h: Long, targets: DoubleArray)
    @JvmStatic external fun setServo(h: Long, on: Int)
    @JvmStatic external fun step(h: Long, dt: Double, n: Int)
    @JvmStatic external fun linkPoses(h: Long, n: Int, out: DoubleArray)
    @JvmStatic external fun jointValue(h: Long, joint: Int): Double
    @JvmStatic external fun contacts(h: Long): Int
}

private val ID3 = doubleArrayOf(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)
private val ZERO3 = doubleArrayOf(0.0, 0.0, 0.0)

/** スレッド: 作る・step・setTargets などはすべてメインスレッドから呼ぶ (RobotState) */
class PhysicsSim(val model: RobotModel, angles: FloatArray, val realServo: Boolean = false) {
    private var h: Long
    val dt: Double
    var time = 0.0; private set
    var targets: FloatArray = angles; private set
    private var acc = 0.0
    private val poseBuf = DoubleArray(12 * model.links.size)

    init {
        val ph = model.physics
        dt = ph?.world?.dt ?: 0.001
        val g = ph?.world?.gravity ?: doubleArrayOf(0.0, 0.0, -9.8)
        // 関節の CFM: JSON の 0.01 (SI 単位) だと関節が伸びて 2 cm 沈むので 1e-5 以下にする
        h = OdeNative.create(g, ph?.world?.erp ?: 0.2, min(ph?.world?.cfm ?: 1e-5, 1e-5),
            ph?.contact?.mu ?: 1.0, ph?.contact?.softErp ?: 0.2, ph?.contact?.softCfm ?: 1e-4,
            ph?.contact?.bounce ?: 0.0, ph?.world?.iterations ?: 50)
        OdeNative.setOptions(h, if (ph?.world?.quickstep ?: (ph == null)) 1 else 0, ph?.contact?.maxContacts ?: 4, ph?.contact?.bounceVel ?: 0.05)
        // 初めの姿勢: 足の裏 (メッシュと形状のいちばん低い点) が床に触れる高さに置く
        val w = forwardKinematics(model, angles)
        var zmin = Float.MAX_VALUE
        for ((i, l) in model.links.withIndex()) {
            val T = w[i]
            for (me in l.meshes) {
                val v = me.vertices; var k = 0
                while (k + 2 < v.size) { zmin = min(zmin, Mat.transformZ(T, v[k], v[k + 1], v[k + 2])); k += 3 }
            }
            for (sh in ph?.links?.getOrNull(i)?.shapes ?: emptyList()) for (c in corners(sh)) zmin = min(zmin, Mat.transformZ(T, c[0], c[1], c[2]))
        }
        if (zmin != Float.MAX_VALUE) { val lift = 0.001f - zmin; for (T in w) T[14] += lift }
        for ((i, l) in model.links.withIndex()) {
            val p = ph?.links?.getOrNull(i)
            val (mass, com, inertia) = massProps(l, p)
            val T = w[i]
            val pos = doubleArrayOf(T[12].toDouble(), T[13].toDouble(), T[14].toDouble())
            val rot = DoubleArray(9) { T[(it % 3) * 4 + it / 3].toDouble() }   // 行優先 r[row*3+col] = T[col*4+row]
            val li = OdeNative.addLink(h, mass, com, inertia, pos, rot)
            val shapes = p?.shapes ?: listOf(PhysShape("mesh", null, null, null, null, null))
            for (s in shapes) {
                if (s.type == "box" && s.size != null) {
                    OdeNative.addBox(h, li, s.size, s.pos ?: ZERO3, s.rot ?: ID3)
                } else if (s.type == "cylinder" && s.radius != null && s.length != null) {
                    OdeNative.addCylinder(h, li, s.radius, s.length, s.pos ?: ZERO3, s.rot ?: ID3)
                } else {
                    for (me in l.meshes) if (me.indices.size >= 3) OdeNative.addMesh(h, li, me.vertices, me.indices)
                }
            }
        }
        for ((k, j) in model.joints.withIndex()) {
            val child = j.link; val parent = model.links[child].parent
            val T = w[child]
            val a = j.axis
            var ax = DoubleArray(3) { r -> (T[r] * a[0] + T[4 + r] * a[1] + T[8 + r] * a[2]).toDouble() }
            val n = kotlin.math.sqrt(ax[0] * ax[0] + ax[1] * ax[1] + ax[2] * ax[2])
            if (n > 0) ax = DoubleArray(3) { ax[it] / n }
            val jp = ph?.joints?.getOrNull(k)
            val lin = j.linear
            // 既定は eusdyna (odedyna_motor: kp 10, 力は実質無制限). realServo なら KRS の公称トルク
            val em = ph?.odedynaMotor
            val fmax = if (realServo) (jp?.fmax ?: 1.36) else (em?.fmax ?: jp?.fmax ?: (if (lin) 20.0 else 2.0))
            val vmax = if (realServo) (jp?.vmax ?: 8.0) else 1e6
            val kp = em?.kp ?: jp?.kp ?: 30.0
            OdeNative.addJoint(h, parent, child, if (lin) 1 else 0,
                doubleArrayOf(T[12].toDouble(), T[13].toDouble(), T[14].toDouble()), ax, 0.0, 0.0, fmax, vmax, kp)
            val s = if (lin) 0.001 else Math.PI / 180
            // 可動範囲の端 (ストップ) は 1° (1 mm) 外側に置く. サーボが端に押し付けると軽いリンクで発散するため.
            // 始めの角度が範囲の外なら, それも含める. 目標は setTargets で範囲の中に収める
            val q = (angles.getOrNull(k) ?: 0f).toDouble()
            val lo = (j.min ?: -180f).toDouble(); val hi = (j.max ?: 180f).toDouble()
            OdeNative.setJointOffset(h, k, q * s, (min(lo, q) - 1) * s, (max(hi, q) + 1) * s)
            if (jp?.motor == "rotation") OdeNative.setJointMode(h, k, 1)
        }
        setTargets(angles)
    }

    fun destroy() { if (h != 0L) { OdeNative.destroy(h); h = 0 } }

    /** サーボの目標 (度・mm) */
    fun setTargets(a: FloatArray) {
        targets = a
        val t = DoubleArray(model.joints.size) { k ->
            val j = model.joints[k]
            var v = (a.getOrNull(k) ?: 0f).toDouble()
            if (model.physics?.joints?.getOrNull(k)?.motor != "rotation") v = min(max(v, (j.min ?: -1e6f).toDouble()), (j.max ?: 1e6f).toDouble())
            v * (if (j.linear) 0.001 else Math.PI / 180)
        }
        OdeNative.setTargets(h, t)
    }

    fun setServo(on: Boolean) = OdeNative.setServo(h, if (on) 1 else 0)

    /** 実時間で seconds だけ進める (dt の端数は次に持ち越す) */
    fun step(seconds: Double) {
        acc += seconds
        val n = (acc / dt).toInt()
        if (n > 0) { OdeNative.step(h, dt, n); acc -= n * dt; time += n * dt }
    }

    /** リンクのワールドの位置姿勢 (z が上, 列優先 4x4) */
    fun linkPoses(): List<FloatArray> {
        OdeNative.linkPoses(h, model.links.size, poseBuf)
        return List(model.links.size) { i -> Mat.fromXyzRot(FloatArray(12) { poseBuf[12 * i + it].toFloat() }) }
    }

    /** 関節の今の値 (度・mm) */
    fun jointValues(): FloatArray = FloatArray(model.joints.size) { k ->
        (OdeNative.jointValue(h, k) * (if (model.joints[k].linear) 1000.0 else 180 / Math.PI)).toFloat()
    }

    val contacts: Int get() = OdeNative.contacts(h)

    companion object {
        /** 質量・重心・慣性: JSON の値, なければメッシュの外接箱から密度で見積もる */
        fun massProps(l: RobotLink, p: PhysLink?): Triple<Double, DoubleArray, DoubleArray> {
            val m = p?.mass; val c = p?.com; val I = p?.inertia
            if (m != null && c != null && I != null && m > 0) return Triple(m, c, I)
            val lo = FloatArray(3) { Float.MAX_VALUE }; val hi = FloatArray(3) { -Float.MAX_VALUE }
            for (me in l.meshes) { val v = me.vertices; var k = 0
                while (k + 2 < v.size) { for (d in 0..2) { lo[d] = min(lo[d], v[k + d]); hi[d] = max(hi[d], v[k + d]) }; k += 3 } }
            if (lo[0] == Float.MAX_VALUE) return Triple(0.005, doubleArrayOf(0.0, 0.0, 0.0), doubleArrayOf(1e-7, 0.0, 0.0, 1e-7, 0.0, 1e-7))
            val s = DoubleArray(3) { (hi[it] - lo[it]).toDouble() }; val cc = DoubleArray(3) { ((hi[it] + lo[it]) / 2).toDouble() }
            val mass = max(0.005, s[0] * s[1] * s[2] * 400)   // 樹脂の部品とサーボで平均 400 kg/m³ くらい (目安)
            val In = doubleArrayOf(mass * (s[1] * s[1] + s[2] * s[2]) / 12, 0.0, 0.0, mass * (s[0] * s[0] + s[2] * s[2]) / 12, 0.0, mass * (s[0] * s[0] + s[1] * s[1]) / 12)
            return Triple(mass, cc, In)
        }

        /** 形状の頂点 (リンク座標系, 床に置く高さを決めるため) */
        fun corners(s: PhysShape): List<FloatArray> {
            val hx: Double; val hy: Double; val hz: Double
            if (s.type == "box" && s.size != null) { hx = s.size[0] / 2; hy = s.size[1] / 2; hz = s.size[2] / 2 }
            else if (s.type == "cylinder" && s.radius != null && s.length != null) { hx = s.radius; hy = s.radius; hz = s.length / 2 }
            else return emptyList()
            val p = s.pos ?: ZERO3; val r = s.rot ?: ID3
            val out = ArrayList<FloatArray>()
            for (sx in doubleArrayOf(-1.0, 1.0)) for (sy in doubleArrayOf(-1.0, 1.0)) for (sz in doubleArrayOf(-1.0, 1.0)) {
                val x = sx * hx; val y = sy * hy; val z = sz * hz
                out.add(floatArrayOf((p[0] + r[0] * x + r[1] * y + r[2] * z).toFloat(), (p[1] + r[3] * x + r[4] * y + r[5] * z).toFloat(), (p[2] + r[6] * x + r[7] * y + r[8] * z).toFloat()))
            }
            return out
        }
    }
}
