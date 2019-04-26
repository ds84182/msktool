library msk.attr.src.attr_bin;

import 'dart:async';
import 'dart:typed_data';
import 'package:file/file.dart';
import 'package:msk_attr/msk_attr.dart';
import 'package:msk_attr/src/attr_id_hash.dart';
import 'package:msk_util/msk_util.dart';

class AttrBinHeader extends ByteSerializable {
  int one;
  List<int> magic;
  int version;
  int numCollections;
  int strTableSize;
  int numStrTable;

  @override
  void read(ByteData data) {
    one = read32BE(data, 0);
    magic = data.buffer.asUint8List(4, 4);
    version = read32BE(data, 8);
    numCollections = read32BE(data, 12);
    strTableSize = read32BE(data, 16);
    // 12 bytes of padding!
    numStrTable = read32BE(data, 20 + 12);
  }

  @override
  int get serializeSize => 20 + 12 + 4;

  @override
  void write(ByteData data) {
//    write32BE(data, 0, one);
//    data.buffer.asUint8List(4, 4).setRange(4, 8, magic);
//    write32BE(data, 8, version);
//    write32BE(data, 12, unknown1);
  }
}

class AttrBinCollectionHeader extends ByteSerializable {
  int id;
  int type; // MAYBE? 0xC702C0AF
  int clazz;
  int parent;

  int unknown1; // 0x2001
  int unknown2; // 0xFFFFFFFF_FFFFFFFF

  int fieldCount; // 0x0003 (also duplicated)
  int totalFieldCount;
  int staticBlobSize;
  int totalBlobSize; // 0x0033 (also duplicated)

  int get serializeSize => 4 + 4 + 4 + 4 + 4 + 8 + 4 + 4;

  @override
  void read(ByteData data) {
    id = read32BE(data, 0);
    type = read32BE(data, 4);
    clazz = read32BE(data, 8);
    parent = read32BE(data, 12);

//    print(id.toRadixString(16).padLeft(8, '0'));
//    print(type.toRadixString(16).padLeft(8, '0'));
//    print(clazz.toRadixString(16).padLeft(8, '0'));
//    print(parent.toRadixString(16).padLeft(8, '0'));

    unknown1 = read16BE(data, 16);
    // assert(read16BE(data, 18) == 0x0000);
    unknown2 = read64BE(data, 20);

    fieldCount = read16BE(data, 28);
    totalFieldCount = read16BE(data, 30);
    // print(fieldCount);
    // print(totalFieldCount);
    // assert(fieldCount == read16BE(data, 30));
//    collectionBlobSize = read16BE(data, 32);
//    print(collectionBlobSize);
//    assert(collectionBlobSize == read16BE(data, 34));
    staticBlobSize = read16BE(data, 32);
    totalBlobSize = read16BE(data, 34);
    //print(read16BE(data, 32));
    //print(collectionBlobSize);
  }

  @override
  void write(ByteData data) {
    throw "TODO: Implement";
  }
}

class AttrBinCollectionField extends ByteSerializable {
  int id;
  int data;

  int get serializeSize => 4 + 4;

  @override
  void read(ByteData data) {
    id = read32BE(data, 0);
    this.data = read32BE(data, 4);
  }

  @override
  void write(ByteData data) {
    throw "TODO: Implement";
  }
}

class AttrBinString extends ByteSerializable {
  int hash;
  int offset;
  String data;

  int get serializeSize => 4 + 4;

  @override
  void read(ByteData data) {
    hash = read32BE(data, 0);
    offset = read32BE(data, 4);
  }

  @override
  void write(ByteData data) {
    throw "TODO: Implement";
  }
}

const _kAttrBinDebug = false;

