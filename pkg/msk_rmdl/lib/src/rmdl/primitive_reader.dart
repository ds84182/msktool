import 'package:hkxread/src/parser.dart';
import 'reader.dart';

class PrimitiveLayout {
  final int vtxDesc;

  PrimitiveLayout() : vtxDesc = 0xFFFFFFFFFFFF;
  PrimitiveLayout._(this.vtxDesc);

  PrimitiveLayout enable(VtxAttrType attr, int bits) {
    final int mask = (3 << (attr.index << 1));
    return PrimitiveLayout._((vtxDesc & ~mask) | (bits << (attr.index << 1)));
  }

  int getDescRaw(int index) => (vtxDesc & (3 << (index << 1))) >> (index << 1);
  int getDesc(VtxAttrType attr) => getDescRaw(attr.index);
  bool isEnabled(VtxAttrType attr) => getDesc(attr) != kAttrDisabled;

  int get stride {
    int i = 0;
    for (int n = 0; n < 20; n++) {
      final desc = getDescRaw(n);
      if (desc == kAttrDisabled)
        continue;
      else if (desc == kAttrIndex8)
        i += 1;
      else if (desc == kAttrIndex16)
        i += 2;
      else if (desc == kAttrDirect) throw "NYI";
    }
    return i;
  }

  Iterable<PrimitiveIndex> extract(DataStream stream) sync* {
    for (int n = 0; n < 20; n++) {
      final desc = getDescRaw(n);
      if (desc == kAttrDisabled)
        continue;
      else if (desc == kAttrIndex8) {
        yield PrimitiveIndex(VtxAttrType.values[n], stream.uint8());
      } else if (desc == kAttrIndex16) {
        yield PrimitiveIndex(VtxAttrType.values[n], stream.uint16());
      } else if (desc == kAttrDirect) throw "NYI";
    }
  }

  static const kAttrDirect = 0;
  static const kAttrIndex8 = 1;
  static const kAttrIndex16 = 2;
  static const kAttrDisabled = 3;
}

class PrimitiveIndex {
  final VtxAttrType type;
  final int index;

  const PrimitiveIndex(this.type, this.index);
}
