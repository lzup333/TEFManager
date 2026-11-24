import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/models.dart';
import 'addon_codec.dart';
import 'light_store.dart';

class ResourcePackSnapshot {
  const ResourcePackSnapshot({
    this.packs = const {
      PackType.texture: [],
      PackType.language: [],
      PackType.languagePatch: [],
      PackType.audio: [],
      PackType.font: [],
    },
    this.enabled = const {},
    this.selectedFont,
  });

  final Map<PackType, List<ResourcesPackItem>> packs;

  /// PackType -> set of enabled fileNames (texture/language/languagePatch/audio).
  final Map<PackType, Set<String>> enabled;

  final String? selectedFont;

  List<ResourcesPackItem> of(PackType type) => packs[type] ?? const [];

  bool isEnabled(PackType type, String fileName) {
    if (type == PackType.font) return selectedFont == fileName;
    return (enabled[type] ?? const <String>{}).contains(fileName);
  }
}

class PackInstallResult {
  const PackInstallResult({required this.success, this.item, this.error});

  final bool success;
  final ResourcesPackItem? item;
  final String? error;
}

class _PackKindConfig {
  const _PackKindConfig({
    required this.moduleId,
    required this.subDir,
    required this.configName,
    required this.type,
    this.hasTypeField = true,
  });

  final String moduleId;
  final String subDir;
  final String configName;
  final PackType type;
  final bool hasTypeField;
}

/// Storage-compatible resource pack manager.
class ResourcePackStore {
  ResourcePackStore(this.dataDir);

  final Directory dataDir;

  static const _kinds = {
    PackType.texture: _PackKindConfig(
      moduleId: 'eternal.future.texturepackextension',
      subDir: 'texture_packs',
      configName: 'config.json',
      type: PackType.texture,
    ),
    PackType.language: _PackKindConfig(
      moduleId: 'eternal.future.languagepackextension',
      subDir: 'language_packs',
      configName: 'config.json',
      type: PackType.language,
      hasTypeField: false,
    ),
    PackType.languagePatch: _PackKindConfig(
      moduleId: 'eternal.future.languagepackextension',
      subDir: 'language_patch_packs',
      configName: 'language_patch_packs.json',
      type: PackType.languagePatch,
    ),
    PackType.audio: _PackKindConfig(
      moduleId: 'eternal.future.audiopackextension',
      subDir: 'audio_packs',
      configName: 'config.json',
      type: PackType.audio,
    ),
    PackType.font: _PackKindConfig(
      moduleId: 'eternal.future.fontpackextension',
      subDir: 'font_packs',
      configName: 'selected.json',
      type: PackType.font,
    ),
  };

  static const languagePackLimit = 7;

  _PackKindConfig _config(PackType type) => _kinds[type]!;

  Directory packsDir(PackType type) {
    final config = _config(type);
    return Directory(
      '${dataDir.path}/module/private/${config.moduleId}/${config.subDir}',
    );
  }

  File configFile(PackType type) => File(
    '${dataDir.path}/module/private/${_config(type).moduleId}/${_config(type).configName}',
  );

  File iconFile(PackType type, String packId) =>
      File('${packsDir(type).path}/icons/$packId.png');

  File packFile(PackType type, String fileName) =>
      File('${packsDir(type).path}/$fileName');

  LightStore<ResourcesPackItem> _store(PackType type) => LightStore(
    directory: Directory('${packsDir(type).path}/db'),
    encode: encodeResourcePack,
    decode: decodeResourcePack,
    keyOf: (v) => v.fileName,
  );

  Future<ResourcePackSnapshot> load() async {
    final packs = <PackType, List<ResourcesPackItem>>{};
    final enabled = <PackType, Set<String>>{};
    String? selectedFont;

    for (final type in PackType.values) {
      final items = List<ResourcesPackItem>.of(await _store(type).readAll());
      packs[type] = items;
      if (type == PackType.font) {
        selectedFont = await _readSelectedFont();
      } else {
        final configs = await _readConfigs(type);
        enabled[type] = configs
            .where((c) => c.enable)
            .map((c) => c.file)
            .toSet();
        // Keep the list order aligned with the config file.
        final order = {
          for (var i = 0; i < configs.length; i++) configs[i].file: i,
        };
        items.sort((a, b) {
          final ai = order[a.fileName] ?? 1 << 30;
          final bi = order[b.fileName] ?? 1 << 30;
          return ai.compareTo(bi);
        });
      }
    }

    return ResourcePackSnapshot(
      packs: packs,
      enabled: enabled,
      selectedFont: selectedFont,
    );
  }

