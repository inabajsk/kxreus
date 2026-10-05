// DesktopBvh.kt : BVH の画面のデスクトップの部分 (画面の移り変わり, 3D 表示). 画面そのものは共通の BvhScreens.kt (Android 版と同じ)
package jp.jsk.eusview

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier

/** BVH: 種類の一覧 → ファイルの一覧 → 再生. 起動の引数 -bvh auto | auto:<種類> | <種類> | <種類>/<名前> */
@Composable
fun BvhApp(onBack: () -> Unit) {
    val index = remember { loadBvhIndex() }
    var kindName by remember { mutableStateOf<String?>(null) }
    var play by remember { mutableStateOf<Triple<List<BvhEntry>, Int, Boolean>?>(null) }
    LaunchedEffect(Unit) {
        val arg = Launch.get("bvh") ?: return@LaunchedEffect
        val all = index.orEmpty().flatMap { k -> k.files.map { BvhEntry(k.name, it) } }
        when {
            arg == "auto" && all.isNotEmpty() -> play = Triple(all, 0, true)
            arg.startsWith("auto:") -> all.indexOfFirst { it.kind == arg.removePrefix("auto:") }.takeIf { it >= 0 }?.let { play = Triple(all, it, true) }
            all.any { "${it.kind}/${it.file.name}" == arg } -> play = Triple(listOf(all.first { "${it.kind}/${it.file.name}" == arg }), 0, false)
            index.orEmpty().any { it.name == arg } -> kindName = arg
        }
    }
    val p = play
    val kind = index?.firstOrNull { it.name == kindName }
    when {
        p != null -> BvhPlayerScreen(p.first, p.second, p.third) { play = null }
        kind != null -> BvhFileListScreen(kind, { kindName = null }) { l, s, a -> play = Triple(l, s, a) }
        else -> BvhHomeScreen(index, onBack, { kindName = it.name }) { l, s, a -> play = Triple(l, s, a) }
    }
}

/** モーションごとに 3D 表示を作る (骨格が種類ごとに違うため) */
@Composable
internal fun BvhGL(st: BvhPlayer, scene: RobotScene, dark: Boolean) {
    val glView = remember(scene) { RobotGLView(scene, dark, floatArrayOf(1f, 12f)) }
    DisposableEffect(glView) { onDispose { glView.dispose() } }
    LaunchedEffect(glView) { st.glView = glView; st.resetCamera() }
    LaunchedEffect(dark) { glView.setDark(dark) }
    RobotGL(glView, Modifier.fillMaxSize())
}
