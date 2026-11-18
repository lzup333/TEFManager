import 'dart:typed_data';

import '../models/models.dart';
import 'protobuf.dart';

/// Bidirectional codec for the metadata store used by the official Kotlin
/// manager (`LightProtoStore` + `kotlinx.serialization.protobuf`).
///
/// Kotlin assigns protobuf field numbers from the declaration order and encodes
/// enums as their ordinal, with `encodeDefaults = true`. Keeping the exact same
/// layout lets players switch between the official app and this Flutter build
/// without losing their installed component list.

// ---------------------------------------------------------------------------
// Encoding
// ---------------------------------------------------------------------------

Uint8List encodePlugin(PluginItem item) {
  final w = PbWriter();
  w.writeString(1, item.pkgId);
  w.writeString(2, item.name);
  w.writeString(3, item.author);
  w.writeString(4, item.description);
  w.writeString(5, item.version);
  w.writeInt(6, item.versionCode);
  return w.takeBytes();
}

Uint8List encodeModule(ModuleItem item) {
  final w = PbWriter();
  w.writeString(1, item.pkgId);
  w.writeString(2, item.name);
  w.writeString(3, item.author);
  w.writeString(4, item.description);
  w.writeString(5, item.brieflyDescribe);
  w.writeString(6, item.version);
  w.writeInt(7, item.versionCode);
  w.writeString(8, item.detailsURL);
  for (final d in item.dependence) {
    w.writeMessage(9, _encodeDependence(d));
  }
  w.writeMessage(10, _encodePlatformSupport(item.support));
  return w.takeBytes();
}

Uint8List encodeModLoader(ModLoaderItem item) {
  final w = PbWriter();
  w.writeString(1, item.pkgId);
  w.writeString(2, item.name);
  w.writeString(3, item.author);
  w.writeString(4, item.brieflyDescribe);
  w.writeString(5, item.description);
  w.writeString(6, item.version);
  w.writeInt(7, item.versionCode);
  for (final d in item.dependence) {
    w.writeMessage(8, _encodeDependence(d));
  }
  w.writeMessage(9, _encodePlatformSupport(item.support));
  w.writeString(10, item.updateInfoUrl);
  w.writeString(11, item.modRepositoryIndexUrl);
  return w.takeBytes();
}

Uint8List encodeMod(ModItem item) {
  final w = PbWriter();
  w.writeString(1, item.pkgId);
  w.writeString(2, item.name);
  w.writeString(3, item.author);
  w.writeString(4, item.version);
  w.writeInt(5, item.versionCode);
  w.writeString(6, item.brieflyDescribe);
  w.writeString(7, item.description);
  for (final f in item.features) {
    w.writeEnum(8, f.index);
  }
  w.writeEnum(9, item.sizeCategory.index);
  w.writeString(10, item.targetGameVersion);
  w.writeString(11, item.minGameVersion);
  w.writeString(12, item.maxGameVersion);
  w.writeMessage(13, _encodePlatformSupport(item.support));
  for (final d in item.dependence) {
    w.writeMessage(14, _encodeDependence(d));
  }
  for (final c in item.conflicts) {
    w.writeString(15, c);
  }
  w.writeString(16, item.detailsURL);
  w.writeBool(17, item.stableVerified);
  w.writeBool(18, item.experimental);
  w.writeBool(19, item.deprecated);
  w.writeBool(20, item.hasExtendedContent);
  for (final s in item.settings) {
    w.writeMessage(21, _encodeSetting(s));
  }
  w.writeString(22, item.updateInfoUrl);
  return w.takeBytes();
}

PbWriter _encodeDependence(Dependence d) {
  final w = PbWriter();
  w.writeString(1, d.pkgId);
  w.writeInt(2, d.minVersionCode);
  w.writeInt(3, d.maxVersionCode);
  return w;
}

PbWriter _encodePlatformSupport(PlatformSupport s) {
  final w = PbWriter();
  w.writeMessage(1, _encodeArch(s.android));
  w.writeMessage(2, _encodeArch(s.windows));
  w.writeMessage(3, _encodeArch(s.linux));
  w.writeMessage(4, _encodeArch(s.mac));
  w.writeMessage(5, _encodeArch(s.ios));
  return w;
}

