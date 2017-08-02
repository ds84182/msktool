import 'dart:async';
import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:msk_pf/src/defs.dart';
import 'package:msk_util/msk_util.dart';

class PFHeader extends ByteSerializable {
  List<PFPackageHeader> packageHeaders;
  List<PFPackage> packages;

  List<int> magic;
  int versionMajor, versionMinor;
  int count;

  int get serializeSize => 4 + 2 + 2 + 4;

  void read(ByteData data) {
    magic = data.buffer.asUint8List(0, 4);
    versionMajor = read16BE(data, 4);
    versionMinor = read16BE(data, 6);
    count = read32BE(data, 8);
  }

  void write(ByteData data) {
    data.buffer.asUint8List(0, 4).setRange(0, 4, magic);
    write16BE(data, 4, versionMajor);
    write16BE(data, 6, versionMinor);
    write32BE(data, 8, count);
  }
}

class PFPackageHeader extends ByteSerializable {
  PFHeader header;
  PFPackage package;
  String packageName;
  String packagePath;

  int id, bodySize, flags;

  int get serializeSize => 4 + 4 + 4;

  void read(ByteData data) {
    id = read32BE(data, 0);
    bodySize = read32BE(data, 4);
    flags = read32BE(data, 8);
  }

  void write(ByteData data) {
    write32BE(data, 0, id);
    write32BE(data, 4, bodySize);
    write32BE(data, 8, flags);
  }
}

class PFPackage extends ByteSerializable {
  PFHeader header;
  PFPackageHeader packageHeader;
  List<PFType> types;
  List<PFEntry> entries;

  int unknown1;
  int count, typeCount;

  int get serializeSize => 4 + 4 + 4;

  void read(ByteData data) {
    unknown1 = read32BE(data, 0);
    count = read32BE(data, 4);
    typeCount = read32BE(data, 8);
  }

  void write(ByteData data) {
    write32BE(data, 0, unknown1);
    write32BE(data, 4, count);
    write32BE(data, 8, typeCount);
  }
}

class PFType extends ByteSerializable {
  PFPackage package;

  int id, entryFormat, count;
  int unknown2;

  String get name {
    return kTypeDefs[id] ?? id.toRadixString(16).toUpperCase().padLeft(8, '0');
  }

  int get serializeSize => 4 + 4 + 4 + 4;

  void read(ByteData data) {
    id = read32BE(data, 0);
    entryFormat = read32BE(data, 4);
    count = read32BE(data, 8);
    unknown2 = read32BE(data, 12);
  }

  void write(ByteData data) {
    write32BE(data, 0, id);
    write32BE(data, 4, entryFormat);
    write32BE(data, 8, count);
    write32BE(data, 12, unknown2);
  }
}

class PFEntry extends ByteSerializable {
  PFPackage package;
  PFType type;

  int id;
  int fileOffset;
  int size;

  String get name {
    return kFileDefs[id] ?? id.toRadixString(16).toUpperCase().padLeft(16, '0');
  }

  int get serializeSize => 8 + 4 + 4;

  void read(ByteData data) {
    id = read64BE(data, 0);
    fileOffset = read32BE(data, 8);
    size = read32BE(data, 12);
  }

  void write(ByteData data) {
    write64BE(data, 0, id);
    write32BE(data, 8, fileOffset);
    write32BE(data, 12, size);
  }
}

class PFCompressedEntry extends PFEntry {
  int compressedSize;

  @override
  int get serializeSize => super.serializeSize + 4;

  @override
  void read(ByteData data) {
    super.read(data);
    compressedSize = size;
    size = read32BE(data, 16);
  }

  @override
  void write(ByteData data) {
    super.write(data);
    write32BE(data, 12, compressedSize);
    write32BE(data, 16, size);
  }
}

