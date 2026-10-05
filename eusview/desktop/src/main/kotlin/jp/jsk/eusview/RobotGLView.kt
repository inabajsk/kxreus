// RobotGLView.kt (デスクトップ) : ロボットの 3D 表示. Android 版 RobotGLView.kt (OpenGL ES 3.0) と同じ描き方を OpenGL 3.2 core で
//   ・メッシュ・床・格子・光・色・カメラは共通 (shared/kotlin/.../SceneCommon.kt)
//   ・GL のスレッド (OffscreenGL) で 4x MSAA の FBO に描き, glReadPixels で読んで Skia の Image にして Compose の Canvas に出す
//     (Compose の上に重ねる文字 (物理の状態など) がそのまま出る. 大きい画面では描く画素の数を抑えて引き伸ばす)
//   ・マウス: 左ドラッグで回転, 右ドラッグ・中ドラッグ・Shift + 左ドラッグで平行移動, ホイールで拡大縮小
package jp.jsk.eusview

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.isPrimaryPressed
import androidx.compose.ui.input.pointer.isShiftPressed
import androidx.compose.ui.input.pointer.isSecondaryPressed
import androidx.compose.ui.input.pointer.isTertiaryPressed
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.unit.dp
import org.jetbrains.skia.ColorAlphaType
import org.jetbrains.skia.ColorType
import org.jetbrains.skia.FilterMipmap
import org.jetbrains.skia.FilterMode
import org.jetbrains.skia.Image
import org.jetbrains.skia.ImageInfo
import org.jetbrains.skia.MipmapMode
import org.jetbrains.skia.Rect
import org.lwjgl.opengl.GL32C.*
import org.lwjgl.system.MemoryUtil
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean
import javax.swing.SwingUtilities
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/** 描いた 1 コマ (上下が逆: OpenGL の下から) */
class GLFrame(val image: Image, val w: Int, val h: Int)

/** grid: 床の格子 [間隔, 半分の幅] m (null ならロボットの大きさから決める) */
class RobotGLView(val scene: RobotScene, dark: Boolean, grid: FloatArray? = null) : SceneView {
    private val renderer = DesktopRenderer(scene, dark, grid)
    val cam get() = renderer.cam
    var frame by mutableStateOf<GLFrame?>(null); private set
    var error by mutableStateOf<String?>(null); private set
    @Volatile private var width = 1; @Volatile private var height = 1
    private val scheduled = AtomicBoolean(false)
    @Volatile private var disposed = false
    // 古い Image は 3 コマ後に閉じる (Compose が前のコマの絵をまだ持っていることがあるため)
    private val old = ArrayDeque<Image>()

    init { scene.onChange = { requestRender() } }

    fun setDark(d: Boolean) { if (renderer.dark != d) { renderer.dark = d; requestRender() } }
    override fun follow(dx: Float, dy: Float, dz: Float) { cam.shift(dx, dy, dz); requestRender() }
    override fun resetCamera() { cam.frame(scene.bounds()); requestRender() }
    override fun frontView(b: FloatArray) { cam.frame(b, floatArrayOf(2.3f, -0.7f, 0.8f)); requestRender() }

    fun resize(w: Int, h: Int) { if (w != width || h != height) { width = max(w, 1); height = max(h, 1); requestRender() } }
    val viewHeight get() = height

    /** 描き直す (GL のスレッドで. 描いている間に頼まれたら, もう 1 回だけ) */
    fun requestRender() {
        if (disposed || !scheduled.compareAndSet(false, true)) return
        OffscreenGL.post({
            scheduled.set(false)
            if (disposed) return@post
            // 描く画素の数を 250 万までに抑える (Retina や 4K の画面で glReadPixels が重くならないように)
            val k = min(1.0, sqrt(2.5e6 / (width.toDouble() * height)))
            val w = max(1, (width * k).toInt()); val h = max(1, (height * k).toInt())
            val t0 = System.nanoTime()
            val img = renderer.render(w, h)
            stats(w, h, (System.nanoTime() - t0) / 1e6)
            SwingUtilities.invokeLater {
                if (disposed) { img.close(); return@invokeLater }
                frame?.let { old.addLast(it.image) }
                while (old.size > 3) old.removeFirst().close()
                frame = GLFrame(img, w, h)
            }
        }) { e ->
            scheduled.set(false)
            SwingUtilities.invokeLater { error = OffscreenGL.error ?: e.toString() }
        }
    }

