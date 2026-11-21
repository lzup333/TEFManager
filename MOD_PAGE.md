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
- `PageNode` 类型：`column / row / text / button / checkbox / slider / input / separator / spacer / progress / collapsing / image / pickFile`
- 状态保存在 `<private>/page-state.json`
- 类名由 `Info.json` 的 `pageClass` 指定，默认 `default.PageClass`

页面 JAR 路径：

```
<files>/mods/<loaderId>/private/<pkgId>/page/android.jar
```

管理器升级 UI 框架不会让 Mod 页面失效，因为 Mod 没有直接引用任何 UI 框架类。


### 文件选择器（pickFile）

页面不直接调用 SAF / 系统文件对话框，而是声明一个节点，由宿主打开选择器并把结果回传：

```kotlin
PageNode(
    type = "pickFile",
    props = mapOf(
        "id" to "pick",                              // 回调的 event id
        "label" to "选择文件",
        "extensions" to listOf(".json", ".txt"),     // 可选，扩展名提示
        "multiple" to false,                         // 可选
    ),
)

override fun onEvent(id: String, value: String?, api: ModPageApi) {
    if (id == "pick") {
        // value 为选中的路径，多个用换行分隔
        api.setState("picked", value ?: "")
    }
}
```

Android 宿主用 SAF，桌面端用 FileKit，页面 JAR 本身不含任何平台相关 API。
