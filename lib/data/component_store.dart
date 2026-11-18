import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/models.dart';
import 'addon_codec.dart';
import 'light_store.dart';

enum AddonKind { module, plugin, modLoader, mod }

extension AddonKindX on AddonKind {
  String get rootDir => switch (this) {
        AddonKind.module => 'module',
        AddonKind.plugin => 'plugin',
        AddonKind.modLoader => 'modloader',
        AddonKind.mod => 'mods',
      };

  String get pkgDir => switch (this) {
        AddonKind.mod => 'mod',
        _ => 'pkg',
      };

  bool get hasExtension => this != AddonKind.mod;

  String get manifestType => switch (this) {
        AddonKind.module => 'module',
        AddonKind.plugin => 'plugin',
        AddonKind.modLoader => 'modloader',
        AddonKind.mod => 'mod',
      };
}

class ComponentSnapshot {
  const ComponentSnapshot({
    this.modules = const [],
    this.plugins = const [],
    this.loaders = const [],
    this.mods = const {},
    this.enabledModules = const {},
    this.enabledPlugins = const {},
    this.enabledLoaders = const {},
    this.enabledMods = const {},
  });

  final List<ModuleItem> modules;
  final List<PluginItem> plugins;
  final List<ModLoaderItem> loaders;

  /// loader pkgId -> installed mods
  final Map<String, List<ModItem>> mods;

  final Set<String> enabledModules;
  final Set<String> enabledPlugins;
  final Set<String> enabledLoaders;
  final Map<String, Set<String>> enabledMods;

  bool isEnabled(AddonKind kind, String pkgId, {String? loaderId}) => switch (kind) {
        AddonKind.module => enabledModules.contains(pkgId),
        AddonKind.plugin => enabledPlugins.contains(pkgId),
        AddonKind.modLoader => enabledLoaders.contains(pkgId),
        AddonKind.mod =>
          (enabledMods[loaderId] ?? const <String>{}).contains(pkgId),
      };
}

class InstallResult {
  const InstallResult({
    required this.success,
    this.kind,
    this.pkgId = '',
    this.name = '',
    this.error,
    this.enabled = false,
  });

  final bool success;
  final AddonKind? kind;
  final String pkgId;
  final String name;
  final String? error;
  final bool enabled;
}

typedef InstallProgressCallback = void Function(String phase, {String? detail});

/// Storage-compatible implementation of the official addon managers.
class ComponentStore {
  ComponentStore(this.dataDir, {this.kernelVersion = '1.0.0'});

  final Directory dataDir;
  final String kernelVersion;

  Directory get _root => dataDir;

  Directory kindDir(AddonKind kind, {String? loaderId}) {
    if (kind == AddonKind.mod) {
      return Directory('${_root.path}/${kind.rootDir}/${loaderId ?? ''}');
    }
    return Directory('${_root.path}/${kind.rootDir}');
  }

  Directory privateDir(AddonKind kind, String pkgId, {String? loaderId}) =>
      Directory('${kindDir(kind, loaderId: loaderId).path}/private/$pkgId');

  File iconFile(AddonKind kind, String pkgId, {String? loaderId}) =>
      File('${kindDir(kind, loaderId: loaderId).path}/icons/$pkgId.icon');

  File packageFile(AddonKind kind, String pkgId, {String? loaderId}) {
    final ext = kind.hasExtension ? '.tefpkg' : '';
    return File('${kindDir(kind, loaderId: loaderId).path}/${kind.pkgDir}/$pkgId$ext');
  }

  EnableList _enableList(AddonKind kind, {String? loaderId}) =>
      EnableList(File('${kindDir(kind, loaderId: loaderId).path}/enables.txt'));

  LightStore<ModuleItem> _moduleStore() => LightStore(
        directory: Directory('${kindDir(AddonKind.module).path}/db'),
        encode: encodeModule,
        decode: decodeModule,
        keyOf: (v) => v.pkgId,
      );

  LightStore<PluginItem> _pluginStore() => LightStore(
        directory: Directory('${kindDir(AddonKind.plugin).path}/db'),
        encode: encodePlugin,
        decode: decodePlugin,
        keyOf: (v) => v.pkgId,
      );

  LightStore<ModLoaderItem> _loaderStore() => LightStore(
        directory: Directory('${kindDir(AddonKind.modLoader).path}/db'),
        encode: encodeModLoader,
        decode: decodeModLoader,
        keyOf: (v) => v.pkgId,
      );

  LightStore<ModItem> _modStore(String loaderId) => LightStore(
        directory: Directory('${kindDir(AddonKind.mod, loaderId: loaderId).path}/db'),
        encode: encodeMod,
        decode: decodeMod,
        keyOf: (v) => v.pkgId,
      );

