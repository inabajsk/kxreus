// BvhData.kt : BVH（モーションキャプチャ）を eusview/bvh/convert_bvh.py で変換した .ebvh を読み, 関節のワールドの変換を求める
//   (iOS 版 BVHData.swift と同じ). アプリのデータ (Platform.store) の bvh/ (= eusview/bvh/cache/ をビルドのときにコピー) の index.json と <種類>/<名前>.ebvh
//   .ebvh = "EBVH" + uint32 ヘッダの長さ + ヘッダ (JSON) + コマのデータ (位置 int32 0.1 mm, 回転 int16 0.01 度, リトルエンディアン)
//   関節のローカルの変換 = T(位置のチャンネル か OFFSET) · R(ch1) · R(ch2) · R(ch3) (BVH のチャンネルの順)
//   ワールド (EusLisp の座標, z が上, m) = base · (BVH の座標の変換, m)
package jp.jsk.eusview

import org.json.JSONArray
import org.json.JSONObject
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.cos
import kotlin.math.sin

class BvhIndexFile(val name: String, val file: String, val frames: Int, val fps: Double, val duration: Double, val joints: Int)
class BvhIndexKind(val name: String, val title: String, val unit: String, val height: Double, val duration: Double, val files: List<BvhIndexFile>)
/** 再生する 1 本 (種類とファイル) */
class BvhEntry(val kind: String, val file: BvhIndexFile)

private fun JSONArray.objects() = (0 until length()).map { getJSONObject(it) }
private fun JSONArray.floats() = FloatArray(length()) { getDouble(it).toFloat() }

/** アプリに入っている BVH の一覧 (bvh/index.json). なければ null */
fun loadBvhIndex(): List<BvhIndexKind>? = try {
    val o = JSONObject(Platform.store.open("bvh/index.json").use { it.readBytes().toString(Charsets.UTF_8) })
    o.getJSONArray("kinds").objects().map { k ->
        BvhIndexKind(k.getString("name"), k.optString("title", k.getString("name")), k.optString("unit"), k.optDouble("height"),
            k.optDouble("duration"),
            k.getJSONArray("files").objects().map { f ->
                BvhIndexFile(f.getString("name"), f.getString("file"), f.getInt("frames"), f.getDouble("fps"), f.getDouble("duration"), f.getInt("joints"))
            })
    }
} catch (e: Exception) { null }

class BvhJoint(val name: String, val parent: Int, val offset: FloatArray, val channels: List<String>)
class BvhEnd(val parent: Int, val offset: FloatArray)

/** 1 コマ: 関節のワールドの変換と, ローカルの回転 (3x3 行優先, BVH の軸) */
class BvhPose(val world: List<Tf>, val local: Array<FloatArray>)

class BvhMotion(bytes: ByteArray) {
    val kind: String; val name: String
    val fps: Double; val frames: Int
    val joints: List<BvhJoint>; val ends: List<BvhEnd>
    private val buf: ByteBuffer
    private val dataStart: Int
    private val frameBytes: Int
    private val chJoint: IntArray; private val chKind: IntArray; private val chOff: IntArray   // 種類 0..2 = X/Y/Z 位置, 3..5 = X/Y/Z 回転
    private val posScale: Float; private val rotScale: Float
    private val base: FloatArray          // 列優先 4x4
    /** base の回転 (3x3 行優先, BVH の軸 → 世界) と位置 (m) */
    val baseRot: FloatArray; val basePos: FloatArray
    val step: Int
    val checkFrame: Int; val check: List<FloatArray>?

    init {
        require(bytes.size >= 8 && String(bytes, 0, 4, Charsets.US_ASCII) == "EBVH") { "EBVH の形式ではありません" }
        buf = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        val n = buf.getInt(4)
        val h = JSONObject(String(bytes, 8, n, Charsets.UTF_8))
        dataStart = 8 + n
        kind = h.getString("kind"); name = h.getString("name")
        fps = h.getDouble("fps"); frames = h.getInt("frames")
        posScale = h.getDouble("posScale").toFloat() / 1000f; rotScale = h.getDouble("rotScale").toFloat()
        joints = h.getJSONArray("joints").objects().map { j ->
            val ch = j.getJSONArray("channels")
            BvhJoint(j.getString("name"), j.getInt("parent"), j.getJSONArray("offset").floats(), (0 until ch.length()).map { ch.getString(it) })
        }
        ends = h.getJSONArray("ends").objects().map { BvhEnd(it.getInt("parent"), it.getJSONArray("offset").floats()) }
        val cj = ArrayList<Int>(); val ck = ArrayList<Int>(); val co = ArrayList<Int>()
        var off = 0
        for ((j, jt) in joints.withIndex()) for (c in jt.channels) {
            val axis = "XYZ".indexOf(c.first().uppercaseChar()).coerceAtLeast(0)
            val pos = c.endsWith("position")
            cj.add(j); ck.add((if (pos) 0 else 3) + axis); co.add(off)
            off += if (pos) 4 else 2
        }
        chJoint = cj.toIntArray(); chKind = ck.toIntArray(); chOff = co.toIntArray()
        frameBytes = off
        require(bytes.size >= dataStart + frameBytes * frames) { "コマのデータが足りません" }
        val bz = h.getJSONArray("base").floats()
        base = Mat.fromXyzRot(bz)
        baseRot = bz.copyOfRange(3, 12); basePos = bz.copyOfRange(0, 3)
        step = h.optInt("step", 1)
        val c = h.optJSONObject("check")
        checkFrame = c?.getInt("frame") ?: -1
        check = c?.getJSONArray("joints")?.let { a -> (0 until a.length()).map { a.getJSONArray(it).floats() } }
    }

