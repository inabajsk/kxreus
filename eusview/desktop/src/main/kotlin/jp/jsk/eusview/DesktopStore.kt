// DesktopStore.kt : デスクトップ版のデータの置き場所 (ロボットの JSON, BVH) と設定, JNI のライブラリ
//   データの探し方 (先にあるもの):
//     1. 起動の引数 -data <フォルダ> か 環境変数 EUSVIEW_DATA
//     2. -Deusview.repo=<eusview のフォルダ> (./gradlew run が付ける. robots/, bvh/cache/, bvh/retarget_tables.json)
//     3. 配布物の中 (Compose の compose.application.resources.dir/data: robots/, bvh/)
//     4. 今のフォルダから上へ robots/ と bvh/ のあるフォルダ (eusview/)
//   フォルダの形は 2 通り: リポジトリ (bvh/cache/ がある) と配布物 (bvh/ に index.json と retarget_tables.json)
//   設定: $XDG_CONFIG_HOME/eusview/settings.properties (なければ ~/.config/eusview/)
package jp.jsk.eusview

import java.io.File
import java.io.FileNotFoundException
import java.io.InputStream
import java.util.Properties

data class RobotFile(val path: String, val group: String, val name: String)

class DesktopStore(val root: File?, val robotsDir: File?, val bvhDir: File?, val tablesFile: File?) : AppStore {
    private val prefsFile = File(System.getenv("XDG_CONFIG_HOME")?.takeIf { it.isNotEmpty() } ?: (System.getProperty("user.home") + "/.config"), "eusview/settings.properties")
    private val props = Properties().also { p -> try { prefsFile.inputStream().use { p.load(it) } } catch (_: Exception) {} }

    override fun open(path: String): InputStream {
        val f = when {
            path.startsWith("/") -> File(path)
            path.startsWith("robots/") -> robotsDir?.let { File(it, path.removePrefix("robots/")) }
            path == "bvh/retarget_tables.json" -> tablesFile
            path.startsWith("bvh/") -> bvhDir?.let { File(it, path.removePrefix("bvh/")) }
            else -> root?.let { File(it, path) }
        } ?: throw FileNotFoundException(path)
        return f.inputStream().buffered(1 shl 16)
    }

    override fun getString(key: String): String? = synchronized(props) { props.getProperty(key) }
    override fun putString(key: String, value: String) {
        synchronized(props) {
            props.setProperty(key, value)
            try { prefsFile.parentFile.mkdirs(); prefsFile.outputStream().use { props.store(it, "EusView") } }
            catch (e: Exception) { Platform.logError("設定を書けません: $prefsFile", e) }
        }
    }

    /** robots/<グループ>/ の JSON と, -robots <フォルダ> で足したフォルダの JSON (グループは名前から) */
    fun robotFiles(): List<RobotFile> {
        val out = ArrayList<RobotFile>()
        robotsDir?.let { d ->
            for (g in robotGroups) for (f in File(d, g).listFiles { f -> f.name.endsWith(".json") }.orEmpty())
                out.add(RobotFile(f.path, g, f.name.removeSuffix(".json")))
        }
        Launch.get("robots")?.let { File(it) }?.listFiles { f -> f.name.endsWith(".json") }?.forEach { f ->
            val n = f.name
            out.add(RobotFile(f.path, if (n.startsWith("khr")) "khr" else if (n.startsWith("kxr")) "kxr" else "jsk", n.removeSuffix(".json")))
        }
        return out.sortedBy { it.name }
    }

    val description: String get() = "ロボット: ${robotsDir ?: "なし"}  BVH: ${bvhDir ?: "なし"}"

    companion object {
        fun create(): DesktopStore {
            val cands = ArrayList<File>()
            (Launch.get("data") ?: System.getenv("EUSVIEW_DATA"))?.takeIf { it.isNotEmpty() }?.let { cands.add(File(it)) }
            System.getProperty("eusview.repo")?.let { cands.add(File(it)) }
            System.getProperty("compose.application.resources.dir")?.let { cands.add(File(it, "data")) }
            var d: File? = File(System.getProperty("user.dir")).absoluteFile
            while (d != null) { cands.add(d); d = d.parentFile }
            for (c in cands) {
                if (!File(c, "robots").isDirectory) continue
                val repo = File(c, "bvh/cache").isDirectory
                val bvh = if (repo) File(c, "bvh/cache") else File(c, "bvh")
                val tables = File(c, "bvh/retarget_tables.json")
                return DesktopStore(c, File(c, "robots"), bvh.takeIf { it.isDirectory }, tables.takeIf { it.isFile })
            }
            return DesktopStore(null, null, null, null)
        }

        /** JNI のライブラリ (libeusviewode.dylib / .so): -Deusview.native, 配布物の中, desktop/build/native/<os>-<arch> */
        fun nativeLibrary(): File? {
            val name = System.mapLibraryName("eusviewode")
            val dirs = listOfNotNull(System.getProperty("eusview.native"), System.getProperty("compose.application.resources.dir"),
                System.getenv("EUSVIEW_NATIVE"))
            for (d in dirs) File(d, name).takeIf { it.isFile }?.let { return it }
            val os = System.getProperty("os.name").lowercase(); val arch = System.getProperty("os.arch").lowercase()
            val t = (if (os.contains("mac")) "macos" else "linux") + "-" + (if (arch == "aarch64" || arch == "arm64") "arm64" else "x64")
            var d: File? = File(System.getProperty("user.dir")).absoluteFile
            while (d != null) {
                for (sub in listOf("build/native/$t", "desktop/build/native/$t")) File(d, "$sub/$name").takeIf { it.isFile }?.let { return it }
                d = d.parentFile
            }
            return null
        }
    }
}
