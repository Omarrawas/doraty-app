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
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Enable core library desugaring which some plugins require
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.doraty.app"
        // Ensure minSdk is set from Flutter config and enable multidex for desugaring
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        multiDexEnabled = true
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        signingConfigs {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias") ?: "doraty_key"
                keyPassword = keystoreProperties.getProperty("keyPassword") ?: "changeit"
                // Resolve store file relative to project root for predictable path
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile") ?: "android/app/key.jks")
                storePassword = keystoreProperties.getProperty("storePassword") ?: "changeit"
            }
        }
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            // Ensure shrinkResources is disabled unless code shrinking is enabled
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required for desugaring (support for newer Java APIs on older devices)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
    // Required when using core library desugaring
    implementation("androidx.multidex:multidex:2.0.1")
}
