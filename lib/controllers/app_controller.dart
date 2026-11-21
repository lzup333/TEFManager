import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../core/app_info.dart';
import '../core/config.dart';
import '../core/i18n.dart';
import '../core/easter_egg.dart';
import '../core/native_bridge.dart';
import '../data/bundled_installer.dart';
import '../data/backup_store.dart';
import '../data/component_store.dart';
import '../data/mod_groups_store.dart';
import '../data/mod_repository.dart';
import '../data/mod_settings_store.dart';
import '../data/update_service.dart';
import '../data/resource_pack_store.dart';

/// Central application state.
///
/// The Kotlin app kept a set of global Compose singletons; Flutter maps that to
/// one [ChangeNotifier] exposed through an `InheritedNotifier`, which keeps the
/// dependency footprint at zero.
class AppController extends ChangeNotifier {
  AppController();

  final NativeBridge _native = NativeBridge.instance;

  bool _ready = false;
  bool _busy = false;
  String? _error;
  late AppConfig _config;
  late Directory _rootDir;
  late Directory _dataDir;
  ModGroupsState _modGroups = const ModGroupsState();
  ModGroupsStore? _modGroupsStore;
  bool _uiHidden = false;
  Timer? _jumpTimer;
  late Directory _cacheDir;
  late ConfigStore _configStore;
  List<GameItem> _games = const [];
  GameItem? _selectedGame;
  bool _moduleActive = false;
  String _arch = '';
  int _sdk = 0;
  ComponentSnapshot _components = const ComponentSnapshot();
  ComponentStore? _componentStore;
  ResourcePackSnapshot _resources = const ResourcePackSnapshot();
  ResourcePackStore? _resourceStore;
  final ModRepositoryService _modRepository = ModRepositoryService();
  final UpdateService _updateService = UpdateService();
  List<ModStoreEntry> _storeEntries = const [];
  bool _storeLoading = false;
  String? _storeError;
  bool _storeLoaded = false;

  bool get ready => _ready;
  bool get busy => _busy;
  String? get error => _error;
  AppConfig get config => _config;
  Directory get rootDir => _rootDir;
  Directory get dataDir => _dataDir;
  Directory get cacheDir => _cacheDir;
  String get backgroundImagePath {
    final value = _config.backgroundImage;
    if (value.isEmpty) return '';
    final path = value.startsWith('/')
        ? value
        : '${_rootDir.path}/backgrounds/$value';
    return File(path).existsSync() ? path : '';
  }

  List<GameItem> get games => _games;
  GameItem? get selectedGame => _selectedGame;
  bool get moduleActive => _moduleActive;
  String get arch => _arch;
  int get sdk => _sdk;
  ComponentSnapshot get components => _components;
  ComponentStore get componentStore => _componentStore!;
  ModGroupsState get modGroups => _modGroups;
  bool get uiHidden => _uiHidden;
  ResourcePackSnapshot get resources => _resources;
  ResourcePackStore get resourceStore => _resourceStore!;
  List<ModStoreEntry> get storeEntries => _storeEntries;
  bool get storeLoading => _storeLoading;
  String? get storeError => _storeError;

  AppLanguage get language => _config.language;
  AppThemeMode get themeMode => _config.themeMode;

