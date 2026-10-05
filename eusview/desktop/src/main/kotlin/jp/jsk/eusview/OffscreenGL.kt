// OffscreenGL.kt : 画面に出さない OpenGL のコンテキストを 1 つ作り, 専用のスレッドで使う (デスクトップ版の 3D 表示)
//   ウィンドウは Compose (Swing / AWT) のものだけ. OpenGL は FBO に描いて glReadPixels で読み, Compose に画像で出す (RobotGLView.kt)
//   ・macOS: CGL (OpenGL 3.2 core). GLFW は macOS ではメインスレッドでしか使えず AWT とぶつかるので使わない
//   ・Linux: EGL (pbuffer か面なし, デスクトップの OpenGL 3.2 core). だめなら GLFW の見えないウィンドウ (X11 / XWayland / Wayland)
//   EUSVIEW_GL=egl | glfw で Linux の方法を決められる
package jp.jsk.eusview

import org.lwjgl.PointerBuffer
import org.lwjgl.egl.EGL
import org.lwjgl.egl.EGL10
import org.lwjgl.glfw.GLFW
import org.lwjgl.opengl.CGL
import org.lwjgl.opengl.GL
import org.lwjgl.opengl.GL11C
import org.lwjgl.system.Configuration
import org.lwjgl.system.FunctionProvider
import org.lwjgl.system.Library
import org.lwjgl.system.MemoryStack
import org.lwjgl.system.MemoryUtil.NULL
import org.lwjgl.system.SharedLibrary
import java.nio.ByteBuffer
import java.util.concurrent.Executors

object OffscreenGL {
    private val exec = Executors.newSingleThreadExecutor { r -> Thread(r, "EusView-GL").also { it.isDaemon = true } }
    /** コンテキストを作れなかったときの理由 (null なら使える) */
    @Volatile var error: String? = null; private set
    @Volatile var info: String = ""; private set
    private var ready = false
    private var tried = false

    /** GL のスレッドで f を実行する (コンテキストは current). コンテキストを作れないときや f が失敗したときは onError */
    fun post(f: () -> Unit, onError: (Throwable) -> Unit) {
        exec.execute {
            try { ensure(); f() } catch (e: Throwable) {
                if (ready) Platform.logError("OpenGL", e)
                onError(e)
            }
        }
    }

    private fun ensure() {
        if (tried) { if (!ready) throw IllegalStateException(error ?: "OpenGL がありません"); return }
        tried = true
        val os = System.getProperty("os.name").lowercase()
        val errs = ArrayList<String>()
        val how = System.getenv("EUSVIEW_GL")?.lowercase()
        val ways: List<Pair<String, () -> Unit>> = if (os.contains("mac")) listOf("CGL" to ::initCGL)
            else when (how) {
                "glfw" -> listOf("GLFW" to ::initGLFW)
                "egl" -> listOf("EGL" to ::initEGL)
                else -> listOf("EGL" to ::initEGL, "GLFW" to ::initGLFW)
            }
        // GL の関数の読み方は方法ごとに決める (GL.create を自分で呼ぶ)
        Configuration.OPENGL_EXPLICIT_INIT.set(true)
        for ((name, f) in ways) {
            try {
                f()
                ready = true
                info = "$name: ${GL11C.glGetString(GL11C.GL_RENDERER)} / OpenGL ${GL11C.glGetString(GL11C.GL_VERSION)}"
                Platform.log("OpenGL ($info)")
                return
            } catch (e: Throwable) {
                errs.add("$name: ${e.message ?: e.javaClass.simpleName}")
                try { GL.destroy() } catch (_: Throwable) {}
                Platform.logError("OpenGL ($name) を使えません", e)
            }
        }
        error = "OpenGL のコンテキストを作れません (" + errs.joinToString("; ") + ")"
        throw IllegalStateException(error)
    }

    // ---- macOS ----
    private fun initCGL() {
        GL.create()
        MemoryStack.stackPush().use { st ->
            val pix = st.mallocPointer(1); val npix = st.mallocInt(1)
            val attrs = st.ints(
                CGL.kCGLPFAOpenGLProfile, CGL.kCGLOGLPVersion_3_2_Core,
                CGL.kCGLPFAColorSize, 24, CGL.kCGLPFAAlphaSize, 8, CGL.kCGLPFADepthSize, 24,
                CGL.kCGLPFAAccelerated, CGL.kCGLPFAAllowOfflineRenderers, 0)
            check(CGL.CGLChoosePixelFormat(attrs, pix, npix) == 0 && pix.get(0) != NULL) { "CGLChoosePixelFormat" }
            val ctx = st.mallocPointer(1)
            check(CGL.CGLCreateContext(pix.get(0), NULL, ctx) == 0 && ctx.get(0) != NULL) { "CGLCreateContext" }
            CGL.CGLDestroyPixelFormat(pix.get(0))
            check(CGL.CGLSetCurrentContext(ctx.get(0)) == 0) { "CGLSetCurrentContext" }
        }
        GL.createCapabilities()
    }

