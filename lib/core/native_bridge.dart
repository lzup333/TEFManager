import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Thin wrapper around the Android MethodChannel.
///
/// Everything that needs Android APIs (PackageManager, root, SAF, APK
/// patching, foreground service) goes through here; pure-Dart code can be
/// unit tested without a device.
class NativeBridge {
  NativeBridge._();

  static final NativeBridge instance = NativeBridge._();

  static const MethodChannel _channel =
      MethodChannel('eternal.future.tefmanager/native');

  bool _available = true;

  bool get isAvailable => _available;

  Future<T?> _invoke<T>(String method, [dynamic arguments]) async {
    if (!_available) return null;
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      _available = false;
      return null;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Paths & device
  // ---------------------------------------------------------------------------

  /// [dataDir] = `.../files`, [cacheDir] = internal cache,
  /// [externalCacheDir] = `.../cache`.
  Future<Directory> resolveDataDir() async {
    final paths = await _invoke<Map>('paths');
    if (paths != null && paths['externalFiles'] is String) {
      return Directory(paths['externalFiles'] as String);
    }
    final dir = await getExternalStorageDirectory();
    if (dir != null) return dir;
    return getApplicationSupportDirectory();
  }

  Future<Directory> resolveExternalCacheDir() async {
    final paths = await _invoke<Map>('paths');
    if (paths != null && paths['externalCache'] is String) {
      return Directory(paths['externalCache'] as String);
    }
    final dir = await getExternalCacheDirectories();
    if (dir != null && dir.isNotEmpty) return dir.first;
    return getTemporaryDirectory();
  }

  Future<Map<String, dynamic>> deviceInfo() async {
    final raw = await _invoke<Map>('device.info');
    return raw == null ? <String, dynamic>{} : raw.cast<String, dynamic>();
  }

  // ---------------------------------------------------------------------------
  // Games
  // ---------------------------------------------------------------------------

  Future<List<GameItem>> listGames() async {
    final raw = await _invoke<List>('game.list');
    if (raw == null) return const [];
    return raw
        .whereType<Map>()
        .map((m) => GameItem.fromMap(m.cast<String, dynamic>()))
        .toList();
  }

  Future<bool> launchGame(String packageName) async {
    final ok = await _invoke<bool>('game.launch', {'package': packageName});
    return ok ?? false;
  }

  Future<bool> isModuleActive() async =>
      await _invoke<bool>('module.active') ?? false;

  // ---------------------------------------------------------------------------
  // Root / external mode
  // ---------------------------------------------------------------------------

  Future<bool> hasRoot() async => await _invoke<bool>('root.hasPermission') ?? false;

  Future<bool> grantRootAccess(String packageName) async =>
      await _invoke<bool>('root.grantAccess', {'package': packageName}) ?? false;

  Future<void> startFileProviderService() async =>
      _invoke<void>('service.start');

  Future<void> stopFileProviderService() async => _invoke<void>('service.stop');

  // ---------------------------------------------------------------------------
  // Files (SAF)
  // ---------------------------------------------------------------------------

  /// Lets the user pick one or more files and copies them into the app cache.
  /// Returns absolute paths that can be read by dart:io.
  Future<List<String>> pickFiles({
    bool multiple = false,
    List<String> mimeTypes = const ['*/*'],
  }) async {
    final raw = await _invoke<List>('file.pick', {
      'multiple': multiple,
      'mimeTypes': mimeTypes,
    });
    return raw?.whereType<String>().toList() ?? const [];
  }

  /// Saves a local file through the system save dialog.
  Future<bool> exportFile(String sourcePath, String suggestedName) async {
    final ok = await _invoke<bool>('file.export', {
      'path': sourcePath,
      'name': suggestedName,
    });
    return ok ?? false;
  }

  Future<void> openUrl(String url) async => _invoke<void>('url.open', {'url': url});
}