    /** i コマ目の関節のワールドの変換 (列優先 4x4, EusLisp の座標, z が上, m) */
    fun frame(i0: Int): List<FloatArray> {
        val i = i0.coerceIn(0, frames - 1)
        val nj = joints.size
        val pos = Array(nj) { j -> FloatArray(3) { joints[j].offset[it] / 1000f } }
        val rot = Array(nj) { floatArrayOf(1f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, 1f) }   // 3x3 行優先
        val start = dataStart + frameBytes * i
        for (k in chJoint.indices) {
            val j = chJoint[k]; val t = chKind[k]
            if (t < 3) pos[j][t] = buf.getInt(start + chOff[k]) * posScale
            else rot[j] = mul3(rot[j], rot3(t - 3, buf.getShort(start + chOff[k]) * rotScale))
        }
        val w = ArrayList<FloatArray>(nj)
        for (j in 0 until nj) {
            val local = Mat.fromPosRot(pos[j], rot[j])
            val p = joints[j].parent
            w.add(Mat.mul(if (p >= 0) w[p] else base, local))
        }
        return w
    }

    /** i コマ目の関節のローカルの回転 (3x3 行優先, BVH の軸) とワールドの変換 (Tf, android.opengl を使わない. BvhRetarget.kt 用) */
    fun pose(i0: Int): BvhPose {
        val i = i0.coerceIn(0, frames - 1)
        val nj = joints.size
        val pos = Array(nj) { j -> FloatArray(3) { joints[j].offset[it] / 1000f } }
        val rot = Array(nj) { floatArrayOf(1f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, 1f) }
        val start = dataStart + frameBytes * i
        for (k in chJoint.indices) {
            val j = chJoint[k]; val t = chKind[k]
            if (t < 3) pos[j][t] = buf.getInt(start + chOff[k]) * posScale
            else rot[j] = mul3(rot[j], rot3(t - 3, buf.getShort(start + chOff[k]) * rotScale))
        }
        return BvhPose(worldOf(pos, rot), rot)
    }

    /** 初期姿勢 (回転 0, 位置 = OFFSET) の関節のワールドの変換 */
    fun restPose(): List<Tf> = worldOf(Array(joints.size) { j -> FloatArray(3) { joints[j].offset[it] / 1000f } },
        Array(joints.size) { floatArrayOf(1f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, 1f) })

    /** End Site のワールドの位置 (ends の順) */
    fun endPositions(w: List<Tf>): List<FloatArray> = ends.map { e -> w[e.parent].apply(FloatArray(3) { e.offset[it] / 1000f }) }

    private fun worldOf(pos: Array<FloatArray>, rot: Array<FloatArray>): List<Tf> {
        val w = ArrayList<Tf>(joints.size)
        val b = Tf(baseRot, basePos)
        for ((j, jt) in joints.withIndex()) {
            val l = Tf(rot[j], pos[j])
            w.add(if (jt.parent >= 0) w[jt.parent] * l else b * l)
        }
        return w
    }

    /** 変換したときの値 (check, Python で計算) とのずれの最大 (mm) */
    fun checkError(): Float? {
        val c = check ?: return null
        val w = frame(checkFrame)
        var e = 0f
        for ((j, p) in c.withIndex()) if (j < w.size) {
            val dx = w[j][12] - p[0]; val dy = w[j][13] - p[1]; val dz = w[j][14] - p[2]
            e = maxOf(e, kotlin.math.sqrt(dx * dx + dy * dy + dz * dz) * 1000f)
        }
        return e
    }

    companion object {
        fun load(file: String) = BvhMotion(Platform.store.open("bvh/$file").use { it.readBytes() })

        fun rot3(axis: Int, deg: Float): FloatArray {
            val r = Math.toRadians(deg.toDouble()); val c = cos(r).toFloat(); val s = sin(r).toFloat()
            return when (axis) {
                0 -> floatArrayOf(1f, 0f, 0f, 0f, c, -s, 0f, s, c)
                1 -> floatArrayOf(c, 0f, s, 0f, 1f, 0f, -s, 0f, c)
                else -> floatArrayOf(c, -s, 0f, s, c, 0f, 0f, 0f, 1f)
            }
        }

        fun mul3(a: FloatArray, b: FloatArray) = FloatArray(9) { k ->
            val r = k / 3; val c = k % 3
            a[r * 3] * b[c] + a[r * 3 + 1] * b[3 + c] + a[r * 3 + 2] * b[6 + c]
        }
    }
}
