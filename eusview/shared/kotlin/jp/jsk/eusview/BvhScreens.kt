// BvhScreens.kt : BVH（モーションキャプチャ）の画面 (iOS 版 BVHView.swift と同じ). Android 版とデスクトップ版で共通
//   ・種類の一覧 → ファイルの一覧 (名前で探す) → 再生 (止めるまで繰り返す)
//   ・自動再生 (全部): 種類ごと・ファイルごとに順に再生し, 最後まで行ったら最初に戻る
//   画面の移り変わり (BvhApp) と 3D 表示 (BvhGL) は環境ごと (Android: BvhAndroid.kt, デスクトップ: DesktopBvh.kt)
package jp.jsk.eusview

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.materialIcon
import androidx.compose.material.icons.materialPath
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
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
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BvhHomeScreen(index: List<BvhIndexKind>?, onBack: () -> Unit, onKind: (BvhIndexKind) -> Unit, onPlay: (List<BvhEntry>, Int, Boolean) -> Unit) {
    Scaffold(topBar = {
        TopAppBar(title = { Text("BVH") }, navigationIcon = { IconButton(onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "戻る") } })
    }) { pad ->
        if (index.isNullOrEmpty()) {
            Column(Modifier.padding(pad).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("BVH のデータが入っていません", fontWeight = FontWeight.Bold)
                Text("BVH のファイル（~/kxreus/bvh）は git に入れていないので, Mac で変換してからアプリをビルドし直してください。")
                Text("python3 eusview/bvh/convert_bvh.py", fontFamily = FontFamily.Monospace, fontSize = 13.sp)
                Text("eusview/bvh/cache/ に書き出され, ビルドのときにアプリに入ります（全部で約 90 MB）。",
                    fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            return@Scaffold
        }
        val all = index.flatMap { k -> k.files.map { BvhEntry(k.name, it) } }
        LazyColumn(Modifier.padding(pad).fillMaxSize()) {
            item {
                ListButton("自動再生（全部）", Icons.Filled.PlayArrow) { onPlay(all, 0, true) }
                Text("${index.size} 種類・${all.size} 本を, 種類ごと・ファイルごとに順に再生します（止めるまで繰り返し）",
                    Modifier.padding(horizontal = 16.dp, vertical = 6.dp), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("種類", Modifier.padding(start = 16.dp, top = 12.dp, bottom = 4.dp), fontSize = 13.sp, color = MaterialTheme.colorScheme.primary)
            }
            items(index, key = { it.name }) { k ->
                Column(Modifier.fillMaxWidth().clickable { onKind(k) }.padding(horizontal = 20.dp, vertical = 10.dp)) {
                    Text("${k.name}（${k.files.size} 本）")
                    Text(k.title, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(String.format("計 %s・単位 %s・背の高さ %.2f m", bvhDuration(k.duration), k.unit, k.height),
                        fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                HorizontalDivider(Modifier.padding(start = 20.dp))
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BvhFileListScreen(kind: BvhIndexKind, onBack: () -> Unit, onPlay: (List<BvhEntry>, Int, Boolean) -> Unit) {
    var search by rememberSaveable { mutableStateOf("") }
    val shown = kind.files.filter { search.isEmpty() || it.name.contains(search, ignoreCase = true) }
    Scaffold(topBar = {
        TopAppBar(title = { Text(kind.name) }, navigationIcon = { IconButton(onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "戻る") } })
    }) { pad ->
        Column(Modifier.padding(pad).fillMaxSize()) {
            OutlinedTextField(search, { search = it }, Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
                placeholder = { Text("名前で探す") }, singleLine = true,
                leadingIcon = { Icon(Icons.Filled.Search, null) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Ascii))
            LazyColumn(Modifier.fillMaxSize()) {
                if (search.isEmpty()) item {
                    ListButton("自動再生（${kind.name} を順に）", Icons.Filled.PlayArrow) { onPlay(kind.files.map { BvhEntry(kind.name, it) }, 0, true) }
                }
                if (shown.isEmpty()) item { Text("見つかりません", Modifier.padding(16.dp), color = MaterialTheme.colorScheme.onSurfaceVariant) }
                items(shown, key = { it.file }) { f ->
                    Row(Modifier.fillMaxWidth().clickable { onPlay(listOf(BvhEntry(kind.name, f)), 0, false) }.padding(horizontal = 20.dp, vertical = 14.dp)) {
                        Text(f.name, Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text("${bvhDuration(f.duration)}・${f.frames} コマ", fontSize = 12.sp, fontFamily = FontFamily.Monospace,
                            color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    HorizontalDivider(Modifier.padding(start = 20.dp))
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BvhPlayerScreen(list: List<BvhEntry>, start: Int, auto: Boolean, onBack: () -> Unit) {
    val st = remember(list, start, auto) { BvhPlayer(list, start, auto) }
    DisposableEffect(st) { onDispose { st.shutdown() } }
    val dark = MaterialTheme.colorScheme.surface.luminance() < 0.5f
    Scaffold(topBar = {
        TopAppBar(title = { Text(if (auto) "自動再生" else st.entry.file.name, maxLines = 1, overflow = TextOverflow.Ellipsis) },
            navigationIcon = { IconButton(onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "戻る") } })
    }) { pad ->
        Column(Modifier.padding(pad).fillMaxSize()) {
            Box(Modifier.weight(1f).fillMaxWidth()) {
                val scene = st.scene
                if (scene != null) key(scene) { BvhGL(st, scene, dark) }
                Column(Modifier.padding(8.dp).background(MaterialTheme.colorScheme.surface.copy(alpha = 0.8f), RoundedCornerShape(6.dp)).padding(6.dp)) {
                    val small = 11.sp
                    if (auto) Text("自動再生 ${st.current + 1} / ${st.list.size}", fontSize = small, fontWeight = FontWeight.Bold)
                    Text("${st.entry.kind} / ${st.entry.file.name}", fontSize = small, fontWeight = FontWeight.Bold)
                    st.motion?.let { m ->
                        Text(String.format("コマ %d / %d・%.0f fps・%.1f / %.1f 秒", st.frame + 1, m.frames, m.fps, st.frame / m.fps, m.frames / m.fps),
                            fontSize = small, fontFamily = FontFamily.Monospace)
                        Text("関節 ${m.joints.size}・${st.checkInfo}", fontSize = small, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    if (st.robot.group.isNotEmpty()) {
                        Text(st.robotInfo, fontSize = small, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        val a = listOfNotNull("棒人形".takeIf { st.showStick }, "関節名".takeIf { st.showNames }, "GMR".takeIf { st.showGmr }, "GMR+QP".takeIf { st.showQp }, "QP+バランス".takeIf { st.showBalance }, "GMR+MPC".takeIf { st.physCompare && st.showMpc })
                        Text("左から " + a.joinToString("・") + (if (st.showGmr && st.gmrMs > 0) String.format("・GMR %.2f ms/コマ", st.gmrMs) else ""),
                            fontSize = small, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        st.qpProgress?.let { Text(String.format("GMR + QP を計算中 %.0f%%", it * 100), fontSize = small, color = Color(0xFFFF9500)) }
                        if (st.qpInfo.isNotEmpty()) Text(st.qpInfo, fontSize = small, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        st.balProgress?.let { Text(String.format("QP + バランスを計算中 %.0f%%", it * 100), fontSize = small, color = Color(0xFFFF9500)) }
                        if (st.balInfo.isNotEmpty()) Text(st.balInfo, fontSize = small, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        if (st.physInfo.isNotEmpty()) Text(st.physInfo, fontSize = small, fontWeight = FontWeight.Bold)
                        if (st.frameInfo.isNotEmpty()) Text(st.frameInfo, fontSize = small, fontFamily = FontFamily.Monospace)
                    }
                    st.error?.let { Text(it, fontSize = small, color = MaterialTheme.colorScheme.error) }
                }
            }
            Column(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 6.dp)) {
                val m = st.motion
                if (m != null && m.frames > 1) Slider(st.frame.toFloat(), { st.seek(it.toInt()) }, valueRange = 0f..(m.frames - 1).toFloat())
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    if (st.list.size > 1) TextButton({ st.prev() }) { Text("前へ") }
                    Button({ st.playing = !st.playing }) {
                        Icon(if (st.playing) StopIconBvh else Icons.Filled.PlayArrow, null); Spacer(Modifier.width(4.dp))
                        Text(if (st.playing) "止める" else "再生")
                    }
                    if (st.list.size > 1) TextButton({ st.next() }) { Text("次へ") }
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    val speeds = listOf(0.5, 1.0, 2.0)
                    SingleChoiceSegmentedButtonRow(Modifier.width(200.dp)) {
                        speeds.forEachIndexed { i, s ->
                            SegmentedButton(selected = st.speed == s, onClick = { st.speed = s }, shape = SegmentedButtonDefaults.itemShape(i, speeds.size), icon = {}) {
                                Text(if (s == 0.5) "0.5x" else "${s.toInt()}x", fontSize = 13.sp)
                            }
                        }
                    }
                    Spacer(Modifier.weight(1f))
                }
                RetargetControls(st)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("カメラが追う", fontSize = 14.sp); Spacer(Modifier.width(8.dp)); Switch(st.follow, { st.follow = it })
                    Spacer(Modifier.weight(1f))
                    TextButton({ st.resetCamera() }) { Text("カメラを戻す") }
                }
            }
        }
    }
}

/** ロボットを選ぶ (なし / KXR / KHR / JSK の既定, ほかのロボット) と, 棒人形・関節名・GMR・GMR+QP・QP+バランス・物理で比べる (GMR+MPC)・違反・人の大きさの切り替え */
@Composable
fun RetargetControls(st: BvhPlayer) {
    var menu by remember { mutableStateOf(false) }
    var others by remember { mutableStateOf<String?>(null) }
    Row(Modifier.horizontalScroll(rememberScrollState()), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Box {
            TextButton({ menu = true }) { Text(if (st.robot.group.isEmpty()) "ロボット: なし" else "ロボット: ${st.robot.name}", fontSize = 13.sp) }
            DropdownMenu(menu, { menu = false }) {
                DropdownMenuItem({ Text("なし") }, { menu = false; st.chooseRobot(RetargetChoice("", "")) })
                for (g in robotGroups) {
                    val cs = st.choices(g)
                    cs.firstOrNull()?.let { d -> DropdownMenuItem({ Text("${g.uppercase()}（${d.name}）") }, { menu = false; st.chooseRobot(d) }) }
                    if (cs.size > 1) DropdownMenuItem({ Text("${g.uppercase()} のほかのロボット…") }, { menu = false; others = g })
                }
            }
            others?.let { g ->
                DropdownMenu(true, { others = null }) {
                    for (c in st.choices(g).drop(1)) DropdownMenuItem({ Text(c.name) }, { others = null; st.chooseRobot(c) })
                }
            }
        }
        if (st.robot.group.isNotEmpty()) {
            FilterChip(st.showStick, { st.setShow(stick = !st.showStick) }, { Text("棒人形", fontSize = 12.sp) })
            FilterChip(st.showNames, { st.setShow(names = !st.showNames) }, { Text("関節名", fontSize = 12.sp) })
            FilterChip(st.showGmr, { st.setShow(gmr = !st.showGmr) }, { Text("GMR", fontSize = 12.sp) })
            FilterChip(st.showQp, { st.setShow(qp = !st.showQp) }, { Text("GMR+QP", fontSize = 12.sp) })
            FilterChip(st.showBalance, { st.setShow(balance = !st.showBalance) }, { Text("QP+バランス", fontSize = 12.sp) })
            FilterChip(st.physCompare, { st.setPhysics(!st.physCompare) }, { Text("物理で比べる", fontSize = 12.sp) })
            if (st.physCompare) {
                FilterChip(st.showMpc, { st.setShow(mpc = !st.showMpc) }, { Text("GMR+MPC", fontSize = 12.sp) })   // 閉ループの MPC (物理のときだけ)
                TextButton({ st.restartPhysics() }) { Text("最初に戻す", fontSize = 12.sp) }
            }
            FilterChip(st.showViolations, { st.setShow(violations = !st.showViolations) }, { Text("違反", fontSize = 12.sp) })
            FilterChip(st.lifeSize, { st.setShow(life = !st.lifeSize) }, { Text("人の大きさ", fontSize = 12.sp) })
        }
    }
}

private val StopIconBvh: ImageVector by lazy { materialIcon("Stop") { materialPath { moveTo(6f, 6f); horizontalLineToRelative(12f); verticalLineToRelative(12f); horizontalLineTo(6f); close() } } }

