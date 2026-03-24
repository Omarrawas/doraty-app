import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Load keystore properties from android/key.properties (not checked into VCS)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

android {
    namespace = "com.doraty.app"
    compileSdk = 35
    ndkVersion = "26.1.10909125"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Enable core library desugaring which some plugins require
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.doraty.app"
        // Ensure minSdk is set from Flutter config and enable multidex for desugaring
        minSdk = 24
        targetSdk = 35
        multiDexEnabled = true
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String? ?: "doraty_key"
            keyPassword = keystoreProperties["keyPassword"] as String? ?: "changeit"
            storeFile = if (keystoreProperties["storeFile"] != null) {
                rootProject.file(keystoreProperties["storeFile"])
            } else {
                file("key.jks")
            }
            storePassword = keystoreProperties["storePassword"] as String? ?: "changeit"
        }
        getByName("debug") {
            keyAlias = keystoreProperties["keyAlias"] as String? ?: "doraty_key"
            keyPassword = keystoreProperties["keyPassword"] as String? ?: "changeit"
            storeFile = if (keystoreProperties["storeFile"] != null) {
                rootProject.file(keystoreProperties["storeFile"])
            } else {
                file("key.jks")
            }
            storePassword = keystoreProperties["storePassword"] as String? ?: "changeit"
        }
    }

    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required for desugaring (support for newer Java APIs on older devices)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Required when using core library desugaring
    implementation("androidx.multidex:multidex:2.0.1")
    // Added for Android 15 Edge-to-Edge support
    implementation("androidx.activity:activity-ktx:1.10.0")
}
