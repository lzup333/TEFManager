import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import '../core/native_bridge.dart';

import '../models/models.dart';
import 'component_store.dart';

class BundledStep {
  const BundledStep({
    required this.name,
    required this.success,
    this.skipped = false,
    this.error,
  });

  final String name;
  final bool success;
  final bool skipped;
  final String? error;
}

class BundledModuleAsset {
  const BundledModuleAsset({
    required this.asset,
    required this.pkgId,
    required this.label,
  });

  final String asset;
  final String pkgId;
  final String label;
}

const bundledModules = [
  BundledModuleAsset(
    asset: 'LanguagePackExtension.zip',
    pkgId: 'eternal.future.languagepackextension',
    label: 'LanguagePackExtension',
  ),
  BundledModuleAsset(
    asset: 'TexturePackExtension.zip',
    pkgId: 'eternal.future.texturepackextension',
    label: 'TexturePackExtension',
  ),
  BundledModuleAsset(
    asset: 'FontPackExtension.zip',
    pkgId: 'eternal.future.fontpackextension',
    label: 'FontPackExtension',
  ),
  BundledModuleAsset(
    asset: 'AudioPackExtension.zip',
    pkgId: 'eternal.future.audiopackextension',
    label: 'AudioPackExtension',
  ),
];

class BundledInstaller {
  BundledInstaller(this.dataDir);

  final Directory dataDir;

  static Future<Uint8List> loadAsset(String path) async {
    final bytes = await NativeBridge.instance.readAndroidAsset(path);
    if (bytes == null) throw StateError('Asset not found: $path');
    return bytes;
  }

  Future<String?> installKernel() async {
    return installKernelBytes(await loadAsset('tefkernel.zip'));
  }

  Future<String?> installKernelBytes(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final target = Directory('${dataDir.path}/tefkernel');
    await target.create(recursive: true);
    String? version;
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final name = entry.name.replaceAll('\\', '/');
      if (name.contains('..') || name.startsWith('/')) continue;
      final file = File('${target.path}/$name');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.content, flush: true);
      if (name == 'info.json') {
        try {
          final map = jsonDecode(utf8.decode(entry.content));
          if (map is Map && map['version'] != null) {
            version = map['version'].toString();
          }
        } catch (_) {}
      }
    }
    return version;
  }

  Future<String?> moduleVersion(Uint8List bytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final entry in archive.files) {
        if (entry.isFile && entry.name == 'Info.json') {
          final map = (jsonDecode(utf8.decode(entry.content)) as Map)
              .cast<String, dynamic>();
          return map['version']?.toString();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<BundledStep>> installAll({
    required ComponentStore store,
    required Future<void> Function(String? kernelVersion) onKernelInstalled,
    void Function(String label, int index, int total)? onProgress,
  }) async {
    final steps = <BundledStep>[];
    var index = 0;
    final total = bundledModules.length + 1;

    onProgress?.call('TEFKernel', index, total);
    try {
      final version = await installKernel();
      await onKernelInstalled(version);
      steps.add(const BundledStep(name: 'TEFKernel', success: true));
    } catch (e) {
      steps.add(BundledStep(name: 'TEFKernel', success: false, error: '$e'));
    }
    index++;

    final installed = await store.load();
    for (final module in bundledModules) {
      onProgress?.call(module.label, index, total);
      try {
        final bytes = await loadAsset(module.asset);
        final assetVersion = await moduleVersion(bytes);
        final existing = installed.modules
            .where((m) => m.pkgId == module.pkgId)
            .toList();
        if (existing.isNotEmpty &&
            assetVersion != null &&
            !_isNewer(assetVersion, existing.first.version)) {
          steps.add(BundledStep(
            name: module.label,
            success: true,
            skipped: true,
          ));
        } else {
          final result = await store.installBytes(bytes);
          steps.add(BundledStep(
            name: module.label,
            success: result.success,
            error: result.error,
          ));
        }
      } catch (e) {
        steps.add(BundledStep(name: module.label, success: false, error: '$e'));
      }
      index++;
    }
    return steps;
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
}

/// Convenience for callers that only need the list of component names.
List<String> get bundledModuleLabels =>
    [for (final m in bundledModules) m.label];

/// Kept for potential migration of legacy databases.
Future<List<ModuleItem>> readModuleDatabase(Directory dataDir) async {
  final store = ComponentStore(dataDir);
  return (await store.load()).modules;
}