  Future<void> setEnabled(
    PackType type,
    ResourcesPackItem pack,
    bool enabled,
  ) async {
    if (type == PackType.font) {
      await _writeSelectedFont(enabled ? pack.fileName : null);
      return;
    }
    final configs = await _readConfigs(type);
    if (enabled &&
        type == PackType.language &&
        configs.where((c) => c.enable && c.file != pack.fileName).length >=
            languagePackLimit) {
      throw StateError('language pack limit reached');
    }
    var changed = false;
    for (var i = 0; i < configs.length; i++) {
      if (configs[i].file == pack.fileName) {
        configs[i] = configs[i].copyWith(enable: enabled);
        changed = true;
      }
    }
    if (!changed) {
      configs.add(
        _PackConfig(
          file: pack.fileName,
          enable: enabled,
          priority: configs.length,
          type: pack.type == PackOrigin.terraria ? 0 : 1,
        ),
      );
    }
    await _writeConfigs(type, configs);
  }

  Future<void> move(PackType type, String fileName, bool up) async {
    if (type == PackType.font) return;
    final configs = await _readConfigs(type);
    configs.sort((a, b) => a.priority.compareTo(b.priority));
    final index = configs.indexWhere((c) => c.file == fileName);
    if (index < 0) return;
    final target = up ? index - 1 : index + 1;
    if (target < 0 || target >= configs.length) return;
    final a = configs[index];
    final b = configs[target];
    configs[index] = a.copyWith(priority: b.priority);
    configs[target] = b.copyWith(priority: a.priority);
    await _writeConfigs(type, configs);
  }

