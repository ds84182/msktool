library msk.pf.src.context;

import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:file/file.dart';
import 'package:charcode/ascii.dart';

import 'reader_writer.dart';
import 'id.dart';

class PFContext {
  final Directory dir;
  PFHeader header;

  PFContext(Directory dir)
      : dir = dir;

  String forceRelative(String path) =>
      p.isAbsolute(path) ? p.relative(path, from: p.rootPrefix(path)) : path;

  File file(String path) => dir.childFile(forceRelative(path));
  Directory directory(String path) => dir.childDirectory(forceRelative(path));

  Future open([String filename = "PFStatic.idx"]) async {
    final raf = await file(filename).open();
    header = await readPF(raf);
    await raf.close();
  }

  Future save([String filename = "PFStaticNew.idx"]) async {
    final raf = await file(filename).open(mode: FileMode.WRITE);
    await writePF(header, raf);
    await raf.close();
  }

  Stream<PFPackageHeader> list() =>
      new Stream.fromIterable(header.packageHeaders);

  PFPackageHeader findPackage(String packageName) => header.packageHeaders
      .firstWhere((pkg) => pkg.packageName == packageName, orElse: () => null);

  PFEntry findEntry(String packageName, id) {
    int intId = createId(id);

    return findPackage(packageName)
        ?.package
        ?.entries
        ?.firstWhere((entry) => entry.id == intId, orElse: () => null);
  }

  Iterable<PFEntry> findAllEntries(id) {
    int intId = createId(id);

    return header.packageHeaders
        .expand((x) => x.package.entries.where((entry) => entry.id == intId));
  }

  File findFile(PFPackageHeader packageHeader) {
    return file(
        "${packageHeader.packagePath}/${packageHeader.packageName}.package");
  }

  Stream<List<int>> readEntry(PFEntry entry) {
    if (entry is PFCompressedEntry) {
      throw "Don't know how to read a compressed entry";
    }

    return findFile(entry.package.packageHeader)
        .openRead(entry.fileOffset, entry.fileOffset + entry.size);
  }

  FileOffsetPair getEntryOffset(PFEntry entry) {
    return new FileOffsetPair(
      file: findFile(entry.package.packageHeader),
      offset: entry.fileOffset,
    );
  }

  Future patchEntry(
      PFEntry entry, int length, Stream<List<int>> dataStream) async {
    if (entry is PFCompressedEntry) {
      throw "Don't know how to write a compressed entry";
    }

    final file = findFile(entry.package.packageHeader);
    final raf = await file.open(mode: FileMode.WRITE_ONLY_APPEND);

    final offset = await raf.length();
    await raf.setPosition(offset);

    await for (final data in dataStream) {
      await raf.writeFrom(data);
    }

    entry.size = length;
    entry.fileOffset = offset;
  }

  void addEntry(PFEntry entry) {
    // Wire up all the fields from PFEntry to their targets
    int placementOffset = 0;
    for (final type in entry.package.types) {
      placementOffset += type.count;
      if (type == entry.type) break;
    }
    entry.package.entries.insert(placementOffset, entry);
    entry.type.count += 1;
    entry.package.count += 1;

    fix();
  }

  void fix() {
    header.packageHeaders.forEach((ph) {
      Map<PFType, List<PFEntry>> typeEntryGroups = {};
      for (final type in ph.package.types) {
        typeEntryGroups[type] = ph.package.entries.where((entry) => entry.type == type).toList();
      }

      ph.package.entries = ph.package.types.expand((type) => typeEntryGroups[type]).toList();
    });
  }

  dynamic handlePath(List<String> split) {
    if (split.length == 1) {
      // Root
      return header;
    } else if (split.length == 2) {
      // Package
      return findPackage(split[1]);
    } else if (split.length == 3) {
      // Type
      final package = findPackage(split[1]);
      final type =
          package.package.types.firstWhere((type) => type.name == split[2]);
      return type;
    } else if (split.length == 4) {
      // Entry
      final package = findPackage(split[1]);
      final type =
          package.package.types.firstWhere((type) => type.name == split[2]);
      final id = createId(split[3]);

      return package.package.entries.firstWhere(
          (entry) => entry.type == type && entry.id == id,
          orElse: () => null);
    } else {
      return null;
    }
  }

  static int createId(id) {
    int intId;

    if (id is String) {
      if (id.length == 16 && id.toUpperCase().codeUnits.every((cu) => (cu >= $0 && cu <= $9) || (cu >= $A && cu <= $F))) {
        intId = int.parse(id, radix: 16);
      } else {
        intId = computeId(id.codeUnits);
      }
    } else {
      intId = id;
    }

    return intId;
  }

  static Iterable<dynamic> listFrom(dynamic data) {
    if (data is PFHeader) {
      // List packages
      return data.packageHeaders;
    } else if (data is PFPackageHeader) {
      // List types
      return data.package.types;
    } else if (data is PFType) {
      // List entries
      return data.package.entries.where((entry) => entry.type == data);
    } else {
      return null;
    }
  }

  static Iterable<String> makePath(dynamic data) sync* {
    if (data is PFEntry) {
      yield* makePath(data.type);
      yield data.name;
    } else if (data is PFType) {
      yield* makePath(data.package);
      yield data.name;
    } else if (data is PFPackage) {
      yield data.packageHeader.packageName;
    }
  }
}

class FileOffsetPair {
  final File file;
  final int offset;
  const FileOffsetPair({this.file, this.offset});
}
