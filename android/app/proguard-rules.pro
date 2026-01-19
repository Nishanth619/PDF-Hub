# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.BuildConfig { *; }
-keep class io.flutter.embedding.** { *; }
-keep class androidx.lifecycle.** { *; }

# Google ML Kit
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.gms.** { *; }

# Google ML Kit Text Recognition
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }

# Flutter plugins
-keep class io.flutter.plugins.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep setters in Views so that animations can still work
-keepclassmembers public class * extends android.view.View {
   void set*(***);
   *** get*();
}

# GSON - Comprehensive rules to prevent TypeToken reflection crashes
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Gson uses generic type information stored in a class file when working with fields.
# R8 removes such information by default, so configure it to keep all of it.
-keep class com.google.gson.** { *; }

# Prevent R8 from leaving Data object members always null
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Prevent stripping interface information from TypeAdapter, TypeAdapterFactory,
# JsonSerializer, JsonDeserializer instances (so they can be used in @JsonAdapter)
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# TypeToken uses reflection to access generic type info at runtime
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Keep generic signatures for TypeToken
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations

-keep class org.apache.http.** { *; }

# Keep common Android classes
-keep class android.** { *; }
-keep class androidx.** { *; }
-keep class com.google.android.material.** { *; }

# Keep syncfusion classes
-keep class com.syncfusion.** { *; }

# Keep pdf classes
-keep class com.tom_roush.pdfbox.** { *; }
-keep class com.shockwave.** { *; }

# Keep image classes
-keep class com.drew.** { *; }
-keep class android.graphics.Bitmap { *; }

# Additional rules to prevent R8 errors
-dontwarn com.google.android.play.core.**
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google.mlkit.common.**
-dontwarn com.google.mlkit.vision.**
-dontwarn com.google.mlkit.**

# MediaPipe for flutter_gemma AI
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# Protocol Buffers for AI models
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# RAG functionality for AI chat
-keep class com.google.ai.edge.localagents.** { *; }
-dontwarn com.google.ai.edge.localagents.**

# In-App Purchase / Billing
-keep class com.android.vending.billing.** { *; }
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# Google AdMob
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**