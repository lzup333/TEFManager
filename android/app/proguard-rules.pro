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


# ModPage 页面 JAR 由外部 Mod 编译，运行时会直接引用 Kotlin 运行时类。
# R8 会因为宿主力自身已内联这些调用而把它们裁掉，导致外部页面
# 报 "Failed resolution of: Lkotlin/jvm/internal/Intrinsics;"。
-keep class kotlin.** { *; }
-keep interface kotlin.** { *; }
