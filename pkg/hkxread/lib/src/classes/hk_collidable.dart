library hkxread.src.classes.hk_collidable;

import 'package:hkxread/src/classes/hk_cd_body.dart';
import 'package:hkxread/src/classes/hk_typed_broad_phase_handle.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 16 bytes (base) + 4 + 12 + 4 = 36 bytes
class HkCollidable extends HkCdBody {
  HkTypedBroadPhaseHandle broadPhaseHandle;
  double allowedPenetrationDepth;

  @override
  void read(DataStream data, ObjectReader reader) {
    super.read(data, reader);
    data.skipBytes(4); // owner offset (no save)
    broadPhaseHandle = new HkTypedBroadPhaseHandle()..read(data, reader);
    allowedPenetrationDepth = data.float32();
  }
}
