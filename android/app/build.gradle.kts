import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "uz.romflow.offline"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Release signing. android/key.properties (never committed; CI writes it
    // from repository secrets) names the release key. Without it the pilot
    // key in pilot-signing/ is used when that folder exists, so every pilot
    // APK installs over the previous one; otherwise Android's debug key.
    val keyProperties = Properties().apply {
        val f = rootProject.file("key.properties")
        if (f.exists()) f.inputStream().use { load(it) }
    }
    val pilotKey = file("pilot-signing/debug.keystore")
    signingConfigs {
        val keyFile = keyProperties.getProperty("storeFile")
        if (keyFile != null) {
            create("release") {
                storeFile = file(keyFile)
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        } else if (pilotKey.exists()) {
            create("release") {
                storeFile = pilotKey
                storePassword = "android"
                keyAlias = "androiddebugkey"
                keyPassword = "android"
            }
        }
    }
    val appKey = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")

    defaultConfig {
        // A new id: earlier pilot APKs were signed with a key that is not
        // available, so reusing their id would make Android refuse the install.
        applicationId = "uz.romflow.workshop"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml, also for the per-ABI APKs
        // (see the end of this file).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("debug") {
            signingConfig = appKey
        }
        release {
            signingConfig = appKey
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

// For per-ABI APKs (--split-per-abi) Flutter adds 1000 × the ABI number to
// the version code, so the arm64 APK of build 15 would be 2015. Then the
// universal APK of build 16 could not be installed over it. Keep the
// pubspec version code on every APK; this runs after Flutter's own hook.
@Suppress("DEPRECATION")
android.applicationVariants.configureEach {
    val code = versionCode
    outputs.configureEach {
        (this as com.android.build.gradle.api.ApkVariantOutput).versionCodeOverride = code
    }
}
