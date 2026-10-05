// LiveLink.kt : EusLisp (Mac など) から WebSocket で関節角を受け取る (iOS 版 LiveLink.swift)
//   受け取る JSON: {"angles": [...]}  関節角 (度・mm, JSON の関節の順)
//                  {"pose": "reset-pose"}  名前の付いた姿勢へ動かす
//                  {"root": [x y z r00..r22]}  ルートリンクの位置姿勢
package jp.jsk.eusview

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class LiveLink(private val st: RobotState) {
    private val prefs = Platform.store
    var url by mutableStateOf(prefs.getString("liveURL") ?: "ws://192.168.1.59:8766/")
    var status by mutableStateOf("未接続")
    var connected by mutableStateOf(false)
    private var ws: WebSocket? = null
    /** OkHttp のスレッドから画面のスレッドへ (Android: Looper, デスクトップ: Swing) */
    private val main = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private fun post(f: () -> Unit) { main.launch { f() } }

    companion object {
        private val client by lazy { OkHttpClient.Builder().readTimeout(0, TimeUnit.MILLISECONDS).pingInterval(20, TimeUnit.SECONDS).build() }
    }

    fun connect() {
        val req = try { Request.Builder().url(url.trim()).build() } catch (e: IllegalArgumentException) { status = "URL が正しくありません"; return }
        prefs.putString("liveURL", url)
        status = "接続中…"; connected = true
        lateinit var me: WebSocket
        me = client.newWebSocket(req, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                webSocket.send(JSONObject().put("hello", st.model.name).toString())
                post { if (ws === webSocket) status = "接続しました" }
            }
            override fun onMessage(webSocket: WebSocket, text: String) {
                post { if (ws === webSocket) handle(text) }
            }
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                post { if (ws === webSocket) { status = "切断: ${t.message ?: t.javaClass.simpleName}"; ws = null; connected = false } }
            }
            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                post { if (ws === webSocket) { status = "切断"; ws = null; connected = false } }
            }
        })
        ws = me
    }

    fun disconnect() {
        ws?.close(1001, null); ws = null; connected = false; status = "未接続"
    }

    private fun handle(text: String) {
        status = "受信中"
        val o = try { JSONObject(text) } catch (e: Exception) { return }
        o.optJSONArray("angles")?.let { a ->
            st.stop(); st.set(FloatArray(a.length()) { a.optDouble(it, 0.0).toFloat() })
        }
        o.optString("pose", "").takeIf { it.isNotEmpty() }?.let { p -> st.model.poses?.get(p)?.let { st.move(it) } }
        o.optJSONArray("root")?.let { r ->
            if (r.length() >= 12 && !st.physics) st.scene.setRoot(FloatArray(12) { r.optDouble(it, 0.0).toFloat() })
        }
    }
}
