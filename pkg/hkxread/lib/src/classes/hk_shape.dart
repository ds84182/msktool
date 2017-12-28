library hkxread.src.classes.hk_shape;

import 'package:hkxread/src/classes/hk_referenced_object.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 8 bytes (base) + 4 = 12 bytes
class HkShape extends HkReferencedObject {
  int userData;

  @override
  void read(DataStream data, ObjectReader reader) {
    super.read(data, reader);
    userData = data.uint32();
  }
}
