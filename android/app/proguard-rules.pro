# Flutter Wrapper ProGuard & R8 Optimization Rules
# Flutter engine and embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.view.** { *; }

# Tidara application package
-keep class com.tidara.tidara_smartclock.** { *; }
-keepclassmembers class com.tidara.tidara_smartclock.** { *; }

# Native cryptography & security
-keep class javax.crypto.** { *; }
-keep class java.security.** { *; }
-keep class android.security.keystore.** { *; }

# AndroidX and NotificationCompat
-keep class androidx.core.app.NotificationCompat** { *; }
-keep class androidx.core.content.ContextCompat** { *; }

# Media & Audio
-keep class android.media.** { *; }

# Suppress harmless warnings for missing optional classes
-dontwarn io.flutter.**
-dontwarn javax.annotation.**

