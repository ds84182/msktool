library msk.attr.src.attr_context;

import 'attr_data.dart';
import 'attr_id_hash.dart';
import 'dart:typed_data';
import 'package:msk_attr/src/attr_field_parser.dart' as fieldParser;

class AttrNameManager {
  final Map<int, String> _hashToName = <int, String>{};

  void addName(String name, [int precomputedHash]) {
    if (precomputedHash != null) {
      assert(() {
        int calculatedHash = calculateHash1(name.codeUnits);
        if (precomputedHash != calculatedHash) {
          String h(int id) => id.toRadixString(16).padLeft(8, '0');
          print(
              "The precomputed hash (${h(precomputedHash)}) does not match the calculated hash ${h(calculatedHash)} for the string '$name'");
          return false;
        }
        return true;
      } ());
    } else {
      precomputedHash = calculateHash1(name.codeUnits);
    }

    String existingName = _hashToName[precomputedHash];

    if (existingName == null) {
      _hashToName[precomputedHash] = name;
    } else {
      assert(() {
        return existingName.toLowerCase() == name.toLowerCase();
      } ());
    }
  }

  String lookupName(int hash) {
    return _hashToName[hash];
  }
}

class AttrClassManager {
  final Map<int, _AttrClassMetadata> _classes = <int, _AttrClassMetadata>{};
  final List<_AttrClassMetadata> _classList = <_AttrClassMetadata>[];
  Uint32List _classIds;
  int _classCount = 0;

  Iterable<AttrClass> get classes =>
      _classes.values.map((meta) => meta.attrClass);

  void addClass(AttrClass clazz) {
    _classList.add(_classes[clazz.id] = new _AttrClassMetadata(clazz));
  }

  void addFieldsToClass(int classId, Iterable<AttrField> fields) {
    fields.forEach(_classes[classId].addField);
  }

  void addCollectionsToClass(
      int classId, Iterable<AttrCollection> collections) {
    collections.forEach(_classes[classId].addCollection);
  }

  _AttrClassMetadata _lookupMetadata(int id) {
    if (_classIds != null) {
      int min = 0;
      int max = _classCount;
      while (min < max) {
        int mid = min + ((max - min) >> 1);
        int element = _classIds[mid];
        if (element == id) return _classList[mid];
        if (element < id) {
          min = mid + 1;
        } else {
          max = mid;
        }
      }
      return null;
    } else {
      return _classes[id];
    }
  }

  AttrClass lookupClass(int id) {
    return _lookupMetadata(id).attrClass;
  }

  AttrField lookupClassField(int classId, int fieldId) {
    return _lookupMetadata(classId).fieldMap[fieldId];
  }

  Iterable<AttrField> lookupClassFields(int classId) {
    return _lookupMetadata(classId).fieldMap.values;
  }

  AttrCollection lookupCollection(int classId, int collectionId) {
    return _lookupMetadata(classId).lookupCollection(collectionId);
  }

  Iterable<AttrCollection> lookupCollections(int classId) {
    return _lookupMetadata(classId)._collectionList;
  }

  void finalize() {
//    _classCount = _classList.length;
//    _classIds = new Uint32List(_classCount);
//    for (int i = 0; i < _classCount; i++) {
//      final meta = _classList[i]..finalize();
//      _classIds[i] = meta.attrClass.id;
//    }
    _classList.forEach((meta) => meta.finalize());
  }
}

class _AttrClassMetadata {
  final AttrClass attrClass;
  final Map<int, AttrField> fieldMap = <int, AttrField>{};
  final Map<int, AttrCollection> collectionMap = <int, AttrCollection>{};
  final List<AttrCollection> _collectionList = <AttrCollection>[];
  Uint32List _collectionIds;
  int _collectionCount = 0;

  _AttrClassMetadata(this.attrClass);

  void addField(AttrField field) {
    fieldMap[field.id] = field;
  }

  void addCollection(AttrCollection collection) {
    collectionMap[collection.id] = collection;
    _collectionList.add(collection);
  }

  AttrCollection lookupCollection(int id) {
    if (_collectionIds != null) {
      int min = 0;
      int max = _collectionCount;
      while (min < max) {
        int mid = min + ((max - min) >> 1);
        int element = _collectionIds[mid] - id;
        if (element == 0)
          return _collectionList[mid];
        if (element < 0) {
          min = mid + 1;
        } else {
          max = mid;
        }
      }
      return null;
    } else {
      return collectionMap[id];
    }
  }

  void finalize() {
    _collectionCount = collectionMap.length;
    _collectionIds = new Uint32List(_collectionCount);
    for (int i = 0; i < _collectionCount; i++) {
      _collectionIds[i] = _collectionList[i].id;
    }
  }
}

class AttrTypeManager {
  final Map<int, AttrType> _types = <int, AttrType>{};

  Iterable<AttrType> get types => _types.values;

  AttrType lookupType(int id) {
    return _types[id];
  }

  AttrType lookupOrCreateType(int id, int size) {
    // TODO: Reuse types from known_types.dart
    final type = _types.putIfAbsent(id, () => new AttrType.raw(id, size));

    if (type.size != size) {
      throw "Sizes aren't equal, given: $size already have: ${type.size}";
    }

    return type;
  }
}

class AttrStringTableManager {
  final Map<int, String> _stringTable = <int, String>{};

  void addStringTableEntry(int hash, String string) {
    _stringTable[hash] = string;
  }

  String lookupString(int hash) {
    return _stringTable[hash];
  }
}

abstract class AttrCollectionHelper {
  static dynamic readField(
      AttrContext context, AttrCollection collection, AttrField field) {
    while (true) {
      final collectionField = collection.lookupField(field.id);

      if (collectionField != null) {
        return collectionField.decodedData ??=
            fieldParser.readField(context, field, collection, collectionField);
      }

      if (collection.parent != null &&
          collection.parent != 0 &&
          collection.parent != collection.id) {
        final parentCollection =
            context.lookupCollection(collection.classId, collection.parent);

        if (parentCollection != null) {
          collection = parentCollection;
          continue;
        }
      }

      return null;
    }
  }
}

// TODO: AttrContextBuilder, so we can have optimized lookups elsewhere

class AttrContext = Object
    with
        AttrClassManager,
        AttrNameManager,
        AttrTypeManager,
        AttrStringTableManager;
