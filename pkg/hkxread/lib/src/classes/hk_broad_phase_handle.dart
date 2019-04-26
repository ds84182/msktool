library hkxread.src.classes.hk_broad_phase_handle;

import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';
import 'package:meta/meta.dart';

// Size: 4 bytes
class HkBroadPhaseHandle extends Serializable {
  @override
  @mustCallSuper
  void read(DataStream data, ObjectReader reader) {
    data.skipBytes(4); // id (no save)
  }
}
