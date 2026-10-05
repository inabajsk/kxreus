// EusView デスクトップ版 (Ubuntu / Mac): jskeus / kxreus のロボットモデル (eus2json.l で書き出した JSON) を表示する
//   iPhone / Mac / Android 版と同じ機能を 1 つのウィンドウに:
//   ・左: ロボットの一覧 (KXR / KHR / JSK, 名前で探す) と BVH
//   ・右: 3D 表示 (左ドラッグで回転, 右ドラッグ・Shift + ドラッグで移動, ホイールで拡大縮小) と
//         物理（ODE）・サーボ・置き直す, 関節 / 姿勢 / 動作 / 接続 の欄 (共通の RobotPanels.kt)
//   起動の引数 (確認用, iOS 版と同じ名前): -open <ロボット> -physics 1 -bvhmotion <種類>/<名前> -method names|gmr
//     -bvh home|auto|auto:<種類>|<種類>|<種類>/<名前> -robot kxr|khr|jsk|<名前> -method both|names|gmr -stick 0 -speed 2
//   デスクトップ版だけ: -motion <名前か番号> (動作を再生) -live <ws://...> (接続する) -tab 0..3 -theme auto|light|dark
//     -fps 1 (3D の描く速さをログに) -width / -height / -x / -y (ウィンドウの大きさと位置 dp)
//     -data <フォルダ> (robots/ と bvh/) -robots <フォルダ> (JSON を足す)
package jp.jsk.eusview

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.VerticalDivider
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.graphics.toComposeImageBitmap
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.WindowPosition
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

/** -key value の並び (値のない -key は "1") */
fun parseArgs(args: Array<String>): Map<String, String> {
    val m = LinkedHashMap<String, String>()
    var i = 0
    while (i < args.size) {
        val a = args[i]
        if (a.startsWith("-") && a.length > 1) {
            val k = a.trimStart('-')
            val next = args.getOrNull(i + 1)
            if (next != null && !next.startsWith("-")) { m[k] = next; i++ } else m[k] = "1"
        }
        i++
    }
    return m
}

fun main(args: Array<String>) {
    System.setProperty("apple.awt.application.name", "EusView")   // macOS のメニューバーの名前
    Launch.extras = parseArgs(args)
    val store = DesktopStore.create()
    Platform.store = store
    OdeLib.load = {
        val f = DesktopStore.nativeLibrary() ?: throw UnsatisfiedLinkError("物理 (ODE) の JNI ライブラリ ${System.mapLibraryName("eusviewode")} がありません (desktop で make native)")
        System.load(f.absolutePath)
    }
    Platform.log(store.description)
    val iconBytes = DesktopStore::class.java.getResourceAsStream("/eusview-icon.png")?.use { it.readBytes() }
    // macOS の Dock のアイコン (Linux はウィンドウのアイコン)
    try {
        if (iconBytes != null && java.awt.Taskbar.isTaskbarSupported() && java.awt.Taskbar.getTaskbar().isSupported(java.awt.Taskbar.Feature.ICON_IMAGE))
            java.awt.Taskbar.getTaskbar().iconImage = javax.imageio.ImageIO.read(iconBytes.inputStream())
    } catch (_: Throwable) {}
    application {
        val icon = remember { iconBytes?.let { BitmapPainter(org.jetbrains.skia.Image.makeFromEncoded(it).toComposeImageBitmap()) } }
        val x = Launch.get("x")?.toIntOrNull(); val y = Launch.get("y")?.toIntOrNull()
        val ws = rememberWindowState(width = (Launch.get("width")?.toIntOrNull() ?: 1360).dp, height = (Launch.get("height")?.toIntOrNull() ?: 880).dp,
            position = if (x != null && y != null) WindowPosition(x.dp, y.dp) else WindowPosition.PlatformDefault)
        Window(onCloseRequest = ::exitApplication, title = "EusView", state = ws, icon = icon) {
            DesktopApp(store)
        }
    }
}

@Composable
fun DesktopApp(store: DesktopStore) {
    var theme by remember { mutableStateOf(Launch.get("theme") ?: store.getString("theme") ?: "auto") }
    val sys = isSystemInDarkTheme()
    val dark = when (theme) { "dark" -> true; "light" -> false; else -> sys }
    MaterialTheme(colorScheme = if (dark) darkColorScheme() else lightColorScheme()) {
        Surface(Modifier.fillMaxSize()) {
            MainLayout(store, theme) { t -> theme = t; store.putString("theme", t) }
        }
    }
}

