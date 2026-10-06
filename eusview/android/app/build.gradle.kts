plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

// ロボットの JSON・一覧の画像 (eusview/robots/<グループ>/*.{json,png}, catalog.json) を APK の assets/robots/ に入れる.
// git には入れず, ビルドのたびに build/generated/robotAssets/robots/ へコピーする
val robotsDir = rootProject.file("../robots")
val robotAssetsDir = layout.buildDirectory.dir("generated/robotAssets")
val copyRobots by tasks.registering(Sync::class) {
    from(robotsDir) { include("*/*.json", "*/*.png", "catalog.json") }
    into(robotAssetsDir.map { it.dir("robots") })
}

// BVH (eusview/bvh/convert_bvh.py の出力 eusview/bvh/cache/, git に入れない) を APK の assets/bvh/ に入れる. なければ空
val bvhDir = rootProject.file("../bvh/cache")
val bvhAssetsDir = layout.buildDirectory.dir("generated/bvhAssets")
val copyBvh by tasks.registering(Sync::class) {
    from(bvhDir) { include("index.json", "*/*.ebvh") }
    from(rootProject.file("../bvh/retarget_tables.json"))   // BVH → ロボットの移し替えの表 (BvhRetarget.kt)
    into(bvhAssetsDir.map { it.dir("bvh") })
}

android {
    namespace = "jp.jsk.eusview"
    compileSdk = 35
    ndkVersion = "27.2.12479018"
    buildToolsVersion = "35.0.0"

    defaultConfig {
        applicationId = "jp.jsk.eusview"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
        ndk { abiFilters += listOf("arm64-v8a", "x86_64") }
        externalNativeBuild {
            cmake {
                arguments += listOf("-DANDROID_STL=c++_static", "-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            // 手元で入れる用: debug の鍵で署名する (配布するときは自分の鍵に変える)
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
    // Android 版とデスクトップ版 (eusview/desktop) で共通のコード (android.* を使わない): eusview/shared/kotlin
    sourceSets["main"].java.srcDir(rootProject.file("../shared/kotlin"))
    sourceSets["main"].assets.srcDir(robotAssetsDir)
    sourceSets["main"].assets.srcDir(bvhAssetsDir)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }
    packaging { jniLibs { useLegacyPackaging = false } }
    testOptions { unitTests.all { it.testLogging { showStandardStreams = true; events("failed") } } }
}

tasks.named("preBuild") { dependsOn(copyRobots, copyBvh) }

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.10.01")
    implementation(composeBom)
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-core")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    debugImplementation("androidx.compose.ui:ui-tooling")
    // BvhRetarget.kt の JVM の単体テスト (RetargetTest.kt): org.json は Android の stub ではなく本物を使う
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
