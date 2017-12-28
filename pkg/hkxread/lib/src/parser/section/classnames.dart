library hkxread.src.parser.section.classnames;

import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/parser/section_header.dart';

class ClassTableParser extends EfficientLengthParser<ClassTable> {
  final SectionHeader section;

  const ClassTableParser(this.section);

  @override
  ClassTable read(DataStream data) {
    data.goto(section.offset);

    final classTable = new ClassTable();

    ClassTableEntry readEntry() {
      final id = data.uint32();

      if (id == 0xFFFFFFFF) return null;

      return new ClassTableEntry()
        ..classId = id
        ..unknownByte = data.uint8()
        ..offset = data.offset - section.offset
        ..name = DataStreamUtils
            .convertZeroTerminatedString(data.zeroTerminatedUint8List());
    }

    while (data.offsetIsBefore(section.data1Offset)) {
      final entry = readEntry();
      if (entry == null) break;
      classTable.addEntry(entry);
    }

    // Section header parsing OK
    return classTable;
  }

  @override
  int get size => section.data1Offset - section.offset;
}

class ClassTable {
  List<ClassTableEntry> entries = <ClassTableEntry>[];
  Map<int, ClassTableEntry> offsetToEntryMap = <int, ClassTableEntry>{};

  void addEntry(ClassTableEntry entry) {
    entries.add(entry);
    offsetToEntryMap[entry.offset] = entry;
  }
}

class ClassTableEntry {
  int classId;

  int unknownByte;

  /// Note: This is the offset to the class from the start of the class section.
  /// Also, this points to the class name. Walk 5 bytes back to read the class
  /// ID (a uint32).
  int offset;

  String name;
}
