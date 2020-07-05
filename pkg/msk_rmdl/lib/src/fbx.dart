library msk_rmdl.fbx;

import 'package:charcode/ascii.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

abstract class FBXVisitor<T> {
  T visitNode(FBXNode node);
  T visitProperty<V>(FBXProperty<V> property);
}

class FBXAsciiWriter extends FBXVisitor<void> {
  String _indent = "";
  bool _afterNewline = true;
  final StringSink sink;

  FBXAsciiWriter(this.sink);

  void _out(String s) {
    if (_afterNewline) {
      sink.write(_indent);
      _afterNewline = false;
    }
    sink.write(s);
  }

  void _nl() {
    sink.writeln();
    _afterNewline = true;
  }

  void _serialize(Object obj) {
    if (obj is List) {
      for (int i = 0; i < obj.length; i++) {
        if (i != 0) _out(", ");
        _serialize(obj[i]);
      }
    } else if (obj is num) {
      _out("$obj");
    } else if (obj is String) {
      _out('"');
      int start = 0;
      int i = 0;
      while (i < obj.length) {
        if (obj.codeUnitAt(i) == $quote) {
          // Escape, first dump remaining
          if (start != i) _out(obj.substring(start, i));
          // Then escape
          _out('\\"');
          start = i + 1;
        }
        i++;
      }
      // Dump remaining
      if (start != i) _out(obj.substring(start, i));
      _out('"');
    } else {
      throw "Cannot serialize ${obj.runtimeType} ($obj)";
    }
  }

  @override
  void visitNode(FBXNode node) {
    _out(node.name);
    _out(": ");
    _serialize(node.data);
    _out("{");
    _nl();

    final oldIndent = _indent;
    _indent = "$oldIndent  ";

    node.elements.forEach((e) => e.visit(this));

    _indent = oldIndent;
    _out("}");
    _nl();
  }

  @override
  void visitProperty<V>(FBXProperty<V> property) {
    _out(property.name);
    _out(": ");
    _serialize(property.value);
    _nl();
  }
}

abstract class FBXElement {
  String get name;
  set name(String name);

  const FBXElement();

  T visit<T>(FBXVisitor<T> visitor);
}

class FBXNode extends FBXElement {
  @override
  String name;

  final List<Object> data;
  final List<FBXElement> elements;

  FBXNode(this.name, {List<Object> data, List<FBXElement> elements})
      : this.data = data ?? <Object>[],
        this.elements = elements ?? <FBXElement>[];

  @override
  T visit<T>(FBXVisitor<T> visitor) => visitor.visitNode(this);
}

class FBXProperty<T> extends FBXElement {
  @override
  String name;

  T value;

  FBXProperty(this.name, this.value);

  @override
  VT visit<VT>(FBXVisitor<VT> visitor) => visitor.visitProperty(this);
}

class FBXHeaderExtension {
  int headerVersion = 1003;
  int version = 6100;

  FBXNode asNode() => //
      FBXNode("FBXHeaderExtension", elements: [
        FBXProperty("FBXHeaderVersion", headerVersion),
        FBXProperty("FBXVersion", version),
      ]);
}

class Definitions {
  static const int version = 100;

  final List<FBXObject> objects;

  Definitions(this.objects);

  FBXNode asNode() => //
      FBXNode(
        "Definitions",
        elements: [
          FBXProperty("Version", version),
          FBXProperty("Count", objects.length),
        ]..addAll(groupBy(objects, (FBXObject o) => o.typeName).entries.map(
              (entry) => //
                  FBXNode("ObjectType", data: [
                    entry.key
                  ], elements: [
                    FBXProperty("Count", entry.value.length),
                  ]),
            )),
      );
}

class Objects {
  final List<FBXObject> objects;

  const Objects(this.objects);

  FBXNode asNode() => //
      FBXNode("Objects", elements: objects.map((o) => o.asNode()).toList());
}

class Connections {
  final List<Connection> connections = [];

  void connect(FBXObject child, {@required FBXObject to}) =>
      connections.add(Connection(to, child));

  void connectAll(Iterable<FBXObject> children, {@required FBXObject to}) =>
      children.forEach((c) => connect(c, to: to));

  FBXNode asNode() => //
      FBXNode("Connections",
          elements: connections.map((c) => c.asProperty()).toList());
}

