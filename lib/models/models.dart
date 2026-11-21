/// Domain models shared by the Flutter UI.
///
/// Field names intentionally mirror the Kotlin models (and therefore the
/// `Info.json` / `Manifest.json` files used by the TEF ecosystem), so existing
/// packages can be parsed without a translation layer.
library;

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

String _asString(dynamic v) => v is String ? v : (v == null ? '' : '$v');

bool _asBool(dynamic v) => v == true || v == 'true';

List<String> _asStringList(dynamic v) => v is List
    ? v.map((e) => _asString(e)).where((e) => e.isNotEmpty).toList()
    : const [];

class GameItem {
  const GameItem({
    this.apkPackName = '',
    this.filePath = '',
    this.tefloaderPath = '',
    this.version = '',
    this.versionCode = 0,
    this.hash = '',
    this.architecture = '',
  });

  final String apkPackName;
  final String filePath;
  final String tefloaderPath;
  final String version;
  final int versionCode;
  final String hash;
  final String architecture;

  factory GameItem.fromMap(Map<String, dynamic> m) => GameItem(
    apkPackName: _asString(m['apkPackName']),
    filePath: _asString(m['filePath']),
    tefloaderPath: _asString(m['tefloaderPath']),
    version: _asString(m['version']),
    versionCode: _asInt(m['versionCode']),
    hash: _asString(m['hash']),
    architecture: _asString(m['architecture']),
  );
}

class Dependence {
  const Dependence({
    this.pkgId = '',
    this.minVersionCode = 0,
    this.maxVersionCode = 0,
  });

  final String pkgId;
  final int minVersionCode;
  final int maxVersionCode;

  factory Dependence.fromMap(Map<String, dynamic> m) => Dependence(
    pkgId: _asString(m['pkgId']),
    minVersionCode: _asInt(m['minVersionCode']),
    maxVersionCode: _asInt(m['maxVersionCode']),
  );
}

class ArchitectureSupport {
  const ArchitectureSupport({
    this.arm64 = false,
    this.arm = false,
    this.x64 = false,
    this.x86 = false,
  });

  final bool arm64;
  final bool arm;
  final bool x64;
  final bool x86;

  bool get isEmpty => !arm64 && !arm && !x64 && !x86;

  List<String> get archs => [
    if (arm64) 'ARM64',
    if (arm) 'ARM',
    if (x64) 'x64',
    if (x86) 'x86',
  ];

  factory ArchitectureSupport.fromMap(Map<String, dynamic>? m) =>
      ArchitectureSupport(
        arm64: _asBool(m?['arm64']),
        arm: _asBool(m?['arm']),
        x64: _asBool(m?['x64']),
        x86: _asBool(m?['x86']),
      );
}

class PlatformSupport {
  const PlatformSupport({
    this.android = const ArchitectureSupport(),
    this.windows = const ArchitectureSupport(),
    this.linux = const ArchitectureSupport(),
    this.mac = const ArchitectureSupport(),
    this.ios = const ArchitectureSupport(),
  });

  final ArchitectureSupport android;
  final ArchitectureSupport windows;
  final ArchitectureSupport linux;
  final ArchitectureSupport mac;
  final ArchitectureSupport ios;

  /// Platforms relevant to the Android-only build.
  List<String> get supportedPlatforms {
    final out = <String>[];
    void add(String name, ArchitectureSupport a) {
      if (a.isEmpty) return;
      out.add(
        a.archs.length == 1
            ? '$name (${a.archs.first})'
            : '$name (${a.archs.join(', ')})',
      );
    }

    add('Android', android);
    add('Windows', windows);
    add('Linux', linux);
    add('macOS', mac);
    add('iOS', ios);
    return out;
  }

  factory PlatformSupport.fromMap(Map<String, dynamic>? m) => PlatformSupport(
    android: ArchitectureSupport.fromMap(
      m?['android'] as Map<String, dynamic>?,
    ),
    windows: ArchitectureSupport.fromMap(
      m?['windows'] as Map<String, dynamic>?,
    ),
    linux: ArchitectureSupport.fromMap(m?['linux'] as Map<String, dynamic>?),
    mac: ArchitectureSupport.fromMap(m?['mac'] as Map<String, dynamic>?),
    ios: ArchitectureSupport.fromMap(m?['ios'] as Map<String, dynamic>?),
  );
}

