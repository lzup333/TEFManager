# Mod 自定义界面（Flutter Fork）

Flutter fork 通过 MethodChannel `eternal.future.tefmanager/modpage` 加载 Mod 页面 JAR，
原生层把稳定的 `PageNode` 树序列化给 Dart，Dart 用自己的控件渲染。

## 稳定 ABI（与官方版共用）

Mod 只 compileOnly 依赖冻结的 `modpage-api.jar`，不依赖 Compose / Flutter：

```kotlin
class Page : ModPage {
    override fun title() = "My Page"
    override fun render(api: ModPageApi): PageNode = PageNode(
        type = "column",
        children = listOf(
            PageNode("text", mapOf("value" to "Hello ${api.privatePath}")),
            PageNode("button", mapOf("id" to "click", "label" to "点我")),
        ),
    )
    override fun onEvent(id: String, value: String?, api: ModPageApi) {}
}
```

- `ModPageApi`：`privatePath` / `dataPath` / `state(key)` / `setState(key,value)` / `openUrl` / `close`
- `PageNode` 类型：`column / row / text / button / checkbox / slider / input / separator / spacer / progress / collapsing / image`
- 状态保存在 `<private>/page-state.json`
- 类名由 `Info.json` 的 `pageClass` 指定，默认 `default.PageClass`

页面 JAR 路径：

```
<files>/mods/<loaderId>/private/<pkgId>/page/android.jar
```

管理器升级 UI 框架不会让 Mod 页面失效，因为 Mod 没有直接引用任何 UI 框架类。