    // -fps 1: 描いたコマの数と 1 コマの時間 (描く + 読む) を 5 秒ごとに出す
    private var nFrames = 0; private var msSum = 0.0; private var tStat = System.nanoTime()
    private fun stats(w: Int, h: Int, ms: Double) {
        if (Launch.get("fps") == null) return
        nFrames++; msSum += ms
        val now = System.nanoTime()
        if (now - tStat > 5e9) {
            Platform.log(String.format("3D: %.1f コマ/秒, 描く + 読む %.2f ms/コマ (%d x %d, 三角形 %d)", nFrames / ((now - tStat) / 1e9), msSum / nFrames, w, h, renderer.triangles))
            nFrames = 0; msSum = 0.0; tStat = now
        }
    }

    fun dispose() {
        disposed = true
        scene.onChange = null
        OffscreenGL.post({ renderer.release() }) { }
        SwingUtilities.invokeLater { old.forEach { it.close() }; old.clear() }
    }
}

/** 3D 表示 (マウスで回転・移動・拡大縮小) */
@Composable
fun RobotGL(view: RobotGLView, modifier: Modifier = Modifier) {
    DisposableEffect(view) { view.requestRender(); onDispose { } }
    Box(modifier
        .onSizeChanged { view.resize(it.width, it.height) }
        .pointerInput(view) {
            awaitPointerEventScope {
                var last: Offset? = null
                while (true) {
                    val e = awaitPointerEvent()
                    val c = e.changes.firstOrNull() ?: continue
                    when (e.type) {
                        PointerEventType.Press -> last = c.position
                        PointerEventType.Release -> if (!e.buttons.isPrimaryPressed && !e.buttons.isSecondaryPressed && !e.buttons.isTertiaryPressed) last = null
                        PointerEventType.Move -> {
                            val l = last
                            if (l != null && (e.buttons.isPrimaryPressed || e.buttons.isSecondaryPressed || e.buttons.isTertiaryPressed)) {
                                val dx = c.position.x - l.x; val dy = c.position.y - l.y
                                val h = view.viewHeight
                                if (e.buttons.isPrimaryPressed && !e.keyboardModifiers.isShiftPressed) view.cam.orbit(dx, dy, h)
                                else view.cam.pan(dx, dy, h)
                                view.requestRender()
                                c.consume()
                            }
                            last = c.position
                        }
                        PointerEventType.Scroll -> {
                            val d = c.scrollDelta.y
                            if (d != 0f) { view.cam.zoom(exp(-d * 0.1f)); view.requestRender(); c.consume() }
                        }
                    }
                }
            }
        }) {
        Canvas(Modifier.fillMaxSize()) {
            val f = view.frame ?: return@Canvas
            drawIntoCanvas { cv ->
                val nc = cv.nativeCanvas
                nc.save()
                nc.translate(0f, size.height)
                nc.scale(1f, -1f)
                nc.drawImageRect(f.image, Rect.makeWH(f.w.toFloat(), f.h.toFloat()), Rect.makeWH(size.width, size.height),
                    FilterMipmap(FilterMode.LINEAR, MipmapMode.NONE), null, true)
                nc.restore()
            }
        }
        view.error?.let { Text("3D 表示を使えません: $it", Modifier.align(Alignment.Center).padding(16.dp), color = MaterialTheme.colorScheme.error) }
    }
}

/** Android 版 RobotRenderer と同じ描き方 (GL のスレッドだけで使う) */
class DesktopRenderer(private val scene: RobotScene, @Volatile var dark: Boolean, private val grid: FloatArray?) {
    val cam = OrbitCamera().also { it.frame(scene.bounds()) }
    private val meshes: List<FlatMesh> = flatMeshes(scene.model)
    val triangles = meshes.sumOf { it.count / 3 }
    private val world = FloatArray(16 * scene.model.links.size)
    private var inited = false
    private var prog = 0; private var floorProg = 0
    private var uMvp = 0; private var uModel = 0; private var uColor = 0; private var uL1 = 0; private var uL2 = 0; private var uAmb = 0; private var uEmit = 0
    private var fMvp = 0; private var fColor = 0
    private var floorVao = 0; private var floorCount = 0; private var gridVao = 0; private var gridCount = 0
    private var ovVao = 0; private var ovVbo = 0   // 重ねて描く印 (毎コマ書き換える)
    private val buffers = ArrayList<Int>()
    private val vaos = ArrayList<Int>()
    // FBO: MSAA (色 + 深さ) → 解決用 (色)
    private var fw = 0; private var fh = 0
    private var msFbo = 0; private var msColor = 0; private var msDepth = 0; private var fbo = 0; private var color = 0
    private var samples = 4
    private var pixels: ByteBuffer? = null
    private var bytes = ByteArray(0)

