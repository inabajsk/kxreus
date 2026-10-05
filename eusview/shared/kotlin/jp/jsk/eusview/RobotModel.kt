// RobotModel.kt : eus2json.l が書き出すロボットの JSON (単位 m・度, EusLisp の座標: z が上)
//   iOS 版 RobotModel.swift / PhysicsSim.swift の構造体と同じ. Json.kt の JsonReader (android.util.JsonReader と同じ使い方) で読む
//   Android 版とデスクトップ版で共通 (android.* を使わない)
package jp.jsk.eusview

import java.io.InputStream
import java.io.InputStreamReader

class RobotMesh(val color: FloatArray, val vertices: FloatArray, val indices: IntArray)

class RobotLink(
    val name: String, val parent: Int, val pos: FloatArray, val rot: FloatArray, val meshes: List<RobotMesh>,
) {
    /** 親リンクから見た関節角 0 のときの変換 (列優先 4x4, android.opengl.Matrix と同じ並び) */
    val rest: FloatArray
        get() = Mat.fromPosRot(pos, rot)
}

class RobotJoint(
    val name: String, val link: Int, val type: String, val axis: FloatArray, val min: Float?, val max: Float?,
) {
    val linear get() = type == "linear"
}

class RobotMotion(val name: String, val fps: Float, val frames: List<FloatArray>, val root: List<FloatArray>?)

// 物理パラメータ (eus2physics.l, README の「物理パラメータ」)
class PhysShape(
    val type: String, val size: DoubleArray?, val radius: Double?, val length: Double?,
    val pos: DoubleArray?, val rot: DoubleArray?,
)
class PhysLink(val mass: Double?, val com: DoubleArray?, val inertia: DoubleArray?, val shapes: List<PhysShape>?)
class PhysJoint(val motor: String?, val fmax: Double?, val vmax: Double?, val kp: Double?)
class PhysWorld(
    val gravity: DoubleArray?, val dt: Double?, val erp: Double?, val cfm: Double?,
    val quickstep: Boolean?, val iterations: Int?,
)
class PhysContact(
    val mu: Double?, val softErp: Double?, val softCfm: Double?, val bounce: Double?,
    val bounceVel: Double?, val maxContacts: Int?,
)
class PhysMotor(val kp: Double?, val fmax: Double?)
class Physics(
    val links: List<PhysLink>?, val joints: List<PhysJoint>?, val world: PhysWorld?,
    val contact: PhysContact?, val odedynaMotor: PhysMotor?,
)

class RobotModel(
    val name: String, val source: String?, val links: List<RobotLink>, val joints: List<RobotJoint>,
    val poses: Map<String, FloatArray>?, val motions: List<RobotMotion>?, val physics: Physics?,
) {
    companion object {
        fun parse(input: InputStream): RobotModel =
            JsonReader(InputStreamReader(input.buffered(1 shl 16), Charsets.UTF_8)).use { RobotJson(it).model() }
    }
}

/** ストリームで読む (余分なキーは読み飛ばす) */
private class RobotJson(val r: JsonReader) {
    private inline fun obj(f: (String) -> Unit) {
        r.beginObject()
        while (r.hasNext()) f(r.nextName())
        r.endObject()
    }
    private inline fun <T> list(f: () -> T): List<T> {
        val out = ArrayList<T>()
        r.beginArray()
        while (r.hasNext()) out.add(f())
        r.endArray()
        return out
    }
    private fun isNull(): Boolean = if (r.peek() == JsonToken.NULL) { r.nextNull(); true } else false
    private fun str(): String? = if (isNull()) null else r.nextString()
    private fun num(): Double? = if (isNull()) null else r.nextDouble()