class Connection {
  final FBXObject parent, child;
  const Connection(this.parent, this.child);

  FBXProperty asProperty() => //
      FBXProperty("Connect", [
        "OO",
        "${child.typeName}::${child.name}",
        "${parent.typeName}::${parent.name}"
      ]);
}

abstract class FBXObject {
  const FBXObject();

  String get name;
  String get typeName;
  FBXNode asNode();
}

class Scene extends FBXObject {
  const Scene();

  String get name => "Scene";
  String get typeName => "Model";
  FBXNode asNode() => throw "Cannot serialize Scene";
}

class Model extends FBXObject {
  @override
  String name;
  ModelVertices vertices;
  ModelNormals normals; // TODO: Support multiple sets of normals
  ModelSmoothing smoothing = const ModelSmoothing.wholePolygon();

  // TODO: Actual layer system
  List<ModelVertexElement> get layerElements =>
      [normals, smoothing]..removeWhere((n) => n == null);

  Model() {
    name = "Model_$hashCode";
  }

  @override
  String get typeName => "Model";

  @override
  FBXNode asNode() => //
      FBXNode(
        "Model",
        data: ["Model::$name", "Mesh"],
        elements: (() sync* {
          if (vertices != null) yield* vertices.intoElements();
          if (normals != null) yield normals.asNode(0);
          yield smoothing.asNode(0);

          yield FBXNode(
            "Layer",
            data: [0],
            elements: [
              FBXProperty("Version", 100),
            ]..addAll(layerElements.map((e) {
                return FBXNode("LayerElement", elements: [
                  FBXProperty("Type", "LayerElement${e.typeName}"),
                  FBXProperty("TypedIndex", 0),
                ]);
              })),
          );
        })()
            .toList(),
      );
}

class ModelVertices {
  final List<double> vertices;
  final List<int> polygonVertexIndex;

  const ModelVertices(this.vertices, this.polygonVertexIndex);

  Iterable<FBXElement> intoElements() => [
        FBXProperty("Vertices", vertices),
        FBXProperty("PolygonVertexIndex", polygonVertexIndex),
      ];
}

enum MappingType { polygon, vertex }

enum ReferenceType { direct, indexToDirect }

abstract class ModelVertexElement<T> {
  String get typeName;
  String get dataPropertyName;
  String get indexPropertyName;

  int get version => 101;
  T get data;
  List<int> get index;
  MappingType get mappingType;
  ReferenceType get referenceType =>
      index != null ? ReferenceType.indexToDirect : ReferenceType.direct;

  const ModelVertexElement();

  FBXNode asNode(int layerIndex) => //
      FBXNode(
        "LayerElement$typeName",
        data: [layerIndex],
        elements: [
          FBXProperty("Version", version),
          FBXProperty(
              "MappingInformationType",
              mappingType == MappingType.polygon
                  ? "ByPolygon"
                  : "ByPolygonVertex"),
          FBXProperty(
              "ReferenceInformationType",
              referenceType == ReferenceType.direct
                  ? "Direct"
                  : "IndexToDirect"),
          FBXProperty(dataPropertyName, data),
          // TODO: Use UI-As-Code here
          index != null ? FBXProperty(indexPropertyName, index) : null,
        ]..removeWhere((e) => e == null),
      );
}

class ModelNormals extends ModelVertexElement<List<double>> {
  const ModelNormals(
    this.data, {
    this.index,
    this.mappingType = MappingType.vertex,
  });

  String get typeName => "Normal";
  String get dataPropertyName => "Normals";
  String get indexPropertyName => "NormalsIndex";

  final List<double> data;
  final List<int> index;
  final MappingType mappingType;
}

class ModelSmoothing extends ModelVertexElement<List<int>> {
  const ModelSmoothing(
    this.data, {
    this.index,
    this.mappingType = MappingType.vertex,
  });

  const ModelSmoothing.wholePolygon()
      : data = const <int>[1],
        index = null,
        mappingType = MappingType.polygon;

  String get typeName => "Smoothing";
  String get dataPropertyName => "Smoothing";
  String get indexPropertyName => "SmoothingIndex";

  final List<int> data;
  final List<int> index;
  final MappingType mappingType;
}