  Future<ComponentSnapshot> load() async {
    final modules = await _moduleStore().readAll();
    final plugins = await _pluginStore().readAll();
    final loaders = await _loaderStore().readAll();
    final mods = <String, List<ModItem>>{};
    final enabledMods = <String, Set<String>>{};
    for (final loader in loaders) {
      mods[loader.pkgId] = await _modStore(loader.pkgId).readAll();
      enabledMods[loader.pkgId] =
          await _enableList(AddonKind.mod, loaderId: loader.pkgId).read();
    }
    return ComponentSnapshot(
      modules: modules,
      plugins: plugins,
      loaders: loaders,
      mods: mods,
      enabledModules: await _enableList(AddonKind.module).read(),
      enabledPlugins: await _enableList(AddonKind.plugin).read(),
      enabledLoaders: await _enableList(AddonKind.modLoader).read(),
      enabledMods: enabledMods,
    );
  }

  Future<void> setEnabled(
    AddonKind kind,
    String pkgId,
    bool enabled, {
    String? loaderId,
  }) async {
    final list = _enableList(kind, loaderId: loaderId);
    if (enabled) {
      await list.enable(pkgId);
    } else {
      await list.disable(pkgId);
    }
  }

  Future<void> delete(AddonKind kind, String pkgId, {String? loaderId}) async {
    switch (kind) {
      case AddonKind.module:
        final store = _moduleStore();
        await store.writeAll(
          (await store.readAll()).where((e) => e.pkgId != pkgId),
        );
      case AddonKind.plugin:
        final store = _pluginStore();
        await store.writeAll(
          (await store.readAll()).where((e) => e.pkgId != pkgId),
        );
      case AddonKind.modLoader:
        final store = _loaderStore();
        await store.writeAll(
          (await store.readAll()).where((e) => e.pkgId != pkgId),
        );
        await kindDir(AddonKind.mod, loaderId: pkgId)
            .delete(recursive: true);
      case AddonKind.mod:
        final store = _modStore(loaderId ?? '');
        await store.writeAll(
          (await store.readAll()).where((e) => e.pkgId != pkgId),
        );
    }
    await _enableList(kind, loaderId: loaderId).disable(pkgId);
    _tryDelete(await packageFile(kind, pkgId, loaderId: loaderId));
    _tryDelete(await iconFile(kind, pkgId, loaderId: loaderId));
    _tryDeleteDir(privateDir(kind, pkgId, loaderId: loaderId));
  }

