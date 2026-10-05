// RobotGLView.kt : ロボットの 3D 表示 (OpenGL ES 3.0). iOS 版の SceneKit の代わり
//   ・メッシュごとに頂点バッファ (三角形ごとに頂点を分けて面の法線: 角ばった見た目) を 1 度だけ作り, 毎コマは行列だけ変える
//   ・平行光 2 つ + 環境光, 両面 (裏面は法線を反転), z = 0 の灰色の床と格子
//   ・1 本指で回転, 2 本指でつまんで拡大縮小・動かして平行移動
//   カメラ・メッシュ・床・光・色は共通 (eusview/shared/kotlin/.../SceneCommon.kt, デスクトップ版と同じ)
package jp.jsk.eusview

import android.annotation.SuppressLint
import android.content.Context
import android.opengl.GLES30
import android.opengl.GLSurfaceView
import android.opengl.Matrix
import android.util.Log
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import javax.microedition.khronos.egl.EGL10
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.egl.EGLDisplay
import javax.microedition.khronos.opengles.GL10
import kotlin.math.max

@SuppressLint("ViewConstructor")
class RobotGLView(context: Context, val scene: RobotScene, dark: Boolean, grid: FloatArray? = null) : GLSurfaceView(context), SceneView {
    private val renderer = RobotRenderer(scene, dark, grid)

    init {
        setEGLContextClientVersion(3)
        setEGLConfigChooser(MsaaConfigChooser())
        preserveEGLContextOnPause = true
        setRenderer(renderer)
        renderMode = RENDERMODE_WHEN_DIRTY
        scene.onChange = { requestRender() }
    }

    /** 明るい / 暗い表示を切り替える (端末のダークモードに合わせる) */
    fun setDark(d: Boolean) { if (renderer.dark != d) { renderer.dark = d; requestRender() } }

    /** カメラの注視点と視点を (dx, dy, dz) m だけ動かす (BVH の再生で腰についていく) */
    override fun follow(dx: Float, dy: Float, dz: Float) { renderer.cam.shift(dx, dy, dz); requestRender() }

    /** カメラを最初の向き・距離に戻す (今の姿勢の外接箱) */
    override fun resetCamera() { renderer.cam.frame(scene.bounds()); requestRender() }

    /** カメラを前 (+x) から少し斜めに: BVH の画面で棒人形とロボットを横に並べて見る. dir = 注視点から視点への向き (EusLisp の座標) */
    override fun frontView(b: FloatArray) { renderer.cam.frame(b, floatArrayOf(2.3f, -0.7f, 0.8f)); requestRender() }

    // ---- 触って動かす ----
    private var lastX = 0f; private var lastY = 0f; private var lastCount = 0
    private val scaleDetector = ScaleGestureDetector(context, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
        override fun onScale(d: ScaleGestureDetector): Boolean {
            renderer.cam.zoom(d.scaleFactor); requestRender(); return true
        }
    })

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(e: MotionEvent): Boolean {
        parent?.requestDisallowInterceptTouchEvent(true)
        scaleDetector.onTouchEvent(e)
        val n = e.pointerCount
        var cx = 0f; var cy = 0f
        for (i in 0 until n) { cx += e.getX(i); cy += e.getY(i) }
        cx /= n; cy /= n
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN, MotionEvent.ACTION_POINTER_UP -> {
                // 指の数が変わったら基準を取り直す (ACTION_POINTER_UP は離れる指も数に入っている)
                if (e.actionMasked == MotionEvent.ACTION_POINTER_UP) {
                    cx = 0f; cy = 0f; var m = 0
                    for (i in 0 until n) if (i != e.actionIndex) { cx += e.getX(i); cy += e.getY(i); m++ }
                    cx /= max(m, 1); cy /= max(m, 1); lastCount = m
                } else lastCount = n
                lastX = cx; lastY = cy
            }
            MotionEvent.ACTION_MOVE -> {
                if (n != lastCount) { lastCount = n; lastX = cx; lastY = cy; return true }
                val dx = cx - lastX; val dy = cy - lastY
                lastX = cx; lastY = cy
                if (n == 1) renderer.cam.orbit(dx, dy, height) else renderer.cam.pan(dx, dy, height)
                requestRender()
            }
        }
        return true
    }
}