PbWriter _encodeArch(ArchitectureSupport a) {
  final w = PbWriter();
  w.writeBool(1, a.arm64);
  w.writeBool(2, a.arm);
  w.writeBool(3, a.x64);
  w.writeBool(4, a.x86);
  return w;
}

PbWriter _encodeSetting(ModSetting s) {
  final w = PbWriter();
  w.writeString(1, s.key);
  w.writeString(2, s.title);
  w.writeString(3, s.description);
  w.writeEnum(4, s.type.index);
  w.writeString(5, _encodeJsonPrimitive(s.defaultValue));
  w.writeInt(6, s.min);
  w.writeInt(7, s.max);
  w.writeInt(8, s.step);
  w.writeString(9, s.unit);
  for (final o in s.options) {
    final ow = PbWriter();
    ow.writeString(1, o.value);
    ow.writeString(2, o.label);
    w.writeMessage(10, ow);
  }
  w.writeString(11, s.section);
  return w;
}

String _encodeJsonPrimitive(dynamic value) {
  if (value is String) return 's:$value';
  if (value is bool) return 'b:$value';
  if (value is num) return 'n:$value';
  if (value == null) return 's:';
  return 's:$value';
}

dynamic _decodeJsonPrimitive(String stored) {
  if (stored.startsWith('b:')) return stored.substring(2) == 'true';
  if (stored.startsWith('n:')) {
    final number = stored.substring(2);
    return int.tryParse(number) ?? double.tryParse(number) ?? number;
  }
  if (stored.startsWith('s:')) return stored.substring(2);
  return stored;
}

// ---------------------------------------------------------------------------
// Decoding
// ---------------------------------------------------------------------------

PluginItem decodePlugin(Uint8List bytes) {
  var pkgId = '', name = '', author = '', description = '', version = '';
  var versionCode = 0;
  final r = PbReader(bytes);
  while (!r.isDone) {
    final f = r.readField();
    switch (f.number) {
      case 1:
        pkgId = f.asString;
      case 2:
        name = f.asString;
      case 3:
        author = f.asString;
      case 4:
        description = f.asString;
      case 5:
        version = f.asString;
      case 6:
        versionCode = f.asInt;
    }
  }
  return PluginItem(
    pkgId: pkgId,
    name: name,
    author: author,
    description: description,
    version: version,
    versionCode: versionCode,
  );
}

ModuleItem decodeModule(Uint8List bytes) {
  var pkgId = '', name = '', author = '', description = '', briefly = '';
  var version = '', detailsURL = '';
  var versionCode = 0;
  final deps = <Dependence>[];
  var support = const PlatformSupport();
  final r = PbReader(bytes);
  while (!r.isDone) {
    final f = r.readField();
    switch (f.number) {
      case 1:
        pkgId = f.asString;
      case 2:
        name = f.asString;
      case 3:
        author = f.asString;
      case 4:
        description = f.asString;
      case 5:
        briefly = f.asString;
      case 6:
        version = f.asString;
      case 7:
        versionCode = f.asInt;
      case 8:
        detailsURL = f.asString;
      case 9:
        deps.add(_decodeDependence(f.asBytes));
      case 10:
        support = _decodePlatformSupport(f.asBytes);
    }
  }
  return ModuleItem(
    pkgId: pkgId,
    name: name,
    author: author,
    description: description,
    brieflyDescribe: briefly,
    version: version,
    versionCode: versionCode,
    detailsURL: detailsURL,
    dependence: deps,
    support: support,
  );
}

ModLoaderItem decodeModLoader(Uint8List bytes) {
  var pkgId = '', name = '', author = '', briefly = '', description = '';
  var version = '', updateInfoUrl = '', repository = '';
  var versionCode = 0;
  final deps = <Dependence>[];
  var support = const PlatformSupport();
  final r = PbReader(bytes);
  while (!r.isDone) {
    final f = r.readField();
    switch (f.number) {
      case 1:
        pkgId = f.asString;
      case 2:
        name = f.asString;
      case 3:
        author = f.asString;
      case 4:
        briefly = f.asString;
      case 5:
        description = f.asString;
      case 6:
        version = f.asString;
      case 7:
        versionCode = f.asInt;
      case 8:
        deps.add(_decodeDependence(f.asBytes));
      case 9:
        support = _decodePlatformSupport(f.asBytes);
      case 10:
        updateInfoUrl = f.asString;
      case 11:
        repository = f.asString;
    }
  }
  return ModLoaderItem(
    pkgId: pkgId,
    name: name,
    author: author,
    brieflyDescribe: briefly,
    description: description,
    version: version,
    versionCode: versionCode,
    dependence: deps,
    support: support,
    updateInfoUrl: updateInfoUrl,
    modRepositoryIndexUrl: repository,
  );
}

