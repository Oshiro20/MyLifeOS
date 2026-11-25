# Flutter Local Notifications + Gson (CRITICO para notificaciones programadas en release)
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep generic signatures & annotations required by Gson reflection
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod
-keepattributes InnerClasses