/** 4x MSAA が使えればそれ, なければ普通の設定 */
private class MsaaConfigChooser : GLSurfaceView.EGLConfigChooser {
    override fun chooseConfig(egl: EGL10, display: EGLDisplay): EGLConfig {
        val EGL_OPENGL_ES3_BIT = 0x40
        fun attrs(samples: Int) = intArrayOf(
            EGL10.EGL_RED_SIZE, 8, EGL10.EGL_GREEN_SIZE, 8, EGL10.EGL_BLUE_SIZE, 8, EGL10.EGL_DEPTH_SIZE, 24,
            EGL10.EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
            EGL10.EGL_SAMPLE_BUFFERS, if (samples > 0) 1 else 0, EGL10.EGL_SAMPLES, samples, EGL10.EGL_NONE)
        for (s in intArrayOf(4, 0)) {
            val cfg = arrayOfNulls<EGLConfig>(1); val num = IntArray(1)
            if (egl.eglChooseConfig(display, attrs(s), cfg, 1, num) && num[0] > 0 && cfg[0] != null) return cfg[0]!!
        }
        throw IllegalStateException("EGL の設定が見つかりません")
    }
}

/** grid: 床の格子 [間隔, 半分の幅] m (null ならロボットの大きさから決める) */
class RobotRenderer(private val scene: RobotScene, @Volatile var dark: Boolean, private val grid: FloatArray? = null) : GLSurfaceView.Renderer {
    val cam = OrbitCamera().also { it.frame(scene.bounds()) }

    private val meshes: List<FlatMesh> = flatMeshes(scene.model)
    private val world = FloatArray(16 * scene.model.links.size)
    private var prog = 0; private var floorProg = 0
    private var uMvp = 0; private var uModel = 0; private var uColor = 0; private var uL1 = 0; private var uL2 = 0; private var uAmb = 0; private var uEmit = 0
    private var fMvp = 0; private var fColor = 0
    private var floorVao = 0; private var floorCount = 0; private var gridVao = 0; private var gridCount = 0
    private var ovVao = 0; private var ovVbo = 0   // 重ねて描く印 (毎コマ書き換える)
    private val proj = FloatArray(16); private val view = FloatArray(16); private val vp = FloatArray(16); private val mvp = FloatArray(16)
    private var aspect = 1f

    private fun shader(type: Int, src: String): Int {
        val s = GLES30.glCreateShader(type)
        GLES30.glShaderSource(s, src); GLES30.glCompileShader(s)
        val ok = IntArray(1); GLES30.glGetShaderiv(s, GLES30.GL_COMPILE_STATUS, ok, 0)
        if (ok[0] == 0) Log.e("EusView", "shader: " + GLES30.glGetShaderInfoLog(s))
        return s
    }
    private fun program(vs: String, fs: String): Int {
        val p = GLES30.glCreateProgram()
        GLES30.glAttachShader(p, shader(GLES30.GL_VERTEX_SHADER, vs))
        GLES30.glAttachShader(p, shader(GLES30.GL_FRAGMENT_SHADER, fs))
        GLES30.glLinkProgram(p)
        val ok = IntArray(1); GLES30.glGetProgramiv(p, GLES30.GL_LINK_STATUS, ok, 0)
        if (ok[0] == 0) Log.e("EusView", "link: " + GLES30.glGetProgramInfoLog(p))
        return p
    }

    private fun floatBuffer(a: FloatArray): FloatBuffer =
        ByteBuffer.allocateDirect(a.size * 4).order(ByteOrder.nativeOrder()).asFloatBuffer().also { it.put(a); it.position(0) }

