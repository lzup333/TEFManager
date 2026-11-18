import 'dart:convert';
import 'dart:io';

/// Reads/writes a mod's own settings file, compatible with the official
/// manager:
///   mods/<loaderId>/private/<pkgId>/config.json
///   {"schemaVersion":1,"values":{"key": <json value>}}
class ModSettingsStore {
  const ModSettingsStore._();

  static File fileFor(Directory privateDir) =>
      File('${privateDir.path}/config.json');

  static Future<Map<String, dynamic>> read(Directory privateDir) async {
    final file = fileFor(privateDir);
    if (!await file.exists()) return {};
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is Map && raw['values'] is Map) {
        return (raw['values'] as Map).cast<String, dynamic>();
      }
    } catch (_) {}
    return {};
  }

  static Future<void> write(
    Directory privateDir,
    Map<String, dynamic> values,
  ) async {
    final file = fileFor(privateDir);
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    const encoder = JsonEncoder.withIndent('  ');
    await temp.writeAsString(
      encoder.convert({'schemaVersion': 1, 'values': values}),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }
}