class PluginItem {
  const PluginItem({
    this.pkgId = '',
    this.name = '',
    this.author = '',
    this.description = '',
    this.version = '',
    this.versionCode = 0,
  });

  final String pkgId;
  final String name;
  final String author;
  final String description;
  final String version;
  final int versionCode;

  factory PluginItem.fromMap(Map<String, dynamic> m) => PluginItem(
    pkgId: _asString(m['pkgId']),
    name: _asString(m['name']),
    author: _asString(m['author']),
    description: _asString(m['description']),
    version: _asString(m['version']),
    versionCode: _asInt(m['versionCode']),
  );
}

class ModuleItem {
  const ModuleItem({
    this.pkgId = '',
    this.name = '',
    this.author = '',
    this.description = '',
    this.brieflyDescribe = '',
    this.version = '',
    this.versionCode = 0,
    this.detailsURL = '',
    this.dependence = const [],
    this.support = const PlatformSupport(),
  });

  final String pkgId;
  final String name;
  final String author;
  final String description;
  final String brieflyDescribe;
  final String version;
  final int versionCode;
  final String detailsURL;
  final List<Dependence> dependence;
  final PlatformSupport support;

  factory ModuleItem.fromMap(Map<String, dynamic> m) => ModuleItem(
    pkgId: _asString(m['pkgId']),
    name: _asString(m['name']),
    author: _asString(m['author']),
    description: _asString(m['description']),
    brieflyDescribe: _asString(m['brieflyDescribe']),
    version: _asString(m['version']),
    versionCode: _asInt(m['versionCode']),
    detailsURL: _asString(m['detailsURL']),
    dependence: _deps(m['dependence']),
    support: PlatformSupport.fromMap(m['support'] as Map<String, dynamic>?),
  );
}

class ModLoaderItem {
  const ModLoaderItem({
    this.pkgId = '',
    this.name = '',
    this.author = '',
    this.brieflyDescribe = '',
    this.description = '',
    this.version = '',
    this.versionCode = 0,
    this.dependence = const [],
    this.support = const PlatformSupport(),
    this.updateInfoUrl = '',
    this.modRepositoryIndexUrl = '',
  });

  final String pkgId;
  final String name;
  final String author;
  final String brieflyDescribe;
  final String description;
  final String version;
  final int versionCode;
  final List<Dependence> dependence;
  final PlatformSupport support;
  final String updateInfoUrl;
  final String modRepositoryIndexUrl;

  factory ModLoaderItem.fromMap(Map<String, dynamic> m) => ModLoaderItem(
    pkgId: _asString(m['pkgId']),
    name: _asString(m['name']),
    author: _asString(m['author']),
    brieflyDescribe: _asString(m['brieflyDescribe']),
    description: _asString(m['description']),
    version: _asString(m['version']),
    versionCode: _asInt(m['versionCode']),
    dependence: _deps(m['dependence']),
    support: PlatformSupport.fromMap(m['support'] as Map<String, dynamic>?),
    updateInfoUrl: _asString(m['updateInfoUrl']),
    modRepositoryIndexUrl: _asString(m['modRepositoryIndexUrl']),
  );
}

List<Dependence> _deps(dynamic v) => v is List
    ? v.whereType<Map<String, dynamic>>().map(Dependence.fromMap).toList()
    : const [];

class ModSettingOption {
  const ModSettingOption({this.value = '', this.label = ''});

  final String value;
  final String label;

  factory ModSettingOption.fromMap(Map<String, dynamic> m) => ModSettingOption(
    value: _asString(m['value']),
    label: _asString(m['label']),
  );
}

enum ModSettingType { switchType, integer, choice, string }

class ModSetting {
  const ModSetting({
    required this.key,
    required this.title,
    this.description = '',
    this.type = ModSettingType.string,
    this.defaultValue,
    this.min = 0,
    this.max = 0,
    this.step = 1,
    this.unit = '×',
    this.options = const [],
    this.section = '',
  });

  final String key;
  final String title;
  final String description;
  final ModSettingType type;
  final dynamic defaultValue;
  final int min;
  final int max;
  final int step;
  final String unit;
  final List<ModSettingOption> options;
  final String section;

