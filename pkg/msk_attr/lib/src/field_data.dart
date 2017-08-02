library msk.attr.src.field_data;

import 'package:msk_attr/src/attr_context.dart';
import 'package:msk_attr/src/attr_data.dart';
import 'package:msk_attr/src/attr_id_hash.dart';

String _hex(int i) => i.toRadixString(16).toUpperCase().padLeft(8, '0');

class Key {
  final AttrContext context;
  final int key;

  Key(this.context, this.key);
  Key.byName(this.context, String name) : key = attrId(name);

  @override
  int get hashCode => key;

  @override
  bool operator ==(other) {
    if (other.runtimeType == runtimeType) {
      final Key typedOther = other;
      return typedOther.context == context && typedOther.key == key;
    }

    return false;
  }

  @override
  String toString() => context.lookupName(key) ?? _hex(key);
}

class ClassKey extends Key {
  ClassKey(AttrContext context, int key) : super(context, key);
  ClassKey.byName(AttrContext context, String name)
      : super.byName(context, name);

  RefSpec withCollection(collection) {
    if (collection is int) {
      return new RefSpec(context, key, collection);
    } else if (collection is String) {
      return new RefSpec(context, key, attrId(collection));
    } else if (collection is CollectionKey) {
      return new RefSpec(context, key, collection.key);
    } else {
      throw new ArgumentError.value(
          collection, "int, String, or CollectionKey expected");
    }
  }

  AttrClass lookup() {
    return context.lookupClass(key);
  }

  Iterable<AttrCollection> lookupCollections() =>
      context.lookupCollections(key);
}

class CollectionKey extends Key {
  CollectionKey(AttrContext context, int key) : super(context, key);
  CollectionKey.byName(AttrContext context, String name)
      : super.byName(context, name);

  RefSpec withClass(clazz) {
    if (clazz is int) {
      return new RefSpec(context, clazz, key);
    } else if (clazz is String) {
      return new RefSpec(context, attrId(clazz), key);
    } else if (clazz is ClassKey) {
      return new RefSpec(context, clazz.key, key);
    } else {
      throw new ArgumentError.value(clazz, "int, String, or ClassKey expected");
    }
  }

  Iterable<AttrCollection> lookupAll() {
    return context.classes
        .map((clazz) => context.lookupCollection(clazz.id, key))
        .where((collection) => collection != null);
  }
}

class RefSpec {
  final AttrContext context;
  final int classKey;
  final int collectionKey;

  RefSpec(this.context, this.classKey, this.collectionKey);

  RefSpec.byName(this.context, String className, String collectionName)
      : classKey = attrId(className),
        collectionKey = attrId(collectionName);

  RefSpec.fromCollection(this.context, AttrCollection collection)
      : classKey = collection.classId,
        collectionKey = collection.id;

  ClassKey get classOnly => new ClassKey(context, classKey);
  CollectionKey get collectionOnly => new CollectionKey(context, collectionKey);

  AttrCollection lookup() {
    return context.lookupCollection(classKey, collectionKey);
  }

  @override
  int get hashCode => ((classKey << 1) ^ collectionKey) >> 1;

  @override
  bool operator ==(other) {
    if (other.runtimeType == runtimeType) {
      final RefSpec typedOther = other;
      return typedOther.context == context &&
          typedOther.classKey == classKey &&
          typedOther.collectionKey == collectionKey;
    }

    return false;
  }

  @override
  String toString() =>
      (context.lookupName(classKey) ?? _hex(classKey)) +
      ":" +
      (context.lookupName(collectionKey) ?? _hex(collectionKey));
}
