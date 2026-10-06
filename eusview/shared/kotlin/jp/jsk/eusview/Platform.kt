// Platform.kt : Android 版とデスクトップ版 (eusview/desktop) で共通のコード (eusview/shared/kotlin) が使う, 環境ごとに違うもの
//   共通のコードは android.* を使わない. 環境ごとのファイル (Android: android/app/src/main/java, デスクトップ: desktop/src/main/kotlin) が
//   Platform.store を入れ, 同じ名前のクラス・関数 (RobotGLView, BvhGL) を用意する
package jp.jsk.eusview

import java.io.InputStream

/** アプリのデータ (ロボットの JSON, BVH) と設定. Android: assets と SharedPreferences, デスクトップ: フォルダと設定ファイル */
interface AppStore {
    /** path: "robots/<グループ>/<名前>.json", "bvh/index.json", "bvh/<種類>/<名前>.ebvh", "bvh/retarget_tables.json" */
    fun open(path: String): InputStream
    fun getString(key: String): String?
    fun putString(key: String, value: String)
}

object Platform {
    lateinit var store: AppStore
    var log: (String) -> Unit = { println("EusView: $it") }
    var logError: (String, Throwable?) -> Unit = { m, e -> System.err.println("EusView: $m"); e?.printStackTrace() }
}

/** 起動の引数 (確認用. iOS 版の起動の引数と同じ名前)
 *  bvh: home | auto | auto:<種類> | <種類> | <種類>/<名前>,  robot: kxr | khr | jsk | <名前>,
 *    method: all (既定) | both | names | gmr | qp | gmrqp | balance (GMR+QP と QP+バランス) | mpc (物理で比べる 3 体: GMR+QP・QP+バランス・GMR+MPC),
 *    violations: 0 (違反の表示を消す),  stick: 0,
 *    frame: <n> (そのコマで止める),  bvhphysics: 1 (物理で比べる: GMR+QP と QP+バランスと GMR+MPC を物理で動かす)
 *  open: <ロボットの名前> と bvhmotion: <種類>/<名前>, method: names | gmr | gmrqp | balance (GMR + QP + バランス) | mpc (GMR + MPC, 閉ループ),
 *    physics: 1 でロボットの画面の BVH の動作
 *  Android は adb shell am start ... --es <名前> <値> で同じ名前 */
object Launch {
    var extras: Map<String, String> = emptyMap()
    fun get(k: String): String? = extras[k]
}

val robotGroups = listOf("kxr", "khr", "jsk")

/** 3D 表示のカメラの操作 (RobotState, BvhPlayer から呼ぶ. Android / デスクトップの RobotGLView) */
interface SceneView {
    /** カメラの注視点と視点を (dx, dy, dz) m だけ動かす (BVH の再生で腰についていく) */
    fun follow(dx: Float, dy: Float, dz: Float)
    /** カメラを前 (+x) から少し斜めに. b = 外接箱 [minx miny minz maxx maxy maxz] */
    fun frontView(b: FloatArray)
    /** カメラを最初の向き・距離に戻す (今の姿勢の外接箱) */
    fun resetCamera()
}
