library hkxread.src.hkxcontext;

import 'package:hkxread/src/classes/hk_box_shape.dart';
import 'package:hkxread/src/classes/hk_cylinder_shape.dart';
import 'package:hkxread/src/classes/hk_mopp_bv_tree_shape.dart';
import 'package:hkxread/src/classes/hk_physics_data.dart';
import 'package:hkxread/src/classes/hk_physics_system.dart';
import 'package:hkxread/src/classes/hk_rigid_body.dart';
import 'package:hkxread/src/classes/hk_simple_mesh_shape.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/parser/header.dart';
import 'package:hkxread/src/parser/section/classnames.dart';
import 'package:hkxread/src/parser/section/data/global_fixup_table.dart';
import 'package:hkxread/src/parser/section/data/local_fixup_table.dart';
import 'package:hkxread/src/parser/section/data/virtual_fixup_table.dart';
import 'package:hkxread/src/parser/section_header.dart';
import 'package:hkxread/src/serializable.dart';
import 'package:meta/meta.dart';

class HkxContext {
  final DataStream data;
  final Header header;
  final Map<String, SectionHeader> sectionHeaders;
  final SectionHeader classSection, dataSection, typeSection;
  final ClassTable classTable;
  final LocalFixupTable localFixupTable;
  final GlobalFixupTable globalFixupTable;
  final VirtualFixupTable virtualFixupTable;
  final ObjectReader objectReader;
  final HkPhysicsData physicsData;

  factory HkxContext.parse(DataStream data) {
    final header = _parseHeader(data);
    final sectionHeaders = _parseSections(data);
    final classSection = sectionHeaders["__classnames__"];
    final dataSection = sectionHeaders["__data__"];
    final typeSection = sectionHeaders["__types__"];
    final classTable = _parseClassTable(data, classSection);
    final localFixupTable = _parseLocalFixupTable(data, dataSection);
    final globalFixupTable = _parseGlobalFixupTable(data, dataSection);
    final virtualFixupTable = _parseVirtualFixupTable(data, dataSection);
    final objectReader = new _ObjectReaderImpl(
      dataSection: dataSection,
      classTable: classTable,
      localFixupTable: localFixupTable,
      globalFixupTable: globalFixupTable,
      virtualFixupTable: virtualFixupTable,
    );
    final physicsData =
        objectReader.readObjectAt<HkPhysicsData>(data, dataSection.offset);
    return new HkxContext._(
      data: data,
      header: header,
      sectionHeaders: sectionHeaders,
      classSection: classSection,
      dataSection: dataSection,
      typeSection: typeSection,
      classTable: classTable,
      localFixupTable: localFixupTable,
      globalFixupTable: globalFixupTable,
      virtualFixupTable: virtualFixupTable,
      objectReader: objectReader,
      physicsData: physicsData,
    );
  }

  HkxContext._({
    @required this.data,
    @required this.header,
    @required this.sectionHeaders,
    @required this.classSection,
    @required this.dataSection,
    @required this.typeSection,
    @required this.classTable,
    @required this.localFixupTable,
    @required this.globalFixupTable,
    @required this.virtualFixupTable,
    @required this.objectReader,
    @required this.physicsData,
  });

  static Header _parseHeader(DataStream data) =>
      data.parse(const HeaderParser());

  static Map<String, SectionHeader> _parseSections(DataStream data) {
    final res = <String, SectionHeader>{};
    for (int i = 0; i < 3; i++) {
      final section = data.parse(const SectionHeaderParser());
      res[section.name] = section;
    }
    return res;
  }

  static ClassTable _parseClassTable(
          DataStream data, SectionHeader classSection) =>
      data.parse(new ClassTableParser(classSection));

  static LocalFixupTable _parseLocalFixupTable(
          DataStream data, SectionHeader dataSection) =>
      data.parse(new LocalFixupTableParser(dataSection));

  static GlobalFixupTable _parseGlobalFixupTable(
          DataStream data, SectionHeader dataSection) =>
      data.parse(new GlobalFixupTableParser(dataSection));

  static VirtualFixupTable _parseVirtualFixupTable(
          DataStream data, SectionHeader dataSection) =>
      data.parse(new VirtualFixupTableParser(dataSection));
}

class _ObjectReaderImpl extends ObjectReader {
  final SectionHeader dataSection;
  final ClassTable classTable;
  final LocalFixupTable localFixupTable;
  final GlobalFixupTable globalFixupTable;
  final VirtualFixupTable virtualFixupTable;

  _ObjectReaderImpl({
    @required this.dataSection,
    @required this.classTable,
    @required this.localFixupTable,
    @required this.globalFixupTable,
    @required this.virtualFixupTable,
  });

  int get dataBase => dataSection.offset;

  int _dataOffset(DataStream data) => data.offset - dataBase;

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

  @override
  T readObject<T>(DataStream data) {
    return _readObjectUnsafe(data) as T;
  }

  @override
  int getGlobalFixupOffset(DataStream data) {
    final offset = _dataOffset(data);
    data.skipBytes(4);
    return globalFixupTable.relocationToEntry[offset].objectOffset + dataBase;
  }

  @override
  int getLocalFixupOffset(DataStream data) {
    final offset = _dataOffset(data);
    data.skipBytes(4);
    return localFixupTable.relocationToEntry[offset].srcOffset + dataBase;
  }
}