    private fun shader(type: Int, src: String): Int {
        val s = glCreateShader(type)
        glShaderSource(s, src); glCompileShader(s)
        if (glGetShaderi(s, GL_COMPILE_STATUS) == 0) Platform.log("shader: " + glGetShaderInfoLog(s))
        return s
    }
    private fun program(vs: String, fs: String, normal: Boolean): Int {
        val p = glCreateProgram()
        glAttachShader(p, shader(GL_VERTEX_SHADER, vs)); glAttachShader(p, shader(GL_FRAGMENT_SHADER, fs))
        glBindAttribLocation(p, 0, "aPos"); if (normal) glBindAttribLocation(p, 1, "aNor")
        glBindFragDataLocation(p, 0, "frag")
        glLinkProgram(p)
        if (glGetProgrami(p, GL_LINK_STATUS) == 0) Platform.log("link: " + glGetProgramInfoLog(p))
        return p
    }

    private fun makeVao(data: FloatArray, stride: Int, withNormal: Boolean): Int {
        val vao = glGenVertexArrays(); val b = glGenBuffers()
        glBindVertexArray(vao)
        glBindBuffer(GL_ARRAY_BUFFER, b)
        glBufferData(GL_ARRAY_BUFFER, data, GL_STATIC_DRAW)
        glEnableVertexAttribArray(0)
        glVertexAttribPointer(0, 3, GL_FLOAT, false, stride * 4, 0L)
        if (withNormal) { glEnableVertexAttribArray(1); glVertexAttribPointer(1, 3, GL_FLOAT, false, stride * 4, 12L) }
        glBindVertexArray(0)
        vaos.add(vao); buffers.add(b)
        return vao
    }

    private fun init() {
        inited = true
        prog = program(
            """#version 150
            in vec3 aPos; in vec3 aNor;
            uniform mat4 uMvp; uniform mat4 uModel;
            out vec3 vNor;
            void main() { vNor = mat3(uModel) * aNor; gl_Position = uMvp * vec4(aPos, 1.0); }""",
            """#version 150
            in vec3 vNor; uniform vec4 uColor; uniform vec3 uL1; uniform vec3 uL2; uniform float uAmb; uniform vec3 uEmit;
            out vec4 frag;
            void main() {
              vec3 n = normalize(vNor); if (!gl_FrontFacing) n = -n;
              float d = uAmb + 0.70 * max(dot(n, uL1), 0.0) + 0.25 * max(dot(n, uL2), 0.0);
              frag = vec4(min(uColor.rgb * min(d, 1.15) + uEmit, 1.0), uColor.a);
            }""", true)
        uMvp = glGetUniformLocation(prog, "uMvp"); uModel = glGetUniformLocation(prog, "uModel")
        uColor = glGetUniformLocation(prog, "uColor"); uL1 = glGetUniformLocation(prog, "uL1")
        uL2 = glGetUniformLocation(prog, "uL2"); uAmb = glGetUniformLocation(prog, "uAmb")
        uEmit = glGetUniformLocation(prog, "uEmit")
        floorProg = program(
            """#version 150
            in vec3 aPos; uniform mat4 uMvp;
            void main() { gl_Position = uMvp * vec4(aPos, 1.0); }""",
            """#version 150
            uniform vec4 uColor; out vec4 frag;
            void main() { frag = uColor; }""", false)
        fMvp = glGetUniformLocation(floorProg, "uMvp"); fColor = glGetUniformLocation(floorProg, "uColor")
        for (m in meshes) m.vao = makeVao(m.data, 6, true)
        val r = cam.radius
        floorVao = makeVao(floorTriangles(r, grid), 3, false); floorCount = 6
        val lines = gridLines(r, grid)
        gridVao = makeVao(lines, 3, false); gridCount = lines.size / 3
        ovVao = glGenVertexArrays(); ovVbo = glGenBuffers()
        glBindVertexArray(ovVao); glBindBuffer(GL_ARRAY_BUFFER, ovVbo)
        glEnableVertexAttribArray(0); glVertexAttribPointer(0, 3, GL_FLOAT, false, 12, 0L)
        glBindVertexArray(0)
        vaos.add(ovVao); buffers.add(ovVbo)
        samples = min(4, glGetInteger(GL_MAX_SAMPLES))
    }

