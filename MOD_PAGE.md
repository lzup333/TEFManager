# Mod 自定义界面（Flutter Fork）

Flutter fork 的 Mod 自定义界面使用 **Android 原生 Compose 页面**，通过 MethodChannel
`eternal.future.tefmanager/modpage` 在 FlutterActivity 上叠加 `ComposeView` 显示。

## Mod 页面约定

```
<files>/mods/<loaderId>/private/<pkgId>/page/android.jar
```

页面 JAR 中的类：

```kotlin
package my.mod.page

class Page {
    var params: Map<String, *> = emptyMap()

    val Content: @Composable () -> Unit = {
        Text("private: ${params["private-path"]}")
        Text("data: ${params["data-path"]}")
    }
}
```

- 类名由 `Info.json` 的 `pageClass` 指定，默认 `default.PageClass`
- 可选 `fun initialize(api: Map<String, *>)`，加载时调用
- 宿主注入 `private-path` / `data-path`

## 版本要求

页面 JAR 必须与本 App 使用相同的 Compose 版本构建：

- Compose UI `1.7.6`
- Compose Material3 `1.3.1`
- activity-compose `1.9.3`

版本不一致可能出现 `NoSuchMethodError`。

## 行为

- Mod 卡片菜单 → “自定义界面”
- 返回键由原生层拦截，关闭页面并通知 Dart
- 页面 ClassLoader 按 JAR 路径缓存，关闭时释放
- 加载失败显示错误提示，不影响 Flutter 界面
