// QpTest.kt : GMR + 全身 QP (WholeBodyQp.kt → JNI → wbqp.cpp) を Mac / Linux の JVM で確かめる (iOS 版 tools/qptest.swift と同じ集計)
//   cd eusview/android && make -C ../desktop native && make test-qp
//   JNI のライブラリはデスクトップ版のもの (../desktop/build/native/<os>-<arch>/libeusviewode.{dylib,so}). なければ何もしない
//   コマごとの参照と答えを android/build/qptest/<ロボット>-<種類>_<名前>.csv に書く (qptest -dump と同じ形. 比べる: eusview/bvh/qpcompare.py)
package jp.jsk.eusview

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class QpTest {
    private val eusview = File(System.getProperty("user.dir")).let { if (File(it, "app").exists()) it.parentFile else it.parentFile.parentFile }
    private val cache = File(eusview, "bvh/cache")

    private fun robot(name: String): RobotModel {
        val f = listOf("kxr", "khr", "jsk").map { File(eusview, "robots/$it/$name.json") }.first { it.exists() }
        return f.inputStream().use { RobotModel.parse(it) }
    }

    private fun lib(): File? = File(eusview, "desktop/build/native").listFiles().orEmpty()
        .flatMap { it.listFiles().orEmpty().toList() }.firstOrNull { it.name.startsWith("libeusviewode.") }

    private fun stats(v: List<Float>): Pair<Float, Float> {
        if (v.isEmpty()) return 0f to 0f
        val s = v.sorted()
        return v.sum() / v.size to s[minOf(s.size - 1, s.size * 95 / 100)]
    }
    private fun pct(a: Int, n: Int) = if (n > 0) 100.0 * a / n else 0.0

    @Test fun gmrQp() {
        if (!File(cache, "index.json").exists()) { println("BVH の cache がないので何もしない"); return }
        val so = lib() ?: run { println("デスクトップ版の JNI のライブラリがないので何もしない (make -C ../desktop native)"); return }
        OdeLib.load = { System.load(so.absolutePath) }
        val tables = RetargetTables.parse(File(eusview, "bvh/retarget_tables.json").readText())
        val dump = File(eusview, "android/build/qptest").also { it.mkdirs() }
        val files = (System.getenv("QPTEST_FILES") ?: "mocopi/greeting1.ebvh,rikiya/rbvh_a_A01.ebvh").split(",")
        val robots = (System.getenv("QPTEST_ROBOTS") ?: "kxrl2l6a6h2,khr20h2,sample-robot").split(",")
        for (rn in robots) {
            val m = robot(rn)
            val rl = m.links.indexOfFirst { it.parent < 0 }
            var printed = false
            for (f in files) {
                val mo = BvhMotion(File(cache, f).readBytes())
                val rt = BvhRetargeter(m, mo, tables)
                if (!rt.gmrOK) { println("!! GMR not available $f $rn"); continue }
                val qp = WholeBodyQp(m, rt, mo.fps)
                if (!printed) {
                    printed = true
                    val sole = DoubleArray(60)
                    val ns = WbqpNative.sole(qp.h, 0, sole, 20)
                    println(String.format("== %s: リンク %d 関節 %d, カプセル %d, 調べる組 %d, 質量 %.3f kg, 大きさ (脚) %.3f m, 足の裏の頂点 %d",
                        rn, m.links.size, m.joints.size, qp.capsules, qp.pairs, qp.totalMass, qp.scale, ns))
                }
                val out = ArrayList<QpFrame>()
                val t0 = System.nanoTime()
                assertTrue(runGmrQp(rt, qp) { _, fr -> out.add(fr) })
                val total = (System.nanoTime() - t0) / 1e6
                val n = out.size
                assertEquals(mo.frames, n)
                // コマごとの CSV (qptest -dump と同じ並び)
                File(dump, "$rn-${f.replace("/", "_").removeSuffix(".ebvh")}.csv").printWriter().use { w ->
                    for ((i, fr) in out.withIndex()) {
                        val d = fr.diag
                        val row = arrayListOf("$i", "${d.contact}", "${d.support}", "${d.status}", "${d.before.nCollide}", "${d.after.nCollide}")
                        for (x in doubleArrayOf(d.before.minDist, d.after.minDist, d.before.comMargin, d.after.comMargin)) row.add(String.format("%.6f", x))
                        for (x in WholeBodyQp.pose12(fr.rootRef) + WholeBodyQp.pose12(fr.root)) row.add(String.format("%.6f", x))
                        for (x in fr.qRef + fr.q) row.add(String.format("%.4f", x))
                        w.println(row.joinToString(","))
                    }
                }
                val qpMs = out.map { it.diag.timeMs.toFloat() }
                val (qpMean, qp95) = stats(qpMs)
                val gmrMs = (total - qpMs.sum()) / n
                var cB = 0; var cA = 0; var lB = 0; var lA = 0; var comB = 0; var comA = 0; var withC = 0; var fail = 0
                var minB = 1e9; var minA = 1e9
                val jerr = ArrayList<Float>()
                for (fr in out) {
                    val d = fr.diag
                    if (d.before.nCollide > 0) cB++
                    if (d.after.nCollide > 0) cA++
                    if (d.before.nAtLimit > 0) lB++
                    if (d.after.nAtLimit > 0) lA++
                    if (d.status < 0) fail++
                    minB = minOf(minB, d.before.minDist); minA = minOf(minA, d.after.minDist)
                    if (d.contact != 0) { withC++; if (d.before.comMargin < 0) comB++; if (d.after.comMargin < 0) comA++ }
                    for (k in m.joints.indices) if (!m.joints[k].linear) jerr.add(kotlin.math.abs(fr.q[k] - fr.qRef[k]))
                    // 答えの関節角は可動範囲の中
                    for ((k, j) in m.joints.withIndex()) assertTrue("$rn $f joint ${j.name} ${fr.q[k]}",
                        fr.q[k] >= (j.min ?: -1e9f) - 0.05f && fr.q[k] <= (j.max ?: 1e9f) + 0.05f)
                }
                val (jm, j95) = stats(jerr)
                println(String.format("-- %s × %s: %d コマ (%.0f fps)  GMR %.2f ms/コマ, QP 平均 %.2f / 95%% %.2f / 最大 %.2f ms/コマ, 解けない %d",
                    f, rn, n, mo.fps, gmrMs, qpMean, qp95, qpMs.maxOrNull() ?: 0f, fail))
                println(String.format("   自己衝突 %.1f%% → %.1f%% (最小距離 %.1f → %.1f mm), 可動範囲の端 %.1f%% → %.1f%%, 重心が外 %.1f%% → %.1f%% (足が着いたコマ %d)",
                    pct(cB, n), pct(cA, n), minB * 1000, minA * 1000, pct(lB, n), pct(lA, n), pct(comB, withC), pct(comA, withC), withC))
                println(String.format("   追従のずれ: 関節 平均 %.1f° / 95%% %.1f°", jm, j95))
                assertEquals(0, fail)
                qp.destroy()
            }
        }
    }
}
