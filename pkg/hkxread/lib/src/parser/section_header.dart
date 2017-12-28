library hkxread.src.parser.section_header;

import 'package:hkxread/src/parser.dart';

class SectionHeaderParser extends EfficientLengthParser<SectionHeader> {
  const SectionHeaderParser();

  @override
  SectionHeader read(DataStream data) {
    final sectionHeader = new SectionHeader();

    sectionHeader.name = DataStreamUtils.convertZeroTerminatedString(data.uint8list(16));

    data.magic32(0x000000FF, errorMessage: "Invalid HKX section header magic");

    sectionHeader.offset = data.uint32();
    sectionHeader.rawData1 = data.uint32();
    sectionHeader.rawData2 = data.uint32();
    sectionHeader.rawData3 = data.uint32();
    sectionHeader.rawData4 = data.uint32();
    sectionHeader.rawData5 = data.uint32();
    sectionHeader.rawEnd = data.uint32();

    // Section header parsing OK
    return sectionHeader;
  }

  @override
  int get size => 48;
}

class SectionHeader {
  String name;

  int offset, rawData1, rawData2, rawData3, rawData4, rawData5, rawEnd;

  int get data1Offset => offset + rawData1;
  int get data2Offset => offset + rawData2;
  int get data3Offset => offset + rawData3;
  int get data4Offset => offset + rawData4;
  int get data5Offset => offset + rawData5;
  int get endOffset => offset + rawEnd;
}
