library hkxread.src.classes.hk_material;

import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 12 bytes
class HkMaterial extends Serializable {
  int responseType;
  double friction, restitution;

  @override
  void read(DataStream data, ObjectReader reader) {
    responseType = data.uint8();
    data.skipBytes(3); // Padding
    friction = data.float32();
    restitution = data.float32();
  }
}
