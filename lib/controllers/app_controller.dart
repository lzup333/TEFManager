import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../core/config.dart';
import '../core/i18n.dart';
import '../core/native_bridge.dart';

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
      await _loadGames();

      _ready = true;
      _error = null;
    } catch (e) {
      _error = '$e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

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
