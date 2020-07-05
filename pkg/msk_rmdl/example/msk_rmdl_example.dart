import 'dart:typed_data';

import 'package:msk_rmdl/src/model_export.dart';
import 'package:msk_rmdl/src/rmdl.dart';
import 'package:msk_rmdl/src/rmdl/display_list.dart';
import 'package:msk_rmdl/src/fbx.dart' as fbx;

import 'dart:io';

void main(List<String> args) {
  final data = File(args.first).readAsBytesSync() as Uint8List;

  final rmdl = RMDL.parse(data);

  String indent = "";
  void out(arg) => print("$indent$arg");
  void indented(void Function() func) {
    final oldIndent = indent;
    indent = "$oldIndent  ";
    func();
    indent = oldIndent;
  }

//  Uint32List readBoneNames(rmdl.ModelHeader model) {
//    stream.goto(model.boneNamesPtr);
//    final count = stream.uint32();
//    final list = Uint32List(count);
//    for (int i = 0; i < count; i++) {
//      list[i] = stream.uint32();
//    }
//    return list;
//  }
//
//  void dumpBoneNames(Uint32List list) {
//    list
//        .map((i) => i.toRadixString(16).toUpperCase().padLeft(8, '0'))
//        .forEach(out);
//  }

  final fbxScene = <fbx.FBXObject>[];

  int modelIndex = 0;

  out("RMDL {");
  indented(() {
    out("Model Count: ${rmdl.models.length}");

    rmdl.models.forEach((model) {
      out("Model {");
      indented(() {
        String formatAsset(int asset) {
          final hi =
              (asset >> 32).toUnsigned(32).toRadixString(16).padLeft(8, "0");
          final lo = asset.toUnsigned(32).toRadixString(16).padLeft(8, "0");
          return "$hi$lo".toUpperCase();
        }

        out("Material Asset: ${formatAsset(model.header.matAssetPackage)}");
        out("AABB: ${model.header.boundingBox.min} to ${model.header.boundingBox.max}");

        out("Display List Size: ${model.header.displayListSize}");
        out("Display List {");
        indented(() {
          model.displayList.forEach((cmd) {
            if (cmd is DLDraw) {
              out("Draw(${cmd.type}, vat: ${cmd.vat}, count: ${cmd.elementCount}, stride: ${cmd.elementStride})");
            } else {
              out(cmd.runtimeType);
            }
          });
        });
        out("}");

        out("Vertex Attribute Count: ${model.header.vtxAttrCount}");
        out("Vertex Attributes {");
        indented(() {
          model.vtxAttrs.forEach((attr) {
            out("${attr.type} ${attr.compType} ${attr.size} at ${attr.dataPtr.toRadixString(16)}");
          });
        });
        out("}");

        final fbxModel = exportModel(data, model);
        fbxModel.name = "model$modelIndex";
        fbxScene.add(fbxModel);
      });
      out("}");

      modelIndex++;
    });
  });
  out("}");

//  final fbxOut = File(args.first + ".fbx").openWrite();

  final writer = fbx.FBXAsciiWriter(stdout);

  fbx.FBXHeaderExtension().asNode().visit(writer);
  fbx.Definitions(fbxScene).asNode().visit(writer);
  fbx.Objects(fbxScene).asNode().visit(writer);
  (fbx.Connections()..connectAll(fbxScene, to: const fbx.Scene()))
      .asNode()
      .visit(writer);

//  fbxOut.close();
}
