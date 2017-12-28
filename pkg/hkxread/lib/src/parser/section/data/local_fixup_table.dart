/// The local fixup table is a table of file offsets to other file offsets.
///
/// This links various (local) things together, like the data ptr for an
/// hkArray.
library hkxread.src.parser.section.data.local_fixup_table;

import 'dart:typed_data';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/parser/section_header.dart';

class LocalFixupTableParser extends EfficientLengthParser<LocalFixupTable> {
  final SectionHeader dataSection;

  const LocalFixupTableParser(this.dataSection);

  @override
  LocalFixupTable read(DataStream data) {
    data.goto(dataSection.data1Offset);

    final table = new LocalFixupTable(dataSection);

    LocalFixup readEntry() {
      final entry = new LocalFixup();
      entry.dstOffset = data.uint32();
      entry.srcOffset = data.uint32();
      return entry;
    }

    while (data.offsetIsBefore(dataSection.data4Offset)) {
      table.addEntry(readEntry());
    }

    // Section header parsing OK
    return table;
  }

  @override
  int get size => dataSection.data4Offset - dataSection.data3Offset;
}

class LocalFixupTable {
  final SectionHeader dataSection;
  final entries = <LocalFixup>[];
  final relocationToEntry = <int, LocalFixup>{};

  LocalFixupTable(this.dataSection);

  void addEntry(LocalFixup entry) {
    entries.add(entry);
    relocationToEntry[entry.dstOffset] = entry;
  }
}

class LocalFixup {
  /// Where to write the pointer to [srcOffset].
  int dstOffset;

  /// The object to refer to at [dstOffset].
  int srcOffset;

  void apply(ByteData data, {int offset: 0}) {
    data.setUint32(dstOffset + offset, srcOffset + offset);
  }
}
