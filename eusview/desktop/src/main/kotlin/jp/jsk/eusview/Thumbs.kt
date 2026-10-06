// Thumbs.kt : ロボットの一覧に出す画像 (robots/<グループ>/<名前>.png) を作る
//   ./gradlew run --args="-thumbs ../robots"  (make thumbs). reset-pose を斜め前から, 明るい背景で SIZE × SIZE
//   iPhone・Mac・Android・デスクトップの一覧が同じ画像を使う
package jp.jsk.eusview

import org.jetbrains.skia.EncodedImageFormat
import java.io.File
import java.util.concurrent.CountDownLatch

object Thumbs {
    const val SIZE = 320

    /** 全部の頂点のワールド座標 (間引いて最大 6 万点) */
    private fun worldVertices(scene: RobotScene): FloatArray {
        val m = scene.model
        val w = FloatArray(16 * m.links.size); scene.copyWorld(w)
        val total = m.links.sumOf { l -> l.meshes.sumOf { it.vertices.size / 3 } }
        val step = maxOf(1, total / 60000)
        val out = ArrayList<Float>()
        var c = 0
        for ((i, l) in m.links.withIndex()) for (me in l.meshes) {
            val v = me.vertices; var k = 0; val o = 16 * i
            while (k + 2 < v.size) {
                if (c++ % step == 0) for (d in 0..2) out.add(w[o + d] * v[k] + w[o + 4 + d] * v[k + 1] + w[o + 8 + d] * v[k + 2] + w[o + 12 + d])
                k += 3
            }
        }
        return out.toFloatArray()
    }

    /** 頂点を画面に写したとき, 縦横とも 84% に収まり真ん中に来るように, カメラの注視点と距離を直す (縦の画角 45°, 正方形) */
    private fun fit(cam: OrbitCamera, p: FloatArray) {
        if (p.isEmpty()) return
        val t = kotlin.math.tan(Math.toRadians(22.5)).toFloat()
        repeat(4) {
            val e = cam.eye(); val g = cam.target
            val f = floatArrayOf(g[0] - e[0], g[1] - e[1], g[2] - e[2]).let { v -> val n = kotlin.math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]); FloatArray(3) { v[it] / n } }
            val rt = floatArrayOf(f[1], -f[0], 0f).let { v -> val n = kotlin.math.sqrt(v[0] * v[0] + v[1] * v[1]); FloatArray(3) { v[it] / n } }
            val up = floatArrayOf(rt[1] * f[2] - rt[2] * f[1], rt[2] * f[0] - rt[0] * f[2], rt[0] * f[1] - rt[1] * f[0])
            var x0 = Float.MAX_VALUE; var x1 = -Float.MAX_VALUE; var y0 = Float.MAX_VALUE; var y1 = -Float.MAX_VALUE
            var k = 0
            while (k + 2 < p.size) {
                val dx = p[k] - e[0]; val dy = p[k + 1] - e[1]; val dz = p[k + 2] - e[2]
                val z = dx * f[0] + dy * f[1] + dz * f[2]
                if (z > 1e-4f) {
                    val x = (dx * rt[0] + dy * rt[1] + dz * rt[2]) / (z * t)
                    val y = (dx * up[0] + dy * up[1] + dz * up[2]) / (z * t)
                    if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y
                }
                k += 3
            }
            if (x0 > x1) return
            // 真ん中へ: 注視点を画面の面の中で動かす (注視点の奥行き = dist)
            val cx = (x0 + x1) / 2 * cam.dist * t; val cy = (y0 + y1) / 2 * cam.dist * t
            for (d in 0..2) cam.target[d] += rt[d] * cx + up[d] * cy
            cam.dist *= maxOf(x1 - x0, y1 - y0) / 2 / 0.84f
        }
    }

    fun run(outDir: File, only: String?) {
        val store = DesktopStore.create()
        Platform.store = store
        var n = 0
        for (f in store.robotFiles()) {
            if (only != null && !f.name.contains(only)) continue
            val t0 = System.nanoTime()
            val model = File(f.path).inputStream().buffered(1 shl 16).use { RobotModel.parse(it) }
            val scene = RobotScene(model)
            model.poses?.get("reset-pose")?.let { scene.setAngles(it) }
            // 腰が原点のロボットは脚が床の下に隠れるので, いちばん低い点を床 (z = 0) に置く
            val lowest = scene.bounds()[2]
            if (lowest < -1e-3f) {
                val w = FloatArray(16 * model.links.size); scene.copyWorld(w)
                scene.setWorldPoses(model.links.indices.map { i -> w.copyOfRange(16 * i, 16 * i + 16).also { it[14] -= lowest } })
            }
            val r = DesktopRenderer(scene, false, null)
            r.cam.frame(scene.bounds(), floatArrayOf(2.3f, -1.2f, 0.9f))
            fit(r.cam, worldVertices(scene))
            val done = CountDownLatch(1)
            var err: Throwable? = null
            OffscreenGL.post({
                try {
                    val raw = r.render(SIZE, SIZE)
                    // glReadPixels は下の行から: 上下を返す
                    val src = org.jetbrains.skia.Bitmap.makeFromImage(raw).readPixels()!!
                    raw.close()
                    val row = SIZE * 4
                    val flip = ByteArray(src.size)
                    for (y in 0 until SIZE) System.arraycopy(src, y * row, flip, (SIZE - 1 - y) * row, row)
                    val img = org.jetbrains.skia.Image.makeRaster(org.jetbrains.skia.ImageInfo(SIZE, SIZE, org.jetbrains.skia.ColorType.RGBA_8888, org.jetbrains.skia.ColorAlphaType.OPAQUE), flip, row)
                    val data = img.encodeToData(EncodedImageFormat.PNG) ?: error("PNG にできません")
                    val dir = File(outDir, f.group).also { it.mkdirs() }
                    File(dir, f.name + ".png").writeBytes(data.bytes)
                    img.close(); r.release()
                } finally { done.countDown() }
            }) { e -> err = e; done.countDown() }
            done.await()
            err?.let { throw it }
            n++
            println(String.format("%s/%s.png (%.1f 秒)", f.group, f.name, (System.nanoTime() - t0) / 1e9))
        }
        println("$n 枚を $outDir に書きました")
    }
}