  factory ModSetting.fromMap(Map<String, dynamic> m) {
    final rawType = _asString(m['type']);
    final type = switch (rawType) {
      'SWITCH' => ModSettingType.switchType,
      'INTEGER' => ModSettingType.integer,
      'CHOICE' => ModSettingType.choice,
      _ => ModSettingType.string,
    };
    return ModSetting(
      key: _asString(m['key']),
      title: _asString(m['title']),
      description: _asString(m['description']),
      type: type,
      defaultValue: m['defaultValue'],
      min: _asInt(m['min']),
      max: _asInt(m['max']),
      step: _asInt(m['step']) == 0 ? 1 : _asInt(m['step']),
      unit: _asString(m['unit']).isEmpty ? '×' : _asString(m['unit']),
      options: m['options'] is List
          ? (m['options'] as List)
                .whereType<Map<String, dynamic>>()
                .map(ModSettingOption.fromMap)
                .toList()
          : const [],
      section: _asString(m['section']),
    );
  }
}

enum ModFeature {
  assistance,
  qualityOfLife,
  utility,
  accessibility,
  visualEnhancement,
  uiImprovement,
  newContent,
  contentExpansion,
  overhaul,
  mechanicsChange,
  difficultyMod,
  progressionSystem,
  adventure,
  building,
  technology,
  magic,
  fantasy,
  sciFi,
  realism,
  decoration,
  multiplayerEnhanced,
  serverManagement,
  communication;

  static ModFeature? parse(String raw) {
    final normalized = raw.toLowerCase().replaceAll('_', '');
    for (final f in values) {
      if (f.name.toLowerCase() == normalized) return f;
    }
    return null;
  }
}

enum ModSizeCategory { tiny, small, medium, large, huge }

class ModItem {
  const ModItem({
    this.pkgId = '',
    this.name = '',
    this.author = '',
    this.version = '',
    this.versionCode = 0,
    this.brieflyDescribe = '',
    this.description = '',
    this.features = const [],
    this.sizeCategory = ModSizeCategory.tiny,
    this.targetGameVersion = '',
    this.minGameVersion = '',
    this.maxGameVersion = '',
    this.support = const PlatformSupport(),
    this.dependence = const [],
    this.conflicts = const [],
    this.detailsURL = '',
    this.stableVerified = false,
    this.experimental = false,
    this.deprecated = false,
    this.hasExtendedContent = false,
    this.settings = const [],
    this.updateInfoUrl = '',
    this.pageClass = 'default.PageClass',
  });

  final String pkgId;
  final String name;
  final String author;
  final String version;
  final int versionCode;
  final String brieflyDescribe;
  final String description;
  final List<ModFeature> features;
  final ModSizeCategory sizeCategory;
  final String targetGameVersion;
  final String minGameVersion;
  final String maxGameVersion;
  final PlatformSupport support;
  final List<Dependence> dependence;
  final List<String> conflicts;
  final String detailsURL;
  final bool stableVerified;
  final bool experimental;
  final bool deprecated;
  final bool hasExtendedContent;
  final List<ModSetting> settings;
  final String updateInfoUrl;
  final String pageClass;

  factory ModItem.fromMap(Map<String, dynamic> m) => ModItem(
    pkgId: _asString(m['pkgId']),
    name: _asString(m['name']),
    author: _asString(m['author']),
    version: _asString(m['version']),
    versionCode: _asInt(m['versionCode']),
    brieflyDescribe: _asString(m['brieflyDescribe']),
    description: _asString(m['description']),
    features: m['features'] is List
        ? (m['features'] as List)
              .map((e) => ModFeature.parse(_asString(e)))
              .whereType<ModFeature>()
              .toList()
        : const [],
    sizeCategory: ModSizeCategory.values.firstWhere(
      (e) => e.name.toUpperCase() == _asString(m['sizeCategory']).toUpperCase(),
      orElse: () => ModSizeCategory.tiny,
    ),
    targetGameVersion: _asString(m['targetGameVersion']),
    minGameVersion: _asString(m['minGameVersion']),
    maxGameVersion: _asString(m['maxGameVersion']),
    support: PlatformSupport.fromMap(m['support'] as Map<String, dynamic>?),
    dependence: _deps(m['dependence']),
    conflicts: _asStringList(m['conflicts']),
    detailsURL: _asString(m['detailsURL']),
    stableVerified: _asBool(m['stableVerified']),
    experimental: _asBool(m['experimental']),
    deprecated: _asBool(m['deprecated']),
    hasExtendedContent: _asBool(m['hasExtendedContent']),
    settings: m['settings'] is List
        ? (m['settings'] as List)
              .whereType<Map<String, dynamic>>()
              .map(ModSetting.fromMap)
              .toList()
        : const [],
    updateInfoUrl: _asString(m['updateInfoUrl']),
  );
}

