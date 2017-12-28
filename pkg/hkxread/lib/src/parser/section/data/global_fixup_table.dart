/// The global fixup table is a table of file offsets (pointing inside an
/// object or array) to other objects.
///
/// This links objects together.
///
/// Arrays use the local fixup table.
library hkxread.src.parser.section.data.global_fixup_table;

import 'dart:typed_data';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/parser/section_header.dart';

class GlobalFixupTableParser extends EfficientLengthParser<GlobalFixupTable> {
  final SectionHeader dataSection;

  const GlobalFixupTableParser(this.dataSection);

  @override
  GlobalFixupTable read(DataStream data) {
    data.goto(dataSection.data2Offset);
    print(dataSection.data2Offset.toRadixString(16));

    final table = new GlobalFixupTable(dataSection);

    GlobalFixup readEntry() {
      final entry = new GlobalFixup();
      entry.relocOffset = data.uint32();

      if (entry.relocOffset == 0xFFFFFFFF) {
        data.skipBytes(-4);
        return null;
      }

      data.magic32(1, errorMessage: "Invalid entry magic"); // unknown, always 1
      entry.objectOffset = data.uint32();
      return entry;
    }

    while (data.offsetIsBefore(dataSection.data4Offset)) {
      final entry = readEntry();
      if (entry == null) break;
      table.addEntry(entry);
    }

    // Section header parsing OK
    return table;
  }

  @override
  int get size => dataSection.data4Offset - dataSection.data3Offset;
}

class GlobalFixupTable {
  final SectionHeader dataSection;
  final entries = <GlobalFixup>[];
  final relocationToEntry = <int, GlobalFixup>{};

  GlobalFixupTable(this.dataSection);

  void addEntry(GlobalFixup entry) {
    entries.add(entry);
    relocationToEntry[entry.relocOffset] = entry;
  }
}

class GlobalFixup {
  /// Where to write the pointer to [objectOffset].
  int relocOffset;

  /// The object to refer to at [relocOffset].
  int objectOffset;

  void apply(ByteData data, {int offset: 0}) {
    data.setUint32(relocOffset + offset, objectOffset + offset);
  }
}
