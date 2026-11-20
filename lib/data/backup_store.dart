import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Simple whole-data backup/restore for the working directory.
///
/// Backs up `module`, `plugin`, `modloader`, `mods`, `tefkernel`, `logs` and
/// `mod_groups.json`. App config and app-level files are not included.
class BackupStore {
  BackupStore(this.rootDir);

  static const contentDirs = [
    'module',
    'plugin',
    'modloader',
    'mods',
    'tefkernel',
    'logs',
  ];

  final Directory rootDir;

  Future<Uint8List> export() async {
    final archive = Archive();
    archive.add(
      ArchiveFile.string(
        'info.json',
        const JsonEncoder.withIndent('  ').convert({
          'format': 'tefmanager-backup',
          'formatVersion': 1,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        }),
      ),
    );

    for (final name in contentDirs) {
      final source = Directory('${rootDir.path}/$name');
      if (!await source.exists()) continue;
      await for (final entity in source.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final relative = entity.path.substring(rootDir.path.length + 1);
        archive.add(
          ArchiveFile.bytes(
            'data/${relative.replaceAll('\\', '/')}',
            await entity.readAsBytes(),
          ),
        );
      }
    }
    final groups = File('${rootDir.path}/mod_groups.json');
    if (await groups.exists()) {
      archive.add(
        ArchiveFile.bytes('data/mod_groups.json', await groups.readAsBytes()),
      );
    }
    return ZipEncoder().encodeBytes(archive);
  }

  /// Clears the managed working content, then restores from the ZIP.
  Future<void> importZip(Uint8List bytes) async {
    for (final name in contentDirs) {
      final dir = Directory('${rootDir.path}/$name');
      if (await dir.exists()) await dir.delete(recursive: true);
    }
    final groups = File('${rootDir.path}/mod_groups.json');
    if (await groups.exists()) await groups.delete();

    final archive = ZipDecoder().decodeBytes(bytes);
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      var relative = entry.name.replaceAll('\\', '/');
      if (relative == 'info.json' || relative == 'instance.json') continue;
      if (relative.contains('..') || relative.startsWith('/')) continue;
      if (relative.startsWith('data/')) {
        relative = relative.substring('data/'.length);
      }
      if (relative.isEmpty) continue;
      final target = File('${rootDir.path}/$relative');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(entry.content, flush: true);
    }
  }
}
