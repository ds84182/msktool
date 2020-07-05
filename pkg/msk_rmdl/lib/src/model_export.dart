import 'dart:typed_data';

import 'package:msk_rmdl/src/rmdl.dart';
import 'package:msk_rmdl/src/rmdl/display_list.dart';
import 'package:msk_rmdl/src/rmdl/primitive_reader.dart';
import 'package:msk_rmdl/src/fbx.dart' as fbx;

import 'package:hkxread/src/parser.dart';

int _elementCount(DLDraw d) {
  switch (d.type) {
    case DrawType.lines:
    case DrawType.lineStrip:
    case DrawType.points:
      throw "NYI";
    case DrawType.quads:
    case DrawType.quads2:
    case DrawType.triangles:
      return d.elementCount;
    case DrawType.triangleStrip:
    case DrawType.triangleFan:
      return (d.elementCount - 2) * 3;
  }
  throw UnimplementedError();
}

fbx.Model exportModel(TypedData data, Model model) {
  final fbxModel = fbx.Model();
  fbxModel.name = "model";

  final displayList = model.displayList;
  final vtxAttrs = model.vtxAttrs;
  final layout = model.primitiveLayout;

  // Export
  // Figure out the number of vertices
  final int vertexCount = displayList
      .whereType<DLDraw>()
      .map(_elementCount)
      .reduce((a, b) => a + b);

  // Collect index info into a buffer by assembling primitives
  // Negative index == end of primitive
  final Int32List posIndexBuffer = Int32List(vertexCount);
  final Uint16List nrmIndexBuffer = Uint16List(vertexCount);

  int posInd = 0;
  int nrmInd = 0;

  displayList.whereType<DLDraw>().forEach((d) {
    final primStream = DataStream.fromTypedData(d.data);

    void writePrim(int i, {bool last = false}) {
      posIndexBuffer[posInd++] = last ? -(i + 1) : i;
    }

    void writeNrmPrim(int i) {
      nrmIndexBuffer[nrmInd++] = i;
    }

    void writePrimArray(Iterable<PrimitiveIndex> iter, {bool last = false}) {
      iter.forEach((ind) {
        if (ind.type == VtxAttrType.pos) {
          writePrim(ind.index, last: last);
        } else if (ind.type == VtxAttrType.nrm) {
          writeNrmPrim(ind.index);
        }
      });
    }

    switch (d.type) {
      case DrawType.lines:
      case DrawType.lineStrip:
      case DrawType.points:
        throw "NYI";
      case DrawType.quads:
      case DrawType.quads2:
        // Copy all primitives, but negate every 4th
        for (int i = 0; i < d.elementCount; i++) {
          writePrimArray(layout.extract(primStream), last: ((i + 1) % 4) == 0);
        }
        break;
      case DrawType.triangles:
        // Copy all primitives, but negate every 3th
        for (int i = 0; i < d.elementCount; i++) {
          writePrimArray(layout.extract(primStream), last: ((i + 1) % 3) == 0);
        }
        break;
      case DrawType.triangleStrip:
        {
          List<PrimitiveIndex> v1 =
              layout.extract(primStream).toList(growable: false);
          List<PrimitiveIndex> v2 =
              layout.extract(primStream).toList(growable: false);
          List<PrimitiveIndex> v3;
          bool winding = true;
          for (int i = 2; i < d.elementCount; i++) {
            v3 = layout.extract(primStream).toList(growable: false);
            if (!winding) {
              writePrimArray(v1);
              writePrimArray(v2);
              writePrimArray(v3, last: true);
              winding = true;
            } else {
              writePrimArray(v2);
              writePrimArray(v1);
              writePrimArray(v3, last: true);
              winding = false;
            }
            v1 = v2;
            v2 = v3;
          }
          break;
        }
      case DrawType.triangleFan:
        throw "NYI";
        break;
    }
  });

  if (posInd != posIndexBuffer.length)
    throw "Bad pos index buffer size calculation";

  if (nrmInd != nrmIndexBuffer.length)
    throw "Bad nrm index buffer size calculation";

  final maxPosIndex = posIndexBuffer
      .map((x) => x.isNegative ? (-x) - 1 : x)
      .reduce((a, b) => a > b ? a : b);

  final maxNrmIndex = nrmIndexBuffer.reduce((a, b) => a > b ? a : b);

  final stream = DataStream.fromTypedData(data);

  final posAttr = vtxAttrs.singleWhere((attr) => attr.type == VtxAttrType.pos);
  stream.goto(posAttr.dataPtr);
  final posData = Float32List(3 * (maxPosIndex + 1));
  for (int i = 0; i < posData.length; i++) {
    posData[i] = stream.float32();
  }

  final nrmAttr = vtxAttrs.singleWhere((attr) => attr.type == VtxAttrType.nrm);
  stream.goto(nrmAttr.dataPtr);
  final nrmData = Float32List(3 * (maxNrmIndex + 1));
  for (int i = 0; i < nrmData.length; i++) {
    nrmData[i] = stream.float32();
  }

  fbxModel.vertices = fbx.ModelVertices(posData, posIndexBuffer);

  final directNrmData = Float32List(nrmIndexBuffer.length * 3);
  for (int i = 0; i < nrmIndexBuffer.length; i++) {
    final ind = nrmIndexBuffer[i];
    directNrmData[(i * 3) + 0] = nrmData[(ind * 3) + 0];
    directNrmData[(i * 3) + 1] = nrmData[(ind * 3) + 1];
    directNrmData[(i * 3) + 2] = nrmData[(ind * 3) + 2];
  }

  fbxModel.normals = fbx.ModelNormals(nrmData, index: nrmIndexBuffer);

  return fbxModel;
}
