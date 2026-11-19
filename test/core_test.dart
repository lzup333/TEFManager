import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tefmanager/core/utils.dart';
import 'package:tefmanager/models/models.dart';
import 'package:tefmanager/data/addon_codec.dart';
import 'package:tefmanager/data/light_store.dart';
import 'package:tefmanager/data/component_store.dart';
import 'package:tefmanager/data/resource_pack_store.dart';
import 'package:tefmanager/data/mod_settings_store.dart';
import 'package:tefmanager/data/bundled_installer.dart';
import 'package:tefmanager/data/instance_store.dart';
import 'package:tefmanager/data/mod_groups_store.dart';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tefmanager/data/mod_repository.dart';

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
  _settingsTests();
  _storeTests();
  _kernelTests();
  _instanceTests();
  _bundleTests();
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
    final firstLength = ByteData.sublistView(
      data,
      0,
      4,
    ).getInt32(0, Endian.big);
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
    expect(
      await File('${dir.path}/enables.txt').readAsString(),
      'a.one\na.two\n',
    );
    await list.disable('a.one');
    expect(await list.read(), {'a.two'});
    await dir.delete(recursive: true);
  });
}

void _installTests() {
  test('installs a .tefpkg into the official directory layout', () async {
    final dir = await Directory.systemTemp.createTemp('tefinstall');
    final archive = Archive()
      ..add(
        ArchiveFile.string(
          'Manifest.json',
          '{"type":"module","file":"payload/module.json","iconFile":"Icon.png","resources":"res/"}',
        ),
      )
      ..add(
        ArchiveFile.string(
          'Info.json',
          '{"pkgId":"test.module","name":"Test Module","version":"1.0","versionCode":3}',
        ),
      )
      ..add(ArchiveFile.string('payload/module.json', '{"ok":true}'))
      ..add(ArchiveFile.bytes('Icon.png', [1, 2, 3]))
      ..add(ArchiveFile.string('res/config.txt', 'hello'));
    final bytes = ZipEncoder().encodeBytes(archive);

    final store = ComponentStore(dir, kernelVersion: '1.4.0');
    final result = await store.installBytes(bytes);
    expect(result.success, isTrue, reason: result.error);
    expect(result.pkgId, 'test.module');

    expect(
      await File('${dir.path}/module/pkg/test.module.tefpkg').exists(),
      isTrue,
    );
    expect(
      await File('${dir.path}/module/icons/test.module.icon').exists(),
      isTrue,
    );
    expect(
      await File(
        '${dir.path}/module/private/test.module/config.txt',
      ).readAsString(),
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
    expect(
      await File('${dir.path}/module/pkg/test.module.tefpkg').exists(),
      isFalse,
    );

    await dir.delete(recursive: true);
  });

  test('installs a language resource pack and writes config.json', () async {
    final dir = await Directory.systemTemp.createTemp('tefpack');
    final archive = Archive()
      ..add(
        ArchiveFile.string(
          'pack_info.json',
          '{"name":"Test Lang","author":"Me","version":"1.2","type":"languagepack"}',
        ),
      )
      ..add(ArchiveFile.bytes('Icon.png', [9, 9, 9]));
    final bytes = ZipEncoder().encodeBytes(archive);

    final store = ResourcePackStore(dir);
    final result = await store.installBytes(bytes);
    expect(result.success, isTrue, reason: result.error);
    final item = result.item!;
    expect(item.packType, PackType.language);
    expect(item.name, 'Test Lang');
    expect(
      await File(
        '${dir.path}/module/private/eternal.future.languagepackextension/language_packs/${item.fileName}',
      ).exists(),
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

void _settingsTests() {
  test('mod settings use the official config.json schema', () async {
    final dir = await Directory.systemTemp.createTemp('tefmodsettings');
    await ModSettingsStore.write(dir, {
      'speed': 3,
      'enabled': true,
      'name': 'x',
    });
    final raw = await File('${dir.path}/config.json').readAsString();
    expect(raw.contains('"schemaVersion": 1'), isTrue);
    final values = await ModSettingsStore.read(dir);
    expect(values['speed'], 3);
    expect(values['enabled'], isTrue);
    expect(values['name'], 'x');
    await dir.delete(recursive: true);
  });
}

void _storeTests() {
  test('mod repository keeps the index order', () async {
    final client = MockClient((request) async {
      final url = request.url.toString();
      if (url.contains('one')) {
        return http.Response(
          '{"loaderMinVersionCode":0,"mods":['
          '{"pkgId":"b","name":"Zeta","versionCode":1},'
          '{"pkgId":"a","name":"Alpha","versionCode":1}]}',
          200,
        );
      }
      return http.Response(
        '{"loaderMinVersionCode":0,"mods":['
        '{"pkgId":"c","name":"Beta","versionCode":1},'
        '{"pkgId":"a","name":"Alpha","versionCode":2}]}',
        200,
      );
    });
    final service = ModRepositoryService(client: client);
    final entries = await service.fetch(
      const [
        ModLoaderItem(
          pkgId: 'loader.one',
          name: 'One',
          versionCode: 10,
          modRepositoryIndexUrl: 'https://example.com/one.json',
        ),
        ModLoaderItem(
          pkgId: 'loader.two',
          name: 'Two',
          versionCode: 10,
          modRepositoryIndexUrl: 'https://example.com/two.json',
        ),
      ],
      enabledLoaderIds: const {'loader.one', 'loader.two'},
    );
    expect(entries.map((e) => e.mod.pkgId).toList(), ['b', 'a', 'c']);
    // The duplicate keeps its first position but uses the newer version.
    expect(entries[1].mod.versionCode, 2);
  });
}

void _kernelTests() {
  test('kernel import extracts info.json and libraries', () async {
    final dir = await Directory.systemTemp.createTemp('tefkernel');
    final archive = Archive()
      ..add(
        ArchiveFile.string('info.json', '{"version":"1.4.1","versionCode":1}'),
      )
      ..add(ArchiveFile.bytes('libtefkernel.android.arm64-v8a.so', [1, 2, 3]));
    final version = await BundledInstaller(
      dir,
    ).installKernelBytes(ZipEncoder().encodeBytes(archive));
    expect(version, '1.4.1');
    expect(await File('${dir.path}/tefkernel/info.json').exists(), isTrue);
    expect(
      await File(
        '${dir.path}/tefkernel/libtefkernel.android.arm64-v8a.so',
      ).exists(),
      isTrue,
    );

    final bad = Archive()..add(ArchiveFile.string('readme.txt', 'no kernel'));
    await expectLater(
      BundledInstaller(dir).installKernelBytes(ZipEncoder().encodeBytes(bad)),
      throwsA(isA<FormatException>()),
    );
    await dir.delete(recursive: true);
  });
}

void _instanceTests() {
  test('instances: default, create, clone and export layout', () async {
    final root = await Directory.systemTemp.createTemp('tefinst');
    final store = InstanceStore(root);

    var state = await store.load();
    expect(state.activeId, 'default');
    expect(state.items.single.isDefault, isTrue);

    // Put something into the default instance.
    final moduleFile = File('${root.path}/module/pkg/a.tefpkg');
    await moduleFile.parent.create(recursive: true);
    await moduleFile.writeAsString('payload');
    final packFile = File(
      '${root.path}/module/private/eternal.future.texturepackextension/'
      'texture_packs/tex_a.zip',
    );
    await packFile.parent.create(recursive: true);
    await packFile.writeAsString('pack');
    final kernelFile = File('${root.path}/tefkernel/info.json');
    await kernelFile.parent.create(recursive: true);
    await kernelFile.writeAsString('{"version":"1.4.0"}');

    final groupsStore = ModGroupsStore(root);
    await groupsStore.save(
      const ModGroupsState(
        groups: [ModGroup(id: 'g1', name: 'Favorites')],
        assignments: {'loader.x|mod.y': 'g1'},
      ),
    );
    expect((await groupsStore.load()).groups.single.name, 'Favorites');

    state = await store.create(state, name: '副本', cloneFromId: 'default');
    final clone = state.items.last;
    expect(
      await File('${store.dirFor(clone.id).path}/module/pkg/a.tefpkg').exists(),
      isTrue,
    );
    expect(
      await File('${store.dirFor(clone.id).path}/mod_groups.json').exists(),
      isTrue,
    );

    final exported = await store.exportZip(
      clone,
      includeResourcePacks: false,
      loaderBytes: Uint8List.fromList([1, 2, 3]),
    );
    final archive = ZipDecoder().decodeBytes(exported);
    final names = archive.files.map((e) => e.name).toSet();
    expect(names, contains('info.json'));
    expect(names, contains('tefloader.dex'));
    expect(names, contains('tefkernel/info.json'));
    expect(names, contains('data/module/pkg/a.tefpkg'));
    expect(names, contains('data/mod_groups.json'));
    expect(names.any((n) => n.contains('texturepackextension')), isFalse);

    final withPacks = await store.exportZip(
      clone,
      includeResourcePacks: true,
      loaderBytes: Uint8List.fromList([1, 2, 3]),
    );
    final packNames = ZipDecoder()
        .decodeBytes(withPacks)
        .files
        .map((e) => e.name);
    expect(packNames.any((n) => n.contains('texturepackextension')), isTrue);

    // Import into a fresh manager root.
    final root2 = await Directory.systemTemp.createTemp('tefinst2');
    final store2 = InstanceStore(root2);
    var state2 = await store2.load();
    final (next, id) = await store2.importZip(state2, exported);
    state2 = next;
    expect(state2.items.any((e) => e.id == id), isTrue);
    final imported = state2.items.firstWhere((e) => e.id == id);
    expect(imported.name, '副本');
    expect(await File('${root2.path}/tefloader.dex').exists(), isTrue);
    expect(await File('${root2.path}/tefkernel/info.json').exists(), isTrue);
    expect(
      await File('${store2.dirFor(id).path}/module/pkg/a.tefpkg').exists(),
      isTrue,
    );

    await root.delete(recursive: true);
    await root2.delete(recursive: true);
  });
}

void _bundleTests() {
  test('bundle archive is detected and installed one by one', () async {
    Uint8List moduleZip(String pkgId, String name) {
      final archive = Archive()
        ..add(
          ArchiveFile.string(
            'Manifest.json',
            '{"type":"module","file":"payload.bin"}',
          ),
        )
        ..add(
          ArchiveFile.string(
            'Info.json',
            '{"pkgId":"$pkgId","name":"$name","version":"1.0","versionCode":1}',
          ),
        )
        ..add(ArchiveFile.string('payload.bin', pkgId));
      return ZipEncoder().encodeBytes(archive);
    }

    final bundle = Archive()
      ..add(ArchiveFile.bytes('first.tefpkg', moduleZip('bundle.one', 'One')))
      ..add(ArchiveFile.bytes('second.tefpkg', moduleZip('bundle.two', 'Two')))
      ..add(ArchiveFile.string('readme.txt', 'hello'));
    final bundleFile = File(
      '${(await Directory.systemTemp.createTemp('tefbundle')).path}/bundle.zip',
    );
    await bundleFile.writeAsBytes(ZipEncoder().encodeBytes(bundle));

    final dataDir = await Directory.systemTemp.createTemp('tefinstbundle');
    final store = ComponentStore(dataDir);
    final info = await store.probeBundle(bundleFile.path);
    expect(info, isNotNull);
    expect(info!.members.length, 2);

    final results = await store.installArchive(bundleFile.path);
    expect(
      results.every((r) => r.success),
      isTrue,
      reason: results.map((r) => r.error).join(','),
    );

    final snapshot = await store.load();
    expect(snapshot.modules.map((e) => e.pkgId).toSet(), {
      'bundle.one',
      'bundle.two',
    });

    await dataDir.delete(recursive: true);
    await File(bundleFile.path).parent.delete(recursive: true);
  });
}
