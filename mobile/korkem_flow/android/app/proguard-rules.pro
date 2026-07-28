# Flutter's engine reflects into these; R8 must not rename or drop them.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_secure_storage reaches the Android Keystore through reflection.
-keep class androidx.security.crypto.** { *; }

# Flutter's deferred-components support references Play Core, which this app
# does not bundle because it does not use deferred components. Without these
# the R8 pass fails outright — enabling minification is what surfaced it.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
