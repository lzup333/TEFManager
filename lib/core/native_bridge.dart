import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Thin wrapper around the Android MethodChannel.
///
/// Everything that needs Android APIs (PackageManager, root, SAF, APK
/// patching, foreground service) goes through here; pure-Dart code can be
/// unit tested without a device.
class NativeBridge {
  static final NativeBridge instance = NativeBridge._();

  static const MethodChannel _channel = MethodChannel(
    'eternal.future.tefmanager/native',
  );
  static const MethodChannel _modPageChannel = MethodChannel(
    'eternal.future.tefmanager/modpage',
  );

  bool _available = true;
  final StreamController<String> _patchProgress =
      StreamController<String>.broadcast();
  final StreamController<void> _modPageClosed =
      StreamController<void>.broadcast();

  NativeBridge._() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'apk.progress') {
        final args = call.arguments;
        if (args is Map && args['phase'] is String) {
          _patchProgress.add(args['phase'] as String);
        }
      }
      return null;
    });
    _modPageChannel.setMethodCallHandler((call) async {
      if (call.method == 'modpage.closed') {
        _modPageClosed.add(null);
      }
      return null;
    });
  }

  Stream<void> get modPageClosed => _modPageClosed.stream;

  Future<bool> openModPage({
    required String jarPath,
    required String className,
    required Map<String, dynamic> params,
  }) async {
    try {
      final result = await _modPageChannel.invokeMethod<bool>('open', {
        'jarPath': jarPath,
        'className': className,
        'params': params,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> closeModPage() async {
    try {
      await _modPageChannel.invokeMethod<void>('close');
    } catch (_) {}
  }

  /// Emits i18n keys from `home.patch.progress.*` while patching.
  Stream<String> get patchProgress => _patchProgress.stream;

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

  Future<bool> hasRoot() async =>
      await _invoke<bool>('root.hasPermission') ?? false;

  Future<bool> grantRootAccess(String packageName) async =>
      await _invoke<bool>('root.grantAccess', {'package': packageName}) ??
      false;

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

  Future<void> openUrl(String url) async =>
      _invoke<void>('url.open', {'url': url});

  /// Runs the native APK patcher. On success the file at [path] is modified
  /// in place and re-signed with the official certificate.
  Future<PatchResult> patchApk(String path, {PatchOption? option}) async {
    final raw = await _invoke<Map>('apk.patch', {
      'path': path,
      'option': (option ?? PatchOption.appComponentFactory).name,
    });
    if (raw == null) {
      return const PatchResult(
        success: false,
        error: 'Native patcher unavailable',
      );
    }
    return PatchResult(
      success: raw['success'] == true,
      error: raw['error']?.toString(),
    );
  }

  Future<Uint8List?> readAndroidAsset(String name) async {
    try {
      return await _channel.invokeMethod<Uint8List>('asset.read', {
        'name': name,
      });
    } catch (_) {
      return null;
    }
  }
}

enum PatchOption { application, appComponentFactory }

class PatchResult {
  const PatchResult({required this.success, this.error});

  final bool success;
  final String? error;
}
