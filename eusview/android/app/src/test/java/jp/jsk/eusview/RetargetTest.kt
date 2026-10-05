// RetargetTest.kt : BvhRetarget.kt を Mac の JVM で確かめる (iOS 版の tools/retargettest と同じ照合)
//   cd eusview/android && ./gradlew testDebugUnitTest --tests jp.jsk.eusview.RetargetTest   (make test-retarget)
//   方法 1: kxreus eusview-retarget.l :names の書き出し (~/.cache/eusview/retarget-*-names.json, eusview/bvh/retarget-kxreus.l) と比べる
//   方法 2: 全部のコマで解いて, 時間・数でない値・可動範囲・手首 / 足首の目標とのずれ・足の裏の高さ (床に埋まらない: placeHeight)
//   BVH (eusview/bvh/cache) や kxreus の書き出しがなければ何もしない
package jp.jsk.eusview

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Test
import java.io.File

class RetargetTest {
    private val eusview = File(System.getProperty("user.dir")).let { if (File(it, "app").exists()) it.parentFile else it.parentFile.parentFile }
    private val cache = File(eusview, "bvh/cache")

    private fun JSONArray.floats() = FloatArray(length()) { getDouble(it).toFloat() }
    private fun robot(name: String): RobotModel {
        val f = listOf("kxr", "khr", "jsk").map { File(eusview, "robots/$it/$name.json") }.first { it.exists() }
        val o = JSONObject(f.readText())
        val links = o.getJSONArray("links").let { a -> (0 until a.length()).map { i ->
            val l = a.getJSONObject(i)
            val ms = l.optJSONArray("meshes")?.let { m -> (0 until m.length()).map { k -> val x = m.getJSONObject(k)
                RobotMesh(x.getJSONArray("color").floats(), x.getJSONArray("vertices").floats(), IntArray(0)) } } ?: emptyList()
            RobotLink(l.getString("name"), l.getInt("parent"), l.getJSONArray("pos").floats(), l.getJSONArray("rot").floats(), ms)
        } }
        val joints = o.getJSONArray("joints").let { a -> (0 until a.length()).map { i -> val j = a.getJSONObject(i)
            RobotJoint(j.getString("name"), j.getInt("link"), j.getString("type"), j.getJSONArray("axis").floats(),
                if (j.has("min")) j.getDouble("min").toFloat() else null, if (j.has("max")) j.getDouble("max").toFloat() else null) } }
        val poses = o.optJSONObject("poses")?.let { p -> p.keys().asSequence().associateWith { p.getJSONArray(it).floats() } }
        return RobotModel(o.getString("name"), null, links, joints, poses, null, null)
    }
    private val models = HashMap<String, RobotModel>()
    private fun model(n: String) = models.getOrPut(n) { robot(n) }
    private fun ebvh(kind: String, file: String): String {
        var n = file.removePrefix("$kind/").removeSuffix(".bvh").removeSuffix(".BVH").removeSuffix("/poses")
        return "$kind/" + n.replace("/", "_") + ".ebvh"
    }

