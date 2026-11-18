import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'protobuf.dart';

/// Reader/writer compatible with the Kotlin `LightProtoStore`.
///
/// On disk a database consists of:
///   db/data.bin   int32be length + protobuf payload, repeated
///   db/index.bin  int32be keyLen + key + int32be pointerLen + protobuf
///   db/meta.bin   protobuf DatabaseMetadata
///
/// Records are read by scanning data.bin (the payload starts with the item's
/// `pkgId`, so no index lookup is needed). Writing rebuilds all three files so
/// the official manager can open the same directory afterwards.
class LightStore<T> {
  LightStore({
    required this.directory,
    required this.encode,
    required this.decode,
    required this.keyOf,
  });

  final Directory directory;
  final Uint8List Function(T value) encode;
  final T Function(Uint8List bytes) decode;
  final String Function(T value) keyOf;

  File get _dataFile => File('${directory.path}/data.bin');
  File get _indexFile => File('${directory.path}/index.bin');
  File get _metaFile => File('${directory.path}/meta.bin');

  Future<List<T>> readAll() async {
    if (!await _dataFile.exists()) return <T>[];
    final data = await _dataFile.readAsBytes();
    final out = <T>[];
    var offset = 0;
    while (offset + 4 <= data.length) {
      final length = _readInt32Be(data, offset);
      offset += 4;
      if (length < 0 || offset + length > data.length) break;
      try {
        out.add(decode(Uint8List.sublistView(data, offset, offset + length)));
      } catch (_) {
        // Skip a corrupt record instead of dropping the whole database.
      }
      offset += length;
    }
    return out;
  }

  Future<void> writeAll(Iterable<T> values) async {
    await directory.create(recursive: true);

    final unique = <String, T>{};
    for (final value in values) {
      unique[keyOf(value)] = value;
    }

    final data = BytesBuilder(copy: false);
    final pointers = <String, _Pointer>{};
    var offset = 0;
    for (final entry in unique.entries) {
      final bytes = encode(entry.value);
      final header = ByteData(4)..setUint32(0, bytes.length, Endian.big);
      data.add(header.buffer.asUint8List());
      data.add(bytes);
      pointers[entry.key] = _Pointer(offset, bytes.length);
      offset += 4 + bytes.length;
    }

    final dataBytes = data.takeBytes();
    await _writeAtomic(_dataFile, dataBytes);

    final index = BytesBuilder(copy: false);
    for (final entry in pointers.entries) {
      final keyBytes = Uint8List.fromList(utf8.encode(entry.key));
      final pointerBytes = _encodePointer(entry.value);
      final keyHeader = ByteData(4)..setUint32(0, keyBytes.length, Endian.big);
      final pointerHeader = ByteData(4)
        ..setUint32(0, pointerBytes.length, Endian.big);
      index
        ..add(keyHeader.buffer.asUint8List())
        ..add(keyBytes)
        ..add(pointerHeader.buffer.asUint8List())
        ..add(pointerBytes);
    }
    final indexBytes = index.takeBytes();
    await _writeAtomic(_indexFile, indexBytes);

    await _writeAtomic(
      _metaFile,
      _encodeMetadata(
        totalRecords: unique.length,
        dataFileSize: dataBytes.length,
        indexFileSize: indexBytes.length,
        indexEntries: pointers.length,
      ),
    );
  }

  Future<void> _writeAtomic(File target, Uint8List bytes) async {
    final temp = File('${target.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    if (await target.exists()) await target.delete();
    await temp.rename(target.path);
  }
}

class _Pointer {
  const _Pointer(this.offset, this.length);

  final int offset;
  final int length;
}

Uint8List _encodePointer(_Pointer pointer) {
  final w = PbWriter();
  w.writeInt(1, pointer.offset);
  w.writeInt(2, pointer.length);
  return w.takeBytes();
}

Uint8List _encodeMetadata({
  required int totalRecords,
  required int dataFileSize,
  required int indexFileSize,
  required int indexEntries,
}) {
  final w = PbWriter();
  w.writeInt(1, totalRecords);
  w.writeInt(2, 1); // version
  w.writeInt(3, DateTime.now().millisecondsSinceEpoch);
  w.writeInt(4, dataFileSize);
  w.writeInt(5, indexFileSize);
  w.writeInt(6, indexEntries);
  return w.takeBytes();
}

int _readInt32Be(Uint8List data, int offset) {
  return ByteData.sublistView(data, offset, offset + 4).getInt32(0, Endian.big);
}

/// `enables.txt`: one package id per line, newline terminated.
class EnableList {
  EnableList(this.file);

  final File file;

  Future<Set<String>> read() async {
    if (!await file.exists()) return <String>{};
    final content = await file.readAsString();
    return content
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toSet();
  }

  Future<void> enable(String pkgId) async {
    final current = await read();
    if (current.contains(pkgId)) return;
    await file.parent.create(recursive: true);
    await file.writeAsString('$pkgId\n',
        mode: FileMode.append, flush: true);
  }

  Future<void> disable(String pkgId) async {
    final current = await read();
    if (!current.remove(pkgId)) return;
    await _write(current);
  }

  Future<void> replace(Iterable<String> ids) => _write(ids.toSet());

  Future<void> _write(Set<String> ids) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    final buffer = StringBuffer();
    for (final id in ids) {
      if (id.trim().isEmpty) continue;
      buffer.writeln(id.trim());
    }
    await temp.writeAsString(buffer.toString(), flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }
}
