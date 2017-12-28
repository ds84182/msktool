library hkxread.src.classes.hk_box_shape;

import 'package:hkxread/src/classes/hk_convex_shape.dart';
import 'package:hkxread/src/classes/hk_math.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 16 bytes (base) + 16 = 32 bytes
class HkBoxShape extends HkConvexShape {
  HkVector4 halfExtents;

  @override
  void read(DataStream data, ObjectReader reader) {
    super.read(data, reader);
    halfExtents = new HkVector4()..read(data, reader);
  }

  @override
  String toString() => "HkBoxShape: { "
      "radius: $halfExtents, "
      "}";
}
