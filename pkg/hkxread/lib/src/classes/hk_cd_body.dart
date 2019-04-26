library hkxread.src.classes.hk_cd_body;

import 'package:hkxread/src/classes/hk_shape.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';
import 'package:meta/meta.dart';

// Size: 16 bytes
class HkCdBody extends Serializable {
  HkShape shape;

  @override
  @mustCallSuper
  void read(DataStream data, ObjectReader reader) {
    shape = reader.readObjectFromGlobalFixup<HkShape>(data);
    data.skipBytes(4); // shapeKey
    data.skipBytes(4); // motion (no save)
    data.skipBytes(4); // parent (serialized = false)
  }
}