enum PackType { texture, language, languagePatch, audio, font }

enum PackOrigin { terraria, tefManager }

class ResourcesPackItem {
  const ResourcesPackItem({
    this.name = '',
    this.author = '',
    this.description = '',
    this.version = '',
    this.fileName = '',
    this.iconPath = '',
    this.type = PackOrigin.tefManager,
    this.packType = PackType.texture,
    this.enabled = false,
    this.priority = 0,
  });

  final String name;
  final String author;
  final String description;
  final String version;
  final String fileName;
  final String iconPath;
  final PackOrigin type;
  final PackType packType;
  final bool enabled;
  final int priority;

  ResourcesPackItem copyWith({bool? enabled, int? priority}) =>
      ResourcesPackItem(
        name: name,
        author: author,
        description: description,
        version: version,
        fileName: fileName,
        iconPath: iconPath,
        type: type,
        packType: packType,
        enabled: enabled ?? this.enabled,
        priority: priority ?? this.priority,
      );

  factory ResourcesPackItem.fromMap(
    Map<String, dynamic> m,
    PackType packType,
  ) => ResourcesPackItem(
    name: _asString(m['name']),
    author: _asString(m['author']),
    description: _asString(m['description']),
    version: _asString(m['version']),
    fileName: _asString(m['fileName']),
    iconPath: _asString(m['iconPath']),
    type: _asString(m['type']).toLowerCase() == 'terraria'
        ? PackOrigin.terraria
        : PackOrigin.tefManager,
    packType: packType,
    enabled: _asBool(m['enable'] ?? m['enabled']),
    priority: _asInt(m['priority']),
  );
}

class UpdateEntry {
  const UpdateEntry({
    this.fileName = '',
    this.moduleName = '',
    this.newVersion = '',
    this.description = '',
    this.downloadUrl = '',
    this.externalUrl = '',
    this.fileSize = 0,
  });

  final String fileName;
  final String moduleName;
  final String newVersion;
  final String description;
  final String downloadUrl;
  final String externalUrl;
  final int fileSize;

  factory UpdateEntry.fromMap(Map<String, dynamic>? m) => UpdateEntry(
    fileName: _asString(m?['fileName']),
    moduleName: _asString(m?['moduleName']),
    newVersion: _asString(m?['newVersion']),
    description: _asString(m?['description']),
    downloadUrl: _asString(m?['downloadUrl']),
    externalUrl: _asString(m?['externalUrl']),
    fileSize: _asInt(m?['fileSize']),
  );
}

class UpdateInfo {
  const UpdateInfo({
    this.tefmanager,
    this.tefkernel,
    this.tefloader,
    this.language,
    this.texture,
    this.font,
    this.music,
  });

  final UpdateEntry? tefmanager;
  final UpdateEntry? tefkernel;
  final UpdateEntry? tefloader;
  final UpdateEntry? language;
  final UpdateEntry? texture;
  final UpdateEntry? font;
  final UpdateEntry? music;

  factory UpdateInfo.fromMap(Map<String, dynamic> m) => UpdateInfo(
    tefmanager: _entry(m['tefmanager']),
    tefkernel: _entry(m['tefkernel']),
    tefloader: _entry(m['tefloader']),
    language: _entry(m['language']),
    texture: _entry(m['texture']),
    font: _entry(m['font']),
    music: _entry(m['music']),
  );

  static UpdateEntry? _entry(dynamic v) =>
      v is Map<String, dynamic> ? UpdateEntry.fromMap(v) : null;
}

class AddonUpdateInfo {
  const AddonUpdateInfo({
    this.version = '',
    this.versionCode = 0,
    this.fileSize = 0,
    this.downloadUrl = '',
    this.updateLog = '',
  });

