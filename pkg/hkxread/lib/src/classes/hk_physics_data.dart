library hkxread.src.classes.hk_physics_data;

import 'package:hkxread/src/classes/hk_array.dart';
import 'package:hkxread/src/classes/hk_object_ptr.dart';
import 'package:hkxread/src/classes/hk_physics_system.dart';
import 'package:hkxread/src/classes/hk_referenced_object.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 8 bytes (base) + 4 + 12 = 24 bytes
class HkPhysicsData extends HkReferencedObject {
  HkArray<HkObjectPtr<HkPhysicsSystem>> systems;

  @override
  void read(DataStream data, ObjectReader reader) {
    super.read(data, reader);
    data.skipBytes(4); // worldCinfo
    systems =
        new HkArray<HkObjectPtr<HkPhysicsSystem>>(HkArray.objectPtrFactory)
          ..read(data, reader);
  }
}