private val themeNames = listOf("auto" to "自動", "light" to "明るい", "dark" to "暗い")

@Composable
fun MainLayout(store: DesktopStore, theme: String, setTheme: (String) -> Unit) {
    val files = remember { store.robotFiles() }
    val launchOpen = remember { Launch.get("open")?.let { n -> files.firstOrNull { it.name == n } } }
    var group by remember { mutableStateOf(launchOpen?.group ?: store.getString("robotGroup") ?: "kxr") }
    var search by remember { mutableStateOf("") }
    var selected by remember { mutableStateOf(launchOpen) }
    var bvh by remember { mutableStateOf(Launch.get("bvh") != null) }
    val shown = files.filter { it.group == group && (search.isEmpty() || it.name.contains(search, ignoreCase = true)) }
    Row(Modifier.fillMaxSize()) {
        // ---- 左: ロボットの一覧 ----
        Column(Modifier.width(300.dp).fillMaxHeight()) {
            Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 4.dp, top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("EusLisp ロボット", style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                TextButton({ bvh = true; selected = null }) {
                    Icon(Icons.Filled.PlayArrow, null); Spacer(Modifier.width(4.dp))
                    Text("BVH", color = if (bvh) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface)
                }
            }
            SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp)) {
                robotGroups.forEachIndexed { i, g ->
                    SegmentedButton(selected = group == g, onClick = { group = g; store.putString("robotGroup", g) },
                        shape = SegmentedButtonDefaults.itemShape(i, robotGroups.size), icon = {}) {
                        Text("${g.uppercase()}（${files.count { it.group == g }}）", maxLines = 1, fontSize = 12.sp)
                    }
                }
            }
            OutlinedTextField(search, { search = it }, Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp),
                placeholder = { Text("名前で探す") }, singleLine = true, leadingIcon = { Icon(Icons.Filled.Search, null) })
            Box(Modifier.weight(1f).fillMaxWidth()) {
                if (files.isEmpty()) Text("ロボットの JSON が見つかりません\n${store.description}", Modifier.padding(16.dp),
                    color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 13.sp)
                else if (shown.isEmpty()) Text("このグループのロボットはありません", Modifier.align(Alignment.Center),
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                else {
                    val ls = rememberLazyListState(initialFirstVisibleItemIndex = shown.indexOf(selected).coerceAtLeast(0))
                    LazyColumn(Modifier.fillMaxSize(), state = ls) {
                        items(shown, key = { it.path }) { f ->
                            val on = selected?.path == f.path && !bvh
                            Text(f.name, Modifier.fillMaxWidth().clickable { selected = f; bvh = false }
                                .background(if (on) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surface)
                                .padding(horizontal = 20.dp, vertical = 10.dp), maxLines = 1, overflow = TextOverflow.Ellipsis)
                            HorizontalDivider(Modifier.padding(start = 20.dp))
                        }
                    }
                }
            }
            Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("表示", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(start = 8.dp))
                for ((k, n) in themeNames) TextButton({ setTheme(k) }) {
                    Text(n, fontSize = 12.sp, color = if (theme == k) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        VerticalDivider()
        // ---- 右 ----
        Box(Modifier.weight(1f).fillMaxHeight()) {
            val f = selected
            when {
                bvh -> BvhApp { bvh = false }
                f != null -> key(f.path) { RobotLoader(f) }
                else -> Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("左の一覧からロボットを選んでください", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("BVH: モーションキャプチャの再生とロボットへの移し替え", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

@Composable
fun RobotLoader(f: RobotFile) {
    var model by remember(f.path) { mutableStateOf<RobotModel?>(null) }
    var error by remember(f.path) { mutableStateOf<String?>(null) }
    LaunchedEffect(f.path) {
        try {
            val t0 = System.nanoTime()
            model = withContext(Dispatchers.IO) { File(f.path).inputStream().buffered(1 shl 16).use { RobotModel.parse(it) } }
            Platform.log(String.format("%s を %.2f 秒で読みました", f.name, (System.nanoTime() - t0) / 1e9))
        } catch (e: Throwable) { error = "読み込めません: $e" }
    }
    val m = model
    if (m != null) DesktopRobotScreen(m)
    else Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        val e = error
        if (e != null) Text(e, Modifier.padding(16.dp))
        else Column(horizontalAlignment = Alignment.CenterHorizontally) { CircularProgressIndicator(); Spacer(Modifier.height(8.dp)); Text("${f.name} を読み込み中") }
    }
}

/** 起動の引数の -physics / -motion / -live は最初に開いたロボットに一度だけ */
private object DesktopLaunch { var done = false }

@Composable
fun DesktopRobotScreen(model: RobotModel) {
    val st = remember(model) { RobotState(model) }
    DisposableEffect(st) { onDispose { st.shutdown() } }
    val dark = MaterialTheme.colorScheme.surface.luminance() < 0.5f
    val glView = remember(st) { RobotGLView(st.scene, dark) }
    DisposableEffect(glView) { onDispose { glView.dispose() } }
    LaunchedEffect(dark) { glView.setDark(dark) }
    var tab by remember { mutableIntStateOf(if (!DesktopLaunch.done) Launch.get("tab")?.toIntOrNull() ?: 0 else 0) }
    LaunchedEffect(st) {
        st.glView = glView
        if (Launch.get("bvhmotion") != null && !RobotState.launchDone) { tab = 2; st.launchBVH() }
        if (DesktopLaunch.done) return@LaunchedEffect
        DesktopLaunch.done = true
        if (Launch.get("bvhmotion") == null && Launch.get("physics") == "1") st.enablePhysics(true)
        Launch.get("motion")?.let { a ->
            val ms = model.motions.orEmpty()
            (a.toIntOrNull()?.let { ms.getOrNull(it) } ?: ms.firstOrNull { it.name == a })?.let { tab = 2; st.play(it) }
        }
        Launch.get("live")?.let { u -> tab = 3; st.live.url = u; st.live.connect() }
    }
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 8.dp, top = 6.dp, bottom = 2.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(model.name, style = MaterialTheme.typography.titleMedium, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
            Text("リンク ${model.links.size}・関節 ${model.joints.size}・三角形 ${model.links.sumOf { l -> l.meshes.sumOf { it.indices.size / 3 } }}",
                fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            TextButton({ glView.resetCamera() }) { Text("カメラを戻す") }
        }
        HorizontalDivider()
        Row(Modifier.weight(1f).fillMaxWidth()) {
            Box(Modifier.weight(1f).fillMaxHeight()) {
                RobotGL(glView, Modifier.fillMaxSize())
                if (st.physics && st.simInfo.isNotEmpty()) {
                    Text(st.simInfo, Modifier.padding(8.dp).background(MaterialTheme.colorScheme.surface.copy(alpha = 0.8f), RoundedCornerShape(6.dp)).padding(6.dp),
                        fontSize = 12.sp, fontFamily = FontFamily.Monospace)
                } else if (!st.physics && st.simInfo.startsWith("物理")) {
                    Text(st.simInfo, Modifier.padding(8.dp).background(MaterialTheme.colorScheme.surface.copy(alpha = 0.8f), RoundedCornerShape(6.dp)).padding(6.dp),
                        fontSize = 12.sp, color = MaterialTheme.colorScheme.error)
                }
            }
            VerticalDivider()
            Column(Modifier.width(400.dp).fillMaxHeight()) {
                Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp).padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("物理（ODE）", fontSize = 14.sp); Switch(st.physics, { st.enablePhysics(it) })
                    if (st.physics) {
                        Text("サーボ", fontSize = 14.sp); Switch(st.servoOn, { st.enableServo(it) })
                        TextButton({ st.enablePhysics(true) }) { Text("置き直す") }
                    }
                }
                val tabs = listOf("関節", "姿勢", "動作", "接続")
                SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(8.dp)) {
                    tabs.forEachIndexed { i, t ->
                        SegmentedButton(selected = tab == i, onClick = { tab = i }, shape = SegmentedButtonDefaults.itemShape(i, tabs.size), icon = {}) { Text(t) }
                    }
                }
                Box(Modifier.weight(1f).fillMaxWidth()) {
                    when (tab) {
                        0 -> JointList(st)
                        1 -> PoseList(st)
                        2 -> MotionList(st)
                        else -> LiveView(st)
                    }
                }
            }
        }
    }
}