    private fun deleteFbo() {
        if (msFbo != 0) { glDeleteFramebuffers(intArrayOf(msFbo, fbo)); glDeleteRenderbuffers(intArrayOf(msColor, msDepth, color)) }
        msFbo = 0; fbo = 0
    }

    private fun ensureFbo(w: Int, h: Int) {
        if (w == fw && h == fh && msFbo != 0) return
        deleteFbo()
        fw = w; fh = h
        msColor = glGenRenderbuffers(); glBindRenderbuffer(GL_RENDERBUFFER, msColor)
        glRenderbufferStorageMultisample(GL_RENDERBUFFER, samples, GL_RGBA8, w, h)
        msDepth = glGenRenderbuffers(); glBindRenderbuffer(GL_RENDERBUFFER, msDepth)
        glRenderbufferStorageMultisample(GL_RENDERBUFFER, samples, GL_DEPTH_COMPONENT24, w, h)
        msFbo = glGenFramebuffers(); glBindFramebuffer(GL_FRAMEBUFFER, msFbo)
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, msColor)
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, msDepth)
        check(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE) { "FBO (MSAA)" }
        color = glGenRenderbuffers(); glBindRenderbuffer(GL_RENDERBUFFER, color)
        glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8, w, h)
        fbo = glGenFramebuffers(); glBindFramebuffer(GL_FRAMEBUFFER, fbo)
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, color)
        check(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE) { "FBO" }
        pixels?.let { MemoryUtil.memFree(it) }
        pixels = MemoryUtil.memAlloc(w * h * 4)
        bytes = ByteArray(w * h * 4)
    }

    private val proj = FloatArray(16); private val view = FloatArray(16)

    /** w × h で描いて Skia の Image にする (上下は逆) */
    fun render(w: Int, h: Int): Image {
        if (!inited) init()
        ensureFbo(w, h)
        glBindFramebuffer(GL_FRAMEBUFFER, msFbo)
        glViewport(0, 0, w, h)
        glEnable(GL_DEPTH_TEST); glDisable(GL_CULL_FACE)
        glEnable(GL_BLEND); glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
        val dark = dark
        val bg = SceneColors.clear(dark)
        glClearColor(bg[0], bg[1], bg[2], bg[3])
        glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
        scene.copyWorld(world)
        val e = cam.eye(); val t = cam.target
        perspective(proj, 45f, w.toFloat() / max(h, 1), cam.near(), cam.far())
        lookAt(view, e, t)
        val vp = Mat.mul(proj, view)

        // 床: ロボットより先に, 少し奥にずらして描く
        glUseProgram(floorProg)
        glUniformMatrix4fv(fMvp, false, vp)
        glEnable(GL_POLYGON_OFFSET_FILL); glPolygonOffset(1f, 1f)
        SceneColors.floor(dark).let { glUniform4f(fColor, it[0], it[1], it[2], it[3]) }
        glBindVertexArray(floorVao); glDrawArrays(GL_TRIANGLES, 0, floorCount)
        glDisable(GL_POLYGON_OFFSET_FILL)
        SceneColors.grid(dark).let { glUniform4f(fColor, it[0], it[1], it[2], it[3]) }
        glBindVertexArray(gridVao); glDrawArrays(GL_LINES, 0, gridCount)

        glUseProgram(prog)
        val l1 = keyLight(e, t)
        glUniform3f(uL1, l1[0], l1[1], l1[2]); glUniform3f(uL2, 0f, 0f, 1f); glUniform1f(uAmb, SceneColors.AMBIENT)
        val model = FloatArray(16)
        // 違反の表示: リンクの色 (赤 = 衝突, 橙 = 可動範囲の端) と, 薄く描くリンク (不透明のものの後で, 深さを書かずに)
        val tints = scene.tints
        for (pass in 0..1) {
            if (pass == 1) glDepthMask(false)
            for (m in meshes) {
                val tn = tints?.getOrNull(m.link) ?: 0
                if ((tn == Tint.FADED) != (pass == 1)) continue
                System.arraycopy(world, 16 * m.link, model, 0, 16)
                glUniformMatrix4fv(uMvp, false, Mat.mul(vp, model))
                glUniformMatrix4fv(uModel, false, model)
                glUniform4f(uColor, m.color[0], m.color[1], m.color[2], m.color[3] * Tint.alpha(tn))
                val em = Tint.emit(tn)
                glUniform3f(uEmit, em?.get(0) ?: 0f, em?.get(1) ?: 0f, em?.get(2) ?: 0f)
                glBindVertexArray(m.vao)
                glDrawArrays(GL_TRIANGLES, 0, m.count)
            }
            if (pass == 1) glDepthMask(true)
        }
        // 重ねて描く印 (重心の球と床への投影, 支持多角形): 床より少し手前に. onTop は体に隠れても見せる
        val ovs = scene.overlays
        if (ovs.isNotEmpty()) {
            glUseProgram(floorProg)
            glUniformMatrix4fv(fMvp, false, vp)
            glBindVertexArray(ovVao); glBindBuffer(GL_ARRAY_BUFFER, ovVbo)
            glEnable(GL_POLYGON_OFFSET_FILL); glPolygonOffset(-1f, -4f)
            for (o in ovs) {
                if (o.triangles.isEmpty()) continue
                if (o.onTop) glDisable(GL_DEPTH_TEST)
                glBufferData(GL_ARRAY_BUFFER, o.triangles, GL_DYNAMIC_DRAW)
                glUniform4f(fColor, o.color[0], o.color[1], o.color[2], o.color[3])
                glDrawArrays(GL_TRIANGLES, 0, o.triangles.size / 3)
                if (o.onTop) glEnable(GL_DEPTH_TEST)
            }
            glDisable(GL_POLYGON_OFFSET_FILL)
        }
        glBindVertexArray(0)

        // MSAA を解いて読む
        glBindFramebuffer(GL_READ_FRAMEBUFFER, msFbo); glBindFramebuffer(GL_DRAW_FRAMEBUFFER, fbo)
        glBlitFramebuffer(0, 0, w, h, 0, 0, w, h, GL_COLOR_BUFFER_BIT, GL_NEAREST)
        glBindFramebuffer(GL_READ_FRAMEBUFFER, fbo)
        glPixelStorei(GL_PACK_ALIGNMENT, 1)
        val px = pixels!!
        px.clear()
        glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, px)
        px.get(bytes, 0, w * h * 4)
        return Image.makeRaster(ImageInfo(w, h, ColorType.RGBA_8888, ColorAlphaType.OPAQUE), bytes, w * 4)
    }

    fun release() {
        if (!inited) return
        deleteFbo()
        for (v in vaos) glDeleteVertexArrays(v)
        for (b in buffers) glDeleteBuffers(b)
        vaos.clear(); buffers.clear()
        glDeleteProgram(prog); glDeleteProgram(floorProg)
        pixels?.let { MemoryUtil.memFree(it) }; pixels = null
        inited = false
    }

    companion object {
        /** android.opengl.Matrix.perspectiveM と同じ (列優先) */
        fun perspective(m: FloatArray, fovy: Float, aspect: Float, near: Float, far: Float) {
            val f = 1f / kotlin.math.tan(fovy * (Math.PI / 360.0)).toFloat()
            val r = 1f / (near - far)
            m.fill(0f)
            m[0] = f / aspect; m[5] = f; m[10] = (far + near) * r; m[11] = -1f; m[14] = 2f * far * near * r
        }
        /** android.opengl.Matrix.setLookAtM と同じ (上は z) */
        fun lookAt(m: FloatArray, e: FloatArray, t: FloatArray) {
            var fx = t[0] - e[0]; var fy = t[1] - e[1]; var fz = t[2] - e[2]
            val rlf = 1f / sqrt(fx * fx + fy * fy + fz * fz); fx *= rlf; fy *= rlf; fz *= rlf
            val ux = 0f; val uy = 0f; val uz = 1f
            var sx = fy * uz - fz * uy; var sy = fz * ux - fx * uz; var sz = fx * uy - fy * ux
            val rls = 1f / max(sqrt(sx * sx + sy * sy + sz * sz), 1e-12f); sx *= rls; sy *= rls; sz *= rls
            val vx = sy * fz - sz * fy; val vy = sz * fx - sx * fz; val vz = sx * fy - sy * fx
            m[0] = sx; m[1] = vx; m[2] = -fx; m[3] = 0f
            m[4] = sy; m[5] = vy; m[6] = -fy; m[7] = 0f
            m[8] = sz; m[9] = vz; m[10] = -fz; m[11] = 0f
            m[12] = -(sx * e[0] + sy * e[1] + sz * e[2]); m[13] = -(vx * e[0] + vy * e[1] + vz * e[2]); m[14] = fx * e[0] + fy * e[1] + fz * e[2]; m[15] = 1f
        }
    }
}
