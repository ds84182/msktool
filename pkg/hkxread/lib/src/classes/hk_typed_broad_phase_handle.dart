library hkxread.src.classes.hk_typed_broad_phase_handle;

import 'package:collection/collection.dart';
import 'package:hkxread/src/classes/hk_broad_phase_handle.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 4 bytes (base) + 8 bytes = 12 bytes
class HkTypedBroadPhaseHandle extends HkBroadPhaseHandle {
  int type, objectQualityType, collisionFilterInfo;
  @override
  void read(DataStream data, ObjectReader reader) {
    super.read(data, reader);
    type = data.uint8();
    data.skipBytes(1); // owner offset (no save)
    objectQualityType = data.uint16();
    collisionFilterInfo = data.uint32();
  }
}
