buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.9.1")
        classpath("com.google.gms:google-services:4.4.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://storage.googleapis.com/download.flutter.io")
        }
    }
}


val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            
            val manifestFile = file("src/main/AndroidManifest.xml")
            if (manifestFile.exists()) {
                val xml = manifestFile.readText()
                val match = Regex("package=\"([^\"]+)\"").find(xml)
                
                // 1. Set namespace from package attribute if not already set
                if (android.namespace == null && match != null) {
                    android.namespace = match.groupValues[1]
                }
                
                // 2. CRUCIAL FIX: Strip 'package' attribute from Manifest to satisfy AGP 8.x
                // AGP 8 fails if both namespace is set AND package exists in Manifest.
                if (match != null) {
                    val strippedXml = xml.replace(Regex("""\s+package="[^"]+""""), "")
                    manifestFile.writeText(strippedXml)
                }
            }
            
            // Final fallback
            if (android.namespace == null) {
                android.namespace = "com.doraty.generated.${project.name.replace("-", "_")}"
            }

            android.compileSdkVersion(36)
            android.defaultConfig {
                minSdkVersion(24)
            }

            android.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_11
                targetCompatibility = JavaVersion.VERSION_11
            }

            // Fix Kotlin JVM target (Kotlin 2.x)
            project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
                }
            }

            // 3. JAVASURGERY: Fix legacy Flutter V1 embedding errors in Java files
            val javaPluginFile = file("src/main/java/io/adaptant/labs/flutter_windowmanager/FlutterWindowManagerPlugin.java")
            if (javaPluginFile.exists()) {
                var content = javaPluginFile.readText()
                if (content.contains("import io.flutter.plugin.common.PluginRegistry.Registrar;")) {
                    // Remove problematic imports and methods that use Registrar
                    content = content.replace("import io.flutter.plugin.common.PluginRegistry.Registrar;", "")
                    content = content.replace(Regex("""public static void registerWith\(Registrar registrar\) \{.*?\}""", RegexOption.DOT_MATCHES_ALL), "")
                    javaPluginFile.writeText(content)
                }
            }
        }
    }
}






subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}




