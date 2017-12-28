library hkxread.src.classes.hk_cylinder_shape;

import 'package:hkxread/src/classes/hk_convex_shape.dart';
import 'package:hkxread/src/classes/hk_math.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 16 bytes (base) + 4 + 4 + 16 + 16 + 16 + 16 = 96 bytes
class HkCylinderShape extends HkConvexShape {
  double cylRadius, cylBaseRadiusFactorForHeightFieldCollisions;
  HkVector4 vertexA, vertexB, perpendicular1, perpendicular2;

  @override
  void read(DataStream data, ObjectReader reader) {
    super.read(data, reader);
    cylRadius = data.float32();
    cylBaseRadiusFactorForHeightFieldCollisions = data.float32();
    data.skipBytes(8); // Padding
    vertexA = new HkVector4()..read(data, reader);
    vertexB = new HkVector4()..read(data, reader);
    perpendicular1 = new HkVector4()..read(data, reader);
    perpendicular2 = new HkVector4()..read(data, reader);
  }

  @override
  String toString() => "HkCylinderShape: { "
      "radius: $cylRadius, "
      "a: $vertexA, "
      "b: $vertexB, "
      "}";
}
