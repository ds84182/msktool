library hkxread.src.classes.hk_base_object;

import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 4 bytes
class HkBaseObject extends Serializable {
  static void skipVTable(DataStream data) {
    data.skipBytes(4);
  }

  @override
  void read(DataStream data, ObjectReader reader) {
    skipVTable(data);
  }
}