ModItem decodeMod(Uint8List bytes) {
  var pkgId = '', name = '', author = '', version = '';
  var versionCode = 0;
  var briefly = '', description = '';
  final features = <ModFeature>[];
  var size = ModSizeCategory.tiny;
  var target = '', minGame = '', maxGame = '';
  var support = const PlatformSupport();
  final deps = <Dependence>[];
  final conflicts = <String>[];
  var detailsURL = '';
  var stable = false, experimental = false, deprecated = false, extended = false;
  final settings = <ModSetting>[];
  var updateInfoUrl = '';
  final r = PbReader(bytes);
  while (!r.isDone) {
    final f = r.readField();
    switch (f.number) {
      case 1:
        pkgId = f.asString;
      case 2:
        name = f.asString;
      case 3:
        author = f.asString;
      case 4:
        version = f.asString;
      case 5:
        versionCode = f.asInt;
      case 6:
        briefly = f.asString;
      case 7:
        description = f.asString;
      case 8:
        final ordinal = f.asInt;
        if (ordinal >= 0 && ordinal < ModFeature.values.length) {
          features.add(ModFeature.values[ordinal]);
        }
      case 9:
        final ordinal = f.asInt;
        if (ordinal >= 0 && ordinal < ModSizeCategory.values.length) {
          size = ModSizeCategory.values[ordinal];
        }
      case 10:
        target = f.asString;
      case 11:
        minGame = f.asString;
      case 12:
        maxGame = f.asString;
      case 13:
        support = _decodePlatformSupport(f.asBytes);
      case 14:
        deps.add(_decodeDependence(f.asBytes));
      case 15:
        conflicts.add(f.asString);
      case 16:
        detailsURL = f.asString;
      case 17:
        stable = f.asBool;
      case 18:
        experimental = f.asBool;
      case 19:
        deprecated = f.asBool;
      case 20:
        extended = f.asBool;
      case 21:
        settings.add(_decodeSetting(f.asBytes));
      case 22:
        updateInfoUrl = f.asString;
    }
  }
  return ModItem(
    pkgId: pkgId,
    name: name,
    author: author,
    version: version,
    versionCode: versionCode,
    brieflyDescribe: briefly,
    description: description,
    features: features,
    sizeCategory: size,
    targetGameVersion: target,
    minGameVersion: minGame,
    maxGameVersion: maxGame,
    support: support,
    dependence: deps,
    conflicts: conflicts,
    detailsURL: detailsURL,
    stableVerified: stable,
    experimental: experimental,
    deprecated: deprecated,
    hasExtendedContent: extended,
    settings: settings,
    updateInfoUrl: updateInfoUrl,
  );
}

Dependence _decodeDependence(Uint8List bytes) {
  var pkgId = '';
  var min = 0, max = 0;
  final r = PbReader(bytes);
  while (!r.isDone) {
    final f = r.readField();
    switch (f.number) {
      case 1:
        pkgId = f.asString;
      case 2:
        min = f.asInt;
      case 3:
        max = f.asInt;
    }
  }
  return Dependence(pkgId: pkgId, minVersionCode: min, maxVersionCode: max);
}

PlatformSupport _decodePlatformSupport(Uint8List bytes) {
  var android = const ArchitectureSupport();
  var windows = const ArchitectureSupport();
  var linux = const ArchitectureSupport();
  var mac = const ArchitectureSupport();
  var ios = const ArchitectureSupport();
  final r = PbReader(bytes);
  while (!r.isDone) {
    final f = r.readField();
    switch (f.number) {
      case 1:
        android = _decodeArch(f.asBytes);
      case 2:
        windows = _decodeArch(f.asBytes);
      case 3:
        linux = _decodeArch(f.asBytes);
      case 4:
        mac = _decodeArch(f.asBytes);
      case 5:
        ios = _decodeArch(f.asBytes);
    }
  }
  return PlatformSupport(
    android: android,
    windows: windows,
    linux: linux,
    mac: mac,
    ios: ios,
  );
}

