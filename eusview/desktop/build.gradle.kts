// EusView デスクトップ版 (Ubuntu / Mac): Kotlin + Compose Multiplatform Desktop (JVM)
//   共通のコード: ../shared/kotlin (Android 版と同じファイル), デスクトップの部分: src/main/kotlin
//   3D: LWJGL の OpenGL 3.2 core を画面の外 (FBO) で描いて Compose に画像で出す (RobotGLView.kt, OffscreenGL.kt)
//   物理: JNI のライブラリ (native/CMakeLists.txt, make native → build/native/<os>-<arch>/)
//   ./gradlew run --args="-open kxrl2l6a6h2"   ./gradlew packageDeb (Ubuntu)   (Makefile: make run / make native / make deb)
import org.jetbrains.compose.desktop.application.dsl.TargetFormat

plugins {
    kotlin("jvm") version "2.1.0"
    id("org.jetbrains.compose") version "1.7.3"
    id("org.jetbrains.kotlin.plugin.compose") version "2.1.0"
}

val osName = System.getProperty("os.name").lowercase()
val archName = System.getProperty("os.arch").lowercase()
val isMac = osName.contains("mac")
val isArm = archName == "aarch64" || archName == "arm64"
/** Compose の appResources の名前と同じ: macos-x64, macos-arm64, linux-x64, linux-arm64 */
val hostTarget = (if (isMac) "macos" else "linux") + "-" + (if (isArm) "arm64" else "x64")
val lwjglNatives = "natives-" + (if (isMac) "macos" else "linux") + (if (isArm) "-arm64" else "")
val lwjglVersion = "3.3.4"

val eusviewDir = rootProject.file("..")   // eusview/
val nativeDir = layout.buildDirectory.dir("native/$hostTarget")   // make native の出力

kotlin { jvmToolchain(17) }

sourceSets["main"].kotlin.srcDir(eusviewDir.resolve("shared/kotlin"))

// アイコン (iOS 版と同じ) をクラスパスに入れる (ウィンドウのアイコン)
val iconSrc = eusviewDir.resolve("ios/EusView/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
val iconRes = layout.buildDirectory.dir("generated/iconRes")
val copyIcon by tasks.registering(Copy::class) {
    from(iconSrc) { rename { "eusview-icon.png" } }
    into(iconRes)
}
sourceSets["main"].resources.srcDir(iconRes)
tasks.named("processResources") { dependsOn(copyIcon) }

dependencies {
    implementation(compose.desktop.currentOs)
    implementation(compose.material3)
    implementation("org.jetbrains.compose.material:material-icons-core:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-swing:1.9.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("org.json:json:20240303")
    for (m in listOf("lwjgl", "lwjgl-opengl", "lwjgl-glfw")) {
        implementation("org.lwjgl:$m:$lwjglVersion")
        runtimeOnly("org.lwjgl:$m:$lwjglVersion:$lwjglNatives")
    }
    implementation("org.lwjgl:lwjgl-egl:$lwjglVersion")
}

// 配布用のデータ: ロボットの JSON と BVH (eusview/robots, eusview/bvh/cache + retarget_tables.json) と JNI のライブラリ
//   → build/appResources/common/data/{robots,bvh}, build/appResources/<os>-<arch>/libeusviewode.*
val appRes = layout.buildDirectory.dir("appResources")
val syncAppData by tasks.registering(Sync::class) {
    into(appRes.map { it.dir("common/data") })
    from(eusviewDir.resolve("robots")) { include("*/*.json", "*/*.png", "catalog.json"); into("robots") }
    from(eusviewDir.resolve("bvh/cache")) { include("index.json", "*/*.ebvh"); into("bvh") }
    from(eusviewDir.resolve("bvh/retarget_tables.json")) { into("bvh") }
}
val syncAppNative by tasks.registering(Sync::class) {
    into(appRes.map { it.dir(hostTarget) })
    from(nativeDir) { include("libeusviewode.*") }
    doFirst {
        if (nativeDir.get().asFile.listFiles()?.any { it.name.startsWith("libeusviewode.") } != true)
            logger.warn("物理 (ODE) の JNI ライブラリがありません: 先に make native (${nativeDir.get().asFile})")
    }
}

compose.desktop {
    application {
        mainClass = "jp.jsk.eusview.MainKt"
        jvmArgs += listOf("-Xmx2g", "-Dfile.encoding=UTF-8")
        nativeDistributions {
            targetFormats(TargetFormat.Deb, TargetFormat.Dmg)
            packageName = "eusview"
            packageVersion = "1.0.0"
            description = "EusLisp robot model viewer (EusView)"
            vendor = "JSK"
            appResourcesRootDir.set(appRes)
            modules("java.naming", "java.prefs", "jdk.unsupported", "java.management")
            linux {
                packageName = "eusview"
                iconFile.set(iconSrc)
                menuGroup = "Development;Science"
                appCategory = "science"
                shortcut = true
                debMaintainer = "eusview@example.com"
            }
        }
    }
}

// appResources を作ってから配布物・run
afterEvaluate {
    tasks.matching { it.name == "prepareAppResources" }.configureEach { dependsOn(syncAppData, syncAppNative) }
    // ./gradlew run: データはリポジトリ (eusview/) をそのまま読む, JNI は build/native/<os>-<arch>
    tasks.withType<JavaExec>().configureEach {
        systemProperty("eusview.repo", eusviewDir.canonicalPath)
        systemProperty("eusview.native", nativeDir.get().asFile.canonicalPath)
    }
}
