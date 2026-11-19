import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class AppInstance {
  const AppInstance({
    required this.id,
    required this.name,
    this.builtIn = false,
    this.createdAt = 0,
  });

  final String id;
  final String name;
  final bool builtIn;
  final int createdAt;

  bool get isDefault => id == 'default';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'builtIn': builtIn,
    'createdAt': createdAt,
  };

  factory AppInstance.fromJson(Map<String, dynamic> json) => AppInstance(
    id: json['id']?.toString() ?? 'default',
    name: json['name']?.toString() ?? '默认实例',
    builtIn: json['builtIn'] == true,
    createdAt: json['createdAt'] is num
        ? (json['createdAt'] as num).toInt()
        : 0,
  );
}

class InstanceState {
  const InstanceState({required this.activeId, required this.items});

  final String activeId;
  final List<AppInstance> items;

  AppInstance get active =>
      items.firstWhere((e) => e.id == activeId, orElse: () => items.first);
}

/// Manages the default instance (the legacy data root) plus user instances
/// stored under `<root>/instances/<id>/`.
class InstanceStore {
  InstanceStore(this.rootDir);

  static const defaultId = 'default';

  /// Instance data directories that belong to an instance. Kernel, logs,
  /// app_config.json and backgrounds stay shared at the root.
  static const dataDirs = ['module', 'plugin', 'modloader', 'mods'];

  final Directory rootDir;

  Directory get instancesDir => Directory('${rootDir.path}/instances');

  File get metaFile => File('${rootDir.path}/instances.json');

  Directory dirFor(String id) =>
      id == defaultId ? rootDir : Directory('${instancesDir.path}/$id');