    private var fbuf = FloatArray(1024)
    fun floats(): FloatArray {
        var n = 0
        r.beginArray()
        while (r.hasNext()) {
            if (n == fbuf.size) fbuf = fbuf.copyOf(n * 2)
            fbuf[n++] = if (r.peek() == JsonToken.NULL) { r.nextNull(); 0f } else r.nextDouble().toFloat()
        }
        r.endArray()
        return fbuf.copyOf(n)
    }
    private var ibuf = IntArray(1024)
    fun ints(): IntArray {
        var n = 0
        r.beginArray()
        while (r.hasNext()) {
            if (n == ibuf.size) ibuf = ibuf.copyOf(n * 2)
            ibuf[n++] = r.nextInt()
        }
        r.endArray()
        return ibuf.copyOf(n)
    }
    fun doubles(): DoubleArray? = if (isNull()) null else floatsD()
    private fun floatsD(): DoubleArray {
        val out = ArrayList<Double>()
        r.beginArray()
        while (r.hasNext()) out.add(num() ?: 0.0)
        r.endArray()
        return out.toDoubleArray()
    }

    fun model(): RobotModel {
        var name = ""; var source: String? = null
        var links: List<RobotLink> = emptyList(); var joints: List<RobotJoint> = emptyList()
        var poses: Map<String, FloatArray>? = null; var motions: List<RobotMotion>? = null; var physics: Physics? = null
        obj { k ->
            when (k) {
                "name" -> name = str() ?: ""
                "source" -> source = str()
                "links" -> links = list { link() }
                "joints" -> joints = list { joint() }
                "poses" -> { val m = LinkedHashMap<String, FloatArray>(); obj { m[it] = floats() }; poses = m }
                "motions" -> motions = list { motion() }
                "physics" -> physics = physics()
                else -> r.skipValue()
            }
        }
        return RobotModel(name, source, links, joints, poses, motions, physics)
    }

    fun link(): RobotLink {
        var name = ""; var parent = -1; var pos = FloatArray(3); var rot = floatArrayOf(1f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, 1f)
        var meshes: List<RobotMesh> = emptyList()
        obj { k ->
            when (k) {
                "name" -> name = str() ?: ""
                "parent" -> parent = r.nextInt()
                "pos" -> pos = floats()
                "rot" -> rot = floats()
                "meshes" -> meshes = list { mesh() }
                else -> r.skipValue()
            }
        }
        return RobotLink(name, parent, pos, rot, meshes)
    }

    fun mesh(): RobotMesh {
        var color = floatArrayOf(0.7f, 0.7f, 0.7f, 1f); var v = FloatArray(0); var ix = IntArray(0)
        obj { k ->
            when (k) {
                "color" -> color = floats()
                "vertices" -> v = floats()
                "indices" -> ix = ints()
                else -> r.skipValue()
            }
        }
        return RobotMesh(color, v, ix)
    }

    fun joint(): RobotJoint {
        var name = ""; var link = 0; var type = "rotational"; var axis = floatArrayOf(0f, 0f, 1f)
        var mn: Float? = null; var mx: Float? = null
        obj { k ->
            when (k) {
                "name" -> name = str() ?: ""
                "link" -> link = r.nextInt()
                "type" -> type = str() ?: "rotational"
                "axis" -> axis = floats()
                "min" -> mn = num()?.toFloat()
                "max" -> mx = num()?.toFloat()
                else -> r.skipValue()
            }
        }
        return RobotJoint(name, link, type, axis, mn, mx)
    }

    fun motion(): RobotMotion {
        var name = ""; var fps = 30f; var frames: List<FloatArray> = emptyList(); var root: List<FloatArray>? = null
        obj { k ->
            when (k) {
                "name" -> name = str() ?: ""
                "fps" -> fps = (num() ?: 30.0).toFloat()
                "frames" -> frames = list { floats() }
                "root" -> root = if (isNull()) null else list { floats() }
                else -> r.skipValue()
            }
        }
        return RobotMotion(name, fps, frames, root)
    }

    fun physics(): Physics? {
        if (isNull()) return null
        var links: List<PhysLink>? = null; var joints: List<PhysJoint>? = null; var world: PhysWorld? = null
        var contact: PhysContact? = null; var motor: PhysMotor? = null
        obj { k ->
            when (k) {
                "links" -> links = list { physLink() }
                "joints" -> joints = list { physJoint() }
                "world" -> world = physWorld()
                "contact" -> contact = physContact()
                "odedyna_motor" -> motor = physMotor()
                else -> r.skipValue()
            }
        }
        return Physics(links, joints, world, contact, motor)
    }

