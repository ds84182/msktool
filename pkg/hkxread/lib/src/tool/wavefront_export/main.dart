library hkxread.src.tool.wavefront_export.main;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:hkxread/src/classes/hk_box_shape.dart';
import 'package:hkxread/src/classes/hk_cylinder_shape.dart';
import 'package:hkxread/src/classes/hk_mopp_bv_tree_shape.dart';
import 'package:hkxread/src/classes/hk_shape.dart';
import 'package:hkxread/src/classes/hk_simple_mesh_shape.dart';
import 'package:hkxread/src/hkxcontext.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/wavefront_builder.dart';
import 'package:vector_math/vector_math.dart';

Future main(List<String> args) async {
  final hkxFile = new File(args[0]);
  final objPath = args[1];

  await new Directory(objPath).create(recursive: true);

  final bytes = (await hkxFile.readAsBytes()) as Uint8List;
  final data = new DataStream.fromTypedData(bytes);
  final context = new HkxContext.parse(data);
  final system = context.physicsData.systems.single.object;

  Future writeObj(File file, WavefrontBuilder builder) {
    final sink = file.openWrite();
    builder.build().forEach(sink.writeln);
    return sink.close();
  }

  final matrix = new Matrix4.zero();

  for (final bodyPtr in system.rigidBodies) {
    final body = bodyPtr.object;
    HkShape shape = body.collidable.shape;
    final ptrHex = bodyPtr.ptr.toRadixString(16).toUpperCase();

    if (shape is HkMoppBvTreeShape) {
      // Proxy over another shape
      shape = (shape as HkMoppBvTreeShape).shapeContainer.childShape;
    }

    print("${shape.runtimeType}_$ptrHex");

    body.motion.motionState.transform.asMatrix(matrix);

    print(body.motion.motionState.transform);
    print(matrix);

    WavefrontBuilder builder;

    if (shape is HkCylinderShape) {
      builder = WavefrontModels.cylinderBetween(
        shape.vertexA.xyz,
        shape.vertexB.xyz,
        shape.cylRadius,
      );
    } else if (shape is HkSimpleMeshShape) {
      builder = new WavefrontBuilder();
      for (final vertex in shape.vertices) {
        builder.addPositionVec(vertex.xyz);
      }
      for (final triangle in shape.triangles) {
        builder.addFace(triangle.a + 1, triangle.b + 1, triangle.c + 1);
      }
    } else if (shape is HkBoxShape) {
      builder = WavefrontModels.cube.clone()
        ..transform(new Matrix4.diagonal3(shape.halfExtents.xyz));
    }

    if (builder == null) {
      print("${shape.runtimeType} not supported!");
    } else {
      builder.transform(matrix);
      await writeObj(
          new File("$objPath/${shape.runtimeType}_$ptrHex.obj"), builder);
    }
  }
}
