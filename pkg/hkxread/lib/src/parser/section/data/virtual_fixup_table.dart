/// The virtual fixup table is a table of offsets to objects and their class
/// so the class can properly inflate its C++ vtable.
///
/// We can use this information to locate and parse virtual objects.
library hkxread.src.parser.section.data.virtual_fixup_table;

import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/parser/section/classnames.dart';
import 'package:hkxread/src/parser/section_header.dart';

class VirtualFixupTableParser extends EfficientLengthParser<VirtualFixupTable> {
  final SectionHeader dataSection;

  const VirtualFixupTableParser(this.dataSection);

  @override
  VirtualFixupTable read(DataStream data) {
    data.goto(dataSection.data3Offset);

    final table = new VirtualFixupTable(dataSection);

    VirtualFixup readEntry() {
      final entry = new VirtualFixup();
      entry.objectOffset = data.uint32();
      data.skipBytes(4); // unknown, always 0
      entry.classOffset = data.uint32();
      return entry;
    }

    while (data.offset + 12 <= dataSection.data4Offset) {
      table.addEntry(readEntry());
    }

    // Section header parsing OK
    return table;
  }

  @override
  int get size => dataSection.data4Offset - dataSection.data3Offset;
}

class VirtualFixupTable {
  final SectionHeader dataSection;
  final entries = <VirtualFixup>[];
  final objectToEntry = <int, VirtualFixup>{};

  VirtualFixupTable(this.dataSection);

  void addEntry(VirtualFixup entry) {
    entries.add(entry);
    objectToEntry[entry.objectOffset] = entry;
  }
}

class VirtualFixup {
  // Offset to object from dataSection.offset
  int objectOffset;

  /// Note: This is the offset to the class from the start of the class section.
  /// Also, this points to the class name. Walk 5 bytes back to read the class
  /// ID (a uint32).
  ///
  /// This offset can be given to [ClassTable] to look up class information.
  int classOffset;

  ClassTableEntry lookupClass(ClassTable classTable) =>
      classTable.offsetToEntryMap[classOffset];
}