    fun physLink(): PhysLink {
        var mass: Double? = null; var com: DoubleArray? = null; var inertia: DoubleArray? = null
        var shapes: List<PhysShape>? = null
        obj { k ->
            when (k) {
                "mass" -> mass = num()
                "com" -> com = doubles()
                "inertia" -> inertia = doubles()
                "shapes" -> shapes = if (isNull()) null else list { physShape() }
                else -> r.skipValue()
            }
        }
        return PhysLink(mass, com, inertia, shapes)
    }

    fun physShape(): PhysShape {
        var type = ""; var size: DoubleArray? = null; var radius: Double? = null; var length: Double? = null
        var pos: DoubleArray? = null; var rot: DoubleArray? = null
        obj { k ->
            when (k) {
                "type" -> type = str() ?: ""
                "size" -> size = doubles()
                "radius" -> radius = num()
                "length" -> length = num()
                "pos" -> pos = doubles()
                "rot" -> rot = doubles()
                else -> r.skipValue()
            }
        }
        return PhysShape(type, size, radius, length, pos, rot)
    }

    fun physJoint(): PhysJoint {
        var motor: String? = null; var fmax: Double? = null; var vmax: Double? = null; var kp: Double? = null
        obj { k ->
            when (k) {
                "motor" -> motor = str()
                "fmax" -> fmax = num()
                "vmax" -> vmax = num()
                "kp" -> kp = num()
                else -> r.skipValue()
            }
        }
        return PhysJoint(motor, fmax, vmax, kp)
    }

    fun physWorld(): PhysWorld {
        var g: DoubleArray? = null; var dt: Double? = null; var erp: Double? = null; var cfm: Double? = null
        var quick: Boolean? = null; var it: Int? = null
        obj { k ->
            when (k) {
                "gravity" -> g = doubles()
                "dt" -> dt = num()
                "erp" -> erp = num()
                "cfm" -> cfm = num()
                "quickstep" -> quick = if (isNull()) null else r.nextBoolean()
                "iterations" -> it = num()?.toInt()
                else -> r.skipValue()
            }
        }
        return PhysWorld(g, dt, erp, cfm, quick, it)
    }

    fun physContact(): PhysContact {
        var mu: Double? = null; var se: Double? = null; var sc: Double? = null; var b: Double? = null
        var bv: Double? = null; var mc: Int? = null
        obj { k ->
            when (k) {
                "mu" -> mu = num()
                "soft_erp" -> se = num()
                "soft_cfm" -> sc = num()
                "bounce" -> b = num()
                "bounce_vel" -> bv = num()
                "max_contacts" -> mc = num()?.toInt()
                else -> r.skipValue()
            }
        }
        return PhysContact(mu, se, sc, b, bv, mc)
    }

    fun physMotor(): PhysMotor {
        var kp: Double? = null; var fmax: Double? = null
        obj { k ->
            when (k) {
                "kp" -> kp = num()
                "fmax" -> fmax = num()
                else -> r.skipValue()
            }
        }
        return PhysMotor(kp, fmax)
    }
}

/** 4x4 行列 (列優先 FloatArray(16)) の小さな道具 */
object Mat {
    fun identity() = FloatArray(16).also { it[0] = 1f; it[5] = 1f; it[10] = 1f; it[15] = 1f }

    /** 位置と回転 (3x3 行優先) から */
    fun fromPosRot(p: FloatArray, r: FloatArray): FloatArray {
        val m = FloatArray(16)
        for (row in 0..2) for (c in 0..2) m[c * 4 + row] = r[row * 3 + c]
        m[12] = p[0]; m[13] = p[1]; m[14] = p[2]; m[15] = 1f
        return m
    }

    /** [x y z r00..r22] (動作の root, odesim の linkPoses) から */
    fun fromXyzRot(v: FloatArray, off: Int = 0): FloatArray {
        val m = FloatArray(16)
        for (row in 0..2) for (c in 0..2) m[c * 4 + row] = v[off + 3 + row * 3 + c]
        m[12] = v[off]; m[13] = v[off + 1]; m[14] = v[off + 2]; m[15] = 1f
        return m
    }

