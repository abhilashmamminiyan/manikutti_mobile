-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class androidx.lifecycle.** { *; }
-keep class androidx.work.** { *; }
-keep class com.flutter_secure_storage.** { *; }
-dontwarn com.google.android.play.core.**

-keep class com.abhilash.manikutti.** { *; }
-keep class es.antonborri.home_widget.** { *; }
-keep class com.google.mlkit.vision.text.** { *; }

# Ignore missing ML Kit language modules (e.g. Korean, Japanese) when they are not bundled
-dontwarn com.google.mlkit.vision.text.**
-dontwarn javax.annotation.**