    private fun makeVao(data: FloatArray, stride: Int, withNormal: Boolean): Int {
        val ids = IntArray(1); GLES30.glGenVertexArrays(1, ids, 0)
        val b = IntArray(1); GLES30.glGenBuffers(1, b, 0)
        GLES30.glBindVertexArray(ids[0])
        GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, b[0])
        GLES30.glBufferData(GLES30.GL_ARRAY_BUFFER, data.size * 4, floatBuffer(data), GLES30.GL_STATIC_DRAW)
        GLES30.glEnableVertexAttribArray(0)
        GLES30.glVertexAttribPointer(0, 3, GLES30.GL_FLOAT, false, stride * 4, 0)
        if (withNormal) {
            GLES30.glEnableVertexAttribArray(1)
            GLES30.glVertexAttribPointer(1, 3, GLES30.GL_FLOAT, false, stride * 4, 12)
        }
        GLES30.glBindVertexArray(0)
        return ids[0]
    }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        prog = program(
            """#version 300 es
            layout(location = 0) in vec3 aPos;
            layout(location = 1) in vec3 aNor;
            uniform mat4 uMvp; uniform mat4 uModel;
            out vec3 vNor;
            void main() { vNor = mat3(uModel) * aNor; gl_Position = uMvp * vec4(aPos, 1.0); }""",
            """#version 300 es
            precision mediump float;
            in vec3 vNor; uniform vec4 uColor; uniform vec3 uL1; uniform vec3 uL2; uniform float uAmb; uniform vec3 uEmit;
            out vec4 frag;
            void main() {
              vec3 n = normalize(vNor); if (!gl_FrontFacing) n = -n;
              float d = uAmb + 0.70 * max(dot(n, uL1), 0.0) + 0.25 * max(dot(n, uL2), 0.0);
              frag = vec4(min(uColor.rgb * min(d, 1.15) + uEmit, 1.0), uColor.a);
            }""")
        uMvp = GLES30.glGetUniformLocation(prog, "uMvp"); uModel = GLES30.glGetUniformLocation(prog, "uModel")
        uColor = GLES30.glGetUniformLocation(prog, "uColor"); uL1 = GLES30.glGetUniformLocation(prog, "uL1")
        uL2 = GLES30.glGetUniformLocation(prog, "uL2"); uAmb = GLES30.glGetUniformLocation(prog, "uAmb")
        uEmit = GLES30.glGetUniformLocation(prog, "uEmit")
        floorProg = program(
            """#version 300 es
            layout(location = 0) in vec3 aPos; uniform mat4 uMvp;
            void main() { gl_Position = uMvp * vec4(aPos, 1.0); }""",
            """#version 300 es
            precision mediump float; uniform vec4 uColor; out vec4 frag;
            void main() { frag = uColor; }""")
        fMvp = GLES30.glGetUniformLocation(floorProg, "uMvp"); fColor = GLES30.glGetUniformLocation(floorProg, "uColor")
        for (m in meshes) m.vao = makeVao(m.data, 6, true)
        // 床 (z = 0) と格子: 格子の間隔はロボットの大きさに合わせる (10 cm, 1 m ...)
        val r = cam.radius
        floorVao = makeVao(floorTriangles(r, grid), 3, false)
        floorCount = 6
        val lines = gridLines(r, grid)
        gridVao = makeVao(lines, 3, false)
        gridCount = lines.size / 3
        val ids = IntArray(1); GLES30.glGenVertexArrays(1, ids, 0); ovVao = ids[0]
        GLES30.glGenBuffers(1, ids, 0); ovVbo = ids[0]
        GLES30.glBindVertexArray(ovVao); GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, ovVbo)
        GLES30.glEnableVertexAttribArray(0); GLES30.glVertexAttribPointer(0, 3, GLES30.GL_FLOAT, false, 12, 0)
        GLES30.glBindVertexArray(0)
        GLES30.glEnable(GLES30.GL_DEPTH_TEST)
        GLES30.glDisable(GLES30.GL_CULL_FACE)
        GLES30.glEnable(GLES30.GL_BLEND)
        GLES30.glBlendFunc(GLES30.GL_SRC_ALPHA, GLES30.GL_ONE_MINUS_SRC_ALPHA)
    }

    override fun onSurfaceChanged(gl: GL10?, w: Int, h: Int) {
        GLES30.glViewport(0, 0, w, h)
        aspect = w.toFloat() / max(h, 1)
    }

    override fun onDrawFrame(gl: GL10?) {
        val dark = dark
        val bg = SceneColors.clear(dark)
        GLES30.glClearColor(bg[0], bg[1], bg[2], bg[3])
        GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT or GLES30.GL_DEPTH_BUFFER_BIT)
        scene.copyWorld(world)
        val e = cam.eye(); val t = cam.target
        Matrix.perspectiveM(proj, 0, 45f, aspect, cam.near(), cam.far())
        Matrix.setLookAtM(view, 0, e[0], e[1], e[2], t[0], t[1], t[2], 0f, 0f, 1f)
        Matrix.multiplyMM(vp, 0, proj, 0, view, 0)

        // 床: ロボットより先に, 少し奥にずらして描く (足の裏とちらつかないように)
        GLES30.glUseProgram(floorProg)
        GLES30.glUniformMatrix4fv(fMvp, 1, false, vp, 0)
        GLES30.glEnable(GLES30.GL_POLYGON_OFFSET_FILL); GLES30.glPolygonOffset(1f, 1f)
        SceneColors.floor(dark).let { GLES30.glUniform4f(fColor, it[0], it[1], it[2], it[3]) }
        GLES30.glBindVertexArray(floorVao); GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, floorCount)
        GLES30.glDisable(GLES30.GL_POLYGON_OFFSET_FILL)
        SceneColors.grid(dark).let { GLES30.glUniform4f(fColor, it[0], it[1], it[2], it[3]) }
        GLES30.glBindVertexArray(gridVao); GLES30.glDrawArrays(GLES30.GL_LINES, 0, gridCount)

        GLES30.glUseProgram(prog)
        // 光: カメラの左上の前から (視点に合わせて回す) + 上から
        val l1 = keyLight(e, t)
        GLES30.glUniform3f(uL1, l1[0], l1[1], l1[2])
        GLES30.glUniform3f(uL2, 0f, 0f, 1f)
        GLES30.glUniform1f(uAmb, SceneColors.AMBIENT)
        val model = FloatArray(16)
        // 違反の表示: リンクの色 (赤 = 衝突, 橙 = 可動範囲の端) と, 薄く描くリンク (不透明のものの後で, 深さを書かずに)
        val tints = scene.tints
        for (pass in 0..1) {
            if (pass == 1) GLES30.glDepthMask(false)
            for (m in meshes) {
                val t = tints?.getOrNull(m.link) ?: 0
                if ((t == Tint.FADED) != (pass == 1)) continue
                System.arraycopy(world, 16 * m.link, model, 0, 16)
                Matrix.multiplyMM(mvp, 0, vp, 0, model, 0)
                GLES30.glUniformMatrix4fv(uMvp, 1, false, mvp, 0)
                GLES30.glUniformMatrix4fv(uModel, 1, false, model, 0)
                GLES30.glUniform4f(uColor, m.color[0], m.color[1], m.color[2], m.color[3] * Tint.alpha(t))
                val em = Tint.emit(t)
                GLES30.glUniform3f(uEmit, em?.get(0) ?: 0f, em?.get(1) ?: 0f, em?.get(2) ?: 0f)
                GLES30.glBindVertexArray(m.vao)
                GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, m.count)
            }
            if (pass == 1) GLES30.glDepthMask(true)
        }
        // 重ねて描く印 (重心の球と床への投影, 支持多角形): 床より少し手前に. onTop は体に隠れても見せる
        val ovs = scene.overlays
        if (ovs.isNotEmpty()) {
            GLES30.glUseProgram(floorProg)
            GLES30.glUniformMatrix4fv(fMvp, 1, false, vp, 0)
            GLES30.glBindVertexArray(ovVao); GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, ovVbo)
            GLES30.glEnable(GLES30.GL_POLYGON_OFFSET_FILL); GLES30.glPolygonOffset(-1f, -4f)
            for (o in ovs) {
                if (o.triangles.isEmpty()) continue
                if (o.onTop) GLES30.glDisable(GLES30.GL_DEPTH_TEST)
                GLES30.glBufferData(GLES30.GL_ARRAY_BUFFER, o.triangles.size * 4, floatBuffer(o.triangles), GLES30.GL_DYNAMIC_DRAW)
                GLES30.glUniform4f(fColor, o.color[0], o.color[1], o.color[2], o.color[3])
                GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, o.triangles.size / 3)
                if (o.onTop) GLES30.glEnable(GLES30.GL_DEPTH_TEST)
            }
            GLES30.glDisable(GLES30.GL_POLYGON_OFFSET_FILL)
        }
        GLES30.glBindVertexArray(0)
    }
}
