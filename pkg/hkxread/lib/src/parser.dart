library hkxread.src.parser;

import 'dart:typed_data';
import 'dart:convert' show ASCII;
import 'package:hkxread/src/data_stream/byte_data.dart';
import 'package:meta/meta.dart';

String _toHex(int i, int bits) => i.toRadixString(16).padLeft(bits ~/ 8, '0');

abstract class DataStream {
  DataStream();

  factory DataStream.fromTypedData(TypedData data) =>
      new ByteDataStreamImpl(data.buffer.asByteData());

  int get offset;
  int get size;

  void reset() => goto(0);

  void goto(int offset);
  void skipBytes(int count);
  bool offsetIsBefore(int absoluteOffset) => offset < absoluteOffset;

  void magic8(int expected, {String errorMessage: "Invalid magic"}) {
    final read = uint8();
    if (read != expected)
      throw new FormatException(
          "$errorMessage, expected ${_toHex(expected, 8)} "
          "got ${_toHex(read, 8)}");
  }

  void magic32(int expected, {String errorMessage: "Invalid magic"}) {
    final read = uint32();
    if (read != expected)
      throw new FormatException(
          "$errorMessage, expected ${_toHex(expected, 32)} "
          "got ${_toHex(read, 32)}");
  }

  void magic32List(List<int> expectedList,
      {String errorMessage: "Invalid magic"}) {
    for (int i = 0; i < expectedList.length; i++) {
      final expected = expectedList[i];
      final read = uint32();
      if (read != expected)
        throw new FormatException(
            "$errorMessage, expected ${_toHex(expected, 32)} at index $i "
            "got ${_toHex(read, 32)}");
    }
  }

  Uint8List uint8list(int length);
  Uint8List uint8listUntil(bool predicate(int byte),
      {bool includeTerminator: false});
  Uint8List zeroTerminatedUint8List({bool includeTerminator: false}) =>
      uint8listUntil((byte) => byte == 0, includeTerminator: includeTerminator);

  int uint8();
  int uint16();
  int uint32();
  int uint64();

  double float32();
  double float64();

  T doAtomic<T>(T func()) {
    final old = offset;

    try {
      return func();
    } catch (any) {
      goto(old);
      rethrow;
    }
  }

  T parse<T>(Parser<T> parser) => doAtomic(() => parser.read(this));
  void skip(Parser parser) => doAtomic(() => parser.skip(this));
}

class DataStreamUtils {
  const DataStreamUtils._();

  static String convertZeroTerminatedString(Uint8List bytes) {
    int zeroIndex = bytes.indexOf(0);
    if (zeroIndex == -1) zeroIndex = bytes.length;
    return ASCII.decoder.convert(bytes, 0, zeroIndex);
  }
}

@immutable
abstract class Parser<T> {
  const Parser();

  /// Reads an object of type [T] from the given [DataStream].
  T read(DataStream data);

  /// Skips this type of object in the given [DataStream], which may require
  /// reads (if the object is dynamically sized).
  ///
  /// By default this is implemented by reading the object from the [DataStream]
  /// and discarding it, but you can provide a more efficient method using the
  /// [EfficientLengthParser] class.
  void skip(DataStream data) {
    // Inefficient skip implementation, provide your own if needed.
    read(data);
  }
}

abstract class EfficientLengthParser<T> extends Parser<T> {
  const EfficientLengthParser();

  /// Returns the size of the object in bytes
  int get size;

  @override
  void skip(DataStream data) {
    data.skipBytes(size);
  }
}
