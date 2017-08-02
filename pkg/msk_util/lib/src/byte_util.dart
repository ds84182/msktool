import 'dart:async';
import 'dart:typed_data';

import 'package:file/file.dart';

const BE = Endianness.BIG_ENDIAN;
const LE = Endianness.LITTLE_ENDIAN;

int read16BE(ByteData data, int offset) {
  return data.getUint16(offset, BE);
}

int read32BE(ByteData data, int offset) {
  return data.getUint32(offset, BE);
}

int read64BE(ByteData data, int offset) {
  return data.getUint64(offset, BE);
}

void write16BE(ByteData data, int offset, int value) {
  data.setUint16(offset, value, BE);
}

void write32BE(ByteData data, int offset, int value) {
  data.setUint32(offset, value, BE);
}

void write64BE(ByteData data, int offset, int value) {
  data.setUint64(offset, value, BE);
}

abstract class ByteSerializable {
  int get serializeSize;
  void read(ByteData data);
  void write(ByteData data);

  static Future<T> readFromFile<T extends ByteSerializable>(
      T t, RandomAccessFile file) async {
    var buffer = new Uint8List(t.serializeSize);
    await file.readInto(buffer);
    t.read(buffer.buffer.asByteData());
    return t;
  }

  static T readFromBuffer<T extends ByteSerializable>(T t, ByteBuffer buffer, int offset) {
    t.read(buffer.asByteData(offset));
    return t;
  }

  static Future writeToFile<T extends ByteSerializable>(
      T t, RandomAccessFile file) {
    var buffer = new Uint8List(t.serializeSize);
    t.write(buffer.buffer.asByteData());
    return file.writeFrom(buffer);
  }
}
