// BvhAndroid.kt : BVH の画面の Android の部分 (画面の移り変わりと戻るボタン, GLSurfaceView). 画面そのものは共通の BvhScreens.kt
package jp.jsk.eusview

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BvhApp(onBack: () -> Unit) {
    val index = remember { loadBvhIndex() }
    var kindName by rememberSaveable { mutableStateOf<String?>(null) }
    var play by remember { mutableStateOf<Triple<List<BvhEntry>, Int, Boolean>?>(null) }
    // 起動の引数 bvh (確認用): auto | auto:<種類> | <種類> | <種類>/<名前>
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
        p != null -> { BackHandler { play = null }; BvhPlayerScreen(p.first, p.second, p.third) { play = null } }
        kind != null -> { BackHandler { kindName = null }; BvhFileListScreen(kind, { kindName = null }) { l, s, a -> play = Triple(l, s, a) } }
        else -> { BackHandler { onBack() }; BvhHomeScreen(index, onBack, { kindName = it.name }) { l, s, a -> play = Triple(l, s, a) } }
    }
}

/** モーションごとに GLSurfaceView を作る (骨格が種類ごとに違うため) */
@Composable
internal fun BvhGL(st: BvhPlayer, scene: RobotScene, dark: Boolean) {
    val ctx = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val glView = remember(scene) { RobotGLView(ctx, scene, dark, floatArrayOf(1f, 12f)) }
    LaunchedEffect(glView) { st.glView = glView; st.resetCamera() }
    LaunchedEffect(dark) { glView.setDark(dark) }
    DisposableEffect(lifecycle, glView) {
        val obs = LifecycleEventObserver { _, e ->
            if (e == Lifecycle.Event.ON_PAUSE) glView.onPause() else if (e == Lifecycle.Event.ON_RESUME) glView.onResume()
        }
        lifecycle.addObserver(obs)
        onDispose { lifecycle.removeObserver(obs) }
    }
    AndroidView({ glView }, Modifier.fillMaxSize())
}