  Future<InstanceState> load() async {
    await rootDir.create(recursive: true);
    final map = await _readMeta();
    final items = <AppInstance>[];
    final raw = map['items'];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is Map) {
          items.add(AppInstance.fromJson(entry.cast<String, dynamic>()));
        }
      }
    }
    if (!items.any((e) => e.id == defaultId)) {
      items.insert(
        0,
        const AppInstance(id: defaultId, name: '默认实例', builtIn: true),
      );
    }
    var active = map['active']?.toString() ?? defaultId;
    if (!items.any((e) => e.id == active)) active = defaultId;
    final state = InstanceState(activeId: active, items: items);
    await _saveMeta(state);
    return state;
  }

  Future<Map<String, dynamic>> _readMeta() async {
    try {
      if (!await metaFile.exists()) return {};
      final raw = jsonDecode(await metaFile.readAsString());
      return raw is Map ? raw.cast<String, dynamic>() : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveMeta(InstanceState state) async {
    await rootDir.create(recursive: true);
    final data = {
      'active': state.activeId,
      'items': [for (final item in state.items) item.toJson()],
    };
    const encoder = JsonEncoder.withIndent('  ');
    await metaFile.writeAsString(encoder.convert(data), flush: true);
  }

  Future<InstanceState> setActive(InstanceState state, String id) async {
    if (!state.items.any((e) => e.id == id)) return state;
    final next = InstanceState(activeId: id, items: state.items);
    await _saveMeta(next);
    return next;
  }

  Future<InstanceState> create(
    InstanceState state, {
    required String name,
    String? cloneFromId,
  }) async {
    final id = 'inst_${DateTime.now().millisecondsSinceEpoch}';
    final target = dirFor(id);
    await target.create(recursive: true);
    if (cloneFromId != null && cloneFromId.isNotEmpty) {
      await _copyData(dirFor(cloneFromId), target);
    }
    final item = AppInstance(
      id: id,
      name: name.trim().isEmpty ? '新实例' : name.trim(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    final next = InstanceState(
      activeId: state.activeId,
      items: [...state.items, item],
    );
    await _saveMeta(next);
    return next;
  }

  Future<InstanceState> delete(InstanceState state, String id) async {
    if (id == defaultId) return state;
    final target = dirFor(id);
    try {
      if (await target.exists()) await target.delete(recursive: true);
    } catch (_) {}
    final items = state.items.where((e) => e.id != id).toList();
    final active = state.activeId == id ? defaultId : state.activeId;
    final next = InstanceState(activeId: active, items: items);
    await _saveMeta(next);
    return next;
  }

  Future<void> _copyData(Directory from, Directory to) async {
    for (final name in dataDirs) {
      final source = Directory('${from.path}/$name');
      if (!await source.exists()) continue;
      await _copyDir(source, Directory('${to.path}/$name'));
    }
  }

  Future<void> _copyDir(Directory from, Directory to) async {
    await to.create(recursive: true);
    await for (final entity in from.list(followLinks: false)) {
      final name = entity.path.split(Platform.pathSeparator).last;
      final target = '${to.path}/$name';
      if (entity is Directory) {
        await _copyDir(entity, Directory(target));
      } else if (entity is File) {
        await entity.copy(target);
      }
    }
  }

  static const _packModuleIds = [
    'eternal.future.languagepackextension',
    'eternal.future.texturepackextension',
    'eternal.future.audiopackextension',
    'eternal.future.fontpackextension',
  ];

  /// Imports a ZIP exported by this manager (or a plain archive of the
  /// instance data directories). Kernel and loader files are restored to the
  /// shared root, instance data goes to `instances/<id>/`.
  Future<(InstanceState, String)> importZip(
    InstanceState state,
    Uint8List bytes,
  ) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final id = 'inst_${DateTime.now().millisecondsSinceEpoch}';
    final target = dirFor(id);
    await target.create(recursive: true);

    var name = '导入实例';
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      var relative = entry.name.replaceAll('\\', '/');
      if (relative.contains('..') || relative.startsWith('/')) continue;

      if (relative == 'info.json' || relative == 'instance.json') {
        try {
          final meta = jsonDecode(utf8.decode(entry.content));
          if (meta is Map && meta['name'] != null) {
            final value = meta['name'].toString().trim();
            if (value.isNotEmpty) name = value;
          }
        } catch (_) {}
        continue;
      }

      File targetFile;
      if (relative == 'tefloader.dex' || relative == 'tefloader.zip') {
        targetFile = File('${rootDir.path}/$relative');
      } else if (relative.startsWith('tefkernel/')) {
        final rest = relative.substring('tefkernel/'.length);
        if (rest.isEmpty) continue;
        targetFile = File('${rootDir.path}/tefkernel/$rest');
      } else {
        if (relative.startsWith('data/')) {
          relative = relative.substring('data/'.length);
        }
        if (relative.isEmpty) continue;
        targetFile = File('${target.path}/$relative');
      }
      await targetFile.parent.create(recursive: true);
      await targetFile.writeAsBytes(entry.content, flush: true);
    }

    final item = AppInstance(
      id: id,
      name: name,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    final next = InstanceState(
      activeId: state.activeId,
      items: [...state.items, item],
    );
    await _saveMeta(next);
    return (next, id);
  }

  /// Builds a shareable ZIP of the instance data directories.
  ///
  /// Always includes TEFLoader (when [loaderBytes] is provided), TEFKernel and
  /// the instance's component directories. Resource packs can be excluded.
  Future<Uint8List> exportZip(
    AppInstance instance, {
    bool includeResourcePacks = true,
    Uint8List? loaderBytes,
  }) async {
    final dir = dirFor(instance.id);
    final archive = Archive();
    archive.add(
      ArchiveFile.string(
        'info.json',
        const JsonEncoder.withIndent('  ').convert({
          'format': 'tefmanager-instance',
          'formatVersion': 1,
          'name': instance.name,
          'id': instance.id,
          'createdAt': instance.createdAt,
          'includes': {
            'loader': loaderBytes != null,
            'kernel': true,
            'mods': true,
            'resourcePacks': includeResourcePacks,
          },
        }),
      ),
    );

    if (loaderBytes != null && loaderBytes.isNotEmpty) {
      archive.add(ArchiveFile.bytes('tefloader.dex', loaderBytes));
    }

    final kernel = Directory('${rootDir.path}/tefkernel');
    if (await kernel.exists()) {
      await for (final entity in kernel.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final relative = entity.path.substring(kernel.path.length + 1);
        archive.add(
          ArchiveFile.bytes(
            'tefkernel/${relative.replaceAll('\\', '/')}',
            await entity.readAsBytes(),
          ),
        );
      }
    }

    for (final name in dataDirs) {
      final source = Directory('${dir.path}/$name');
      if (!await source.exists()) continue;
      await for (final entity in source.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final relative = entity.path.substring(dir.path.length + 1);
        final normalized = relative.replaceAll('\\', '/');
        final inner = normalized.startsWith('$name/')
            ? normalized.substring(name.length + 1)
            : normalized;
        if (!includeResourcePacks &&
            name == 'module' &&
            _packModuleIds.any((id) => inner.startsWith('private/$id/'))) {
          continue;
        }
        archive.add(
          ArchiveFile.bytes('data/$normalized', await entity.readAsBytes()),
        );
      }
    }
    return ZipEncoder().encodeBytes(archive);
  }
}
