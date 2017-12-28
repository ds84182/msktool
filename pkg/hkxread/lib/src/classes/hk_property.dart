library hkxread.src.classes.hk_property;

import 'package:collection/collection.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

class HkProperty extends Serializable {
  int key;
  int value;

  @override
  void read(DataStream data, ObjectReader reader) {
    key = data.uint32();
    data.skipBytes(4); // alignment padding
    value = data.uint64();
  }
}
