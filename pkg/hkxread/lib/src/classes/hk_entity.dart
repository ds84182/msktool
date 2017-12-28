library hkxread.src.classes.hk_entity;

import 'package:hkxread/src/classes/hk_array.dart';
import 'package:hkxread/src/classes/hk_base_object.dart';
import 'package:hkxread/src/classes/hk_collidable.dart';
import 'package:hkxread/src/classes/hk_material.dart';
import 'package:hkxread/src/classes/hk_motion.dart';
import 'package:hkxread/src/classes/hk_property.dart';
import 'package:hkxread/src/classes/hk_referenced_object.dart';
import 'package:hkxread/src/classes/hk_world_object.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 88 bytes (base) + 4 + 12 + 4 + 12 + 12 + 12 + 2 + 2 + 1 + 11 + 272 + 4 + 48 + 4 = 488 bytes
class HkEntity extends HkWorldObject {
  HkMaterial material;
  HkMotion motion;
  int storageIndex, processContactCallbackDelay, autoRemoveLevel, uid;

  @override
  void read(DataStream data, ObjectReader reader) {
    super.read(data, reader);
    data.skipBytes(4); // simulationIsland (no save)
    material = new HkMaterial()..read(data, reader);
    data.skipBytes(4); // deactivator (don't care)
    data.skipBytes(12); // constraintsMaster (no save)
    data.skipBytes(12); // constraintsSlave (no save)
    data.skipBytes(12); // constraintRuntime (don't care)
    storageIndex = data.uint16();
    processContactCallbackDelay = data.uint16();
    autoRemoveLevel = data.uint8();
    data.skipBytes(11); // Alignment
    motion = new HkMotion()..read(data, reader);
    data.skipBytes(4); // solverData (don't care)
    data.skipBytes(4 * 12); // collisionListeners, activationListeners, entityListeners, actions (no save)
    uid = data.uint32();
  }
}
