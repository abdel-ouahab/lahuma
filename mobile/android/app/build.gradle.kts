import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing key, kept out of git (see key.properties.example).
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = !keystoreProperties.isEmpty

// Fajr Call answer detection through the call log. READ_CALL_LOG is a
// Play-restricted permission, so it is off by default; build with
// `flutter build apk --android-project-arg=fajrCallLog=true` for sideloaded
// builds (see docs/fajr-call.md).
val fajrCallLog = (project.findProperty("fajrCallLog") as String?)?.toBoolean() ?: false

val releaseTasks = gradle.startParameter.taskNames.filter { it.contains("Release") }
if (!hasReleaseKey && releaseTasks.isNotEmpty()) {
    // An app bundle is only ever made to upload to Play, and one signed with
    // the debug key can never be published (nor updated later): stop here.
    if (releaseTasks.any { it.contains("bundle", ignoreCase = true) }) {
        throw GradleException("android/key.properties not found: create the upload key first (see key.properties.example).")
    }
    logger.warn("android/key.properties not found: the release build is signed with the debug key and cannot be published.")
}

// The Dart defines of this build (`--dart-define`), which Flutter hands to
// Gradle base64-encoded. A release build without API_BASE_URL would talk to
// the emulator's dev server (http://10.0.2.2), and release builds block
// plain http:// anyway, so accounts, muezzins and reciters would all fail.
val dartDefines: Map<String, String> = (project.findProperty("dart-defines") as String?)
    .orEmpty()
    .split(",")
    .filter { it.isNotBlank() }
    .mapNotNull {
        val pair = String(Base64.getDecoder().decode(it)).split("=", limit = 2)
        if (pair.size == 2) pair[0] to pair[1] else null
    }
    .toMap()
if (releaseTasks.isNotEmpty()) {
    val apiBaseUrl = dartDefines["API_BASE_URL"]
    if (apiBaseUrl == null || !apiBaseUrl.startsWith("https://")) {
        throw GradleException(
            "Release builds need the production API: add --dart-define=API_BASE_URL=https://<DOMAIN>/api " +
                "(found: ${apiBaseUrl ?: "none"})."
        )
    }
}

android {
    namespace = "com.lahuma.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs java.time on older Android.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.lahuma.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField("boolean", "FAJR_CALL_LOG", fajrCallLog.toString())
        manifestPlaceholders["fajrCallLogPermission"] =
            if (fajrCallLog) "android.permission.READ_CALL_LOG"
            else "com.lahuma.app.permission.FAJR_CALL_LOG_DISABLED"
    }

    buildFeatures {
        buildConfig = true
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // The real key when android/key.properties exists; otherwise the
            // debug key, so `flutter run --release` still works locally.
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Fajr Call engine: notifications, foreground service, permissions.
    implementation("androidx.core:core-ktx:1.16.0")
    // Adhan: the daily and after-boot headless reschedule.
    implementation("androidx.work:work-runtime:2.10.1")
    testImplementation("junit:junit:4.13.2")
}
