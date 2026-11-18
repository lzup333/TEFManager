# Xposed entry point: referenced only by assets/xposed_init, so R8 cannot see
# the reference and would otherwise remove or rename it.
-keep class eternal.future.tefmanager.MainHook { *; }
-keep class eternal.future.tefmanager.Platform { *; }

# Android components instantiated by the framework / manifest.
-keep class eternal.future.tefmanager.FileProvider { *; }
-keep class eternal.future.tefmanager.FileProviderForegroundService { *; }
-keep class eternal.future.tefmanager.MainActivity { *; }

# Called from Dart through the MethodChannel.
-keep class eternal.future.tefmanager.NativeBridge { *; }
-keep class eternal.future.tefmanager.PermissionManager { *; }
-keep class eternal.future.tefmanager.utils.** { *; }

# Xposed API is provided by LSPosed at runtime.
-keep class de.robv.android.xposed.** { *; }
-dontwarn de.robv.android.xposed.**

# APK patching helpers.
-keep class com.apk.axml.** { *; }
-keep class com.wind.meditor.** { *; }
-dontwarn com.android.tools.build.apkzlib.**
-dontwarn com.android.apksig.**