Future readAttrBin(AttrContext context, RandomAccessFile file) async {
  final fileData =
      new Uint8List.fromList(await file.read(await file.length())).buffer;
  int fileOffset = 0;

  final header = ByteSerializable.readFromBuffer(
      new AttrBinHeader(), fileData, fileOffset);
  fileOffset += header.serializeSize;
  fileOffset += 288; // Skip padding.

  String lookupName(int hash) => context.lookupName(hash) ?? intToHex(hash);

  for (int i = 0; i < header.numCollections; i++) {
    final collectionHeader = await ByteSerializable.readFromBuffer(
        new AttrBinCollectionHeader(), fileData, fileOffset);

    if (_kAttrBinDebug) {
      print("");
      print("Collection: ${lookupName(collectionHeader.clazz)}:${lookupName(
          collectionHeader.id)}");
      print("  Header: ");
      tohex(fileData.asUint8List(fileOffset, collectionHeader.serializeSize))
          .map(indent(4))
          .forEach(print);
    }

    fileOffset += collectionHeader.serializeSize;

    var collection =
        context.lookupCollection(collectionHeader.clazz, collectionHeader.id);

    if (collection == null) {
      collection = new AttrCollection(
        classId: collectionHeader.clazz,
        id: collectionHeader.id,
      );
      context.addCollectionsToClass(collectionHeader.clazz, [collection]);
    }

    collection.parent = collectionHeader.parent;

    final fieldData =
        new List<AttrBinCollectionField>(collectionHeader.fieldCount);

    for (int i = 0; i < collectionHeader.fieldCount; i++) {
      final field = fieldData[i] = ByteSerializable.readFromBuffer(
          new AttrBinCollectionField(), fileData, fileOffset + i * 8);

      final fieldStuff =
          context.lookupClassField(collectionHeader.clazz, field.id);

      if (_kAttrBinDebug) {
        print("  Field: "
            "${lookupName(field.id).padRight(24)}\t"
            "${intToHex(field.data)}\t"
            "${lookupName(fieldStuff?.type?.id ?? 0).padRight(16)}\t"
            "${fieldStuff?.flags}");
      }
    }

    fileOffset += 8 * collectionHeader.totalFieldCount;

    // Create a copy of the collection data so we don't keep the attribute bin's data in memory
    final data = new Uint8List.fromList(
        fileData.asUint8List(fileOffset, collectionHeader.totalBlobSize));
    final byteData = data.buffer.asByteData();

    if (_kAttrBinDebug) {
      print("  Data: ");
      tohex(data).map(indent(4)).forEach(print);
    }

    collection.preallocateFields(fieldData.length);
    fieldData.forEach((fieldData) {
      collection.addField(new AttrCollectionField(
        id: fieldData.id,
        inlineData: fieldData.data,
        staticDataLength: collectionHeader.staticBlobSize,
        data: byteData,
      ));
    });

    fileOffset += collectionHeader.totalBlobSize;
  }

  // Read string table
  final strTable = new List<AttrBinString>(header.numStrTable);
  for (int i = 0; i < header.numStrTable; i++) {
    strTable[i] = ByteSerializable.readFromBuffer(
        new AttrBinString(), fileData, fileOffset);
    fileOffset += 8;
  }

  // Read string data
  final strData = fileData.asUint8List(fileOffset, header.strTableSize);
  fileOffset += header.strTableSize;
  String readZTS(int offset) {
    return new String.fromCharCodes(
        strData.getRange(offset, strData.indexOf(0, offset)));
  }

  strTable.forEach((s) {
    s.data = readZTS(s.offset);
    context.addStringTableEntry(s.hash, s.data);
  });

  final maxNFA = <int, int>{};

  context.classes.forEach((clazz) {
    final nfaSet = new Set<AttrField>.from(context.lookupClassFields(clazz.id).where((field) => field.flags.contains(AttrFlag.array) &&
        !field.flags.contains(AttrFlag.fixedArray)));

    if (nfaSet.isNotEmpty) {
      nfaSet.forEach((field) {
        maxNFA.putIfAbsent(field.id, () => 0);
      });

      context.lookupCollections(clazz.id).forEach((collection) {
        collection.fields.where((field) => maxNFA.containsKey(field.id)).forEach((field) {
          final value = maxNFA[field.id];
          final size = field.inlineData >> 16;
          if (size > value) {
            maxNFA[field.id] = size;
          }
        });
      });
    }
  });

  final maxLength = maxNFA.values.reduce((a, b) => a > b ? a : b);

  maxNFA.keys.forEach((id) {
    final base = context.lookupName(id);
    for (int i=0; i<maxLength; i++) {
      context.addName(base + formatArrayIndex(i), attrIdArrayIndex(id, i));
    }
  });

  if (_kAttrBinDebug) {
    context.classes.forEach((clazz) {
      int nonFixedArrayCount = 0;
      Set<int> nfaSet = new Set();
      context.lookupClassFields(clazz.id).forEach((field) {
        if (field.flags.contains(AttrFlag.array) &&
            !field.flags.contains(AttrFlag.fixedArray)) {
          nonFixedArrayCount++;
          nfaSet.add(field.id);
        }
      });
      if (nonFixedArrayCount > 0) {
        print("NFAC: $nonFixedArrayCount ${context.lookupName(clazz.id)}");
      }

      context.lookupCollections(clazz.id).forEach((collection) {
        int nfac = collection.fields.where((f) => nfaSet.contains(f.id)).length;
        if (nfac > 1) {
          print("NFAC Col: $nfac ${context.lookupName(clazz.id)}:${context
              .lookupName(collection.id)}");
          final list = collection.fields
              .where((f) => nfaSet.contains(f.id))
              .map((f) => context.lookupName(f.id))
              .join(", ");
          print(list);
        }
      });
    });
  }

  context.finalize();
}

String intToHex(int value, [int length = 4]) =>
    value.toRadixString(16).padLeft(length * 2, "0");

Iterable<String> tohex(data) sync* {
  if (data is List<int>) {
    final iter = data.map((e) => e.toRadixString(16).padLeft(2, '0')).iterator;

    final immediateBuffer = new List<String>(16);

    do {
      int taken = 0;
      while (taken < 16 && iter.moveNext()) {
        immediateBuffer[taken] = iter.current;
        taken++;
      }
      if (taken == 0) break;
      yield immediateBuffer.take(taken).join(" ");
    } while (true);
  } else if (data is ByteBuffer) {
    yield* tohex(data.asUint8List());
  } else if (data is ByteData) {
    yield* tohex(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  } else {
    yield data;
  }
}

String Function(String data) indent(int level) {
  final ident = " " * level;
  return (data) => "$ident$data";
}
