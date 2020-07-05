import 'package:hkxread/src/parser.dart';
import 'package:vector_math/vector_math.dart';

class RMDLHeader {
  final int modelCount, modelListPtr, matrixInfoPtr;

  const RMDLHeader({this.modelCount, this.modelListPtr, this.matrixInfoPtr});
}

class RMDLHeaderParser extends EfficientLengthParser<RMDLHeader> {
  const RMDLHeaderParser();

  @override
  RMDLHeader read(DataStream data) {
    data.magic32(0x524D444C); // RMDL
    data.magic32(0x00000101); // Version
    data.skipBytes(24); // Padding/BOM
    final int modelCount = data.uint32();
    final int modelListPtr = data.uint32();
    data.skipBytes(8);
    final int matrixInfoPtr = data.uint32();
    return RMDLHeader(
      modelCount: modelCount,
      modelListPtr: modelListPtr,
      matrixInfoPtr: matrixInfoPtr,
    );
  }

  @override
  int get size => 4 + 4 + 24 + 4 + 4 + 4 + 8 + 4;
}

class ModelHeader {
  final int displayListSize;
  final int displayListPtr;
  final int vtxAttrCount;
  final int vtxDataPtr;
  final int matAssetPackage;
  final int unk1, unk2;
  final Aabb3 boundingBox;
  final int unk3, unk4, unk5;
  final int unk6, unk7, unk8;
  final int boneToMatrixBindingInfoPtr;
  final int boneNamesPtr;
  final int boneInfoPtr;

  const ModelHeader({
    this.displayListSize,
    this.displayListPtr,
    this.vtxAttrCount,
    this.vtxDataPtr,
    this.matAssetPackage,
    this.unk1,
    this.unk2,
    this.boundingBox,
    this.unk3,
    this.unk4,
    this.unk5,
    this.unk6,
    this.unk7,
    this.unk8,
    this.boneToMatrixBindingInfoPtr,
    this.boneNamesPtr,
    this.boneInfoPtr,
  });
}

class ModelHeaderParser extends EfficientLengthParser<ModelHeader> {
  const ModelHeaderParser();

  @override
  ModelHeader read(DataStream data) {
    return ModelHeader(
      displayListSize: data.uint32(),
      displayListPtr: data.uint32(),
      vtxAttrCount: data.uint32(),
      vtxDataPtr: data.uint32(),
      matAssetPackage: data.uint64(),
      unk1: data.uint32(),
      unk2: data.uint32(),
      boundingBox: Aabb3.minMax(
        Vector3(data.float32(), data.float32(), data.float32()),
        Vector3(data.float32(), data.float32(), data.float32()),
      ),
      unk3: data.uint32(),
      unk4: data.uint32(),
      unk5: data.uint32(),
      unk6: data.uint32(),
      unk7: data.uint32(),
      unk8: data.uint32(),
      boneToMatrixBindingInfoPtr: data.uint32(),
      boneNamesPtr: data.uint32(),
      boneInfoPtr: data.uint32(),
    );
  }

  @override
  int get size => 0x40 + 4*3 + 4*3;
}

enum VtxAttrType {
  posMtxIdx,
  tex0MtxIdx,
  tex1MtxIdx,
  tex2MtxIdx,
  tex3MtxIdx,
  tex4MtxIdx,
  tex5MtxIdx,
  tex6MtxIdx,
  tex7MtxIdx,
  pos,
  nrm,
  clr0,
  clr1,
  tex0,
  tex1,
  tex2,
  tex3,
  tex4,
  tex5,
  tex6,
  tex7,
  posMtxArray,
  nrmMtxArray,
  texMtxArray,
  lightArray,
  nbt,
}

enum VtxAttrSize {
  u8,
  s8,
  u16,
  s16,
  f32,
  rgb565,
  rgb8,
  rgbx8,
  rgba4,
  rgba6,
  rgba8,
}

enum VtxAttrCompType {
  posXY,
  posXYZ,
  nrmXYZ,
  nrmNBT,
  nrmNBT3,
  clrRGB,
  clrRGBA,
  texS,
  texST
}

class VtxAttr {
  final VtxAttrType type;
  final VtxAttrSize size;
  final VtxAttrCompType compType;
  final int dataPtr;

  const VtxAttr({this.type, this.size, this.compType, this.dataPtr});
}

class VtxAttrParser extends EfficientLengthParser<VtxAttr> {
  const VtxAttrParser();

  @override
  VtxAttr read(DataStream data) {
    final type = VtxAttrType.values[data.uint8()];
    final comp = data.uint8();
    final compSize = selectComponentSize(type, comp & 7);
    final compType = selectComponentType(type, comp >> 3);
    data.skipBytes(2);
    final ptr = data.uint32();

    return VtxAttr(
      type: type,
      size: compSize,
      compType: compType,
      dataPtr: ptr,
    );
  }

  static VtxAttrSize selectComponentSize(VtxAttrType type, int raw) {
    if (type == VtxAttrType.clr0 || type == VtxAttrType.clr1) {
      return const [
        VtxAttrSize.rgb565,
        VtxAttrSize.rgb8,
        VtxAttrSize.rgbx8,
        VtxAttrSize.rgba4,
        VtxAttrSize.rgba6,
        VtxAttrSize.rgba8,
      ][raw];
    } else {
      return const [
        VtxAttrSize.u8,
        VtxAttrSize.s8,
        VtxAttrSize.u16,
        VtxAttrSize.s16,
        VtxAttrSize.f32,
      ][raw];
    }
  }

  static VtxAttrCompType selectComponentType(VtxAttrType type, int raw) {
    if (type == VtxAttrType.pos) {
      return raw == 0 ? VtxAttrCompType.posXY : VtxAttrCompType.posXYZ;
    } else if (type == VtxAttrType.nrm) {
      return const [
        VtxAttrCompType.nrmXYZ,
        VtxAttrCompType.nrmNBT,
        VtxAttrCompType.nrmNBT3,
      ][raw];
    } else if (type == VtxAttrType.clr0 || type == VtxAttrType.clr1) {
      return raw == 0 ? VtxAttrCompType.clrRGB : VtxAttrCompType.clrRGBA;
    } else if (type.index >= 13 && type.index <= 20) {
      return raw == 0 ? VtxAttrCompType.texS : VtxAttrCompType.texST;
    } else {
      return null;
    }
  }

  @override
  int get size => 8;
}
