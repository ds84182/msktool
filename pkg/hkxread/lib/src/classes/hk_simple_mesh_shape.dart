library hkxread.src.classes.hk_simple_mesh_shape;

import 'dart:typed_data';

import 'package:hkxread/src/classes/hk_array.dart';
import 'package:hkxread/src/classes/hk_shape_collection.dart';
import 'package:hkxread/src/classes/hk_math.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 20 bytes (base) + 12 + 12 + 12 + 4 = 60 bytes
class HkSimpleMeshShape extends HkShapeCollection {
  HkArray<HkVector4> vertices;
  HkArray<HkSimpleMeshShapeTriangle> triangles;
  HkArray<int> materialIndices;
  double radius;

  @override
  void read(DataStream data, ObjectReader reader) {
    super.read(data, reader);
    vertices = new HkArray<HkVector4>(HkVector4.factory)..read(data, reader);
    triangles = new HkArray<HkSimpleMeshShapeTriangle>(
        HkSimpleMeshShapeTriangle.factory)
      ..read(data, reader);
    materialIndices = new HkArray<int>((data, reader) => data.uint8())
      ..read(data, reader);
    radius = data.float32();
  }
}

// Size: 12 bytes
class HkSimpleMeshShapeTriangle implements Serializable {
  Uint32List components;

  int get a => components[0];
  int get b => components[1];
  int get c => components[2];

  @override
  void read(DataStream data, ObjectReader reader) {
    components = new Uint32List(3);
    components[0] = data.uint32();
    components[1] = data.uint32();
    components[2] = data.uint32();
  }

  static HkSimpleMeshShapeTriangle factory(
          DataStream data, ObjectReader reader) =>
      new HkSimpleMeshShapeTriangle()..read(data, reader);
}
