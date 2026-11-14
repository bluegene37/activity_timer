import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // Gene - Nov, 14, 2026: Commented out explicit kotlin-android plugin per Flutter 3.50.0 / AGP 9.3.1 template (managed by Flutter Gradle Plugin while android.builtInKotlin=false)
    // id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is read from android/key.properties (gitignored).
// See android/key.properties.example for the expected keys.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

android {
    namespace = "dev.genexis.activitytimer"
    compileSdk = flutter.compileSdkVersion
//    ndkVersion = flutter.ndkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        // flutter_local_notifications schedules with java.time, which needs
        // desugaring to run below API 26.
        isCoreLibraryDesugaringEnabled = true
        // Gene - Nov, 14, 2026: Upgraded Java compatibility from VERSION_11 to VERSION_17 for Flutter 3.50.0 / AGP 9.3.1
        // sourceCompatibility = JavaVersion.VERSION_11
        // targetCompatibility = JavaVersion.VERSION_11
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Gene - Nov, 14, 2026: Migrated deprecated android.kotlinOptions block to top-level kotlin.compilerOptions DSL below for Kotlin 2.4.20 / AGP 9.3.1
    // kotlinOptions {
    //     jvmTarget = JavaVersion.VERSION_11.toString()
    // }

    defaultConfig {
        applicationId = "dev.genexis.activitytimer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Without key.properties, fall back to debug keys so
            // `flutter run --release` still works on a fresh checkout.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// Gene - Nov, 14, 2026: Configured Kotlin compilerOptions JVM target 17 using Kotlin 2.4.20 top-level DSL
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