    // ---- Linux: EGL ----
    private fun initEGL() {
        val dpy = EGL10.eglGetDisplay(NULL /* EGL_DEFAULT_DISPLAY */)
        check(dpy != NULL) { "eglGetDisplay" }
        MemoryStack.stackPush().use { st ->
            val major = st.mallocInt(1); val minor = st.mallocInt(1)
            check(EGL10.eglInitialize(dpy, major, minor)) { "eglInitialize" }
            EGL.createDisplayCapabilities(dpy, major.get(0), minor.get(0))
            val EGL_OPENGL_API = 0x30A2; val EGL_OPENGL_BIT = 0x0008
            check(org.lwjgl.egl.EGL12.eglBindAPI(EGL_OPENGL_API)) { "eglBindAPI(OpenGL)" }
            // pbuffer の使える設定. なければ (Mesa の Wayland など) 面なし (EGL_KHR_surfaceless_context) で使う
            fun choose(surfaceType: Int): Long {
                val attrs = st.ints(EGL10.EGL_SURFACE_TYPE, surfaceType, 0x3040 /* EGL_RENDERABLE_TYPE */, EGL_OPENGL_BIT,
                    EGL10.EGL_RED_SIZE, 8, EGL10.EGL_GREEN_SIZE, 8, EGL10.EGL_BLUE_SIZE, 8, EGL10.EGL_DEPTH_SIZE, 24, EGL10.EGL_NONE)
                val cfgs: PointerBuffer = st.mallocPointer(1); val n = st.mallocInt(1)
                return if (EGL10.eglChooseConfig(dpy, attrs, cfgs, n) && n.get(0) > 0) cfgs.get(0) else NULL
            }
            var cfg = choose(EGL10.EGL_PBUFFER_BIT)
            var surf = if (cfg != NULL) EGL10.eglCreatePbufferSurface(dpy, cfg, st.ints(EGL10.EGL_WIDTH, 16, EGL10.EGL_HEIGHT, 16, EGL10.EGL_NONE)) else NULL
            if (surf == NULL) { cfg = choose(0); surf = NULL /* EGL_NO_SURFACE */ }
            check(cfg != NULL) { "eglChooseConfig" }
            // OpenGL 3.2 core (EGL_KHR_create_context), だめなら既定 (compatibility)
            var ctx = EGL10.eglCreateContext(dpy, cfg, NULL,
                st.ints(0x3098 /* MAJOR */, 3, 0x30FB /* MINOR */, 2, 0x30FD /* PROFILE_MASK */, 0x1 /* CORE */, EGL10.EGL_NONE))
            if (ctx == NULL) ctx = EGL10.eglCreateContext(dpy, cfg, NULL, st.ints(EGL10.EGL_NONE))
            check(ctx != NULL) { "eglCreateContext" }
            check(EGL10.eglMakeCurrent(dpy, surf, surf, ctx)) { "eglMakeCurrent" }
        }
        // GL の関数: libOpenGL.so.0 (GLVND) か eglGetProcAddress
        val lib: SharedLibrary? = try { Library.loadNative(OffscreenGL::class.java, "org.lwjgl.opengl", "libOpenGL.so.0") } catch (e: Throwable) { null }
        GL.create(object : FunctionProvider {
            override fun getFunctionAddress(functionName: ByteBuffer): Long {
                val a = lib?.getFunctionAddress(functionName) ?: NULL
                return if (a != NULL) a else EGL10.eglGetProcAddress(functionName)
            }
        })
        GL.createCapabilities()
    }

    // ---- Linux: GLFW (見えないウィンドウ) ----
    private fun initGLFW() {
        check(GLFW.glfwInit()) { "glfwInit" }
        GLFW.glfwDefaultWindowHints()
        GLFW.glfwWindowHint(GLFW.GLFW_VISIBLE, GLFW.GLFW_FALSE)
        GLFW.glfwWindowHint(GLFW.GLFW_CONTEXT_VERSION_MAJOR, 3)
        GLFW.glfwWindowHint(GLFW.GLFW_CONTEXT_VERSION_MINOR, 2)
        GLFW.glfwWindowHint(GLFW.GLFW_OPENGL_PROFILE, GLFW.GLFW_OPENGL_CORE_PROFILE)
        GLFW.glfwWindowHint(GLFW.GLFW_OPENGL_FORWARD_COMPAT, GLFW.GLFW_TRUE)
        val w = GLFW.glfwCreateWindow(16, 16, "EusView GL", NULL, NULL)
        check(w != NULL) { "glfwCreateWindow" }
        GLFW.glfwMakeContextCurrent(w)
        GL.create(object : FunctionProvider {
            override fun getFunctionAddress(functionName: ByteBuffer): Long = GLFW.glfwGetProcAddress(functionName)
        })
        GL.createCapabilities()
    }
}
