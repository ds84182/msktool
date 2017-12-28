library hkxread.src.classes.hk_math;

import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';
import 'package:vector_math/vector_math.dart';

// Size: 16 bytes
class HkVector4 extends Vector4 implements Serializable {
  HkVector4() : super.zero();

  factory HkVector4.values(double x, double y, double z, double w) =>
      new HkVector4()
        ..x = x
        ..y = y
        ..z = z
        ..w = w;

  @override
  void read(DataStream data, ObjectReader reader) {
    x = data.float32();
    y = data.float32();
    z = data.float32();
    w = data.float32();
  }

  static HkVector4 factory(DataStream data, ObjectReader reader) =>
      new HkVector4()..read(data, reader);
}

// Size: 48 bytes
class HkMatrix3 extends Matrix3 implements Serializable {
  HkMatrix3() : super.zero();
  factory HkMatrix3.identity() => new HkMatrix3()..setIdentity();

  @override
  void read(DataStream data, ObjectReader reader) {
    storage[index(0, 0)] = data.float32();
    storage[index(1, 0)] = data.float32();
    storage[index(2, 0)] = data.float32();
    data.skipBytes(4); // Padding
    storage[index(0, 1)] = data.float32();
    storage[index(1, 1)] = data.float32();
    storage[index(2, 1)] = data.float32();
    data.skipBytes(4); // Padding
    storage[index(0, 2)] = data.float32();
    storage[index(1, 2)] = data.float32();
    storage[index(2, 2)] = data.float32();
    data.skipBytes(4); // Padding
  }
}

// Size: 64 bytes
class HkTransform implements Serializable {
  final HkMatrix3 rotation = new HkMatrix3();
  final HkVector4 translation = new HkVector4();

  @override
  void read(DataStream data, ObjectReader reader) {
    rotation.read(data, reader);
    translation.read(data, reader);
  }

  void transform(Vector3 v) {
    v.applyMatrix3(rotation);
    v.x += translation.x;
    v.y += translation.y;
    v.z += translation.z;
  }

  Matrix4 asMatrix([Matrix4 out]) {
    out ??= new Matrix4.zero();
    out.setIdentity();
    out.setRotation(rotation);
    out.setTranslationRaw(translation.x, translation.y, translation.z);
    return out;
  }

  @override
  String toString() {
    return "HkTransform: { "
        "rotation: ${rotation.row0} ${rotation.row1} ${rotation.row2}, "
        "translation: $translation, "
        "}";
  }
}
