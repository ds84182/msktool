library hkxread.hkxinspect;

import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:hkxread/src/classes/hk_box_shape.dart';
import 'package:hkxread/src/classes/hk_cylinder_shape.dart';
import 'package:hkxread/src/classes/hk_mopp_bv_tree_shape.dart';
import 'package:hkxread/src/classes/hk_physics_data.dart';
import 'package:hkxread/src/classes/hk_physics_system.dart';
import 'package:hkxread/src/classes/hk_rigid_body.dart';
import 'package:hkxread/src/classes/hk_simple_mesh_shape.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/parser/header.dart';
import 'package:hkxread/src/parser/section/data/global_fixup_table.dart';
import 'package:hkxread/src/parser/section/data/local_fixup_table.dart';
import 'package:hkxread/src/parser/section/data/virtual_fixup_table.dart';
import 'package:hkxread/src/parser/section_header.dart';
import 'package:hkxread/src/parser/section/classnames.dart';
import 'package:hkxread/src/serializable.dart';
import 'package:hkxread/src/wavefront_builder.dart';
import 'package:vector_math/vector_math.dart';

/*
Documentation notes:

UUID Entries are based off the data section's .offset (not an indexed offset,
just the base offset).

hkMeshShape @ 0x24 has the number of vertices
hkMeshShape @ 0x30 has the number of triangles

vertices are fvec4s
triangles are uint32_t[3] (an index into vertices)
 */

enum SectionType { classnames, data, types }

DataStream data;

Header header;
Map<SectionType, SectionHeader> sections = <SectionType, SectionHeader>{};
ClassTable classTable;
LocalFixupTable localFixupTable;
GlobalFixupTable globalFixupTable;
VirtualFixupTable virtualFixupTable;

double int2f32(int i) {
  return new Uint32List.fromList([i]).buffer.asFloat32List()[0];
}

void reset() {
  data.reset();
  header = null;
  sections.clear();
  classTable = null;
  localFixupTable = null;
  globalFixupTable = null;
  virtualFixupTable = null;
}

void parse() {
  header = data.parse(const HeaderParser());

  for (int i = 0; i < 3; i++) {
    final sectionHeader = data.parse(const SectionHeaderParser());

    SectionType type;
    switch (sectionHeader.name) {
      case "__classnames__":
        type = SectionType.classnames;
        break;
      case "__data__":
        type = SectionType.data;
        break;
      case "__types__":
        type = SectionType.types;
        break;
      default:
        throw new UnsupportedError(
            "Unknown section header ${sectionHeader.name}");
    }

    sections[type] = sectionHeader;
  }

  classTable =
      data.parse(new ClassTableParser(sections[SectionType.classnames]));

  localFixupTable =
      data.parse(new LocalFixupTableParser(sections[SectionType.data]));
  globalFixupTable =
      data.parse(new GlobalFixupTableParser(sections[SectionType.data]));
  virtualFixupTable =
      data.parse(new VirtualFixupTableParser(sections[SectionType.data]));
}

// exportMeshesAsModel(r"C:\Users\ds841\Documents\MSKKHX")
//Future exportMeshesAsModel(String path) async {
//  final meshClass = classTable.entries
//      .singleWhere((entry) => entry.name == "hkSimpleMeshShape");
//
//  final meshes = uuidTable.entries
//      .where((entry) => entry.classOffset == meshClass.offset)
//      .toList(growable: false);
//
//  for (final mesh in meshes) {
//    // Export mesh data to file
//    data.goto(mesh.rawContentOffset + uuidTable.dataSection.offset);
//
//    data.skipBytes(36); // Padding
//    final vertCount = data.uint32();
//    data.skipBytes(8); // Unknown
//    final triangleCount = data.uint32();
//    data.skipBytes(24); // Unknown
//
//    // Vertex Data
//    final vertexData = new List<double>.generate(
//        vertCount * 4, (_) => data.float32(),
//        growable: false);
//    // Index Data
//    final indexData = new List<int>.generate(
//        triangleCount * 3, (_) => data.uint32(),
//        growable: false);
//
//    final sink = new File(
//            "$path/Mesh_${mesh.rawHeaderOffset.toRadixString(16).toUpperCase()}.obj")
//        .openWrite();
//
//    sink.writeln("# Generated with hkxinspect.dart");
//    for (int i = 0; i < vertexData.length; i += 4) {
//      sink.writeln(
//          "v ${vertexData[i]} ${vertexData[i + 1]} ${vertexData[i + 2]}");
//    }
//    for (int i = 0; i < indexData.length; i += 3) {
//      sink.writeln(
//          "f ${indexData[i] + 1} ${indexData[i + 1] + 1} ${indexData[i + 2] + 1}");
//    }
//
//    await sink.close();
//  }
//}

void out(String f) {
  log(f);
  print(f);
}

void loadFile(String path) {
  data = new DataStream.fromTypedData(
      new File(path).readAsBytesSync() as Uint8List);

  out("Loaded ${data.size} bytes from file");
  inspect(data);
}

class ObjectReaderImpl extends ObjectReader {
  const ObjectReaderImpl();

  int _dataOffset(DataStream data) =>
      data.offset - virtualFixupTable.dataSection.offset;

  Object _readObjectUnsafe(DataStream data) {
    final className = virtualFixupTable.objectToEntry[_dataOffset(data)]
        .lookupClass(classTable)
        .name;

    switch (className) {
      case "hkPhysicsData":
        return new HkPhysicsData()..read(data, this);
      case "hkPhysicsSystem":
        return new HkPhysicsSystem()..read(data, this);
      case "hkRigidBody":
        return new HkRigidBody()..read(data, this);
      case "hkMoppBvTreeShape":
        return new HkMoppBvTreeShape()..read(data, this);
      case "hkSimpleMeshShape":
        return new HkSimpleMeshShape()..read(data, this);
      case "hkCylinderShape":
        return new HkCylinderShape()..read(data, this);
      case "hkBoxShape":
        return new HkBoxShape()..read(data, this);
      default:
        throw new UnsupportedError("Unsupported type: $className");
    }
  }

  int get dataBase => virtualFixupTable.dataSection.offset;

  T readObject<T>(DataStream data) {
    return _readObjectUnsafe(data) as T;
  }

  int getGlobalFixupOffset(DataStream data) {
    final offset = _dataOffset(data);
    data.skipBytes(4);
    return globalFixupTable.relocationToEntry[offset].objectOffset +
        dataBase;
  }

  int getLocalFixupOffset(DataStream data) {
    final offset = _dataOffset(data);
    data.skipBytes(4);
    return localFixupTable.relocationToEntry[offset].srcOffset +
        dataBase;
  }
}

main() async {
  // await new Stream.periodic(const Duration(days: 100)).drain();
  await loadFile(r"C:\Users\ds841\Documents\MSKKHX\reward.hkx");
  parse();

  data.goto(virtualFixupTable.dataSection.offset);
  final obj = const ObjectReaderImpl().readObject(data);
  print(obj);

  final file = new File(r"C:\Users\ds841\Documents\MSKKHX\test.obj");
  final sink = file.openWrite();
  WavefrontModels
      .cylinderBetween(new Vector3(0.0, 6.0, 0.0), new Vector3(4.0, 0.0, 4.0))
      .build().forEach(sink.writeln);
  await sink.close();

//  await extractOffsetsTo(r"C:\Users\ds841\Documents\MSKKHX\reward");
//  await extractTo(r"C:\Users\ds841\Documents\MSKKHX\reward");
}
