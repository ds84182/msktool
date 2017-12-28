library hkxread.src.classes.hk_object_ptr;

import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 4 bytes
class HkObjectPtr<T> extends Serializable {
  int ptr;
  T object;

  @override
  void read(DataStream data, ObjectReader reader) {
    final offset = reader.getGlobalFixupOffset(data);
    ptr = offset - reader.dataBase;
    object = reader.readObjectAt<T>(data, offset);
  }
}
