// SceneCommon.kt : 3D 表示 (Android: OpenGL ES 3.0, デスクトップ: OpenGL 3.2 core) で共通のもの
//   カメラ (注視点のまわりを回る, z が上), 描画用のメッシュ (三角形ごとに頂点を分けて面の法線: 角ばった見た目), 床と格子, 光, 色
package jp.jsk.eusview

import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

/** 注視点のまわりを回るカメラ (z が上) */
class OrbitCamera {
    var target = floatArrayOf(0f, 0f, 0f)
    var dist = 1f
    var yaw = 0f      // rad, x 軸から z 軸まわり
    var pitch = 0f    // rad, 水平から上へ
    var radius = 0.5f
    @Volatile var changed = true

    // iOS 版と同じ向き: SceneKit (x, y 上, z 手前) = (1.6, 0.9, 2.2) r → EusLisp (x, y, z) = (1.6, -2.2, 0.9) r
    fun frame(b: FloatArray, dir: FloatArray = floatArrayOf(1.6f, -2.2f, 0.9f)) {
        target = floatArrayOf((b[0] + b[3]) / 2, (b[1] + b[4]) / 2, (b[2] + b[5]) / 2)
        val d = sqrt((b[3] - b[0]).pow(2) + (b[4] - b[1]).pow(2) + (b[5] - b[2]).pow(2))
        radius = max(d / 2, 0.05f)
        val l = sqrt(dir[0] * dir[0] + dir[1] * dir[1] + dir[2] * dir[2])
        dist = radius * l
        yaw = kotlin.math.atan2(dir[1], dir[0])
        pitch = kotlin.math.asin(dir[2] / l)
        changed = true
    }
    fun eye() = floatArrayOf(
        target[0] + dist * cos(pitch) * cos(yaw), target[1] + dist * cos(pitch) * sin(yaw), target[2] + dist * sin(pitch))
    fun orbit(dx: Float, dy: Float, h: Int) {
        val k = (Math.PI.toFloat() / max(h, 1)) * 1.2f
        yaw -= dx * k
        pitch = (pitch + dy * k).coerceIn(-1.5f, 1.5f)
        changed = true
    }
    fun shift(dx: Float, dy: Float, dz: Float) { target = floatArrayOf(target[0] + dx, target[1] + dy, target[2] + dz); changed = true }
    fun zoom(s: Float) { dist = (dist / s).coerceIn(radius * 0.05f, radius * 40f); changed = true }
    fun pan(dx: Float, dy: Float, h: Int) {
        // 画面の 1 px が注視点の距離で何 m か (縦の画角 45°)
        val m = 2f * dist * kotlin.math.tan(Math.toRadians(22.5).toFloat()) / max(h, 1)
        val rx = -sin(yaw); val ry = cos(yaw)                         // 画面の右
        val ux = -sin(pitch) * cos(yaw); val uy = -sin(pitch) * sin(yaw); val uz = cos(pitch)   // 画面の上
        target = floatArrayOf(target[0] - (rx * dx - ux * dy) * m, target[1] - (ry * dx - uy * dy) * m, target[2] + uz * dy * m)
        changed = true
    }
    /** 近い面と遠い面 (透視投影の) */
    fun near() = max(dist * 0.01f, 0.001f)
    fun far() = dist * 20f + radius * 60f
}

/** 描画用のメッシュ: リンクの番号, 色, 三角形の頂点 (位置 3 + 法線 3) */
class FlatMesh(val link: Int, val color: FloatArray, val data: FloatArray) {
    var vao = 0; var vbo = 0
    val count get() = data.size / 6
}

/** RobotModel のメッシュを, 三角形ごとに頂点を分けて面の法線を付けたものにする */
fun flatMeshes(model: RobotModel): List<FlatMesh> {
    val out = ArrayList<FlatMesh>()
    for ((li, l) in model.links.withIndex()) for (m in l.meshes) {
        val v = m.vertices; val ix = m.indices
        val nt = ix.size / 3
        if (nt == 0) continue
        val d = FloatArray(nt * 18)
        var o = 0
        for (t in 0 until nt) {
            val a = ix[3 * t] * 3; val b = ix[3 * t + 1] * 3; val c = ix[3 * t + 2] * 3
            if (a + 2 >= v.size || b + 2 >= v.size || c + 2 >= v.size) continue
            val e1x = v[b] - v[a]; val e1y = v[b + 1] - v[a + 1]; val e1z = v[b + 2] - v[a + 2]
            val e2x = v[c] - v[a]; val e2y = v[c + 1] - v[a + 1]; val e2z = v[c + 2] - v[a + 2]
            var nx = e1y * e2z - e1z * e2y; var ny = e1z * e2x - e1x * e2z; var nz = e1x * e2y - e1y * e2x
            val n = sqrt(nx * nx + ny * ny + nz * nz)
            if (n > 0f && n.isFinite()) { nx /= n; ny /= n; nz /= n } else { nx = 0f; ny = 0f; nz = 1f }
            for (p in intArrayOf(a, b, c)) {
                d[o++] = v[p]; d[o++] = v[p + 1]; d[o++] = v[p + 2]; d[o++] = nx; d[o++] = ny; d[o++] = nz
            }
        }
        val col = FloatArray(4) { if (it < m.color.size) m.color[it] else 1f }
        out.add(FlatMesh(li, col, if (o == d.size) d else d.copyOf(o)))
    }
    return out
}