  final String version;
  final int versionCode;
  final int fileSize;
  final String downloadUrl;
  final String updateLog;

  factory AddonUpdateInfo.fromMap(Map<String, dynamic> m) => AddonUpdateInfo(
    version: _asString(m['version']),
    versionCode: _asInt(m['versionCode']),
    fileSize: _asInt(m['fileSize']),
    downloadUrl: _asString(m['downloadUrl']),
    updateLog: _asString(m['updateLog']),
  );
}

class ModRepositoryEntry {
  const ModRepositoryEntry({
    this.pkgId = '',
    this.name = '',
    this.author = '',
    this.version = '',
    this.versionCode = 0,
    this.brieflyDescribe = '',
    this.description = '',
    this.iconUrl = '',
    this.fileSize = 0,
    this.downloadUrl = '',
    this.sizeCategory = ModSizeCategory.tiny,
    this.features = const [],
    this.stableVerified = false,
    this.experimental = false,
    this.deprecated = false,
    this.hasExtendedContent = false,
    this.detailsURL = '',
    this.updateLog = '',
  });

  final String pkgId;
  final String name;
  final String author;
  final String version;
  final int versionCode;
  final String brieflyDescribe;
  final String description;
  final String iconUrl;
  final int fileSize;
  final String downloadUrl;
  final ModSizeCategory sizeCategory;
  final List<ModFeature> features;
  final bool stableVerified;
  final bool experimental;
  final bool deprecated;
  final bool hasExtendedContent;
  final String detailsURL;
  final String updateLog;

  factory ModRepositoryEntry.fromMap(Map<String, dynamic> m) =>
      ModRepositoryEntry(
        pkgId: _asString(m['pkgId']),
        name: _asString(m['name']),
        author: _asString(m['author']),
        version: _asString(m['version']),
        versionCode: _asInt(m['versionCode']),
        brieflyDescribe: _asString(m['brieflyDescribe']),
        description: _asString(m['description']),
        iconUrl: _asString(m['iconUrl']),
        fileSize: _asInt(m['fileSize']),
        downloadUrl: _asString(m['downloadUrl']),
        sizeCategory: ModSizeCategory.values.firstWhere(
          (e) =>
              e.name.toUpperCase() ==
              _asString(m['sizeCategory']).toUpperCase(),
          orElse: () => ModSizeCategory.tiny,
        ),
        features: m['features'] is List
            ? (m['features'] as List)
                  .map((e) => ModFeature.parse(_asString(e)))
                  .whereType<ModFeature>()
                  .toList()
            : const [],
        stableVerified: _asBool(m['stableVerified']),
        experimental: _asBool(m['experimental']),
        deprecated: _asBool(m['deprecated']),
        hasExtendedContent: _asBool(m['hasExtendedContent']),
        detailsURL: _asString(m['detailsURL']),
        updateLog: _asString(m['updateLog']),
      );
}

class ModRepositoryIndex {
  const ModRepositoryIndex({
    this.loaderMinVersionCode = 0,
    this.mods = const [],
  });

  final int loaderMinVersionCode;
  final List<ModRepositoryEntry> mods;

  factory ModRepositoryIndex.fromMap(Map<String, dynamic> m) {
    final rawMods = m['mods'];
    return ModRepositoryIndex(
      loaderMinVersionCode: _asInt(m['loaderMinVersionCode']),
      mods: rawMods is List
          ? rawMods
                .whereType<Map<String, dynamic>>()
                .map(ModRepositoryEntry.fromMap)
                .toList()
          : const [],
    );
  }
}

/// A component installed on disk. [kind] selects the storage root.
enum ComponentKind { module, plugin, modLoader, mod }

class InstalledComponent {
  const InstalledComponent({
    required this.kind,
    required this.pkgId,
    required this.item,
    required this.enabled,
    this.loaderId,
  });

  final ComponentKind kind;
  final String pkgId;
  final Object item;
  final bool enabled;
  final String? loaderId;

  InstalledComponent copyWith({bool? enabled}) => InstalledComponent(
    kind: kind,
    pkgId: pkgId,
    item: item,
    enabled: enabled ?? this.enabled,
    loaderId: loaderId,
  );
}
