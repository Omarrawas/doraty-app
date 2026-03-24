# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Supabase & Postgrest
-keep class io.github.jan.supabase.** { *; }
-keep class io.github.jan.supabase.postgrest.** { *; }
-keep class io.github.jan.supabase.auth.** { *; }
-keep class io.github.jan.supabase.storage.** { *; }
-keep class io.github.jan.supabase.realtime.** { *; }

# Video Player / Chewie
-keep class com.google.android.exoplayer2.** { *; }
-keep class com.brianegan.chewie.** { *; }

# Hive
-keep class io.hive.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Screen Security Plugins
-keep class io.adaptant.labs.flutter_windowmanager.** { *; }
-keep class com.example.no_screenshot.** { *; }

# General JNI keep
-keepclasseswithmembernames class * {
    native <methods>;
}

# Flutter Play Store Split / Deferred Components (Resolves R8 Missing Class errors)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