/** 床 (z = 0) の 2 つの三角形. r: ロボットの大きさ (カメラの radius), grid: [間隔, 半分の幅] m か null */
fun floorTriangles(r: Float, grid: FloatArray?): FloatArray {
    val big = max(max(r * 30f, 3f), (grid?.get(1) ?: 0f) * 1.5f)
    return floatArrayOf(-big, -big, 0f, big, -big, 0f, big, big, 0f, -big, -big, 0f, big, big, 0f, -big, big, 0f)
}

/** 床の格子の線: 間隔はロボットの大きさに合わせる (10 cm, 1 m ...) */
fun gridLines(r: Float, grid: FloatArray?): FloatArray {
    val step = grid?.get(0) ?: 10f.pow(floor(log10(r)))
    val half = grid?.get(1) ?: (step * kotlin.math.ceil(r * 4f / step))
    val lines = ArrayList<Float>()
    var x = -half
    while (x <= half + step * 0.01f) {
        lines.addAll(listOf(x, -half, 0f, x, half, 0f, -half, x, 0f, half, x, 0f)); x += step
    }
    return lines.toFloatArray()
}

/** 光 1: カメラの左上の前から (視点に合わせて回す). 光 2 は真上 (0, 0, 1) */
fun keyLight(e: FloatArray, t: FloatArray): FloatArray {
    val vx = e[0] - t[0]; val vy = e[1] - t[1]; val vz = e[2] - t[2]
    val vl = sqrt(vx * vx + vy * vy + vz * vz)
    val rx = -vy; val ry = vx   // 右
    val rl = max(sqrt(rx * rx + ry * ry), 1e-6f)
    var l1x = vx / vl - 0.5f * rx / rl; var l1y = vy / vl - 0.5f * ry / rl; var l1z = vz / vl + 0.8f
    val l1 = sqrt(l1x * l1x + l1y * l1y + l1z * l1z); l1x /= l1; l1y /= l1; l1z /= l1
    return floatArrayOf(l1x, l1y, l1z)
}

/** 背景・床・格子の色 (RGBA) */
object SceneColors {
    fun clear(dark: Boolean) = if (dark) floatArrayOf(0.07f, 0.07f, 0.08f, 1f) else floatArrayOf(1f, 1f, 1f, 1f)
    fun floor(dark: Boolean) = if (dark) floatArrayOf(0.22f, 0.22f, 0.24f, 1f) else floatArrayOf(0.92f, 0.92f, 0.92f, 1f)
    fun grid(dark: Boolean) = if (dark) floatArrayOf(0.32f, 0.32f, 0.35f, 1f) else floatArrayOf(0.82f, 0.82f, 0.82f, 1f)
    const val AMBIENT = 0.32f
}

// ---- 重ねて描く印 (Overlay) の形 ----
object OverlayShapes {
    /** 中心 c, 半径 r の球の三角形 (緯度 8 × 経度 12) */
    fun sphere(c: FloatArray, r: Float): FloatArray {
        val nl = 8; val nm = 12
        fun p(i: Int, k: Int): FloatArray {
            val th = Math.PI * i / nl; val ph = 2 * Math.PI * k / nm
            return floatArrayOf(c[0] + (r * sin(th) * cos(ph)).toFloat(), c[1] + (r * sin(th) * sin(ph)).toFloat(), c[2] + (r * cos(th)).toFloat())
        }
        val out = ArrayList<Float>()
        for (i in 0 until nl) for (k in 0 until nm) {
            val a = p(i, k); val b = p(i, k + 1); val cc = p(i + 1, k); val d = p(i + 1, k + 1)
            for (v in listOf(a, cc, b, b, cc, d)) { out.add(v[0]); out.add(v[1]); out.add(v[2]) }
        }
        return out.toFloatArray()
    }
    /** 床に平らな円 (中心 x y, 高さ z) */
    fun disk(x: Float, y: Float, z: Float, r: Float, n: Int = 24): FloatArray {
        val out = FloatArray(9 * n)
        for (k in 0 until n) {
            val a0 = 2 * Math.PI * k / n; val a1 = 2 * Math.PI * (k + 1) / n
            val o = 9 * k
            out[o] = x; out[o + 1] = y; out[o + 2] = z
            out[o + 3] = x + (r * cos(a0)).toFloat(); out[o + 4] = y + (r * sin(a0)).toFloat(); out[o + 5] = z
            out[o + 6] = x + (r * cos(a1)).toFloat(); out[o + 7] = y + (r * sin(a1)).toFloat(); out[o + 8] = z
        }
        return out
    }
    /** 床に平らな凸多角形 (xy: x y の並び, 高さ z) */
    fun polygon(xy: FloatArray, z: Float): FloatArray {
        val n = xy.size / 2
        if (n < 3) return FloatArray(0)
        val out = FloatArray(9 * (n - 2))
        for (k in 1 until n - 1) {
            val o = 9 * (k - 1)
            out[o] = xy[0]; out[o + 1] = xy[1]; out[o + 2] = z
            out[o + 3] = xy[2 * k]; out[o + 4] = xy[2 * k + 1]; out[o + 5] = z
            out[o + 6] = xy[2 * k + 2]; out[o + 7] = xy[2 * k + 3]; out[o + 8] = z
        }
        return out
    }
}
