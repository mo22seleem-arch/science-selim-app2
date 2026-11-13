# Flutter / plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
# Play Integrity + Play Core
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
# our security bridge (reflection-free, but keep names readable in crash reports)
-keep class com.selim.science.SecurityChecks { *; }
