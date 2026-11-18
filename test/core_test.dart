import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tefmanager/core/utils.dart';
import 'package:tefmanager/models/models.dart';
import 'package:tefmanager/data/addon_codec.dart';
import 'package:tefmanager/data/light_store.dart';
import 'package:tefmanager/data/component_store.dart';
import 'package:tefmanager/data/resource_pack_store.dart';
import 'package:archive/archive.dart';

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

  test('protobuf codec round-trips module metadata', () {
    const item = ModuleItem(
      pkgId: 'eternal.future.language',
      name: 'Language Pack',
      author: 'eternal',
      description: 'desc',
      brieflyDescribe: 'brief',
      version: '1.0.2',
      versionCode: 3,
      detailsURL: 'https://example.com',
      dependence: [Dependence(pkgId: 'tefkernel', minVersionCode: 1)],
      support: PlatformSupport(android: ArchitectureSupport(arm64: true)),
    );
    final decoded = decodeModule(encodeModule(item));
    expect(decoded.pkgId, item.pkgId);
    expect(decoded.name, item.name);
    expect(decoded.dependence.single.pkgId, 'tefkernel');
    expect(decoded.support.android.arm64, isTrue);
    expect(decoded.support.android.arm, isFalse);
  });

  test('protobuf codec keeps enums and setting defaults', () {
    const item = ModItem(
      pkgId: 'a.b',
      features: [ModFeature.newContent, ModFeature.utility],
      sizeCategory: ModSizeCategory.large,
      settings: [
        ModSetting(
          key: 'speed',
          title: 'Speed',
          type: ModSettingType.integer,
          defaultValue: 3,
          min: 1,
          max: 10,
          unit: 'x',
        ),
      ],
    );
    final decoded = decodeMod(encodeMod(item));
    expect(decoded.features, [ModFeature.newContent, ModFeature.utility]);
    expect(decoded.sizeCategory, ModSizeCategory.large);
    expect(decoded.settings.single.defaultValue, 3);
    expect(decoded.settings.single.type, ModSettingType.integer);
  });

  test('bytes formatting', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(1024), '1.00 KB');
  });

  _storageTests();
  _installTests();
}

// ---------------------------------------------------------------------------
// Storage compatibility
// ---------------------------------------------------------------------------

void _storageTests() {
  test('LightStore writes the official data/index/meta layout', () async {
    final dir = await Directory.systemTemp.createTemp('tefstore');
    final store = LightStore(
      directory: Directory('${dir.path}/db'),
      encode: encodeModule,
      decode: decodeModule,
      keyOf: (v) => v.pkgId,
    );
    await store.writeAll(const [
      ModuleItem(pkgId: 'a.one', name: 'One', version: '1.0', versionCode: 1),
      ModuleItem(pkgId: 'a.two', name: 'Two', version: '2.0', versionCode: 2),
    ]);

    final data = await File('${dir.path}/db/data.bin').readAsBytes();
    final firstLength = ByteData.sublistView(data, 0, 4).getInt32(0, Endian.big);
    expect(firstLength, greaterThan(0));
    expect(await File('${dir.path}/db/index.bin').exists(), isTrue);
    expect(await File('${dir.path}/db/meta.bin').exists(), isTrue);

    final loaded = await store.readAll();
    expect(loaded.map((e) => e.pkgId), containsAll(['a.one', 'a.two']));

    await dir.delete(recursive: true);
  });

  test('EnableList keeps enables.txt compatible', () async {
    final dir = await Directory.systemTemp.createTemp('tefenable');
    final list = EnableList(File('${dir.path}/enables.txt'));
    await list.enable('a.one');
    await list.enable('a.two');
    await list.enable('a.one');
    expect(await File('${dir.path}/enables.txt').readAsString(), 'a.one\na.two\n');
    await list.disable('a.one');
    expect(await list.read(), {'a.two'});
    await dir.delete(recursive: true);
  });
}

void _installTests() {
  test('installs a .tefpkg into the official directory layout', () async {
    final dir = await Directory.systemTemp.createTemp('tefinstall');
    final archive = Archive()
      ..add(ArchiveFile.string('Manifest.json',
          '{"type":"module","file":"payload/module.json","iconFile":"Icon.png","resources":"res/"}'))
      ..add(ArchiveFile.string('Info.json',
          '{"pkgId":"test.module","name":"Test Module","version":"1.0","versionCode":3}'))
      ..add(ArchiveFile.string('payload/module.json', '{"ok":true}'))
      ..add(ArchiveFile.bytes('Icon.png', [1, 2, 3]))
      ..add(ArchiveFile.string('res/config.txt', 'hello'));
    final bytes = ZipEncoder().encodeBytes(archive);

    final store = ComponentStore(dir, kernelVersion: '1.4.0');
    final result = await store.installBytes(bytes);
    expect(result.success, isTrue, reason: result.error);
    expect(result.pkgId, 'test.module');

    expect(await File('${dir.path}/module/pkg/test.module.tefpkg').exists(), isTrue);
    expect(await File('${dir.path}/module/icons/test.module.icon').exists(), isTrue);
    expect(
      await File('${dir.path}/module/private/test.module/config.txt').readAsString(),
      'hello',
    );

    var snapshot = await store.load();
    expect(snapshot.modules.single.pkgId, 'test.module');
    expect(snapshot.enabledModules, isEmpty);

    await store.setEnabled(AddonKind.module, 'test.module', true);
    snapshot = await store.load();
    expect(snapshot.enabledModules, contains('test.module'));

    await store.delete(AddonKind.module, 'test.module');
    snapshot = await store.load();
    expect(snapshot.modules, isEmpty);
    expect(await File('${dir.path}/module/pkg/test.module.tefpkg').exists(), isFalse);

    await dir.delete(recursive: true);
  });

  test('installs a language resource pack and writes config.json', () async {
    final dir = await Directory.systemTemp.createTemp('tefpack');
    final archive = Archive()
      ..add(ArchiveFile.string('pack_info.json',
          '{"name":"Test Lang","author":"Me","version":"1.2","type":"languagepack"}'))
      ..add(ArchiveFile.bytes('Icon.png', [9, 9, 9]));
    final bytes = ZipEncoder().encodeBytes(archive);

    final store = ResourcePackStore(dir);
    final result = await store.installBytes(bytes);
    expect(result.success, isTrue, reason: result.error);
    final item = result.item!;
    expect(item.packType, PackType.language);
    expect(item.name, 'Test Lang');
    expect(
      await File('${dir.path}/module/private/eternal.future.languagepackextension/language_packs/${item.fileName}').exists(),
      isTrue,
    );

    var snapshot = await store.load();
    expect(snapshot.of(PackType.language).single.fileName, item.fileName);
    expect(snapshot.isEnabled(PackType.language, item.fileName), isFalse);

    await store.setEnabled(PackType.language, item, true);
    snapshot = await store.load();
    expect(snapshot.isEnabled(PackType.language, item.fileName), isTrue);

    await store.delete(PackType.language, item);
    snapshot = await store.load();
    expect(snapshot.of(PackType.language), isEmpty);

    await dir.delete(recursive: true);
  });
}
