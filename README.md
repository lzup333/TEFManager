# 🎮 TEFManager (Flutter · Android)

TEFManager 是 [TEFKernel](https://github.com/eternalfuture-e38299/TEFKernel) 生态的官方图形化管理工具。
本分支（`release/flutter`）使用 **Flutter** 重写了界面，并**只保留 Android 平台**：

- 移除 Kotlin Multiplatform / Compose Desktop 的 Windows、Linux、macOS、iOS 目标
- 统一手机横竖屏布局（不再维护两套界面）
- 重新整理信息层级，减少重复入口和冗余卡片

> TEFKernel 本身仍然支持多平台，这里只调整管理器。

## ✨ 功能

- **游戏管理**：识别已安装的 Terraria（原版 / Paid），一键启动；Root(Xposed) 与外部模式
- **组件管理**：内核模块、内核插件、ModLoader、Mod 的安装、启用/禁用、删除与更新
- **Mod 仓库**：按 ModLoader 汇总仓库索引，搜索、下载并安装 `.tefpkg`
- **资源包**：语言包、语言补丁、材质包、字体包、音频包，支持排序与启停
- **设置**：主题（亮/暗/跟随系统/自动）、动态取色、字体缩放、语言、日志与更新
- **APK 修补**：为外部模式注入 TEFLoader 并重新签名（原生模块）

## 📱 平台

| 平台 | 架构 | 状态 |
|---|---|---|
| Android | arm64-v8a, armeabi-v7a, x86, x86_64 | ✅ 唯一支持平台 |
| Windows / Linux / macOS / iOS | — | ❌ 本分支已移除 |

最低 Android 版本：**7.0 (API 24)**。

## 🚀 构建

### 环境要求

| 依赖 | 版本 / 说明 |
|---|---|
| Flutter | 3.50+（Dart 3.14），`flutter --version` 可查 |
| JDK | 17 |
| Android SDK | platform 37 + build-tools 37（缺会自动提示安装） |
| Android NDK | 使用 Flutter 默认 NDK 版本 |

首次使用先确认：

```bash
flutter doctor
flutter config --android-sdk /path/to/Android/Sdk
yes | flutter doctor --android-licenses
```

### 一条命令构建

仓库自带脚本（会先跑 analyze + test，再打 release 包）：

```bash
./scripts/build_android.sh
```

其他模式：

```bash
./scripts/build_android.sh --debug          # debug APK
./scripts/build_android.sh --split-per-abi  # 按 ABI 拆分，体积更小
```

### 手动构建

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

产物：

```
build/app/outputs/flutter-apk/app-release.apk
```

安装到设备：

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### 签名

Release 构建自动使用仓库内的官方签名文件：

```
android/app/tefmanager.p12   (alias: TEFManager)
```

与官方版证书一致，可直接覆盖安装、在两个版本之间切换。
Debug 构建使用 Flutter 默认 debug 签名，不能覆盖官方版。

### 网络 / 代理

Gradle 首次构建需要下载依赖。如果直连失败，可设置代理后再构建：

```bash
export HTTP_PROXY=http://127.0.0.1:7890
./scripts/build_android.sh
```

### CI

`.github/workflows/build.yml` 只构建 Android APK；支持 `workflow_dispatch`
和 `v*` tag 触发。若仓库没有提供 `KEYSTORE_BASE64` secret，CI 会生成临时签名。

## 📂 目录

```
lib/                 Flutter UI、状态与领域模型
  core/              配置、i18n、原生桥接
  models/            Info.json / Manifest.json 对应模型
  screens/           主页 / 管理 / 资源 / 设置 / 开源声明
  widgets/           设计系统组件
android/             Android 原生层（文件选择、Root、FileProvider、Xposed 入口）
assets/i18n/         中 / 英 / 俄 文案（沿用原 Kotlin 版本）
```

存储布局与旧版保持一致：`Android/data/eternal.future.tefmanager/files/`（`app_config.json`、
`module/`、`plugin/`、`modloader/`、`mods/`、`tefkernel/`、`logs/`）。

## 📜 开源声明

TEFManager 以 **GNU Affero General Public License v3.0 (AGPL-3.0)** 发布，源码公开可查。
你可以在遵守 AGPL-3.0 的前提下复制、修改和分发本软件；任何衍生作品也必须以 AGPL-3.0 开源。

应用内入口：**设置 → 关于 → 开源声明**，其中包含完整依赖许可证列表。主要第三方组件：

| 组件 | 许可证 |
|---|---|
| Flutter / Dart | BSD-3-Clause |
| path_provider / http / crypto | BSD-3-Clause |
| archive | MIT |
| TEFKernel / TEFLoader | AGPL-3.0 |

完整说明见 [`OPEN_SOURCE.md`](OPEN_SOURCE.md) 与 [`LICENSE`](LICENSE)。

## ⚠️ 免责声明

本项目为第三方社区工具，与 Re-Logic 无关；Terraria 是 Re-Logic 的注册商标。
使用注入/修补功能可能导致游戏崩溃或存档损坏，请自行评估风险并备份存档。