  Future<void> initialize() async {
    _busy = true;
    notifyListeners();
    try {
      _rootDir = await _native.resolveDataDir();
      _cacheDir = await _native.resolveExternalCacheDir();
      _configStore = ConfigStore(File('${_rootDir.path}/app_config.json'));
      _config = await _configStore.load();

      _dataDir = _rootDir;
      _modGroupsStore = ModGroupsStore(_dataDir);
      _modGroups = await _modGroupsStore!.load();

      final info = await _native.deviceInfo();
      _arch = info['arch']?.toString() ?? '';
      _sdk = info['sdk'] is int ? info['sdk'] as int : 0;
      if (info['dynamicColor'] is bool) {
        // Respect the device capability only for the default value; an explicit
        // user setting is preserved from disk.
        if (!File('${_rootDir.path}/app_config.json').existsSync()) {
          _config.dynamicColor = info['dynamicColor'] as bool;
        }
      }

      final systemLocale = info['locale']?.toString();
      await I18n.instance.load(_config.language, systemLocale: systemLocale);
      _moduleActive = await _native.isModuleActive();
      _componentStore = ComponentStore(
        _dataDir,
        kernelVersion: await _readKernelVersion(),
      );
      _resourceStore = ResourcePackStore(_dataDir);
      await _loadGames();
      await _loadComponents();
      await _loadResources();

      _ready = true;
      _error = null;
    } catch (e) {
      _error = '$e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<String> _readKernelVersion() async {
    try {
      final info = File('${_rootDir.path}/tefkernel/info.json');
      if (await info.exists()) {
        final map = jsonDecode(await info.readAsString());
        if (map is Map && map['version'] != null) {
          final version = map['version'].toString();
          if (version.isNotEmpty) return version;
        }
      }
    } catch (_) {}
    return _config.kernelVersion;
  }

  Future<void> _loadResources() async {
    try {
      _resources = await _resourceStore!.load();
    } catch (_) {
      _resources = const ResourcePackSnapshot();
    }
  }

  /// Installs a user-selected kernel ZIP (same layout as the bundled one:
  /// `info.json` + the per-ABI `.so` files).
  Future<String> importKernel(String path) async {
    final bytes = await File(path).readAsBytes();
    final installer = BundledInstaller(_rootDir);
    final version = await installer.installKernelBytes(bytes);
    _config.kernelVersion = version;
    await _configStore.save(_config);
    _componentStore = ComponentStore(_dataDir, kernelVersion: version);
    await _loadComponents();
    notifyListeners();
    return version;
  }

  Future<List<String>> pickKernelFile() => _native.pickFiles(
    multiple: false,
    mimeTypes: const ['application/zip', 'application/octet-stream'],
  );

  Future<List<BundledStep>> installBundledComponents({
    void Function(String label, int index, int total)? onProgress,
  }) async {
    final store = _componentStore;
    if (store == null) return const [];
    final installer = BundledInstaller(_rootDir);
    final steps = await installer.installAll(
      store: store,
      onKernelInstalled: (version) async {
        if (version != null && version.isNotEmpty) {
          _config.kernelVersion = version;
          await _configStore.save(_config);
        }
        _componentStore = ComponentStore(
          _dataDir,
          kernelVersion: _config.kernelVersion,
        );
      },
      onProgress: onProgress,
    );
    await _loadComponents();
    await _loadResources();
    notifyListeners();
    return steps;
  }

  Future<void> reloadResources() async {
    await _loadResources();
    notifyListeners();
  }

  Future<List<PackInstallResult>> installResourcePacks(
    List<String> paths, {
    void Function(String phase)? onProgress,
  }) async {
    final results = <PackInstallResult>[];
    final store = _resourceStore;
    if (store == null) return results;
    for (final path in paths) {
      results.add(await store.installFile(path, onProgress: onProgress));
    }
    await _loadResources();
    notifyListeners();
    return results;
  }

  Future<void> setResourcePackEnabled(
    PackType type,
    ResourcesPackItem pack,
    bool enabled,
  ) async {
    final store = _resourceStore;
    if (store == null) return;
    await store.setEnabled(type, pack, enabled);
    await _loadResources();
    notifyListeners();
  }

  Future<void> moveResourcePack(PackType type, String fileName, bool up) async {
    final store = _resourceStore;
    if (store == null) return;
    await store.move(type, fileName, up);
    await _loadResources();
    notifyListeners();
  }

  Future<void> deleteResourcePack(PackType type, ResourcesPackItem pack) async {
    final store = _resourceStore;
    if (store == null) return;
    await store.delete(type, pack);
    await _loadResources();
    notifyListeners();
  }

  Future<void> refreshStore({bool force = false}) async {
    if (_storeLoading) return;
    if (_storeLoaded && !force) return;
    _storeLoading = true;
    _storeError = null;
    notifyListeners();
    try {
      _storeEntries = await _modRepository.fetch(
        _components.loaders,
        enabledLoaderIds: _components.enabledLoaders,
      );
      _storeLoaded = true;
    } catch (e) {
      _storeError = '$e';
    } finally {
      _storeLoading = false;
      notifyListeners();
    }
  }

  Future<InstallResult?> downloadAndInstall(ModStoreEntry entry) async {
    final path = await _modRepository.download(entry.mod, _cacheDir);
    if (path == null) {
      return const InstallResult(success: false, error: 'Download failed');
    }
    final results = await installPackages([path]);
    try {
      await File(path).delete();
    } catch (_) {}
    return results.isEmpty ? null : results.first;
  }

  Future<void> _loadComponents() async {
    try {
      _components = await _componentStore!.load();
    } catch (_) {
      _components = const ComponentSnapshot();
    }
  }

  Future<void> reloadComponents() async {
    await _loadComponents();
    notifyListeners();
  }

  Future<ModGroup> createModGroup(String name) async {
    final trimmed = name.trim();
    final group = ModGroup(
      id: 'grp_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmed.isEmpty ? tr('manager.group.ungrouped') : trimmed,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _modGroups = _modGroups.copyWith(groups: [..._modGroups.groups, group]);
    await _modGroupsStore?.save(_modGroups);
    notifyListeners();
    return group;
  }

  Future<void> renameModGroup(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final groups = [
      for (final group in _modGroups.groups)
        if (group.id == id)
          ModGroup(id: group.id, name: trimmed, createdAt: group.createdAt)
        else
          group,
    ];
    _modGroups = _modGroups.copyWith(groups: groups);
    await _modGroupsStore?.save(_modGroups);
    notifyListeners();
  }

  Future<void> deleteModGroup(String id) async {
    final groups = _modGroups.groups.where((g) => g.id != id).toList();
    final assignments = Map<String, String>.of(_modGroups.assignments)
      ..removeWhere((_, value) => value == id);
    _modGroups = ModGroupsState(groups: groups, assignments: assignments);
    await _modGroupsStore?.save(_modGroups);
    notifyListeners();
  }

  Future<void> assignModToGroup(
    String loaderId,
    String pkgId,
    String? groupId,
  ) async {
    final key = ModGroupsState.keyOf(loaderId, pkgId);
    final assignments = Map<String, String>.of(_modGroups.assignments);
    if (groupId == null || groupId.isEmpty) {
      assignments.remove(key);
    } else {
      assignments[key] = groupId;
    }
    _modGroups = _modGroups.copyWith(assignments: assignments);
    await _modGroupsStore?.save(_modGroups);
    notifyListeners();
  }

  Future<List<BundleInfo>> inspectBundles(List<String> paths) async {
    final store = _componentStore;
    if (store == null) return const [];
    final bundles = <BundleInfo>[];
    for (final path in paths) {
      final bundle = await store.probeBundle(path);
      if (bundle != null) bundles.add(bundle);
    }
    return bundles;
  }

  Future<List<InstallResult>> installPackages(
    List<String> paths, {
    InstallProgressCallback? onProgress,
  }) async {
    final results = <InstallResult>[];
    final store = _componentStore;
    if (store == null) return results;
    for (final path in paths) {
      results.addAll(await store.installArchive(path, onProgress: onProgress));
    }
    await _loadComponents();
    notifyListeners();
    return results;
  }

  Future<void> setComponentEnabled(
    AddonKind kind,
    String pkgId,
    bool enabled, {
    String? loaderId,
  }) async {
    final store = _componentStore;
    if (store == null) return;
    await store.setEnabled(kind, pkgId, enabled, loaderId: loaderId);
    await _loadComponents();
    notifyListeners();
  }

  Future<void> deleteComponent(
    AddonKind kind,
    String pkgId, {
    String? loaderId,
  }) async {
    final store = _componentStore;
    if (store == null) return;
    await store.delete(kind, pkgId, loaderId: loaderId);
    if (kind == AddonKind.mod && loaderId != null) {
      final key = ModGroupsState.keyOf(loaderId, pkgId);
      if (_modGroups.assignments.containsKey(key)) {
        final assignments = Map<String, String>.of(_modGroups.assignments)
          ..remove(key);
        _modGroups = _modGroups.copyWith(assignments: assignments);
        await _modGroupsStore?.save(_modGroups);
      }
    }
    await _loadComponents();
    notifyListeners();
  }

  Future<List<UpdateCandidate>?> checkUpdates() async {
    final info = await _updateService.fetch();
    if (info == null) return null;
    return _updateService.candidates(
      info,
      appVersion: AppInfo.versionName,
      kernelVersion: _config.kernelVersion,
      components: _components,
    );
  }

  /// Returns null on success, otherwise an error message.
  Future<String?> applyUpdate(UpdateCandidate candidate) async {
    if (candidate.target == UpdateTarget.manager) {
      final url = candidate.entry.externalUrl.isNotEmpty
          ? candidate.entry.externalUrl
          : candidate.entry.downloadUrl;
      if (url.isEmpty) return 'No download URL';
      await _native.openUrl(url);
      return null;
    }
    final file = await _updateService.writeCache(candidate.entry, _cacheDir);
    if (file == null) return 'Download failed';
    try {
      if (candidate.target == UpdateTarget.kernel) {
        final installer = BundledInstaller(_rootDir);
        final bytes = await file.readAsBytes();
        final version = await installer.installKernelBytes(bytes);
        _config.kernelVersion = version;
        await _configStore.save(_config);
        _componentStore = ComponentStore(
          _dataDir,
          kernelVersion: _config.kernelVersion,
        );
        await _loadComponents();
        notifyListeners();
        return null;
      }
      final store = _componentStore;
      if (store == null) return 'Store unavailable';
      final result = await store.installFile(file.path);
      if (!result.success) return result.error ?? 'Install failed';
      await _loadComponents();
      await _loadResources();
      notifyListeners();
      return null;
    } finally {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> loadModSettings(
    String loaderId,
    String pkgId,
  ) async {
    final store = _componentStore;
    if (store == null) return {};
    return ModSettingsStore.read(
      store.privateDir(AddonKind.mod, pkgId, loaderId: loaderId),
    );
  }

  Future<void> saveModSettings(
    String loaderId,
    String pkgId,
    Map<String, dynamic> values,
  ) async {
    final store = _componentStore;
    if (store == null) return;
    await ModSettingsStore.write(
      store.privateDir(AddonKind.mod, pkgId, loaderId: loaderId),
      values,
    );
  }

  Future<List<String>> pickApkFile() => _native.pickFiles(
    multiple: false,
    mimeTypes: const [
      'application/vnd.android.package-archive',
      'application/octet-stream',
    ],
  );

  Future<PatchResult> patchApk(String path, PatchOption option) =>
      _native.patchApk(path, option: option);

  Future<bool> exportFile(String path, String name) =>
      _native.exportFile(path, name);

  Stream<String> get patchProgress => _native.patchProgress;

  Future<List<String>> pickPackageFiles() => _native.pickFiles(
    multiple: true,
    mimeTypes: const ['application/zip', 'application/octet-stream', '*/*'],
  );

  Future<void> _loadGames() async {
    final games = await _native.listGames();
    _games = games;
    if (_selectedGame != null) {
      GameItem? found;
      for (final g in games) {
        if (g.hash == _selectedGame!.hash) {
          found = g;
          break;
        }
      }
      _selectedGame = found;
    }
    _selectedGame ??= games.isNotEmpty ? games.first : null;
  }

  Future<void> refreshGames() async {
    _busy = true;
    notifyListeners();
    try {
      _moduleActive = await _native.isModuleActive();
      await _loadGames();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void selectGame(GameItem? game) {
    _selectedGame = game;
    notifyListeners();
  }

  void setUiHidden(bool value) {
    if (_uiHidden == value) return;
    _uiHidden = value;
    notifyListeners();
  }

  void cancelEasterJump() {
    _jumpTimer?.cancel();
    _jumpTimer = null;
  }

  void scheduleBilibiliJump() {
    cancelEasterJump();
    _jumpTimer = Timer(const Duration(seconds: 20), () {
      _native.openUrl(kEasterBilibiliUrl);
      _jumpTimer = null;
    });
  }

  Future<bool> hasRoot() => _native.hasRoot();

  Future<bool> launchSelected() async {
    final game = _selectedGame;
    if (game == null) return false;
    return _native.launchGame(game.apkPackName);
  }

  Future<void> setLanguage(AppLanguage value) async {
    if (_config.language == value) return;
    _config.language = value;
    final info = await _native.deviceInfo();
    await I18n.instance.load(value, systemLocale: info['locale']?.toString());
    notifyListeners();
    await _configStore.save(_config);
  }

  Future<void> setThemeMode(AppThemeMode value) async {
    if (_config.themeMode == value) return;
    _config.themeMode = value;
    notifyListeners();
    await _configStore.save(_config);
  }

  Future<void> setDynamicColor(bool value) async {
    if (_config.dynamicColor == value) return;
    _config.dynamicColor = value;
    notifyListeners();
    await _configStore.save(_config);
  }

  Future<void> setSeedColor(int argb) async {
    if (_config.themeSeedColor == argb) return;
    _config.themeSeedColor = argb;
    notifyListeners();
    await _configStore.save(_config);
  }

  Future<void> setFontScale(double value) async {
    final clamped = value.clamp(0.5, 2.0);
    if ((_config.fontSizeScale - clamped).abs() < 0.001) return;
    _config.fontSizeScale = clamped;
    notifyListeners();
    await _configStore.save(_config);
  }

  // -------------------------------------------------------------------------
  // Background image
  // -------------------------------------------------------------------------

  Future<bool> pickBackgroundImage() async {
    final paths = await _native.pickFiles(
      multiple: false,
      mimeTypes: const ['image/*'],
    );
    if (paths.isEmpty) return false;
    final source = File(paths.first);
    if (!await source.exists()) return false;
    final nameParts = source.path.split('/').last.split('.');
    final ext = nameParts.length > 1 ? nameParts.last.toLowerCase() : 'png';
    final dir = Directory('${_rootDir.path}/backgrounds');
    await dir.create(recursive: true);
    final fileName = 'bg_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await source.copy('${dir.path}/$fileName');

    final previous = _config.backgroundImage;
    _config.backgroundImage = fileName;
    await _configStore.save(_config);
    if (previous.isNotEmpty && !previous.startsWith('/')) {
      try {
        final old = File('${dir.path}/$previous');
        if (await old.exists()) await old.delete();
      } catch (_) {}
    }
    notifyListeners();
    return true;
  }

  Future<void> setBackgroundDim(double value) async {
    final clamped = value.clamp(0.0, 0.8);
    if ((_config.backgroundDim - clamped).abs() < 0.001) return;
    _config.backgroundDim = clamped;
    await _configStore.save(_config);
    notifyListeners();
  }

  Future<void> clearBackgroundImage() async {
    final previous = _config.backgroundImage;
    if (previous.isEmpty) return;
    _config.backgroundImage = '';
    await _configStore.save(_config);
    if (!previous.startsWith('/')) {
      try {
        final file = File('${_rootDir.path}/backgrounds/$previous');
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<({String? json, String? error})> openModPage({
    required String jarPath,
    required String className,
    required String loaderId,
    required String pkgId,
  }) => _native.openModPage(
    jarPath: jarPath,
    className: className,
    privatePath: '${_rootDir.path}/mods/$loaderId/private/$pkgId',
    dataPath: '${_rootDir.path}/mods/$loaderId/mod/$pkgId',
  );

  Future<String?> modPageEvent(String id, String? value) =>
      _native.modPageEvent(id, value);

  Future<void> closeModPage() => _native.closeModPage();

  // -------------------------------------------------------------------------
  // Data backup / restore
  // -------------------------------------------------------------------------

  /// Exports the working data (mods/modules/kernel/logs) into the cache.
  Future<String?> backupData() async {
    try {
      final bytes = await BackupStore(_rootDir).export();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${_cacheDir.path}/tefmanager-backup-$stamp.zip');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Restores data from a backup ZIP, then reloads every store.
  Future<void> restoreData(String path) async {
    final bytes = await File(path).readAsBytes();
    await BackupStore(_rootDir).importZip(bytes);
    final kernelVersion = await _readKernelVersion();
    if (kernelVersion != _config.kernelVersion) {
      _config.kernelVersion = kernelVersion;
      await _configStore.save(_config);
    }
    _componentStore = ComponentStore(_rootDir, kernelVersion: kernelVersion);
    _resourceStore = ResourcePackStore(_rootDir);
    _modGroupsStore = ModGroupsStore(_rootDir);
    _modGroups = await _modGroupsStore!.load();
    _storeEntries = const [];
    _storeError = null;
    _storeLoaded = false;
    await _loadComponents();
    await _loadResources();
    notifyListeners();
  }

  Future<void> updateConfig(void Function(AppConfig config) change) async {
    change(_config);
    notifyListeners();
    await _configStore.save(_config);
  }

  Future<void> completeOnboarding() async {
    _config.initialized = true;
    notifyListeners();
    await _configStore.save(_config);
  }
}