  Future<void> delete(PackType type, ResourcesPackItem pack) async {
    final store = _store(type);
    await store.writeAll(
      (await store.readAll()).where((e) => e.fileName != pack.fileName),
    );
    final file = packFile(type, pack.fileName);
    if (await file.exists()) await file.delete();
    final icon = iconFile(type, pack.fileName.replaceAll('.zip', ''));
    if (await icon.exists()) await icon.delete();
    if (type == PackType.font) {
      if (await _readSelectedFont() == pack.fileName) {
        await _writeSelectedFont(null);
      }
    } else {
      final configs = await _readConfigs(type);
      await _writeConfigs(
        type,
        configs.where((c) => c.file != pack.fileName).toList(),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Installation
  // -------------------------------------------------------------------------

  Future<PackInstallResult> installFile(
    String path, {
    void Function(String phase)? onProgress,
  }) async {
    try {
      final bytes = await File(path).readAsBytes();
      return await installBytes(bytes, onProgress: onProgress);
    } catch (e) {
      return PackInstallResult(success: false, error: '$e');
    }
  }

  Future<PackInstallResult> installBytes(
    Uint8List bytes, {
    void Function(String phase)? onProgress,
  }) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      return PackInstallResult(success: false, error: 'Invalid ZIP: $e');
    }

    onProgress?.call('analyzing');
    final type = _detectType(archive);
    if (type == null) {
      return const PackInstallResult(
        success: false,
        error: 'Unrecognized resource pack format',
      );
    }

    final info = _readPackInfo(archive, type);
    if (info == null) {
      return const PackInstallResult(
        success: false,
        error: 'Missing pack.json or pack_info.json',
      );
    }

    final fileName = generateFileName(type, info.name, info.author);
    final packId = fileName.replaceAll('.zip', '');
    onProgress?.call('copying');
    final dir = packsDir(type);
    await dir.create(recursive: true);
    await File('${dir.path}/$fileName').writeAsBytes(bytes, flush: true);

    onProgress?.call('icon');
    final iconEntry =
        _entry(archive, 'Icon.png') ?? _entry(archive, 'icon.png');
    String iconPath = '';
    if (iconEntry != null) {
      final target = iconFile(type, packId);
      await target.parent.create(recursive: true);
      await target.writeAsBytes(iconEntry.content, flush: true);
      iconPath = target.path;
    }

    onProgress?.call('database');
    final item = ResourcesPackItem(
      name: info.name,
      author: info.author,
      description: info.description,
      version: info.version,
      fileName: fileName,
      iconPath: iconPath,
      type: info.origin,
      packType: type,
    );
    final store = _store(type);
    await store.writeAll([
      ...(await store.readAll()).where((e) => e.fileName != fileName),
      item,
    ]);

    if (type != PackType.font) {
      final configs = await _readConfigs(type);
      if (!configs.any((c) => c.file == fileName)) {
        configs.add(
          _PackConfig(
            file: fileName,
            enable: false,
            priority: configs.length,
            type: info.origin == PackOrigin.terraria ? 0 : 1,
          ),
        );
        await _writeConfigs(type, configs);
      }
    }

    onProgress?.call('done');
    return PackInstallResult(success: true, item: item);
  }

  PackType? _detectType(Archive archive) {
    final names = archive.files
        .where((e) => e.isFile)
        .map((e) => e.name)
        .toList();
    bool hasDir(String dir) =>
        names.any((name) => name == dir || name.startsWith('$dir/'));

    if (hasDir('Content')) {
      if (hasDir('Content/Music') || hasDir('Content/Sounds')) {
        return PackType.audio;
      }
      if (hasDir('Content/Images')) return PackType.texture;
      return null;
    }
    if (hasDir('Modified')) {
      if (names.any((n) => n.toLowerCase().endsWith('.audio'))) {
        return PackType.audio;
      }
      if (names.any((n) => n.toLowerCase().endsWith('.texture'))) {
        return PackType.texture;
      }
      return null;
    }

    final entry = _entry(archive, 'pack_info.json');
    if (entry == null) return null;
    try {
      final map =
          (_decodeJson(utf8.decode(entry.content, allowMalformed: true)) as Map)
              .cast<String, dynamic>();
      return switch (map['type']?.toString().toLowerCase()) {
        'audiopack' => PackType.audio,
        'texturepack' => PackType.texture,
        'languagepack' => PackType.language,
        'languagepatchpack' => PackType.languagePatch,
        'fontpack' => PackType.font,
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  _PackInfo? _readPackInfo(Archive archive, PackType type) {
    // Language and font packs only use the TEFManager format.
    if (type == PackType.language || type == PackType.font) {
      return _readPackInfoJson(archive);
    }

    final terraria = _entry(archive, 'pack.json');
    if (terraria != null) {
      try {
        final map =
            (_decodeJson(utf8.decode(terraria.content, allowMalformed: true))
                    as Map)
                .cast<String, dynamic>();
        final version = map['Version'];
        var versionText = '1.0';
        if (version is Map) {
          versionText = '${version['major'] ?? 0}.${version['minor'] ?? 0}';
        } else if (version != null) {
          versionText = version.toString();
        }
        return _PackInfo(
          name: map['Name']?.toString() ?? 'Unknown',
          author: map['Author']?.toString() ?? 'Unknown',
          description: map['Description']?.toString() ?? '',
          version: versionText,
          origin: PackOrigin.terraria,
        );
      } catch (_) {
        // Fall through to pack_info.json.
      }
    }
    return _readPackInfoJson(archive);
  }

  _PackInfo? _readPackInfoJson(Archive archive) {
    final entry = _entry(archive, 'pack_info.json');
    if (entry == null) return null;
    try {
      final map =
          (_decodeJson(utf8.decode(entry.content, allowMalformed: true)) as Map)
              .cast<String, dynamic>();
      final name = map['name']?.toString();
      if (name == null || name.isEmpty) return null;
      return _PackInfo(
        name: name,
        author: map['author']?.toString() ?? 'Unknown',
        description: map['description']?.toString() ?? '',
        version: map['version']?.toString() ?? '1.0.0',
        origin: PackOrigin.tefManager,
      );
    } catch (_) {
      return null;
    }
  }

  ArchiveFile? _entry(Archive archive, String name) {
    for (final entry in archive.files) {
      if (entry.isFile && entry.name == name) return entry;
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Config files
  // -------------------------------------------------------------------------

  Future<List<_PackConfig>> _readConfigs(PackType type) async {
    final file = configFile(type);
    if (!await file.exists()) return [];
    try {
      final text = await file.readAsString();
      if (text.trim().isEmpty) return [];
      final list = jsonDecode(text);
      if (list is! List) return [];
      return [
        for (final raw in list)
          if (raw is Map)
            _PackConfig(
              file: raw['file']?.toString() ?? '',
              enable: raw['enable'] == true,
              priority: raw['priority'] is num
                  ? (raw['priority'] as num).toInt()
                  : 0,
              type: raw['type'] is num ? (raw['type'] as num).toInt() : 0,
            ),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeConfigs(PackType type, List<_PackConfig> configs) async {
    final file = configFile(type);
    await file.parent.create(recursive: true);
    configs.sort((a, b) => a.priority.compareTo(b.priority));
    final payload = [
      for (final config in configs)
        {
          'file': config.file,
          'enable': config.enable,
          'priority': config.priority,
          if (_config(type).hasTypeField) 'type': config.type,
        },
    ];
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
  }

  Future<String?> _readSelectedFont() async {
    final file = configFile(PackType.font);
    if (!await file.exists()) return null;
    try {
      final text = (await file.readAsString()).trim();
      if (text.isEmpty || text == 'null') return null;
      return text.replaceAll('"', '');
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSelectedFont(String? fileName) async {
    final file = configFile(PackType.font);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      fileName == null ? 'null' : '"$fileName"',
      flush: true,
    );
  }


/// Some workshop packs contain raw newlines inside JSON strings (pack.json
/// descriptions, most commonly). Strict jsonDecode rejects them, so escape
/// control characters only while inside a string literal.
dynamic _decodeJson(String text) {
  final out = StringBuffer();
  var inString = false;
  var escaped = false;
  for (final rune in text.runes) {
    if (inString) {
      if (escaped) {
        out.writeCharCode(rune);
        escaped = false;
        continue;
      }
      if (rune == 0x5C) {
        out.writeCharCode(rune);
        escaped = true;
        continue;
      }
      if (rune == 0x22) {
        out.writeCharCode(rune);
        inString = false;
        continue;
      }
      if (rune < 0x20) {
        switch (rune) {
          case 0x0A:
            out.write(r'\n');
          case 0x0D:
            out.write(r'\r');
          case 0x09:
            out.write(r'\t');
          default:
            out.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
        }
        continue;
      }
      out.writeCharCode(rune);
    } else {
      if (rune == 0x22) inString = true;
      out.writeCharCode(rune);
    }
  }
  return jsonDecode(out.toString());
}

  static String generateFileName(PackType type, String name, String author) {
    String clean(String value, int max) {
      final cleaned = value
          .trim()
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .replaceAll(RegExp(r'\s+'), '_');
      return cleaned.length > max ? cleaned.substring(0, max) : cleaned;
    }

    final prefix = switch (type) {
      PackType.texture => 'tex',
      PackType.language => 'lang',
      PackType.languagePatch => 'lpatch',
      PackType.audio => 'audio',
      PackType.font => 'font',
    };
    final n = clean(name, 50);
    final a = clean(author, 30);
    final base = a.isEmpty ? '${prefix}_$n' : '${prefix}_${n}-$a';
    return '${base.replaceAll(RegExp(r'^_+|_+$'), '')}.zip';
  }
}

class _PackConfig {
  const _PackConfig({
    required this.file,
    required this.enable,
    required this.priority,
    required this.type,
  });

  final String file;
  final bool enable;
  final int priority;
  final int type;

  _PackConfig copyWith({bool? enable, int? priority}) => _PackConfig(
    file: file,
    enable: enable ?? this.enable,
    priority: priority ?? this.priority,
    type: type,
  );
}

class _PackInfo {
  const _PackInfo({
    required this.name,
    required this.author,
    required this.description,
    required this.version,
    required this.origin,
  });

  final String name;
  final String author;
  final String description;
  final String version;
  final PackOrigin origin;
}
