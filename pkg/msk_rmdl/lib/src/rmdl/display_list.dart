import 'dart:typed_data';

import 'package:hkxread/src/parser.dart';
import 'package:meta/meta.dart';

@immutable
abstract class DLCommand {
  const DLCommand();
}

enum DrawType {
  quads,
  quads2,
  triangles,
  triangleStrip,
  triangleFan,
  lines,
  lineStrip,
  points,
}

class DLDraw extends DLCommand {
  final DrawType type;
  final int vat;
  final Uint8List data;
  final int elementCount;
  final int elementStride;

  const DLDraw(this.type, this.vat, this.data, this.elementCount, this.elementStride);
}

const _kGXCmdNOP = 0x00;
const _kGXCmdLoadIndxA = 0x20;
const _kGXCmdLoadIndxB = 0x28;
const _kGXCmdLoadIndxC = 0x30;
const _kGXCmdLoadIndxD = 0x38;

Iterable<DLCommand> parseDisplayList(DataStream stream, int end, int vertexStride) sync* {
  while (stream.offsetIsBefore(end)) {
    final int cmd = stream.uint8();

    switch (cmd) {
      case _kGXCmdNOP:
        break;
      case _kGXCmdLoadIndxA:
      case _kGXCmdLoadIndxB:
      case _kGXCmdLoadIndxC:
      case _kGXCmdLoadIndxD:
        // NYI, skip
        stream.skipBytes(4);
        break;
      default: {
        // Draw
        final drawCmd = (cmd & 0x78) >> 3;
        final vat = cmd & 7;

        if (drawCmd > 7) {
          // Invalid command
          throw FormatException("Invalid Display List command $cmd at ${stream.offset - 1}");
        } else {
          final drawType = DrawType.values[drawCmd];

          // Read element amount
          final int elemCount = stream.uint16();

          final data = stream.uint8list(elemCount * vertexStride);

          yield DLDraw(drawType, vat, data, elemCount, vertexStride);
        }
      }
    }
  }
}