    @Test fun retarget() {
        if (!File(cache, "index.json").exists()) { println("BVH の cache がないので何もしない"); return }
        val tables = RetargetTables.parse(File(eusview, "bvh/retarget_tables.json").readText())
        val dir = File(System.getProperty("user.home"), ".cache/eusview")
        val fs = dir.listFiles { f -> f.name.startsWith("retarget-") && f.name.endsWith("-names.json") }.orEmpty().sortedBy { it.name }
        println("== 方法 1 (関節名) と kxreus eusview-retarget.l :names の差 (${fs.size} ファイル)")
        val sum = sortedMapOf<String, Array<Any>>()
        for (f in fs) {
            val o = JSONObject(f.readText())
            val kind = o.getString("kind"); val file = o.getString("file"); val rn = o.getString("robot")
            val mo = BvhMotion(File(cache, ebvh(kind, file)).readBytes())
            val m = model(rn)
            val rt = BvhRetargeter(m, mo, tables)
            val names = o.getJSONArray("joints").let { a -> (0 until a.length()).map { a.getString(it) } }
            val cur = sum.getOrPut("$kind $rn") { arrayOf(0f, 0f, 0, "") }
            val frames = o.getJSONArray("frames")
            for (i in 0 until frames.length()) {
                val fr = frames.getJSONObject(i)
                val sf = fr.getInt("frame"); if (sf % mo.step != 0) continue
                val (a, T) = rt.method1(sf / mo.step)
                val ang = fr.getJSONArray("angles").floats(); val root = fr.getJSONArray("root").floats()
                for ((k, n) in names.withIndex()) {
                    if (n.contains("gripper")) continue
                    val j = m.joints.indexOfFirst { it.name == n }
                    val d = kotlin.math.abs(a[j] - ang[k])
                    cur[2] = (cur[2] as Int) + 1
                    if (d > cur[0] as Float) { cur[0] = d; cur[3] = "$file frame $sf $n: app ${a[j]} eus ${ang[k]}" }
                }
                val R = rt.rootLinkPose(T).r
                val E = root.copyOfRange(3, 12)
                cur[1] = maxOf(cur[1] as Float, V3.len(M3.log(M3.mul(M3.t(R), E))) * 57.29578f)
            }
        }
        for ((k, v) in sum) println(String.format("%-28s 関節角 max %.4f° (%d)  ルートの向き max %.3f°  %s", k, v[0], v[2], v[1], v[3]))

        println("== 方法 2 (GMR)")
        for (f in listOf("mocopi/greeting1.ebvh", "rikiya/rbvh_a_A01.ebvh", "sfu/0005_Jogging001.ebvh", "tum-kitchen/0-0.ebvh", "lafan1/walk1_subject1.ebvh")) {
            val mo = BvhMotion(File(cache, f).readBytes())
            for (rn in listOf("kxrl2l6a6h2", "khr20h2", "sample-robot")) {
                val m = model(rn)
                val rt = BvhRetargeter(m, mo, tables)
                var nan = 0; var lim = 0
                val res = HashMap<String, ArrayList<Float>>()
                // 足の裏 (脚の footLink のメッシュ) のいちばん低い点の高さ (GMR の placeHeight: 床に埋まらない. 直す前は sample-robot が 0.71 m 沈んだ)
                val feet = listOf("lleg", "rleg").mapNotNull { rt.limbs[it] }.map { it.footLink ?: it.endLink }
                var footMin = Float.MAX_VALUE; var footMax = -Float.MAX_VALUE
                val t0 = System.nanoTime()
                for (i in 0 until mo.frames) {
                    val (a, T) = rt.gmr(i)
                    if (i % 10 == 0) {
                        val W = robotFK(m, a, T)
                        var z = Float.MAX_VALUE
                        for (l in feet) for (me in m.links[l].meshes) { var k = 0; val v = me.vertices
                            while (k + 2 < v.size) { z = minOf(z, W[l].apply(floatArrayOf(v[k], v[k + 1], v[k + 2]))[2]); k += 3 } }
                        if (z != Float.MAX_VALUE) { footMin = minOf(footMin, z); footMax = maxOf(footMax, z) }
                    }
                    if (a.any { !it.isFinite() } || T.p.any { !it.isFinite() }) nan++
                    for ((k, j) in m.joints.withIndex()) if (a[k] < (j.min ?: -1e9f) - 1e-3f || a[k] > (j.max ?: 1e9f) + 1e-3f) lim++
                    for ((k, v) in rt.residual) res.getOrPut(k) { ArrayList() }.add(v)
                }
                val ms = (System.nanoTime() - t0) / 1e6 / mo.frames
                val s = StringBuilder()
                for (k in listOf("larm", "rarm", "lleg", "rleg")) { val v = res[k] ?: continue; v.sort()
                    s.append(String.format(" %s 中央 %.1f / 95%% %.1f mm", k, v[v.size / 2] * 1000, v[v.size * 95 / 100] * 1000)) }
                println(String.format("%-28s %-13s %5d コマ %.3f ms/コマ  NaN %d  範囲外 %d  s_leg %.3f s_arm %.3f  足の裏の高さ %.1f〜%.1f mm |%s",
                    f, rn, mo.frames, ms, nan, lim, rt.sLeg, rt.sArm, footMin * 1000, footMax * 1000, s))
                // 足首の高さで合わせるので, 足が傾くとつま先・かかとは少し床に入る (脚の長さの 30% まで. 直す前の sample-robot は 0.71 m = 脚の長さ沈んだ)
                val legLen = rt.limbs["lleg"]?.let { it.len1 + it.len2 } ?: 0.2f
                org.junit.Assert.assertTrue("$f $rn: 足の裏が床より下 ${footMin * 1000} mm", footMin > -0.3f * legLen)
                org.junit.Assert.assertEquals("$f $rn NaN", 0, nan)
            }
        }
    }
}
