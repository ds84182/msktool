library hkxread.src.classes.hk_single_shape_container;

import 'package:hkxread/src/classes/hk_shape.dart';
import 'package:hkxread/src/classes/hk_shape_container.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 4 bytes (base) + 4 = 8 bytes
class HkSingleShapeContainer extends HkShapeContainer {
  HkShape childShape;

  @override
  void read(DataStream data, ObjectReader reader) {
    super.read(data, reader);
    childShape = reader.readObjectFromGlobalFixup<HkShape>(data);
  }
}
