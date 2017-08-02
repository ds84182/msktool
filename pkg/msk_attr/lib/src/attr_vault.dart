library msk.attr.src.attr_valt;

import 'dart:async';
import 'dart:typed_data';
import 'package:file/file.dart';
import 'package:msk_attr/msk_attr.dart';
import 'package:msk_util/msk_util.dart';

class AttrVaultHeader extends ByteSerializable {
  int one;
  List<int> magic;
  int version;
  int unknown1;
  int numClasses;
  int numTypes;

  @override
  void read(ByteData data) {
    one = read32BE(data, 0);
    magic = data.buffer.asUint8List(4, 4);
    version = read32BE(data, 8);
    unknown1 = read32BE(data, 12);
    numClasses = read32BE(data, 16);
    numTypes = read32BE(data, 20);
  }

  @override
  int get serializeSize => 24;

  @override
  void write(ByteData data) {
    write32BE(data, 0, one);
    data.buffer.asUint8List(4, 4).setRange(4, 8, magic);
    write32BE(data, 8, version);
    write32BE(data, 12, unknown1);
    write32BE(data, 16, numClasses);
    write32BE(data, 20, numTypes);
  }
}

class AttrVaultType extends ByteSerializable {
  int id;
  int size;
  int unknown1;
  int unknown2;
  int unknown3;
  int unknown4;
  int unknown5;

  @override
  void read(ByteData data) {
    id = read32BE(data, 0);
    size = read16BE(data, 4);
    unknown1 = read16BE(data, 6);
    unknown2 = read32BE(data, 8);
    unknown3 = read32BE(data, 12);
    unknown4 = read32BE(data, 16);
    unknown5 = read32BE(data, 20);
  }

  @override
  int get serializeSize => 24;

  @override
  void write(ByteData data) {
    write32BE(data, 0, id);
    write16BE(data, 4, size);
    write16BE(data, 6, unknown1);
    write32BE(data, 8, unknown2);
    write32BE(data, 12, unknown3);
    write32BE(data, 16, unknown4);
    write32BE(data, 20, unknown5);
  }
}

Future readAttrVault(AttrContext context, RandomAccessFile file) async {
  final header =
      await ByteSerializable.readFromFile(new AttrVaultHeader(), file);
  await file.read(16); // Skip 16 bytes

  final types = new List.generate(header.numTypes, (_) => new AttrVaultType());
  for (final type in types) {
    await ByteSerializable.readFromFile(type, file);
  }

  // Inflate to AttrContext:
  types.forEach((type) {
    context.lookupOrCreateType(
        // type.id.toRadixString(16).padLeft(8, '0').toUpperCase(),
        type.id,
        type.size);
  });

   // TODO: Classes
}