  void _tryDelete(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  void _tryDeleteDir(Directory dir) {
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // Installation
  // -------------------------------------------------------------------------

  Future<InstallResult> installFile(
    String path, {
    InstallProgressCallback? onProgress,
  }) async {
    try {
      final bytes = await File(path).readAsBytes();
      return await installBytes(bytes, onProgress: onProgress);
    } catch (e) {
      return InstallResult(success: false, error: '$e');
    }
  }

  Future<InstallResult> installBytes(
    Uint8List bytes, {
    InstallProgressCallback? onProgress,
    int depth = 0,
  }) async {
    if (depth > 4) {
      return const InstallResult(success: false, error: 'Nested package too deep');
    }
    onProgress?.call('opening');
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      return InstallResult(success: false, error: 'Invalid ZIP: $e');
    }

    final manifestEntry = _entry(archive, 'Manifest.json');
    if (manifestEntry == null) {
      return const InstallResult(success: false, error: 'Missing Manifest.json');
    }
    final Map<String, dynamic> manifest;
    try {
      manifest = (jsonDecode(_text(manifestEntry)) as Map).cast<String, dynamic>();
    } catch (e) {
      return InstallResult(success: false, error: 'Invalid Manifest.json: $e');
    }

    final kernelNode = manifest['tefkernel'];
    final minKernel = manifest['tefkernelMinVersion']?.toString() ??
        (kernelNode is Map ? kernelNode['minVersion']?.toString() : null);
    if (minKernel != null &&
        minKernel.isNotEmpty &&
        _isVersionGreater(minKernel, kernelVersion)) {
      return InstallResult(
        success: false,
        error: 'Kernel too old: $kernelVersion < $minKernel',
      );
    }

    final type = manifest['type']?.toString().toLowerCase();
    final kind = switch (type) {
      'module' => AddonKind.module,
      'plugin' => AddonKind.plugin,
      'modloader' => AddonKind.modLoader,
      'mod' => AddonKind.mod,
      _ => null,
    };
    if (kind == null) {
      return InstallResult(success: false, error: 'Unknown addon type: $type');
    }

    // Inline dependencies are installed before the parent, matching the
    // official AddonManager.
    final inlineError = await _installInlineDependencies(
      archive,
      manifest,
      onProgress: onProgress,
      depth: depth,
    );
    if (inlineError != null) {
      return InstallResult(success: false, error: inlineError);
    }

    if (kind == AddonKind.mod) {
      return _installMod(archive, manifest, onProgress: onProgress);
    }
    return _installAddon(kind, archive, manifest, onProgress: onProgress);
  }

  Future<InstallResult> _installAddon(
    AddonKind kind,
    Archive archive,
    Map<String, dynamic> manifest, {
    InstallProgressCallback? onProgress,
  }) async {
    final info = _entry(archive, 'Info.json');
    if (info == null) {
      return const InstallResult(success: false, error: 'Missing Info.json');
    }
    final Map<String, dynamic> json;
    try {
      json = (jsonDecode(_text(info)) as Map).cast<String, dynamic>();
    } catch (e) {
      return InstallResult(success: false, error: 'Invalid Info.json: $e');
    }
    final pkgId = json['pkgId']?.toString() ?? '';
    if (pkgId.isEmpty) {
      return const InstallResult(success: false, error: 'Info.json has no pkgId');
    }

    final payloadPath = manifest['file']?.toString() ?? '';
    final payload = _entry(archive, payloadPath);
    if (payload == null) {
      return InstallResult(
        success: false,
        error: 'Missing payload "$payloadPath"',
      );
    }

    final Object item = switch (kind) {
      AddonKind.module => ModuleItem.fromMap(json),
      AddonKind.plugin => PluginItem.fromMap(json),
      AddonKind.modLoader => ModLoaderItem.fromMap(json),
      AddonKind.mod => ModItem.fromMap(json),
    };

    onProgress?.call('copying', detail: pkgId);
    final target = packageFile(kind, pkgId);
    await target.parent.create(recursive: true);
    await target.writeAsBytes(payload.content, flush: true);

    await _extractIcon(archive, manifest, iconFile(kind, pkgId));
    await _extractResources(
      archive,
      manifest,
      privateDir(kind, pkgId),
    );

    onProgress?.call('database', detail: pkgId);
    await _put(kind, pkgId, item);

    return InstallResult(
      success: true,
      kind: kind,
      pkgId: pkgId,
      name: _nameOf(item),
    );
  }

  Future<InstallResult> _installMod(
    Archive archive,
    Map<String, dynamic> manifest, {
    InstallProgressCallback? onProgress,
  }) async {
    final loaderId = manifest['parentLoader']?.toString() ?? '';
    if (loaderId.isEmpty) {
      return const InstallResult(
        success: false,
        error: 'Mod manifest missing parentLoader',
      );
    }
    final loaders = await _loaderStore().readAll();
    ModLoaderItem? loader;
    for (final item in loaders) {
      if (item.pkgId == loaderId) {
        loader = item;
        break;
      }
    }
    if (loader == null) {
      return InstallResult(
        success: false,
        error: 'Parent modloader $loaderId is not installed',
      );
    }
    final minLoader = manifest['parentLoaderMinVersion']?.toString();
    if (minLoader != null &&
        minLoader.isNotEmpty &&
        _isVersionGreater(minLoader, loader.version)) {
      return InstallResult(
        success: false,
        error: 'Loader $loaderId too old: ${loader.version} < $minLoader',
      );
    }

    final info = _entry(archive, 'Info.json');
    if (info == null) {
      return const InstallResult(success: false, error: 'Missing Info.json');
    }
    final Map<String, dynamic> json;
    try {
      json = (jsonDecode(_text(info)) as Map).cast<String, dynamic>();
    } catch (e) {
      return InstallResult(success: false, error: 'Invalid Info.json: $e');
    }
    final pkgId = json['pkgId']?.toString() ?? '';
    if (pkgId.isEmpty) {
      return const InstallResult(success: false, error: 'Info.json has no pkgId');
    }
    final payloadPath = manifest['file']?.toString() ?? '';
    final payload = _entry(archive, payloadPath);
    if (payload == null) {
      return InstallResult(
        success: false,
        error: 'Missing payload "$payloadPath"',
      );
    }

    onProgress?.call('copying', detail: pkgId);
    final target = packageFile(AddonKind.mod, pkgId, loaderId: loaderId);
    await target.parent.create(recursive: true);
    await target.writeAsBytes(payload.content, flush: true);

    await _extractIcon(
      archive,
      manifest,
      iconFile(AddonKind.mod, pkgId, loaderId: loaderId),
    );
    await _extractResources(
      archive,
      manifest,
      privateDir(AddonKind.mod, pkgId, loaderId: loaderId),
    );

    onProgress?.call('database', detail: pkgId);
    await _put(AddonKind.mod, pkgId, ModItem.fromMap(json), loaderId: loaderId);

    return InstallResult(
      success: true,
      kind: AddonKind.mod,
      pkgId: pkgId,
      name: json['name']?.toString() ?? pkgId,
    );
  }

  Future<void> _put(
    AddonKind kind,
    String pkgId,
    Object item, {
    String? loaderId,
  }) async {
    switch (kind) {
      case AddonKind.module:
        final store = _moduleStore();
        final all = await store.readAll();
        await store.writeAll([
          ...all.where((e) => e.pkgId != pkgId),
          item as ModuleItem,
        ]);
      case AddonKind.plugin:
        final store = _pluginStore();
        final all = await store.readAll();
        await store.writeAll([
          ...all.where((e) => e.pkgId != pkgId),
          item as PluginItem,
        ]);
      case AddonKind.modLoader:
        final store = _loaderStore();
        final all = await store.readAll();
        await store.writeAll([
          ...all.where((e) => e.pkgId != pkgId),
          item as ModLoaderItem,
        ]);
      case AddonKind.mod:
        final store = _modStore(loaderId ?? '');
        final all = await store.readAll();
        await store.writeAll([
          ...all.where((e) => e.pkgId != pkgId),
          item as ModItem,
        ]);
    }
  }

  Future<String?> _installInlineDependencies(
    Archive archive,
    Map<String, dynamic> manifest, {
    InstallProgressCallback? onProgress,
    required int depth,
  }) async {
    final modloader = manifest['modloader'];
    if (modloader is Map && modloader['type']?.toString() == 'inline') {
      final file = modloader['file']?.toString();
      final entry = file == null ? null : _entry(archive, file);
      if (entry == null) return 'Inline modloader missing "$file"';
      onProgress?.call('dependency', detail: file);
      final result = await installBytes(
        Uint8List.fromList(entry.content),
        onProgress: onProgress,
        depth: depth + 1,
      );
      if (!result.success) return result.error ?? 'Inline modloader failed';
    }

    final plugins = manifest['plugins'];
    if (plugins is Map && plugins['type']?.toString() == 'inline') {
      final files = plugins['files'];
      if (files is List) {
        for (final raw in files) {
          final file = raw.toString();
          final entry = _entry(archive, file);
          if (entry == null) return 'Inline plugin missing "$file"';
          onProgress?.call('dependency', detail: file);
          final result = await installBytes(
            Uint8List.fromList(entry.content),
            onProgress: onProgress,
            depth: depth + 1,
          );
          if (!result.success) return result.error ?? 'Inline plugin failed';
        }
      }
    }
    return null;
  }

  Future<void> _extractIcon(
    Archive archive,
    Map<String, dynamic> manifest,
    File target,
  ) async {
    final iconPath = manifest['iconFile']?.toString();
    if (iconPath == null || iconPath.isEmpty) return;
    final entry = _entry(archive, iconPath);
    if (entry == null) return;
    await target.parent.create(recursive: true);
    await target.writeAsBytes(entry.content, flush: true);
  }

  Future<void> _extractResources(
    Archive archive,
    Map<String, dynamic> manifest,
    Directory target,
  ) async {
    final prefix = manifest['resources']?.toString() ?? '';
    if (prefix.isEmpty) return;
    final normalized = prefix.endsWith('/') ? prefix : '$prefix/';
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      if (!entry.name.startsWith(normalized)) continue;
      final relative = entry.name.substring(normalized.length);
      if (relative.isEmpty || relative.contains('..')) continue;
      final file = File('${target.path}/$relative');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.content, flush: true);
    }
  }

  ArchiveFile? _entry(Archive archive, String name) {
    final normalized = name.replaceAll('\\', '/');
    for (final entry in archive.files) {
      if (entry.isFile && entry.name == normalized) return entry;
    }
    return null;
  }

  String _text(ArchiveFile entry) =>
      utf8.decode(entry.content, allowMalformed: true);

  String _nameOf(Object item) => switch (item) {
        ModuleItem m => m.name,
        PluginItem p => p.name,
        ModLoaderItem l => l.name,
        ModItem m => m.name,
        _ => '',
      };
}

bool _isVersionGreater(String v1, String v2) {
  final a = v1.split('.');
  final b = v2.split('.');
  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final x = i < a.length ? int.tryParse(a[i]) ?? 0 : 0;
    final y = i < b.length ? int.tryParse(b[i]) ?? 0 : 0;
    if (x > y) return true;
    if (x < y) return false;
  }
  return false;
}
