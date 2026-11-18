import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class ModStoreEntry {
  const ModStoreEntry({
    required this.loaderId,
    required this.loaderName,
    required this.mod,
  });

  final String loaderId;
  final String loaderName;
  final ModRepositoryEntry mod;
}

class ModRepositoryService {
  ModRepositoryService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<ModStoreEntry>> fetch(
    List<ModLoaderItem> loaders, {
    Set<String> enabledLoaderIds = const {},
    bool onlyEnabled = true,
  }) async {
    final entries = <String, ModStoreEntry>{};
    for (final loader in loaders) {
      if (loader.modRepositoryIndexUrl.isEmpty) continue;
      if (onlyEnabled && !enabledLoaderIds.contains(loader.pkgId)) continue;
      final index = await _fetchIndex(loader);
      if (index == null) continue;
      if (loader.versionCode < index.loaderMinVersionCode) continue;
      for (final mod in index.mods) {
        final existing = entries[mod.pkgId];
        if (existing == null ||
            mod.versionCode > existing.mod.versionCode ||
            (mod.versionCode == existing.mod.versionCode &&
                mod.version.compareTo(existing.mod.version) > 0)) {
          entries[mod.pkgId] = ModStoreEntry(
            loaderId: loader.pkgId,
            loaderName: loader.name.isEmpty ? loader.pkgId : loader.name,
            mod: mod,
          );
        }
      }
    }
    final list = entries.values.toList()
      ..sort((a, b) => a.mod.name.toLowerCase().compareTo(b.mod.name.toLowerCase()));
    return list;
  }

  Future<ModRepositoryIndex?> _fetchIndex(ModLoaderItem loader) async {
    try {
      final response = await _client
          .get(Uri.parse(loader.modRepositoryIndexUrl))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final map = jsonDecode(utf8.decode(response.bodyBytes));
      if (map is! Map) return null;
      return ModRepositoryIndex.fromMap(map.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<String?> download(
    ModRepositoryEntry mod,
    Directory cacheDir, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final request = http.Request('GET', Uri.parse(mod.downloadUrl));
      final response = await _client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      await cacheDir.create(recursive: true);
      final file = File(
        '${cacheDir.path}/${_safe(mod.pkgId)}-${mod.versionCode}.tefpkg',
      );
      final sink = file.openWrite();
      final total = response.contentLength ?? mod.fileSize;
      var received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
      return file.path;
    } catch (_) {
      return null;
    }
  }

  String _safe(String value) => value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  void dispose() => _client.close();
}
