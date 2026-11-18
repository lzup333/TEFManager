import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/app_info.dart';
import '../models/models.dart';
import 'component_store.dart';

enum UpdateTarget { manager, kernel, language, texture, font, audio, loader }

class UpdateCandidate {
  const UpdateCandidate({
    required this.target,
    required this.title,
    required this.currentVersion,
    required this.entry,
  });

  final UpdateTarget target;
  final String title;
  final String currentVersion;
  final UpdateEntry entry;

  String get latestVersion => entry.newVersion;
}

class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<UpdateInfo?> fetch() async {
    try {
      final response = await _client
          .get(Uri.parse(AppInfo.updateUrl))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final map = jsonDecode(utf8.decode(response.bodyBytes));
      if (map is! Map) return null;
      return UpdateInfo.fromMap(map.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  List<UpdateCandidate> candidates(
    UpdateInfo info, {
    required String appVersion,
    required String kernelVersion,
    required ComponentSnapshot components,
  }) {
    final out = <UpdateCandidate>[];
    void maybe(
      UpdateTarget target,
      String title,
      UpdateEntry? entry,
      String current,
    ) {
      if (entry == null || entry.newVersion.isEmpty) return;
      if (_isNewer(entry.newVersion, current)) {
        out.add(
          UpdateCandidate(
            target: target,
            title: title,
            currentVersion: current,
            entry: entry,
          ),
        );
      }
    }

    maybe(UpdateTarget.manager, 'TEFManager', info.tefmanager, appVersion);
    maybe(UpdateTarget.kernel, 'TEFKernel', info.tefkernel, kernelVersion);
    String moduleVersion(String pkgId) {
      final match = components.modules.where((m) => m.pkgId == pkgId);
      return match.isEmpty ? '0.0.0' : match.first.version;
    }

    maybe(
      UpdateTarget.language,
      'LanguagePackExtension',
      info.language,
      moduleVersion('eternal.future.languagepackextension'),
    );
    maybe(
      UpdateTarget.texture,
      'TexturePackExtension',
      info.texture,
      moduleVersion('eternal.future.texturepackextension'),
    );
    maybe(
      UpdateTarget.font,
      'FontPackExtension',
      info.font,
      moduleVersion('eternal.future.fontpackextension'),
    );
    maybe(
      UpdateTarget.audio,
      'AudioPackExtension',
      info.music,
      moduleVersion('eternal.future.audiopackextension'),
    );
    return out;
  }

  Future<Uint8List?> download(UpdateEntry entry) async {
    if (entry.downloadUrl.isEmpty) return null;
    try {
      final response = await _client
          .get(Uri.parse(entry.downloadUrl))
          .timeout(const Duration(minutes: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  bool _isNewer(String candidate, String current) {
    final a = candidate.split('.');
    final b = current.split('.');
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final x = i < a.length ? int.tryParse(a[i]) ?? 0 : 0;
      final y = i < b.length ? int.tryParse(b[i]) ?? 0 : 0;
      if (x > y) return true;
      if (x < y) return false;
    }
    return false;
  }

  Future<File?> writeCache(UpdateEntry entry, Directory cacheDir) async {
    final bytes = await download(entry);
    if (bytes == null) return null;
    final name = entry.fileName.isEmpty ? 'update.zip' : entry.fileName;
    await cacheDir.create(recursive: true);
    final file = File('${cacheDir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  void dispose() => _client.close();
}
