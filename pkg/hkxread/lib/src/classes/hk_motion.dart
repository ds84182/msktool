library hkxread.src.classes.hk_motion;

import 'package:hkxread/src/classes/hk_referenced_object.dart';
import 'package:hkxread/src/classes/hk_math.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 8 bytes (base) + 1 + 7 + 192 + 16 + 16 + 16 + 16 = 272 bytes
class HkMotion extends HkReferencedObject {
  int type;
  HkMotionState motionState;
  HkVector4 inertiaAndMassInv, linearVelocity, angularVelocity;

  @override
  void read(DataStream data, ObjectReader reader) {
    super.read(data, reader);
    type = data.uint8();
    data.skipBytes(7);
    motionState = new HkMotionState()..read(data, reader);
    inertiaAndMassInv = new HkVector4()..read(data, reader);
    linearVelocity = new HkVector4()..read(data, reader);
    angularVelocity = new HkVector4()..read(data, reader);
    data.skipBytes(16); // Max size padding
  }
}

// Size: 64 + 80 + 16 + 4 + 4 + 4 + 4 + 4 + 2 + 2 + 10 = 192 bytes
class HkMotionState extends Serializable {
  HkTransform transform;
  // HkSweptTransform sweptTransform;
  HkVector4 deltaAngle;
  double objectRadius, maxLinearVelocity, maxAngularVelocity, linearDamping, angularDamping;
  int deactivationClass, deactivationCounter;

  @override
  void read(DataStream data, ObjectReader reader) {
    transform = new HkTransform()..read(data, reader);
    data.skipBytes(80); // sweptTransform, don't care
    deltaAngle = new HkVector4()..read(data, reader);
    objectRadius = data.float32();
    maxLinearVelocity = data.float32();
    maxAngularVelocity = data.float32();
    linearDamping = data.float32();
    angularDamping = data.float32();
    deactivationClass = data.uint16();
    deactivationCounter = data.uint16();
    data.skipBytes(10); // Alignment
  }
}
