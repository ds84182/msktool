import 'dart:typed_data';

import 'package:msk_rmdl/src/rmdl/display_list.dart';
import 'package:msk_rmdl/src/rmdl/primitive_reader.dart';
import 'package:msk_rmdl/src/rmdl/reader.dart';

import 'package:hkxread/src/parser.dart';

export 'package:msk_rmdl/src/rmdl/reader.dart'
    hide VtxAttrParser, ModelHeaderParser, RMDLHeaderParser;

class RMDL {
  final RMDLHeader header;
  final List<Model> models;

  const RMDL(this.header, this.models);

  static RMDL parse(TypedData data) {
    final stream = DataStream.fromTypedData(data);

    final header = stream.parse(const RMDLHeaderParser());

    List<VtxAttr> readVertexAttributes(ModelHeader model) {
      stream.goto(model.vtxDataPtr);
      return List.generate(model.vtxAttrCount, (_) {
        return stream.parse(const VtxAttrParser());
      }, growable: false);
    }

    stream.goto(header.modelListPtr);
    final modelPtrs = List.generate(header.modelCount, (_) => stream.uint32());

    final models = modelPtrs.map((modelPtr) {
      stream.goto(modelPtr);
      final modelHeader = stream.parse(const ModelHeaderParser());

      stream.goto(modelHeader.displayListPtr);
      final displayList = parseDisplayList(
              stream,
              modelHeader.displayListPtr + modelHeader.displayListSize,
              (modelHeader.vtxAttrCount * 2) +
                  (modelHeader.boneNamesPtr != 0 ? 1 : 0))
          .toList(growable: false);

      final vtxAttrs = readVertexAttributes(modelHeader);

      PrimitiveLayout layout = vtxAttrs.fold(
        PrimitiveLayout(),
        (lyt, attr) => lyt.enable(attr.type, PrimitiveLayout.kAttrIndex16),
      );

      if (modelHeader.boneNamesPtr != 0) {
        layout =
            layout.enable(VtxAttrType.posMtxIdx, PrimitiveLayout.kAttrIndex8);
      }

      return Model(modelHeader, displayList, vtxAttrs, layout);
    }).toList(growable: false);

    return RMDL(header, models);
  }
}

class Model {
  final ModelHeader header;
  final List<DLCommand> displayList;
  final List<VtxAttr> vtxAttrs;
  final PrimitiveLayout primitiveLayout;
  // TODO: Bones

  const Model(
      this.header, this.displayList, this.vtxAttrs, this.primitiveLayout);
}
