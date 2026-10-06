// RobotPicker.kt : ロボットを画像と名前で選ぶ画面 (Android とデスクトップで共通. iOS 版は RobotPicker.swift)
//   ・グループ (KXR / KHR / JSK) → 身体の形の分類 (robots/catalog.json, make_catalog.py) → 画像 (robots/<グループ>/<名前>.png) の並び
//   ・分類のチップで絞る (「すべて」は分類ごとに見出しをつけて並べる). 名前で探すと分類をまたいで探す
//   ・画像は desktop の make thumbs で作る. ない (端末に置いた JSON など) ときは名前だけ
package jp.jsk.eusview

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.InputStreamReader

/** 一覧の 1 つ. key: 選んだときに返す (ファイルのパス), thumb: 画像のパス (store.open で読む, null なら画像なし) */
data class PickerRobot(val key: String, val group: String, val name: String, val thumb: String?)

class RobotCategory(val id: String, val title: String, val note: String, val robots: List<String>)

/** robots/catalog.json: グループ → 分類の並び, 名前 → 関節の数 */
class RobotCatalog(val groups: Map<String, List<RobotCategory>>, val joints: Map<String, Int>) {
    companion object {
        @Volatile private var cached: RobotCatalog? = null

        fun load(): RobotCatalog = cached ?: try {
            Platform.store.open("robots/catalog.json").use { parse(JsonReader(InputStreamReader(it, Charsets.UTF_8))) }
        } catch (e: Throwable) {
            Platform.logError("robots/catalog.json を読めません (分類なしで並べる)", e)
            RobotCatalog(emptyMap(), emptyMap())
        }.also { cached = it }

        private fun parse(r: JsonReader): RobotCatalog {
            val groups = LinkedHashMap<String, List<RobotCategory>>()
            val joints = HashMap<String, Int>()
            r.beginObject()
            while (r.hasNext()) when (r.nextName()) {
                "groups" -> {
                    r.beginObject()
                    while (r.hasNext()) {
                        val g = r.nextName()
                        val cats = ArrayList<RobotCategory>()
                        r.beginArray()
                        while (r.hasNext()) {
                            var id = ""; var title = ""; var note = ""; val robots = ArrayList<String>()
                            r.beginObject()
                            while (r.hasNext()) when (r.nextName()) {
                                "id" -> id = r.nextString()
                                "title" -> title = r.nextString()
                                "note" -> note = r.nextString()
                                "robots" -> { r.beginArray(); while (r.hasNext()) robots.add(r.nextString()); r.endArray() }
                                else -> r.skipValue()
                            }
                            r.endObject()
                            cats.add(RobotCategory(id, title, note, robots))
                        }
                        r.endArray()
                        groups[g] = cats
                    }
                    r.endObject()
                }
                "joints" -> { r.beginObject(); while (r.hasNext()) { val n = r.nextName(); joints[n] = r.nextInt() }; r.endObject() }
                else -> r.skipValue()
            }
            r.endObject()
            return RobotCatalog(groups, joints)
        }
    }

    /** グループのロボットを分類ごとに. 分類にないもの (端末に置いた JSON など) は「その他」 */
    fun sections(group: String, robots: List<PickerRobot>): List<Pair<RobotCategory, List<PickerRobot>>> {
        val byName = robots.associateBy { it.name }
        val used = HashSet<String>()
        val out = ArrayList<Pair<RobotCategory, List<PickerRobot>>>()
        for (c in groups[group].orEmpty()) {
            val rs = c.robots.mapNotNull { byName[it] }.filter { used.add(it.key) }
            if (rs.isNotEmpty()) out.add(c to rs)
        }
        val rest = robots.filter { it.key !in used }
        if (rest.isNotEmpty()) out.add(RobotCategory("rest", if (out.isEmpty()) group.uppercase() else "その他", "", rest.map { it.name }) to rest)
        return out
    }
}

/** 画像の読み込み (環境ごと: Android は BitmapFactory, デスクトップは Skia). 読んだものは覚えておく */
object Thumbnails {
    var decode: (ByteArray) -> ImageBitmap? = { null }
    private val cache = java.util.concurrent.ConcurrentHashMap<String, ImageBitmap>()
    private val missing = java.util.Collections.newSetFromMap(java.util.concurrent.ConcurrentHashMap<String, Boolean>())

    fun cached(path: String): ImageBitmap? = cache[path]
    fun load(path: String): ImageBitmap? {
        cache[path]?.let { return it }
        if (path in missing) return null
        val img = try { Platform.store.open(path).use { decode(it.readBytes()) } } catch (_: Throwable) { null }
        if (img != null) cache[path] = img else missing.add(path)
        return img
    }
}

/**
 * ロボットを選ぶ: グループ・分類のチップ・名前で探す・画像の並び.
 * cell: 画像の幅の目安 (列の数は幅から決める), selected: 選ばれているもの (枠をつける)
 */
