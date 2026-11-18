# 🎮 TEFManager (Flutter · Android)

TEFManager is the official graphical manager for the
[TEFKernel](https://github.com/eternalfuture-e38299/TEFKernel) ecosystem.
This branch (`release/flutter`) rewrites the UI in **Flutter** and keeps
**Android only**:

- Windows, Linux, macOS and iOS targets were removed
- One adaptive layout instead of separate portrait/landscape trees
- Simplified information hierarchy and fewer redundant entry points

> TEFKernel itself still supports multiple platforms; only the manager changed.

## ✨ Features

- **Games**: detect Terraria (vanilla / Paid), launch it, Root (Xposed) and external modes
- **Components**: modules, plugins, mod loaders and mods — install, toggle, delete, update
- **Mod repository**: aggregate loader repositories, search, download and install `.tefpkg`
- **Resource packs**: language, language patch, texture, font and audio packs with ordering
- **Settings**: theme, dynamic color, font scale, language, logs and updates
- **APK patching**: inject TEFLoader and re-sign for external mode (native module)

## 📱 Platform

| Platform | Architectures | Status |
|---|---|---|
| Android | **arm64-v8a** | ✅ Only build target |
| Windows / Linux / macOS / iOS | — | ❌ Removed in this branch |

Minimum Android version: **7.0 (API 24)**; 64-bit ARM devices only.

## 🚀 Build

Requires Flutter **3.50+** (Dart 3.14) and Android SDK 36/37.

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

## 📜 Open source

TEFManager is released under the **GNU Affero General Public License v3.0
(AGPL-3.0)**. You may copy, modify and redistribute it under the same license;
derivative works must also be released under AGPL-3.0.

In-app: **Settings → About → Open source**, including the full dependency
license list. Main third-party components:

| Component | License |
|---|---|
| Flutter / Dart | BSD-3-Clause |
| path_provider / http / crypto | BSD-3-Clause |
| archive | MIT |
| TEFKernel / TEFLoader | AGPL-3.0 |

See [`OPEN_SOURCE.md`](OPEN_SOURCE.md) and [`LICENSE`](LICENSE).

## ⚠️ Disclaimer

An unofficial community tool, not affiliated with Re-Logic. Terraria is a
trademark of Re-Logic. Injection/patching may crash the game or corrupt saves —
back up your worlds and use at your own risk.
