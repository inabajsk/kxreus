// JsonReaderTest.kt : 共通の JsonReader (shared/kotlin/.../Json.kt) で読んだロボットを org.json で読んだものと比べる (全部のロボットの JSON)
//   cd eusview/android && ./gradlew testDebugUnitTest --tests jp.jsk.eusview.JsonReaderTest   (make test-json)
package jp.jsk.eusview

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.io.StringReader

class JsonReaderTest {
    private val eusview = File(System.getProperty("user.dir")).let { if (File(it, "app").exists()) it.parentFile else it.parentFile.parentFile }

    private fun JSONArray.floats() = FloatArray(length()) { if (isNull(it)) 0f else getDouble(it).toFloat() }
    private fun JSONArray.ints() = IntArray(length()) { getInt(it) }
    private fun JSONArray.objs() = (0 until length()).map { getJSONObject(it) }

    @Test fun robots() {
        val files = listOf("kxr", "khr", "jsk").flatMap { g -> File(eusview, "robots/$g").listFiles { f -> f.name.endsWith(".json") }.orEmpty().toList() }
        assertTrue("ロボットの JSON がありません", files.isNotEmpty())
        var nv = 0L; var t1 = 0L
        for (f in files) {
            val t0 = System.nanoTime()
            val m = f.inputStream().use { RobotModel.parse(it) }
            t1 += System.nanoTime() - t0
            val o = JSONObject(f.readText())
            assertEquals(o.getString("name"), m.name)
            val ls = o.getJSONArray("links").objs()
            assertEquals(f.name, ls.size, m.links.size)
            for ((i, l) in ls.withIndex()) {
                val ml = m.links[i]
                assertEquals(l.getString("name"), ml.name); assertEquals(l.getInt("parent"), ml.parent)
                assertArrayEquals(l.getJSONArray("pos").floats(), ml.pos, 0f)
                assertArrayEquals(l.getJSONArray("rot").floats(), ml.rot, 0f)
                val ms = l.optJSONArray("meshes")?.objs().orEmpty()
                assertEquals(ms.size, ml.meshes.size)
                for ((k, me) in ms.withIndex()) {
                    assertArrayEquals(me.getJSONArray("color").floats(), ml.meshes[k].color, 0f)
                    assertArrayEquals(me.getJSONArray("vertices").floats(), ml.meshes[k].vertices, 0f)
                    assertArrayEquals(me.getJSONArray("indices").ints(), ml.meshes[k].indices)
                    nv += ml.meshes[k].vertices.size / 3
                }
            }
            val js = o.getJSONArray("joints").objs()
            assertEquals(js.size, m.joints.size)
            for ((k, j) in js.withIndex()) {
                val mj = m.joints[k]
                assertEquals(j.getString("name"), mj.name); assertEquals(j.getInt("link"), mj.link)
                assertArrayEquals(j.getJSONArray("axis").floats(), mj.axis, 0f)
                assertEquals(if (j.has("min") && !j.isNull("min")) j.getDouble("min").toFloat() else null, mj.min)
                assertEquals(if (j.has("max") && !j.isNull("max")) j.getDouble("max").toFloat() else null, mj.max)
            }
            o.optJSONObject("poses")?.let { p -> for (k in p.keys()) assertArrayEquals(p.getJSONArray(k).floats(), m.poses!![k], 0f) }
            val mo = o.optJSONArray("motions")?.objs().orEmpty()
            assertEquals(mo.size, m.motions?.size ?: 0)
            for ((k, x) in mo.withIndex()) {
                val fr = x.getJSONArray("frames")
                assertEquals(x.getString("name"), m.motions!![k].name)
                assertEquals(fr.length(), m.motions!![k].frames.size)
                for (i in 0 until fr.length()) assertArrayEquals(fr.getJSONArray(i).floats(), m.motions!![k].frames[i], 0f)
            }
            o.optJSONObject("physics")?.let { ph ->
                val pl = ph.optJSONArray("links")?.objs().orEmpty()
                for ((i, l) in pl.withIndex()) {
                    if (l.has("mass") && !l.isNull("mass")) assertEquals(l.getDouble("mass"), m.physics!!.links!![i].mass!!, 0.0)
                    l.optJSONArray("inertia")?.let { a -> assertArrayEquals(DoubleArray(a.length()) { a.getDouble(it) }, m.physics!!.links!![i].inertia, 0.0) }
                }
                ph.optJSONObject("world")?.let { w -> if (w.has("dt")) assertEquals(w.getDouble("dt"), m.physics!!.world!!.dt!!, 0.0) }
            }
        }
        println(String.format("JsonReaderTest: %d 体, 頂点 %d, RobotModel.parse 計 %.1f 秒", files.size, nv, t1 / 1e9))
    }

    @Test fun tokens() {
        val r = JsonReader(StringReader("""{"a": [1, -2.5e-3, 1e400, 12345678901234567890, "x\"é\n", true, false, null, {}, []], "b": {"c": -0.0}}"""))
        r.beginObject()
        assertEquals("a", r.nextName())
        r.beginArray()
        assertEquals(1, r.nextInt()); assertEquals(-2.5e-3, r.nextDouble(), 0.0); assertEquals(Double.POSITIVE_INFINITY, r.nextDouble(), 0.0)
        assertEquals(12345678901234567890.0, r.nextDouble(), 0.0)
        assertEquals("x\"é\n", r.nextString()); assertEquals(true, r.nextBoolean()); assertEquals(false, r.nextBoolean())
        assertEquals(JsonToken.NULL, r.peek()); r.nextNull()
        r.beginObject(); r.endObject(); r.beginArray(); assertTrue(!r.hasNext()); r.endArray()
        r.endArray()
        assertEquals("b", r.nextName()); r.skipValue()
        r.endObject()
        assertEquals(JsonToken.END_DOCUMENT, r.peek())
    }
}
