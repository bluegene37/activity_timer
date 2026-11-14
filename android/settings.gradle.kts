pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Gene - Nov, 14, 2026: Upgraded AGP from 8.11.1 to 9.3.1 and Kotlin Gradle Plugin from 2.2.20 to 2.4.20 for Flutter 3.50.0 / Gradle 9.5.0 compatibility
    // id("com.android.application") version "8.11.1" apply false
    // id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    id("com.android.application") version "9.3.1" apply false
    id("org.jetbrains.kotlin.android") version "2.4.20" apply false
}

include(":app")
