// RobotScene.kt : RobotModel のリンクの木と関節角から, 各リンクのワールドの変換を求める (iOS 版 RobotScene.swift)
//   リンクの変換 = rest (親から見た関節角 0 の位置姿勢) · R(axis, 角度)  (直動関節は · T(axis · mm/1000))
//   座標は EusLisp と同じ z が上 (描画側のカメラも z を上にする)
package jp.jsk.eusview

class RobotScene(val model: RobotModel) {
    private val rest = model.links.map { it.rest }
    private val local = rest.map { it.copyOf() }.toMutableList()
    var angles = FloatArray(model.joints.size); private set
    private val rootIndex = model.links.indexOfFirst { it.parent < 0 }

    /** 描画スレッドが読む: リンクのワールドの変換 (16 × リンク数) */
    private val world = FloatArray(16 * model.links.size)
    private val lock = Any()
    @Volatile var version = 0L; private set
    /** 変わったときに呼ぶ (GLSurfaceView.requestRender) */
    var onChange: (() -> Unit)? = null

    init { update() }

    fun setAngles(a: FloatArray) {
        for ((k, j) in model.joints.withIndex()) {
            if (k >= a.size) break
            angles[k] = a[k]
            local[j.link] = Mat.mul(rest[j.link], Mat.joint(j, a[k]))
        }
        update()
    }

    /** 動作の 1 コマ: 関節角と, あればルートの位置姿勢 [x y z r00..r22] */
    fun setFrame(motion: RobotMotion, i: Int) {
        val r = motion.root
        if (r != null && i < r.size && r[i].size >= 12 && rootIndex >= 0) local[rootIndex] = Mat.fromXyzRot(r[i])
        setAngles(motion.frames[i])
    }

    /** ルートリンクの位置姿勢を直接置く (live の {"root": ...}) */
    fun setRoot(v: FloatArray) {
        if (v.size >= 12 && rootIndex >= 0) { local[rootIndex] = Mat.fromXyzRot(v); update() }
    }

    /** 物理モード: リンクのワールドの位置姿勢 (z が上) をそのまま当てはめる */
    fun setWorldPoses(w: List<FloatArray>) {
        for ((i, l) in model.links.withIndex()) {
            if (i >= w.size) break
            local[i] = if (l.parent >= 0) Mat.mul(Mat.invRigid(w[l.parent]), w[i]) else w[i]
        }
        update()
    }

    /** 物理モードをやめたとき: ルートを元の位置に戻して関節角で表示 */
    fun resetRoot() { if (rootIndex >= 0) local[rootIndex] = rest[rootIndex].copyOf() }

    private fun update() {
        val w = arrayOfNulls<FloatArray>(model.links.size)
        for ((i, l) in model.links.withIndex()) w[i] = if (l.parent >= 0) Mat.mul(w[l.parent]!!, local[i]) else local[i]
        synchronized(lock) {
            for (i in w.indices) System.arraycopy(w[i]!!, 0, world, 16 * i, 16)
            version++
        }
        onChange?.invoke()
    }

    fun copyWorld(out: FloatArray) = synchronized(lock) { System.arraycopy(world, 0, out, 0, world.size) }

    // ---- 違反の表示 (BVH の画面の GMR / GMR + QP, iOS 版 RetargetFigure.showViolations と同じ) ----
    /** リンクごとの色の上書き (Tint.*, null = なし). 描画スレッドが読む. 次の setWorldPoses などで描き直す */
    @Volatile var tints: IntArray? = null
    /** 重ねて描く印 (重心の球・床の点・支持多角形. ワールドの三角形) */
    @Volatile var overlays: List<Overlay> = emptyList()

    /** ロボット全体が収まる箱 (今の姿勢, カメラの位置決め用): [minx miny minz maxx maxy maxz] */
    fun bounds(): FloatArray {
        val w = FloatArray(world.size); copyWorld(w)
        val b = floatArrayOf(Float.MAX_VALUE, Float.MAX_VALUE, Float.MAX_VALUE, -Float.MAX_VALUE, -Float.MAX_VALUE, -Float.MAX_VALUE)
        for ((i, l) in model.links.withIndex()) for (me in l.meshes) {
            val v = me.vertices; var k = 0; val o = 16 * i
            while (k + 2 < v.size) {
                val x = v[k]; val y = v[k + 1]; val z = v[k + 2]
                for (d in 0..2) {
                    val p = w[o + d] * x + w[o + 4 + d] * y + w[o + 8 + d] * z + w[o + 12 + d]
                    if (p < b[d]) b[d] = p
                    if (p > b[3 + d]) b[3 + d] = p
                }
                k += 3
            }
        }
        if (b[0] == Float.MAX_VALUE) return floatArrayOf(-0.1f, -0.1f, 0f, 0.1f, 0.1f, 0.2f)
        return b
    }
}

/** リンクの色の上書き (RobotScene.tints) */
object Tint {
    const val NONE = 0
    const val COLLIDE = 1   // 赤: 自己衝突しているリンク
    const val LIMIT = 2     // 橙: 関節が可動範囲の端のリンク
    const val FADED = 3     // 薄く: GMR + QP をまだ計算していないコマ
    /** 足す色 (iOS 版の emission と同じ) と不透明度 */
    fun emit(t: Int) = when (t) { COLLIDE -> floatArrayOf(0.95f, 0.05f, 0.05f); LIMIT -> floatArrayOf(1f, 0.5f, 0f); else -> null }
    fun alpha(t: Int) = if (t == FADED) 0.25f else 1f
}

/** 重ねて描く印: 色 (RGBA), 三角形 (ワールド, x y z の並び), onTop = 体に隠れても見せる (重心の球) */
class Overlay(val color: FloatArray, val triangles: FloatArray, val onTop: Boolean = false)
