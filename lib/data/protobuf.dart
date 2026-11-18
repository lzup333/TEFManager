import 'dart:convert';
import 'dart:typed_data';

/// Minimal protobuf wire-format writer/reader.
///
/// This intentionally implements only what the TEFManager metadata store uses:
/// varints, length-delimited fields and nested messages. Field numbers follow
/// the Kotlin `@Serializable` declaration order, which is what
/// `kotlinx.serialization.protobuf` uses.
class PbWriter {
  final BytesBuilder _out = BytesBuilder(copy: false);

  Uint8List takeBytes() => _out.takeBytes();

  void writeVarint(int value) {
    var v = value;
    while (v < 0 || v >= 0x80) {
      _out.addByte((v & 0x7f) | 0x80);
      v = v >>> 7;
    }
    _out.addByte(v);
  }

  void _tag(int field, int wire) => writeVarint((field << 3) | wire);

  void writeInt(int field, int value) {
    _tag(field, 0);
    writeVarint(value);
  }

  void writeBool(int field, bool value) {
    _tag(field, 0);
    writeVarint(value ? 1 : 0);
  }

  void writeEnum(int field, int ordinal) {
    _tag(field, 0);
    writeVarint(ordinal);
  }

  void writeString(int field, String value) {
    final bytes = Uint8List.fromList(utf8.encode(value));
    _tag(field, 2);
    writeVarint(bytes.length);
    _out.add(bytes);
  }

  void writeBytes(int field, List<int> bytes) {
    _tag(field, 2);
    writeVarint(bytes.length);
    _out.add(bytes);
  }

  void writeMessage(int field, PbWriter message) => writeBytes(field, message.takeBytes());
}

class PbField {
  const PbField(this.number, this.wireType, this.value);

  final int number;
  final int wireType;

  /// int for varint fields, Uint8List for length-delimited fields.
  final Object value;

  int get asInt => value as int;

  bool get asBool => (value as int) != 0;

  String get asString => utf8.decode(value as Uint8List);

  Uint8List get asBytes => value as Uint8List;
}

class PbReader {
  PbReader(this._data);

  final Uint8List _data;
  int _offset = 0;

  bool get isDone => _offset >= _data.length;

  int readVarint() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (_offset >= _data.length) {
        throw const FormatException('Truncated protobuf varint');
      }
      final byte = _data[_offset++];
      result |= (byte & 0x7f) << shift;
      if (byte < 0x80) break;
      shift += 7;
      if (shift > 63) throw const FormatException('Varint too long');
    }
    return result;
  }

  PbField readField() {
    final tag = readVarint();
    final number = tag >>> 3;
    final wire = tag & 0x7;
    switch (wire) {
      case 0:
        return PbField(number, wire, readVarint());
      case 1:
        _skip(8);
        return PbField(number, wire, Uint8List(0));
      case 2:
        final length = readVarint();
        if (length < 0 || _offset + length > _data.length) {
          throw const FormatException('Truncated protobuf bytes');
        }
        final bytes = Uint8List.sublistView(_data, _offset, _offset + length);
        _offset += length;
        return PbField(number, wire, bytes);
      case 5:
        _skip(4);
        return PbField(number, wire, Uint8List(0));
      default:
        throw FormatException('Unsupported protobuf wire type $wire');
    }
  }

  /// Returns null when the field is unknown so callers can skip it.
  int? peekFieldNumber() {
    if (isDone) return null;
    final saved = _offset;
    final tag = readVarint();
    _offset = saved;
    return tag >>> 3;
  }

  void skipField(PbField field) {
    // Length-delimited values are already consumed by [readField].
  }

  void _skip(int count) {
    if (_offset + count > _data.length) {
      throw const FormatException('Truncated protobuf field');
    }
    _offset += count;
  }
}
