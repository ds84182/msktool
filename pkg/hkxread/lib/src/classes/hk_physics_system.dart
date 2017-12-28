library hkxread.src.classes.hk_physics_system;

import 'package:hkxread/src/classes/hk_array.dart';
import 'package:hkxread/src/classes/hk_base_object.dart';
import 'package:hkxread/src/classes/hk_object_ptr.dart';
import 'package:hkxread/src/classes/hk_referenced_object.dart';
import 'package:hkxread/src/classes/hk_rigid_body.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 8 bytes (base) + 12 + 12 + 12 + 12 + 4 + 4 + 1 + 3 = 68 bytes
class HkPhysicsSystem extends HkReferencedObject {
  HkArray<HkObjectPtr<HkRigidBody>> rigidBodies;
  HkArray<Null> constraints;
  HkArray<Null> actions;
  HkArray<Null> phantoms;
  int userdata;
  bool active;

  @override
  void read(DataStream data, ObjectReader reader) {
    super.read(data, reader);
    rigidBodies =
        new HkArray<HkObjectPtr<HkRigidBody>>(HkArray.objectPtrFactory)
          ..read(data, reader);
    constraints = new HkArray<Null>(HkArray.throwFactory)..read(data, reader);
    actions = new HkArray<Null>(HkArray.throwFactory)..read(data, reader);
    phantoms = new HkArray<Null>(HkArray.throwFactory)..read(data, reader);
    data.skipBytes(4); // name ptr
    userdata = data.uint32();
    active = data.uint8() != 0;
    data.skipBytes(3); // Padding
  }
}
