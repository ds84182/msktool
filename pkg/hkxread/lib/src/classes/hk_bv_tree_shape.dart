library hkxread.src.classes.hk_bv_tree_shape;

import 'package:hkxread/src/classes/hk_shape.dart';
import 'package:hkxread/src/classes/hk_single_shape_container.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 12 bytes (base) + 8 = 20 bytes
class HkBvTreeShape extends HkShape {
  HkSingleShapeContainer shapeContainer;

  @override
  void read(DataStream data, ObjectReader reader) {
    super.read(data, reader);
    shapeContainer = new HkSingleShapeContainer()..read(data, reader);
  }
}
