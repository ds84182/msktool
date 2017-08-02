library msk.attr.src.attr_context;

import 'attr_data.dart';
import 'attr_id_hash.dart';
import 'package:msk_attr/src/attr_field_parser.dart' as fieldParser;

class AttrNameManager {
  final Map<int, String> _hashToName = {};

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
      });
    } else {
      precomputedHash = calculateHash1(name.codeUnits);
    }

    String existingName = _hashToName[precomputedHash];

    if (existingName == null) {
      _hashToName[precomputedHash] = name;
    } else {
      assert(() => existingName.toLowerCase() == name.toLowerCase());
    }
  }

  String lookupName(int hash) {
    return _hashToName[hash];
  }
}

class AttrClassManager {
  final Map<int, _AttrClassMetadata> _classes = {};

  Iterable<AttrClass> get classes =>
      _classes.values.map((meta) => meta.attrClass);

  void addClass(AttrClass clazz) {
    _classes[clazz.id] = new _AttrClassMetadata(clazz);
  }

  void addFieldsToClass(int classId, Iterable<AttrField> fields) {
    fields.forEach(_classes[classId].addField);
  }

  void addCollectionsToClass(
      int classId, Iterable<AttrCollection> collections) {
    collections.forEach(_classes[classId].addCollection);
  }

  AttrClass lookupClass(int id) {
    return _classes[id]?.attrClass;
  }

  AttrField lookupClassField(int classId, int fieldId) {
    return _classes[classId].fieldMap[fieldId];
  }

  Iterable<AttrField> lookupClassFields(int classId) {
    return _classes[classId].fieldMap.values;
  }

  AttrCollection lookupCollection(int classId, int collectionId) {
    return _classes[classId]?.collectionMap[collectionId];
  }

  Iterable<AttrCollection> lookupCollections(int classId) {
    return _classes[classId].collectionMap.values;
  }
}

class _AttrClassMetadata {
  AttrClass attrClass;
  Map<int, AttrField> fieldMap = {};
  Map<int, AttrCollection> collectionMap = {};

  _AttrClassMetadata(this.attrClass);

  void addField(AttrField field) {
    fieldMap[field.id] = field;
  }

  void addCollection(AttrCollection collection) {
    collectionMap[collection.id] = collection;
  }
}

class AttrTypeManager {
  final Map<int, AttrType> _types = {};

  Iterable<AttrType> get types => _types.values;

  AttrType lookupType(int id) {
    return _types[id];
  }

  AttrType lookupOrCreateType(int id, int size) {
    final type = _types.putIfAbsent(
        id,
        () => new AttrType(
              id: id,
              size: size,
            ));

    if (type.size != size) {
      throw "Sizes aren't equal, given: $size already have: ${type.size}";
    }

    return type;
  }
}

class AttrStringTableManager {
  final Map<int, String> _stringTable = {};

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
    final collectionField = collection.fields
        .firstWhere((cfield) => cfield.id == field.id, orElse: () => null);

    if (collectionField != null) {
      if (collectionField.decodedData != null) {
        // return collectionField.decodedData;
      }

      return collectionField.decodedData = fieldParser.readField(
          context, field, collection, collectionField);
    }

    if (collection.parent != collection.id) {
      final parentCollection =
          context.lookupCollection(collection.classId, collection.parent);

      if (parentCollection != null) {
        return readField(context, parentCollection, field);
      }
    }

    return null;
  }
}

class AttrContext = Object
    with
        AttrClassManager,
        AttrNameManager,
        AttrTypeManager,
        AttrStringTableManager;
