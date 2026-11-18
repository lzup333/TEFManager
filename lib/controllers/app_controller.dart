import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../core/config.dart';
import '../core/i18n.dart';
import '../core/native_bridge.dart';
import '../data/bundled_installer.dart';
import '../data/component_store.dart';
import '../data/mod_repository.dart';
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
  late Directory _dataDir;
  late Directory _cacheDir;
  late ConfigStore _configStore;
  List<GameItem> _games = const [];
  GameItem? _selectedGame;
  bool _moduleActive = false;
  String _arch = '';
  ComponentSnapshot _components = const ComponentSnapshot();
  ComponentStore? _componentStore;
  ResourcePackSnapshot _resources = const ResourcePackSnapshot();
  ResourcePackStore? _resourceStore;
  final ModRepositoryService _modRepository = ModRepositoryService();
  List<ModStoreEntry> _storeEntries = const [];
  bool _storeLoading = false;
  String? _storeError;
  bool _storeLoaded = false;

  bool get ready => _ready;
  bool get busy => _busy;
  String? get error => _error;
  AppConfig get config => _config;
  Directory get dataDir => _dataDir;
  Directory get cacheDir => _cacheDir;
  List<GameItem> get games => _games;
  GameItem? get selectedGame => _selectedGame;
  bool get moduleActive => _moduleActive;
  String get arch => _arch;
  ComponentSnapshot get components => _components;
  ComponentStore get componentStore => _componentStore!;
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
      _dataDir = await _native.resolveDataDir();
      _cacheDir = await _native.resolveExternalCacheDir();
      _configStore = ConfigStore(File('${_dataDir.path}/app_config.json'));
      _config = await _configStore.load();

      final info = await _native.deviceInfo();
      _arch = info['arch']?.toString() ?? '';
      if (info['dynamicColor'] is bool) {
        // Respect the device capability only for the default value; an explicit
        // user setting is preserved from disk.
        if (!File('${_dataDir.path}/app_config.json').existsSync()) {
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
      final info = File('${_dataDir.path}/tefkernel/info.json');
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

  Future<List<BundledStep>> installBundledComponents({
    void Function(String label, int index, int total)? onProgress,
  }) async {
    final store = _componentStore;
    if (store == null) return const [];
    final installer = BundledInstaller(_dataDir);
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

  Future<void> moveResourcePack(
    PackType type,
    String fileName,
    bool up,
  ) async {
    final store = _resourceStore;
    if (store == null) return;
    await store.move(type, fileName, up);
    await _loadResources();
    notifyListeners();
  }

  Future<void> deleteResourcePack(
    PackType type,
    ResourcesPackItem pack,
  ) async {
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

  Future<List<InstallResult>> installPackages(
    List<String> paths, {
    InstallProgressCallback? onProgress,
  }) async {
    final results = <InstallResult>[];
    final store = _componentStore;
    if (store == null) return results;
    for (final path in paths) {
      final result = await store.installFile(path, onProgress: onProgress);
      results.add(result);
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
    await _loadComponents();
    notifyListeners();
  }

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
