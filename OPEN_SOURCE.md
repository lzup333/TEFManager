# TEFManager — Open Source Declaration

TEFManager is free software: you can redistribute it and/or modify it under the
terms of the **GNU Affero General Public License v3.0** as published by the Free
Software Foundation. See [`LICENSE`](LICENSE).

The same declaration is available inside the app at
**Settings → About → Open source**, together with the full license texts of all
dependencies (Flutter's `showLicensePage`).

## Application

| Component | License | Source |
|---|---|---|
| TEFManager | AGPL-3.0 | https://github.com/lzup333/TEFManager/tree/release/flutter |

## Third-party components

| Component | License | Purpose | Source |
|---|---|---|---|
| Flutter / Dart | BSD-3-Clause | UI framework and language runtime | https://flutter.dev |
| path_provider | BSD-3-Clause | Platform data directories | https://pub.dev/packages/path_provider |
| archive | MIT | ZIP / TEF package handling | https://pub.dev/packages/archive |
| http | BSD-3-Clause | Repository and update downloads | https://pub.dev/packages/http |
| crypto | BSD-3-Clause | Package verification hashes | https://pub.dev/packages/crypto |
| TEFKernel | AGPL-3.0 | Mod kernel loaded by the game | https://github.com/eternalfuture-e38299/TEFKernel |
| TEFLoader | AGPL-3.0 | Bootstrap injected into the patched game | https://github.com/eternalfuture-e38299/TEFKernel |
| androidx.core | Apache-2.0 | Android compatibility helpers | https://developer.android.com/jetpack/androidx |
| Xposed API (compile only) | Apache-2.0 | Root-mode entry point; provided by LSPosed at runtime | https://api.xposed.info |

All bundled assets (kernel ZIP, loader DEX, built-in resource packs) are part of
the TEFKernel project and are distributed under AGPL-3.0.

## Trademarks

Terraria is a registered trademark of Re-Logic. TEFManager is an unofficial
community tool and is not endorsed by or affiliated with Re-Logic.
