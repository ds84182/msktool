import 'dart:typed_data';
import 'package:hkxread/src/parser.dart';

class ByteDataStreamImpl extends DataStream {
  final ByteData data;

  int offset = 0;

  ByteDataStreamImpl(this.data);

  int get size => data.lengthInBytes;

  void goto(int offset) {
    this.offset = offset;
  }

  void skipBytes(int count) {
    offset += count;
  }

  int _advance(int count) {
    final old = offset;
    skipBytes(count);
    return old;
  }

  Uint8List uint8list(int length) =>
      data.buffer.asUint8List(_advance(length), length);

  Uint8List uint8listUntil(bool predicate(int byte),
      {bool includeTerminator: false}) {
    int start = offset;
    while (!predicate(data.getUint8(offset))) {
      offset++;
    }
    final list = data.buffer
        .asUint8List(start, offset - start + (includeTerminator ? 1 : 0));
    offset++;
    return list;
  }

  int uint8() => data.getUint8(_advance(1));
  int uint16() => data.getUint16(_advance(2));
  int uint32() => data.getUint32(_advance(4));
  int uint64() => data.getUint64(_advance(8));

  double float32() => data.getFloat32(_advance(4));
  double float64() => data.getFloat64(_advance(8));
}
