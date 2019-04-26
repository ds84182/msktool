library hkxread.src.classes.hk_linked_collidable;

import 'package:hkxread/src/classes/hk_collidable.dart';
import 'package:hkxread/src/classes/hk_typed_broad_phase_handle.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 36 bytes (base) + 12 = 48 bytes
class HkLinkedCollidable extends HkCollidable {
  HkTypedBroadPhaseHandle broadPhaseHandle;
  double allowedPenetrationDepth;

  @override
  void read(DataStream data, ObjectReader reader) {
    super.read(data, reader);
    data.skipBytes(12); // collision entries array (no save)
  }
}
