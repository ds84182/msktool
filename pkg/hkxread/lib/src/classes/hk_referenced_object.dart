library hkxread.src.classes.hk_referenced_object;

import 'package:hkxread/src/classes/hk_base_object.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 4 bytes (base) + 4 bytes = 8 bytes
class HkReferencedObject extends HkBaseObject {
  @override
  void read(DataStream data, ObjectReader reader) {
    super.read(data, reader);
    // Object doesn't have a VTable because it doesn't create any new virtual
    // methods, only overrides from parent
    data.skipBytes(2); // memSizeAndFlags
    data.skipBytes(2); // referenceCount
  }
}