Future<PFHeader> readPF(RandomAccessFile file) async {
  // print("Reading PFStatic...");

  var header = await ByteSerializable.readFromFile(new PFHeader(), file);
  // print("Read header");

  Future<PFPackageHeader> readPackage() async {
    var pkgHeader =
        await ByteSerializable.readFromFile(new PFPackageHeader(), file);
    // print("Read package header");
    pkgHeader.header = header;
    var pkg = await ByteSerializable.readFromFile(new PFPackage(), file);
    // print("Read package");
    pkg.header = header;

    pkg.packageHeader = pkgHeader;
    pkgHeader.package = pkg;

    pkg.types = [];

    // Load all bytes for type data...

    final typeBytes = new Uint8List(16 * pkg.typeCount);
    await file.readInto(typeBytes);

    pkg.types = new List.generate(
      pkg.typeCount,
      (i) => new PFType()
        ..read(typeBytes.buffer.asByteData(i * 16))
        ..package = pkg,
    );
    // print("Read types");

    pkg.entries = await () async* {
      for (final type in pkg.types) {
        final entrySize = type.entryFormat == 0 ? 16 : 20;
        final entryData = new Uint8List(entrySize * type.count);
        await file.readInto(entryData);

        PFEntry entry;
        for (int i = 0; i < type.count; i++) {
          if (type.entryFormat == 0) {
            entry = new PFEntry();
          } else if (type.entryFormat == 2) {
            entry = new PFCompressedEntry();
          } else {
            throw "Unknown entry format ${type.entryFormat}";
          }

          entry.read(entryData.buffer.asByteData(i * entrySize));

          entry.type = type;
          entry.package = pkg;

          yield entry;
        }
      }
    }()
        .toList();
    // print("Read entries");

    return pkgHeader;
  }

  header.packageHeaders = [];

  await Future.forEach<PFPackageHeader>(
    new Iterable.generate(header.count),
    (_) async => header.packageHeaders.add(await readPackage()),
  );

  header.packages =
      header.packageHeaders.map((ph) => ph.package).toList(growable: false);

  // print("Read packages");

  // Skip string count and string table size
  await file.read(8);

  Uint8List readStringTemp = new Uint8List(2);
  ByteData readStringTempBD = readStringTemp.buffer.asByteData();
  Future<String> readString() async {
    final buffer = new StringBuffer();
    while (true) {
      await file.readInto(readStringTemp);
      var char = readStringTempBD.getUint16(0, BE);
      if (char == 0) break;
      buffer.writeCharCode(char);
    }
    return buffer.toString();
  }

  await Future.forEach(header.packageHeaders, (pkgHeader) async {
    pkgHeader.packageName = await readString();
    pkgHeader.packagePath = await readString();
  });
  // print("Read package names");

  return header;
}

Future writePF(PFHeader header, RandomAccessFile file) async {
  header.count = header.packageHeaders.length;

  await ByteSerializable.writeToFile(header, file);

  Future writePackage(PFPackageHeader pkgHeader) async {
    final pkg = pkgHeader.package;

    pkgHeader.bodySize = pkg.serializeSize +
        pkg.types.fold(0, (a, b) => a + b.serializeSize) +
        pkg.entries.fold(0, (a, b) => a + b.serializeSize);

    await ByteSerializable.writeToFile(pkgHeader, file);

    pkg.typeCount = pkg.types.length;
    pkg.count = pkg.entries.length;

    final body = new Uint8List(pkgHeader.bodySize);
    pkg.write(body.buffer.asByteData());

    int offset = pkg.serializeSize;

    [pkg.types, pkg.entries].expand((x) => x).forEach((element) {
      element.write(body.buffer.asByteData(offset));
      offset += element.serializeSize;
    });

    await file.writeFrom(body);
  }

  await Future.forEach(header.packageHeaders, writePackage);

  final strings = header.packageHeaders
      .expand((package) => [package.packageName, package.packagePath])
      .toList();
  final stringsLength = strings.fold(0, (a, b) => a + b.length + 1);

  final byteData = new ByteData(8);
  write32BE(byteData, 0, strings.length ~/ 2);
  write32BE(byteData, 4, stringsLength * 2);

  await file.writeFrom(byteData.buffer.asUint8List());

  final stringData = new ByteData(stringsLength * 2);
  final stringCodePoints = new Uint16List.fromList(() sync* {
    for (final str in strings) {
      yield* str.codeUnits;
      yield 0;
    }
  }()
      .toList());

  for (int i = 0; i < stringCodePoints.length; i++) {
    write16BE(stringData, i * 2, stringCodePoints[i]);
  }

  await file.writeFrom(stringData.buffer.asUint8List());

  await file.flush();
}
