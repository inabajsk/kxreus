// RobotPanels.kt : ロボットの画面の下の欄 (関節 / 姿勢 / 動作 / 接続) と BVH の動作を選ぶ画面. Android 版とデスクトップ版で共通 (iOS 版 RobotView.swift)
package jp.jsk.eusview

import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.materialIcon
import androidx.compose.material.icons.materialPath
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties

val StopIcon: ImageVector by lazy { materialIcon("Stop") { materialPath { moveTo(6f, 6f); horizontalLineToRelative(12f); verticalLineToRelative(12f); horizontalLineTo(6f); close() } } }

@Composable
fun JointList(st: RobotState) {
    val model = st.model
    LazyColumn(Modifier.fillMaxSize()) {
        itemsIndexed(model.joints) { k, j ->
            Column(Modifier.padding(horizontal = 16.dp, vertical = 2.dp)) {
                Row {
                    Text(j.name, fontSize = 12.sp, modifier = Modifier.weight(1f))
                    Text(String.format(if (j.linear) "%.1f mm" else "%.1f°", st.angles.getOrElse(k) { 0f }), fontSize = 12.sp,
                        fontFamily = FontFamily.Monospace, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                val lo = j.min ?: -180f
                val hi = maxOf(j.max ?: 180f, lo + 0.1f)
                Slider(st.angles.getOrElse(k) { 0f }.coerceIn(lo, hi), { v ->
                    val a = st.angles.copyOf(); a[k] = v; st.stop(); st.set(a)
                }, valueRange = lo..hi, modifier = Modifier.height(32.dp))
            }
        }
    }
}

@Composable
fun PoseList(st: RobotState) {
    val poses = st.model.poses.orEmpty()
    LazyColumn(Modifier.fillMaxSize()) {
        items(poses.keys.sorted()) { name ->
            ListButton(name) { st.move(poses[name]!!) }
        }
        item { ListButton("すべて 0") { st.move(FloatArray(st.model.joints.size)) } }
    }
}

@Composable
fun ListButton(label: String, icon: ImageVector? = null, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 16.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        if (icon != null) { Icon(icon, null, tint = MaterialTheme.colorScheme.primary); Spacer(Modifier.width(8.dp)) }
        Text(label, color = MaterialTheme.colorScheme.primary)
    }
    HorizontalDivider(Modifier.padding(start = 16.dp))
}

@Composable
fun MotionList(st: RobotState) {
    val motions = st.model.motions.orEmpty()
    val canBvh = remember(st) { robotSupportsRetarget(st.model) && loadBvhIndex() != null }
    var picker by remember { mutableStateOf(false) }
    if (picker) BvhMotionPicker({ picker = false }) { e, method -> picker = false; st.playBVH(e, method) }
    LazyColumn(Modifier.fillMaxSize()) {
        if (canBvh) item {
            Text("BVH", Modifier.padding(start = 16.dp, top = 6.dp), fontSize = 13.sp, color = MaterialTheme.colorScheme.primary)
            val p = st.bvhProgress
            if (p != null) Row(Modifier.padding(horizontal = 16.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) { Text(st.bvhInfo, fontSize = 12.sp); LinearProgressIndicator({ p.toFloat() }, Modifier.fillMaxWidth()) }
                TextButton({ st.cancelBVH() }) { Text("やめる") }
            } else {
                ListButton("BVH から選ぶ（種類 → ファイル → 関節名 / GMR / GMR + QP）", Icons.Filled.PlayArrow) { picker = true }
                st.bvhMotion?.let { m ->
                    val on = st.playing == m.name
                    ListButton("${m.name}（${m.frames.size} コマ）", if (on) StopIcon else Icons.Filled.PlayArrow) { if (on) st.stop() else st.play(m, follow = true) }
                }
                if (st.bvhInfo.isNotEmpty()) Text(st.bvhInfo + if (st.physics) "・物理オン: 関節角をサーボの目標に" else "・物理オフ: 腰も BVH のように動かす",
                    Modifier.padding(horizontal = 16.dp, vertical = 4.dp), fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Text("ロボットの動作", Modifier.padding(start = 16.dp, top = 8.dp), fontSize = 13.sp, color = MaterialTheme.colorScheme.primary)
        }
        if (motions.isEmpty()) item {
            Text("このロボットには動作が入っていません", Modifier.padding(16.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        items(motions) { m ->
            val on = st.playing == m.name
            ListButton("${m.name}（${m.frames.size} コマ）", if (on) StopIcon else Icons.Filled.PlayArrow) { if (on) st.stop() else st.play(m) }
        }
    }
}

@Composable
fun LiveView(st: RobotState) {
    val live = st.live
    Column(Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 4.dp)) {
        OutlinedTextField(live.url, { live.url = it }, Modifier.fillMaxWidth(), singleLine = true,
            placeholder = { Text("ws://<Mac の IP>:8766/") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri, autoCorrectEnabled = false))
        Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Button({ if (live.connected) live.disconnect() else live.connect() }) { Text(if (live.connected) "切断する" else "接続する") }
            Spacer(Modifier.weight(1f))
            Text(live.status, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Text("Mac で eusview/live.py を動かし, EusLisp から関節角を送ると, このロボットが同じように動きます。",
            fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** ロボットの画面の「動作」→ BVH: 種類 → ファイル (名前で探す) → 方法 (関節名 / GMR / GMR + QP) */
@Composable
fun BvhMotionPicker(onDismiss: () -> Unit, onPick: (BvhEntry, RetargetMethod) -> Unit) {
    val index = remember { loadBvhIndex().orEmpty() }
    var kind by remember { mutableStateOf(index.firstOrNull()?.name ?: "") }
    var method by remember { mutableStateOf(RetargetMethod.GMR) }
    var search by remember { mutableStateOf("") }
    Dialog(onDismiss, DialogProperties(usePlatformDefaultWidth = false)) {
        Surface(Modifier.fillMaxSize().padding(12.dp), shape = RoundedCornerShape(12.dp)) {
            Column(Modifier.padding(8.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("BVH の動作", fontSize = 18.sp, modifier = Modifier.weight(1f).padding(start = 8.dp))
                    TextButton(onDismiss) { Text("閉じる") }
                }
                SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                    index.forEachIndexed { i, k ->
                        SegmentedButton(selected = kind == k.name, onClick = { kind = k.name }, shape = SegmentedButtonDefaults.itemShape(i, index.size), icon = {}) {
                            Text(k.name, fontSize = 11.sp, maxLines = 1)
                        }
                    }
                }
                SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(vertical = 6.dp)) {
                    RetargetMethod.entries.forEachIndexed { i, m ->
                        SegmentedButton(selected = method == m, onClick = { method = m }, shape = SegmentedButtonDefaults.itemShape(i, RetargetMethod.entries.size), icon = {}) {
                            Text(m.title, fontSize = 12.sp, maxLines = 1)
                        }
                    }
                }
                Text(when (method) {
                    RetargetMethod.NAMES -> "関節名で対応（EusLisp の :copy-state-to と同じ）"
                    RetargetMethod.GMR -> "GMR: 部位の位置を IK で合わせる"
                    RetargetMethod.GMRQP -> "GMR のあと全身 QP で自己衝突・関節の可動範囲・重心を直し, 床に着いた足を止める"
                }, Modifier.padding(horizontal = 8.dp).padding(bottom = 4.dp), fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                OutlinedTextField(search, { search = it }, Modifier.fillMaxWidth(), placeholder = { Text("名前で探す") }, singleLine = true,
                    leadingIcon = { Icon(Icons.Filled.Search, null) }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Ascii))
                val k = index.firstOrNull { it.name == kind }
                LazyColumn(Modifier.fillMaxSize()) {
                    items(k?.files.orEmpty().filter { search.isEmpty() || it.name.contains(search, ignoreCase = true) }, key = { it.file }) { f ->
                        Row(Modifier.fillMaxWidth().clickable { onPick(BvhEntry(k!!.name, f), method) }.padding(horizontal = 12.dp, vertical = 12.dp)) {
                            Text(f.name, Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Text("${bvhDuration(f.duration)}・${f.frames} コマ", fontSize = 12.sp, fontFamily = FontFamily.Monospace,
                                color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        HorizontalDivider()
                    }
                }
            }
        }
    }
}
