library hkxread.src.classes.hk_shape_collection;

import 'package:hkxread/src/classes/hk_base_object.dart';
import 'package:hkxread/src/classes/hk_shape.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 12 bytes (base) + 4 + 1 + 3 = 20 bytes
class HkShapeCollection extends HkShape {
  bool disableWelding;

  @override
  void read(DataStream data, ObjectReader reader) {
    super.read(data, reader);
    HkBaseObject.skipVTable(data);
    disableWelding = data.uint8() != 0;
    data.skipBytes(3);
  }
}