@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun RobotPicker(robots: List<PickerRobot>, selected: String?, onPick: (PickerRobot) -> Unit,
                modifier: Modifier = Modifier, cell: Dp = 104.dp, sidePad: Dp = 12.dp) {
    val store = Platform.store
    val catalog = remember { RobotCatalog.load() }
    val initGroup = remember { robots.firstOrNull { it.key == selected }?.group ?: store.getString("robotGroup") ?: "kxr" }
    var group by remember { mutableStateOf(initGroup) }
    var cat by remember { mutableStateOf(store.getString("robotCategory.$initGroup") ?: "all") }
    var search by remember { mutableStateOf("") }
    val inGroup = remember(robots, group) { robots.filter { it.group == group } }
    val sections = remember(inGroup, group) { catalog.sections(group, inGroup) }
    if (sections.none { it.first.id == cat }) cat = "all"
    val q = search.trim()
    val shown: List<Pair<RobotCategory, List<PickerRobot>>> = when {
        q.isNotEmpty() -> sections.map { (c, rs) -> c to rs.filter { it.name.contains(q, ignoreCase = true) } }.filter { it.second.isNotEmpty() }
        cat == "all" -> sections
        else -> sections.filter { it.first.id == cat }
    }
    Column(modifier) {
        SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(horizontal = sidePad, vertical = 4.dp)) {
            robotGroups.forEachIndexed { i, g ->
                SegmentedButton(selected = group == g, onClick = {
                    group = g; store.putString("robotGroup", g); cat = store.getString("robotCategory.$g") ?: "all"
                }, shape = SegmentedButtonDefaults.itemShape(i, robotGroups.size), icon = {}) {
                    Text("${g.uppercase()}（${robots.count { it.group == g }}）", maxLines = 1, fontSize = 12.sp)
                }
            }
        }
        OutlinedTextField(search, { search = it }, Modifier.fillMaxWidth().padding(horizontal = sidePad, vertical = 2.dp),
            placeholder = { Text("名前で探す") }, singleLine = true, leadingIcon = { Icon(Icons.Filled.Search, null) })
        // 分類のチップ (分類が 2 つ以上のときだけ)
        if (sections.size > 1) FlowRow(Modifier.fillMaxWidth().padding(horizontal = sidePad),
            horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy((-6).dp)) {
            val pick = { id: String -> cat = id; search = ""; store.putString("robotCategory.$group", id) }
            FilterChip(cat == "all" && q.isEmpty(), { pick("all") }, { Text("すべて（${inGroup.size}）", fontSize = 12.sp) })
            for ((c, rs) in sections) FilterChip(cat == c.id && q.isEmpty(), { pick(c.id) }, { Text("${c.title}（${rs.size}）", fontSize = 12.sp) })
        }
        if (shown.isEmpty()) Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(if (q.isNotEmpty()) "「$q」に合うロボットはありません" else "このグループのロボットはありません",
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        } else {
            val state = rememberLazyGridState()
            LazyVerticalGrid(GridCells.Adaptive(cell), Modifier.fillMaxSize(), state = state,
                contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = sidePad, vertical = 6.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                for ((c, rs) in shown) {
                    if (shown.size > 1 || c.note.isNotEmpty()) item(key = "h:${c.id}", span = { GridItemSpan(maxLineSpan) }) {
                        Column(Modifier.padding(top = 6.dp)) {
                            Text(if (shown.size > 1) "${c.title}（${rs.size}）" else c.title, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            if (c.note.isNotEmpty()) Text(c.note, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    items(rs, key = { it.key }) { r -> RobotCell(r, catalog.joints[r.name], r.key == selected) { onPick(r) } }
                }
            }
        }
    }
}

@Composable
private fun RobotCell(r: PickerRobot, joints: Int?, on: Boolean, onClick: () -> Unit) {
    val cs = MaterialTheme.colorScheme
    val img by produceState(r.thumb?.let { Thumbnails.cached(it) }, r.thumb) {
        val t = r.thumb
        if (value == null && t != null) value = withContext(Dispatchers.IO) { Thumbnails.load(t) }
    }
    val shape = RoundedCornerShape(10.dp)
    Column(Modifier.clip(shape).background(if (on) cs.secondaryContainer else cs.surfaceVariant.copy(alpha = 0.45f))
        .then(if (on) Modifier.border(2.dp, cs.primary, shape) else Modifier)
        .clickable(onClick = onClick).padding(4.dp)) {
        Box(Modifier.fillMaxWidth().aspectRatio(1f).clip(RoundedCornerShape(7.dp)).background(cs.surface), contentAlignment = Alignment.Center) {
            val i = img
            if (i != null) Image(i, r.name, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
            else Text(r.name.take(3).uppercase(), color = cs.onSurfaceVariant, fontSize = 18.sp)
        }
        Text(r.name, Modifier.padding(top = 3.dp, start = 2.dp, end = 2.dp), fontSize = 11.5.sp, maxLines = 1, overflow = TextOverflow.Ellipsis,
            fontWeight = if (on) FontWeight.Bold else FontWeight.Normal)
        if (joints != null) Text("関節 $joints", Modifier.padding(start = 2.dp, bottom = 1.dp), fontSize = 10.sp, color = cs.onSurfaceVariant)
    }
}
