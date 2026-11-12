-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class androidx.lifecycle.** { *; }
-keep class androidx.work.** { *; }

# Keep flutter_secure_storage & Tink crypto classes under real namespace
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.google.crypto.tink.** { *; }

# Firebase & ML Kit ComponentDiscovery instantiates ComponentRegistrar implementations via zero-arg reflection.
# firebase-components:18.0.0 omits `{ <init>(); }`, causing AGP 9 R8 full mode to strip registrar constructors
# and crash MlKitInitProvider at startup (NoSuchMethodException -> UnsatisfiedDependency).
-keep class * implements com.google.firebase.components.ComponentRegistrar {
    void <init>();
}
-keep interface com.google.firebase.components.ComponentRegistrar
-keep class com.google.mlkit.common.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }
-keep class com.google.mlkit.vision.text.** { *; }

# Keep Firebase Crashlytics line numbers and source attributes for symbolication
-keepattributes *Annotation*,SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

-dontwarn com.google.android.play.core.**
-keep class com.abhilash.manikutti.** { *; }
-keep class es.antonborri.home_widget.** { *; }

# Ignore missing ML Kit language modules (e.g. Korean, Japanese) when they are not bundled
-dontwarn com.google.mlkit.vision.text.**
-dontwarn javax.annotation.**
