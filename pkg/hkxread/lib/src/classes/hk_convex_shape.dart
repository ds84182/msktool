library hkxread.src.classes.hk_convex_shape;

import 'package:hkxread/src/classes/hk_sphere_rep_shape.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 12 bytes (base) + 4 = 16 bytes
class HkConvexShape extends HkSphereRepShape {
  double radius;

  @override
  void read(DataStream data, ObjectReader reader) {
    super.read(data, reader);
    radius = data.float32();
  }
}
