// EusView (Android): jskeus / kxreus のロボットモデル (eus2json.l で書き出した JSON) を表示するアプリ
//   iOS 版 eusview/ios/EusView と同じ機能:
//   ・ロボットを選ぶ (KXR / KHR / JSK → 身体の形の分類 → 画像と名前, 名前で探す. 共通の RobotPicker.kt) → OpenGL ES で表示 (1 本指で回転, 2 本指で移動・拡大)
//   ・関節角のスライダー, 姿勢 (reset-pose など), 動作の再生, 物理 (ODE)
//   ・接続: Mac などの EusLisp から WebSocket で関節角を受け取って動かす ({"angles": [...]} など)
//   ロボットのデータ・状態・物理・BVH・下の欄の画面はデスクトップ版と共通 (eusview/shared/kotlin, app/build.gradle.kts で読む)
package jp.jsk.eusview

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Button
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.material.icons.materialIcon
import androidx.compose.material.icons.materialPath
import androidx.compose.ui.text.input.KeyboardType
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.InputStream
import android.util.Log

// 起動の引数 (確認用, adb shell am start ... --es bvh mocopi/greeting1 --es robot kxr --es method both など) は Launch (Platform.kt)

/** アプリのデータ (assets/robots, assets/bvh) と設定 (SharedPreferences "eusview") */
class AndroidStore(ctx: Context) : AppStore {
    private val assets = ctx.applicationContext.assets
    private val prefs = ctx.applicationContext.getSharedPreferences("eusview", Context.MODE_PRIVATE)
    override fun open(path: String): InputStream = if (path.startsWith("/")) File(path).inputStream() else assets.open(path)
    override fun getString(key: String): String? = prefs.getString(key, null)
    override fun putString(key: String, value: String) { prefs.edit().putString(key, value).apply() }
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Platform.store = AndroidStore(this)
        Thumbnails.decode = { b -> android.graphics.BitmapFactory.decodeByteArray(b, 0, b.size)?.asImageBitmap() }
        Platform.log = { Log.i("EusView", it) }
        Platform.logError = { m, e -> Log.e("EusView", m, e) }
        intent?.extras?.let { b -> Launch.extras = b.keySet().mapNotNull { k -> b.getString(k)?.let { k to it } }.toMap() }
        enableEdgeToEdge()
        setContent {
            val dark = isSystemInDarkTheme()
            MaterialTheme(colorScheme = if (dark) darkColorScheme() else lightColorScheme()) {
                Surface(Modifier.fillMaxSize()) { App() }
            }
        }
    }
}

/** アプリに入っているロボット (assets/robots/<グループ>/ の JSON) と, 端末に置いたロボット (files/ の JSON) */
data class RobotFile(val path: String, val group: String, val name: String, val asset: Boolean)

fun robotFiles(ctx: Context): List<RobotFile> {
    val out = ArrayList<RobotFile>()
    for (g in robotGroups) for (f in ctx.assets.list("robots/$g").orEmpty()) if (f.endsWith(".json"))
        out.add(RobotFile("robots/$g/$f", g, f.removeSuffix(".json"), true))
    // フォルダに分けていないファイルは名前から決める
    ctx.filesDir.listFiles { f -> f.name.endsWith(".json") }?.forEach { f ->
        val n = f.name
        out.add(RobotFile(f.path, if (n.startsWith("khr")) "khr" else if (n.startsWith("kxr")) "kxr" else "jsk", n.removeSuffix(".json"), false))
    }
    return out.sortedBy { it.name }
}

