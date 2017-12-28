@Deprecated("This is incorrect")
library hkxread.src.parser.section.data.uuid_table;

import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/parser/section/classnames.dart';
import 'package:hkxread/src/parser/section_header.dart';

class UUIDTableParser extends EfficientLengthParser<UUIDTable> {
  final SectionHeader dataSection;

  const UUIDTableParser(this.dataSection);

  @override
  UUIDTable read(DataStream data) {
    data.goto(dataSection.data3Offset);

    final uuidTable = new UUIDTable(dataSection);

    UUIDTableEntry readEntry() {
      final entry = new UUIDTableEntry();
      entry.rawHeaderOffset = data.uint32();
      final unknown = data.uint32();
      entry.classOffset = data.uint32();
      return entry;
    }

    while (data.offsetIsBefore(dataSection.data4Offset)) {
      uuidTable.addEntry(readEntry());
    }

    data.goto(dataSection.data2Offset);

    while (data.offsetIsBefore(dataSection.data3Offset)) {
      final offset = data.uint32();
      final unknown = data.uint32(); // Unknown, always 1?
      final uuid = data.uint32();
      if (!uuidTable.updateEntry(
          uuid, (entry) => entry.rawContentOffset = offset)) {
        break;
      }
    }

    // Section header parsing OK
    return uuidTable;
  }

  @override
  int get size => dataSection.data4Offset - dataSection.data3Offset;
}

class UUIDTable {
  final SectionHeader dataSection;

  List<UUIDTableEntry> entries = <UUIDTableEntry>[];
  Map<int, UUIDTableEntry> uuidToEntryMap = <int, UUIDTableEntry>{};

  UUIDTable(this.dataSection);

  void addEntry(UUIDTableEntry entry) {
    entries.add(entry);
    uuidToEntryMap[entry.rawHeaderOffset] = entry;
  }

  bool updateEntry(int uuid, void func(UUIDTableEntry entry)) {
    final entry = uuidToEntryMap[uuid];
    if (entry == null) return false;
    func(entry);
    return true;
  }

  void estimateEntrySizes() {
    final seenSet = new Set<int>();
    final sortedOffsets = <int>[];

    for (final entry in entries) {
      if (!seenSet.add(entry.rawHeaderOffset)) {
        throw "Already seen raw header offset ${entry.rawHeaderOffset}";
      }
      sortedOffsets.add(entry.rawHeaderOffset);
      if (!seenSet.add(entry.rawContentOffset)) {
        throw "Already seen raw content offset ${entry.rawContentOffset}";
      }
      sortedOffsets.add(entry.rawContentOffset);
    }

    sortedOffsets.sort();

    int sizeEstimate(int offset) {
      int next = sortedOffsets.indexOf(offset) + 1;
      if (next >= sortedOffsets.length) {
        return dataSection.data1Offset - offset;
      } else {
        return sortedOffsets[next] - offset;
      }
    }

    for (final entry in entries) {
      entry.headerSize = sizeEstimate(entry.rawHeaderOffset);
      entry.contentSize = sizeEstimate(entry.rawContentOffset);
    }
  }

  int estimateHeaderSize(UUIDTableEntry entry) {
    if (entries
        .where((e) => e.rawHeaderOffset > entry.rawHeaderOffset)
        .isEmpty) {
      return dataSection.data1Offset - entry.rawHeaderOffset;
    }

    return entries
            .where((e) => e.rawHeaderOffset > entry.rawHeaderOffset)
            .reduce((a, b) => a.rawHeaderOffset < b.rawHeaderOffset ? a : b)
            .rawHeaderOffset -
        entry.rawHeaderOffset;
  }

  int estimateContentSize(UUIDTableEntry entry) {
    if (entries
        .where((e) => e.rawContentOffset > entry.rawContentOffset)
        .isEmpty) {
      return dataSection.data1Offset - entry.rawContentOffset;
    }

    return entries
            .where((e) => e.rawContentOffset > entry.rawContentOffset)
            .reduce((a, b) => a.rawContentOffset < b.rawContentOffset ? a : b)
            .rawContentOffset -
        entry.rawContentOffset;
  }
}

class UUIDTableEntry {
  // offset from dataSection.offset
  int rawHeaderOffset;

  /// Note: This is the offset to the class from the start of the class section.
  /// Also, this points to the class name. Walk 5 bytes back to read the class
  /// ID (a uint32).
  ///
  /// This offset can be given to [ClassTable] to look up class information.
  int classOffset;

  // offset from dataSection.offset
  int rawContentOffset = 0xC;

  int headerSize, contentSize;

  ClassTableEntry lookupClass(ClassTable classTable) =>
      classTable.offsetToEntryMap[classOffset];
}