ArchitectureSupport _decodeArch(Uint8List bytes) {
  var arm64 = false, arm = false, x64 = false, x86 = false;
  final r = PbReader(bytes);
  while (!r.isDone) {
    final f = r.readField();
    switch (f.number) {
      case 1:
        arm64 = f.asBool;
      case 2:
        arm = f.asBool;
      case 3:
        x64 = f.asBool;
      case 4:
        x86 = f.asBool;
    }
  }
  return ArchitectureSupport(arm64: arm64, arm: arm, x64: x64, x86: x86);
}

ModSetting _decodeSetting(Uint8List bytes) {
  var key = '', title = '', description = '';
  var type = ModSettingType.string;
  dynamic defaultValue;
  var min = 0, max = 0, step = 1;
  var unit = '×';
  final options = <ModSettingOption>[];
  var section = '';
  final r = PbReader(bytes);
  while (!r.isDone) {
    final f = r.readField();
    switch (f.number) {
      case 1:
        key = f.asString;
      case 2:
        title = f.asString;
      case 3:
        description = f.asString;
      case 4:
        final ordinal = f.asInt;
        if (ordinal >= 0 && ordinal < ModSettingType.values.length) {
          type = ModSettingType.values[ordinal];
        }
      case 5:
        defaultValue = _decodeJsonPrimitive(f.asString);
      case 6:
        min = f.asInt;
      case 7:
        max = f.asInt;
      case 8:
        step = f.asInt;
      case 9:
        unit = f.asString;
      case 10:
        options.add(_decodeSettingOption(f.asBytes));
      case 11:
        section = f.asString;
    }
  }
  return ModSetting(
    key: key,
    title: title,
    description: description,
    type: type,
    defaultValue: defaultValue,
    min: min,
    max: max,
    step: step == 0 ? 1 : step,
    unit: unit.isEmpty ? '×' : unit,
    options: options,
    section: section,
  );
}

ModSettingOption _decodeSettingOption(Uint8List bytes) {
  var value = '', label = '';
  final r = PbReader(bytes);
  while (!r.isDone) {
    final f = r.readField();
    switch (f.number) {
      case 1:
        value = f.asString;
      case 2:
        label = f.asString;
    }
  }
  return ModSettingOption(value: value, label: label);
}

// ---------------------------------------------------------------------------
// Resource packs
// ---------------------------------------------------------------------------

Uint8List encodeResourcePack(ResourcesPackItem item) {
  final w = PbWriter();
  w.writeString(1, item.name);
  w.writeString(2, item.author);
  w.writeString(3, item.description);
  w.writeString(4, item.version);
  w.writeString(5, item.fileName);
  w.writeString(6, item.iconPath);
  w.writeEnum(7, item.type.index);
  w.writeEnum(8, item.packType.index);
  return w.takeBytes();
}

ResourcesPackItem decodeResourcePack(Uint8List bytes) {
  var name = 'UNKNOWN', author = 'UNKNOWN', description = '';
  var version = '', fileName = '', iconPath = '';
  var type = PackOrigin.terraria;
  var packType = PackType.texture;
  final r = PbReader(bytes);
  while (!r.isDone) {
    final f = r.readField();
    switch (f.number) {
      case 1:
        name = f.asString;
      case 2:
        author = f.asString;
      case 3:
        description = f.asString;
      case 4:
        version = f.asString;
      case 5:
        fileName = f.asString;
      case 6:
        iconPath = f.asString;
      case 7:
        final ordinal = f.asInt;
        if (ordinal >= 0 && ordinal < PackOrigin.values.length) {
          type = PackOrigin.values[ordinal];
        }
      case 8:
        final ordinal = f.asInt;
        if (ordinal >= 0 && ordinal < PackType.values.length) {
          packType = PackType.values[ordinal];
        }
    }
  }
  return ResourcesPackItem(
    name: name,
    author: author,
    description: description,
    version: version,
    fileName: fileName,
    iconPath: iconPath,
    type: type,
    packType: packType,
  );
}
