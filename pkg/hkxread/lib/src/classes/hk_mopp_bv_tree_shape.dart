library hkxread.src.classes.hk_mopp_bv_tree_shape;

import 'package:hkxread/src/classes/hk_bv_tree_shape.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 20 bytes (base) + 4 = 24 bytes
class HkMoppBvTreeShape extends HkBvTreeShape {
  @override
  void read(DataStream data, ObjectReader reader) {
    super.read(data, reader);
//    reader.readObjectFromGlobalFixup(data); // hkMoppCode
    data.skipBytes(4); // hkMoppCode (don't care)
  }
}
