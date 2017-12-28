library hkxread.src.parser.header;

import 'package:hkxread/src/parser.dart';

class HeaderParser extends EfficientLengthParser<Header> {
  const HeaderParser();

  @override
  Header read(DataStream data) {
    data.magic32(0x57E0E057, errorMessage: "Invalid HKX header magic");
    data.magic32(0x10C0C010, errorMessage: "Invalid HKX header magic");
    data.magic32(0x00000000, errorMessage: "Invalid HKX header magic");

    data.magic32(0x00000004, errorMessage: "Invalid HKX version");
    data.magic32(0x04000101, errorMessage: "Invalid HKX build number");

    data.magic32List(const <int>[
      0x00000003, 0x00000001, 0x00000000, 0x00000000, 0x000000CB, //
    ], errorMessage: "Invalid HKX constants");

    const expectedVersionName = "Havok-4.0.0-r1";
    for (int i = 0; i < expectedVersionName.length; i++) {
      data.magic8(
        expectedVersionName.codeUnitAt(i),
        errorMessage: "Invalid HKX version name: Unexpected character",
      );
    }

    data.magic8(
      0,
      errorMessage: "Invalid HKX version name: Not null terminated",
    );

    // Dunno if the byte matters, might be a left over from an uncleared buffer
    data.skipBytes(1);

    // 8 byte padding
    data.skipBytes(8);

    // Header parsing OK, return dummy header object for now
    return new Header();
  }

  @override
  int get size => 64;
}

class Header {}
