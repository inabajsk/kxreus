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
    /** 物理: 関節角の列をサーボの目標にしてコマごとに進める (iOS の qptest の simulate と同じ). 初めて 60° より傾いた時刻 (秒, null = 倒れない).
     *  mpc: 閉ループの MPC (runGmrQpBalance で計画した WholeBodyQp): 毎コマ物理の今の状態から目標を出す (qptest の simulate(... mpc:) と同じ) */
    private fun fallTime(m: RobotModel, frames: List<FloatArray>, fps: Double, maxSec: Double, plan: List<QpFrame>? = null, stab: BalanceStabilizer? = null,
                         mpc: WholeBodyQp? = null, record: MutableList<FloatArray>? = null): Double? {
        val rl = m.links.indexOfFirst { it.parent < 0 }
        val b = M3.mv(M3.t(m.links[rl].rot), floatArrayOf(0f, 0f, 1f))
        val sim = PhysicsSim(m, frames[0])
        try {
            sim.step(0.5)
            for ((i, f) in frames.withIndex()) {
                if (i >= maxSec * fps) break
                if (mpc != null && plan != null) sim.setTargets(mpc.mpcStep(i, sim, plan[i]).also { record?.add(it) })
                else if (stab != null && plan != null) sim.setTargets(stab.adjust(f, plan[i].root, plan[i].diag.contact, sim.linkPoses(), (1 / fps).toFloat()))
                else sim.setTargets(f)
                sim.step(1 / fps)
                val up = M3.mv(BalanceStabilizer.rot3(sim.linkPoses()[rl]), b)
                if (!up[2].isFinite() || up[2] < 0.5f) return i / fps
            }
            return null
        } finally { sim.destroy() }
    }

    /** GMR + QP + バランス (runGmrQpBalance) と物理の安定化 (BalanceStabilizer). iOS の qptest -balance 1 と比べる
     *  (Mac の qptest: aiming1 × khr20h2 は GMR+QP も QP+バランスも 30 秒倒れない, walk1 × khr20h2 は GMR+QP 6.8 秒・QP+バランス 19.7 秒)
     *  GMR+MPC (閉ループの MPC, wbqp_mpc_step) も物理で動かす (qptest -mpc 1: walk1 × khr20h2 15.0 秒, aiming1 × khr20h2 20.5 秒で倒れる)
     *  QPTEST_BALANCE_FILES=lafan1/walk1_subject1.ebvh,lafan1/aiming1_subject1.ebvh で両方 */
    @Test fun balance() {
        if (!File(cache, "index.json").exists()) { println("BVH の cache がないので何もしない"); return }
        val so = lib() ?: run { println("デスクトップ版の JNI のライブラリがないので何もしない (make -C ../desktop native)"); return }
        OdeLib.load = { System.load(so.absolutePath) }
        val tables = RetargetTables.parse(File(eusview, "bvh/retarget_tables.json").readText())
        val files = (System.getenv("QPTEST_BALANCE_FILES") ?: "lafan1/walk1_subject1.ebvh").split(",")
        val robots = (System.getenv("QPTEST_BALANCE_ROBOTS") ?: "khr20h2").split(",")
        val maxSec = System.getenv("QPTEST_SEC")?.toDoubleOrNull() ?: 30.0
        for (rn in robots) for (f in files) {
            val m = robot(rn)
            val mo = BvhMotion(File(cache, f).readBytes())
            val rt = BvhRetargeter(m, mo, tables)
            if (!rt.gmrOK) continue
            val out = ArrayList<QpFrame>(); val outB = ArrayList<QpFrame>()
            val qp = WholeBodyQp(m, rt, mo.fps)
            assertTrue(runGmrQp(rt, qp) { _, fr -> out.add(fr) })
            qp.destroy()
            val qb = WholeBodyQp(m, rt, mo.fps)
            val slack = IntArray(1)
            val t0 = System.nanoTime()
            assertTrue(runGmrQpBalance(rt, qb, zmpSlack = slack) { _, fr -> outB.add(fr) })
            val ms = (System.nanoTime() - t0) / 1e6 / maxOf(1, outB.size)
            assertEquals(mo.frames, outB.size)
            for (fr in outB) for ((k, j) in m.joints.withIndex()) assertTrue("$rn $f joint ${j.name} ${fr.q[k]}",
                fr.q[k] >= (j.min ?: -1e9f) - 0.05f && fr.q[k] <= (j.max ?: 1e9f) + 0.05f)
            val feet = listOf("lleg", "rleg").mapNotNull { rt.limbs[it] }.map { it.footLink ?: it.endLink }
            fun s(t: Double?) = t?.let { String.format("%.1f 秒で倒れる", it) } ?: "倒れない"
            val tG = fallTime(m, out.map { it.qRef }, mo.fps, maxSec)
            val tQ = fallTime(m, out.map { it.q }, mo.fps, maxSec)
            val tB0 = fallTime(m, outB.map { it.q }, mo.fps, maxSec)
            val tB = fallTime(m, outB.map { it.q }, mo.fps, maxSec, outB, BalanceStabilizer(m, feet))
            val tm0 = System.nanoTime()
            val rec = ArrayList<FloatArray>()
            val tM = fallTime(m, outB.map { it.q }, mo.fps, maxSec, outB, mpc = qb, record = rec)
            // QPTEST_MPC_DUMP=<フォルダ>: QP+バランスの関節角と MPC の目標を CSV に (qptest -saverobot の balance, mpc_targets と比べる)
            System.getenv("QPTEST_MPC_DUMP")?.let { d ->
                val b = "$d/${rn}-${f.substringAfterLast('/').removeSuffix(".ebvh")}"
                File("$b-balance.csv").printWriter().use { w -> for (fr in outB) w.println(fr.q.joinToString(",")) }
                File("$b-mpc.csv").printWriter().use { w -> for (a in rec) w.println(a.joinToString(",")) }
            }
            val nM = minOf(outB.size, ((tM ?: maxSec) * mo.fps).toInt() + 1)
            val msM = (System.nanoTime() - tm0) / 1e6 / maxOf(1, nM)
            qb.destroy()
            println(String.format("-- %s × %s (%.0f 秒まで): GMR %s, GMR+QP %s, QP+バランス %s (安定化なし %s), GMR+MPC %s, ZMP を緩めたコマ %d, %.2f ms/コマ, MPC と物理 %.2f ms/コマ",
                f, rn, maxSec, s(tG), s(tQ), s(tB), s(tB0), s(tM), slack[0], ms, msM))
        }
    }
    /** 倒れたら起き上がってから続ける (FallRecovery): walk1 × khr20h2 の GMR + QP を物理で 40 秒 (iOS 版と同じ作り) */
    @Test fun recovery() {
        if (!File(cache, "index.json").exists()) return
        val so = lib() ?: return
        OdeLib.load = { System.load(so.absolutePath) }
        val tables = RetargetTables.parse(File(eusview, "bvh/retarget_tables.json").readText())
        val m = robot(System.getenv("QPTEST_RECOVER_ROBOT") ?: "khr20h2")
        val mo = BvhMotion(File(cache, System.getenv("QPTEST_RECOVER_FILE") ?: "lafan1/walk1_subject1.ebvh").readBytes())
        val rt = BvhRetargeter(m, mo, tables)
        val qp = WholeBodyQp(m, rt, mo.fps)
        val out = ArrayList<QpFrame>()
        assertTrue(runGmrQp(rt, qp) { _, fr -> out.add(fr) })
        qp.destroy()
        val rec = FallRecovery(m)
        var sim = PhysicsSim(m, out[0].q)
        sim.step(0.5)
        val dt = 1 / mo.fps
        var i = 0; var steps = 0
        val log = ArrayList<String>()
        var lastPhase = rec.phase
        while (steps < 40 * mo.fps && i < out.size) {
            val r = rec.step(sim, dt, out[i].q) { a -> sim.destroy(); sim = PhysicsSim(m, a); sim.step(0.3) }
            if (r != null) sim.setTargets(r) else { sim.setTargets(out[i].q); i++ }
            sim.step(dt); steps++
            if (rec.phase != lastPhase) { log.add(String.format("%.1f 秒 (コマ %d) %s %s", steps / mo.fps, i, rec.phase, rec.current)); lastPhase = rec.phase }
        }
        sim.destroy()
        println("-- 起き上がり ${m.name}: 起き上がりの動作 うつ伏せ ${rec.getupProne?.name}, 仰向け ${rec.getupSupine?.name}")
        println("   40 秒で動作のコマ $i まで, ${rec.summary}")
        for (l in log) println("   $l")
    }
}