    /** a · b (android.opengl.Matrix.multiplyMM と同じ) */
    fun mul(a: FloatArray, b: FloatArray): FloatArray {
        val m = FloatArray(16)
        for (c in 0..3) {
            val b0 = b[c * 4]; val b1 = b[c * 4 + 1]; val b2 = b[c * 4 + 2]; val b3 = b[c * 4 + 3]
            for (r in 0..3) m[c * 4 + r] = a[r] * b0 + a[4 + r] * b1 + a[8 + r] * b2 + a[12 + r] * b3
        }
        return m
    }

    /** 軸 (x, y, z) まわりに deg 度回す (android.opengl.Matrix.setRotateM と同じ式) */
    fun rotate(deg: Float, x0: Float, y0: Float, z0: Float): FloatArray {
        val m = identity()
        val a = deg * (Math.PI / 180.0).toFloat()
        val s = kotlin.math.sin(a.toDouble()).toFloat(); val c = kotlin.math.cos(a.toDouble()).toFloat()
        // 座標軸のときは android.opengl.Matrix と同じく 0 と 1 をそのまま入れる
        if (x0 == 1f && y0 == 0f && z0 == 0f) { m[5] = c; m[10] = c; m[6] = s; m[9] = -s; return m }
        if (x0 == 0f && y0 == 1f && z0 == 0f) { m[0] = c; m[10] = c; m[8] = s; m[2] = -s; return m }
        if (x0 == 0f && y0 == 0f && z0 == 1f) { m[0] = c; m[5] = c; m[1] = s; m[4] = -s; return m }
        var x = x0; var y = y0; var z = z0
        val len = kotlin.math.sqrt(x * x + y * y + z * z)
        if (len != 1f && len > 0f) { val k = 1f / len; x *= k; y *= k; z *= k }
        val nc = 1f - c
        val xy = x * y; val yz = y * z; val zx = z * x; val xs = x * s; val ys = y * s; val zs = z * s
        m[0] = x * x * nc + c; m[4] = xy * nc - zs; m[8] = zx * nc + ys
        m[1] = xy * nc + zs; m[5] = y * y * nc + c; m[9] = yz * nc - xs
        m[2] = zx * nc - ys; m[6] = yz * nc + xs; m[10] = z * z * nc + c
        return m
    }

    /** 剛体変換の逆 */
    fun invRigid(a: FloatArray): FloatArray {
        val m = FloatArray(16)
        for (row in 0..2) for (c in 0..2) m[c * 4 + row] = a[row * 4 + c]
        for (row in 0..2) m[12 + row] = -(m[row] * a[12] + m[4 + row] * a[13] + m[8 + row] * a[14])
        m[15] = 1f
        return m
    }

    /** 関節の変換: 回転関節は R(axis, 度), 直動関節は T(axis × mm / 1000) */
    fun joint(j: RobotJoint, value: Float): FloatArray {
        val ax = j.axis
        val n = kotlin.math.sqrt(ax[0] * ax[0] + ax[1] * ax[1] + ax[2] * ax[2]).takeIf { it > 0 } ?: 1f
        if (!j.linear) return rotate(value, ax[0] / n, ax[1] / n, ax[2] / n)
        val m = identity()
        m[12] = ax[0] / n * value / 1000f; m[13] = ax[1] / n * value / 1000f; m[14] = ax[2] / n * value / 1000f
        return m
    }

    fun transformZ(m: FloatArray, x: Float, y: Float, z: Float) = m[2] * x + m[6] * y + m[10] * z + m[14]
}

/** 関節角 (度・mm) からリンクのワールドの位置姿勢 (z が上, m) を求める */
fun forwardKinematics(m: RobotModel, angles: FloatArray, root: FloatArray? = null): List<FloatArray> {
    val local = m.links.map { it.rest }.toMutableList()
    for ((k, j) in m.joints.withIndex()) if (k < angles.size) local[j.link] = Mat.mul(local[j.link], Mat.joint(j, angles[k]))
    val w = ArrayList<FloatArray>()
    for ((i, l) in m.links.withIndex()) w.add(if (l.parent >= 0) Mat.mul(w[l.parent], local[i]) else if (root != null) Mat.mul(root, local[i]) else local[i])
    return w
}
