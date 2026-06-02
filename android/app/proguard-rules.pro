# MyChannel Android — ProGuard / R8 rules
#
# Baseline rules so release builds (minifyEnabled true) link correctly.
# Task 17 expands these with full coverage for Retrofit, Gson, Firebase,
# and ExoPlayer. Keep additions append-only to avoid clobbering parallel work.

# --- Kotlin / Coroutines ---
-dontwarn kotlinx.coroutines.**
-keepclassmembers class kotlin.Metadata { *; }

# --- Hilt / Dagger (generated components) ---
-dontwarn dagger.hilt.**
-keep class dagger.hilt.** { *; }

# --- Firebase ---
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Keep model classes used for Firestore (de)serialization (added in Task 2).
# Firestore uses reflection to map documents onto data classes.
-keepclassmembers class com.mychannel.domain.model.** {
    <init>();
    <fields>;
}

# --- Retrofit / OkHttp / Gson ---
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn okhttp3.**
-dontwarn retrofit2.**
-keep class com.google.gson.** { *; }

# --- Media3 / ExoPlayer ---
-dontwarn androidx.media3.**
-keep class androidx.media3.** { *; }