@Composable
fun App() {
    val ctx = LocalContext.current
    val files = remember { robotFiles(ctx) }
    var open by rememberSaveable { mutableStateOf(Launch.get("open")?.let { n -> files.firstOrNull { it.name == n }?.path }) }
    var bvh by rememberSaveable { mutableStateOf(Launch.get("bvh") != null) }
    val f = files.firstOrNull { it.path == open }
    if (bvh) BvhApp { bvh = false }
    else if (f == null) RobotListScreen(files, { bvh = true }) { open = it.path }
    else {
        BackHandler { open = null }
        RobotLoaderScreen(f) { open = null }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RobotListScreen(files: List<RobotFile>, onBvh: () -> Unit, onOpen: (RobotFile) -> Unit) {
    // 一覧の画像は JSON の隣の <名前>.png (assets/robots/<グループ>/, desktop の make thumbs で作る)
    val items = remember(files) { files.map { PickerRobot(it.path, it.group, it.name, it.path.removeSuffix(".json") + ".png") } }
    Scaffold(topBar = {
        TopAppBar(title = { Text("EusLisp ロボット") }, actions = {
            TextButton(onBvh) { Icon(Icons.Filled.PlayArrow, null); Spacer(Modifier.width(4.dp)); Text("BVH") }
        })
    }) { pad ->
        RobotPicker(items, null, { p -> files.firstOrNull { it.path == p.key }?.let(onOpen) }, Modifier.padding(pad).fillMaxSize(), cell = 104.dp, sidePad = 16.dp)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RobotLoaderScreen(f: RobotFile, onBack: () -> Unit) {
    val ctx = LocalContext.current
    var model by remember(f.path) { mutableStateOf<RobotModel?>(null) }
    var error by remember(f.path) { mutableStateOf<String?>(null) }
    LaunchedEffect(f.path) {
        try {
            model = withContext(Dispatchers.IO) {
                (if (f.asset) ctx.assets.open(f.path) else File(f.path).inputStream()).use { RobotModel.parse(it) }
            }
        } catch (e: Throwable) { error = "読み込めません: $e" }
    }
    val m = model
    if (m != null) RobotScreen(m, onBack)
    else Scaffold(topBar = {
        TopAppBar(title = { Text(f.name) }, navigationIcon = { IconButton(onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "戻る") } })
    }) { pad ->
        Box(Modifier.padding(pad).fillMaxSize(), contentAlignment = Alignment.Center) {
            val e = error
            if (e != null) Text(e, Modifier.padding(16.dp))
            else Column(horizontalAlignment = Alignment.CenterHorizontally) { CircularProgressIndicator(); Spacer(Modifier.height(8.dp)); Text("読み込み中") }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RobotScreen(model: RobotModel, onBack: () -> Unit) {
    val ctx = LocalContext.current
    val st = remember(model) { RobotState(model) }
    DisposableEffect(st) { onDispose { st.shutdown() } }
    var tab by rememberSaveable { mutableIntStateOf(0) }
    val dark = isSystemInDarkTheme()
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val glView = remember(st) { RobotGLView(ctx, st.scene, dark) }
    LaunchedEffect(st) { st.glView = glView; if (Launch.get("bvhmotion") != null && !RobotState.launchDone) { tab = 2; st.launchBVH() } }
    LaunchedEffect(dark) { glView.setDark(dark) }
    DisposableEffect(lifecycle, glView) {
        val obs = LifecycleEventObserver { _, e ->
            if (e == Lifecycle.Event.ON_PAUSE) glView.onPause() else if (e == Lifecycle.Event.ON_RESUME) glView.onResume()
        }
        lifecycle.addObserver(obs)
        onDispose { lifecycle.removeObserver(obs) }
    }
    Scaffold(topBar = {
        TopAppBar(title = { Text(model.name, maxLines = 1, overflow = TextOverflow.Ellipsis) },
            navigationIcon = { IconButton(onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "戻る") } })
    }) { pad ->
        Column(Modifier.padding(pad).fillMaxSize()) {
            Box(Modifier.weight(1f).fillMaxWidth()) {
                AndroidView({ glView }, Modifier.fillMaxSize())
                if (st.physics && st.simInfo.isNotEmpty()) {
                    Text(st.simInfo, Modifier.padding(8.dp).background(MaterialTheme.colorScheme.surface.copy(alpha = 0.8f), RoundedCornerShape(6.dp)).padding(6.dp),
                        fontSize = 11.sp, fontFamily = FontFamily.Monospace)
                }
            }
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
            Box(Modifier.fillMaxWidth().height(260.dp)) {
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

