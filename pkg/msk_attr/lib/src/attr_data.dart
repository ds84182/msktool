/// Data structures to describe attribute classes, collections, and their fields.
library msk.attr.attr_data;

import 'dart:typed_data';

/// Flags applied to classes, fields, and collections.
enum AttrFlag {
  importable,
  forced,
  readOnly,
  inheritable,
  ignoreRefCount,
  array,
  fixedArray,
  serializable,
  cloneable,
  autoGenerated,
}

/// Describes the type and size of an [AttrField].
class AttrType {
  int id;
  int size;

  AttrType({this.id, this.size});
}

/// Describes a piece of data defined for an [AttrClass].
class AttrField {
  int id;
  AttrType type;
  Set<AttrFlag> flags;

  AttrField({this.id, this.type, this.flags});

  int get size => type.size;
}

/// Describes the expected data layout for some [AttrCollection]s.
class AttrClass {
  int id;
  Set<AttrFlag> flags;

  AttrClass({this.id, this.flags});
}

/// An instance of an [AttrClass], which carries data and can inherit from other
/// [AttrCollection]s.
class AttrCollection {
  int classId;
  int id;
  int parent;
  Set<AttrFlag> flags;
  List<AttrCollectionField> fields = [];

  AttrCollection({this.classId, this.id, this.parent, this.flags});
}

/// A field in an [AttrCollection].
class AttrCollectionField {
  int id;
  int inlineData;
  int staticDataLength;
  ByteData data;
  dynamic decodedData;

  AttrCollectionField({this.id, this.inlineData, this.staticDataLength, this.data});
}
