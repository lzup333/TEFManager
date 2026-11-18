import 'package:flutter_test/flutter_test.dart';
import 'package:tefmanager/core/utils.dart';
import 'package:tefmanager/models/models.dart';

void main() {
  test('version comparison follows the Kotlin implementation', () {
    expect(isVersionGreater('1.2.0', '1.1.9'), isTrue);
    expect(isVersionGreater('1.0', '1.0.0'), isFalse);
    expect(isVersionGreater('2', '10'), isFalse);
  });

  test('mod manifest parsing keeps optional fields', () {
    final mod = ModItem.fromMap({
      'pkgId': 'author.mod',
      'name': 'Example',
      'version': '1.0.0',
      'features': ['NEW_CONTENT', 'QUALITY_OF_LIFE'],
      'support': {
        'android': {'arm64': true},
      },
    });
    expect(mod.pkgId, 'author.mod');
    expect(mod.features, [ModFeature.newContent, ModFeature.qualityOfLife]);
    expect(mod.support.android.archs, ['ARM64']);
  });

  test('bytes formatting', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(1024), '1.00 KB');
  });
}
