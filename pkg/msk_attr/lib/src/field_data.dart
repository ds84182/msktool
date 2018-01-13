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

  AttrField lookupField(int id) => context.lookupClassField(key, id);

  Iterable<AttrField> lookupFields() {
    return context.lookupClassFields(key);
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

class BlockCost {
  final AttrContext context;
  final int blockCollectionKey;
  final int cost;

  BlockCost(this.context, this.blockCollectionKey, this.cost);

  CollectionKey get block => new CollectionKey(context, blockCollectionKey);

  @override
  int get hashCode => blockCollectionKey ^ (cost << 1);

  @override
  bool operator ==(other) {
    if (other is BlockCost) {
      return other.context == context &&
          other.blockCollectionKey == blockCollectionKey &&
          other.cost == cost;
    }

    return false;
  }

  @override
  String toString() => "BlockCost($block, $cost)";
}

enum Interest {
  cute,
  fun,
  nature,
  spooky,
  tech,
  elegant,
  chair,
  food,
  domestic,
  sculpture,
  paint,
  bonusAll,
  bonusLimited,
}

const interestNames = const <Interest, String>{
  Interest.cute: "Cute",
  Interest.fun: "Fun",
  Interest.nature: "Nature",
  Interest.spooky: "Spooky",
  Interest.tech: "Tech",
  Interest.elegant: "Elegant",
  Interest.chair: "Chair",
  Interest.food: "Food",
  Interest.domestic: "Domestic",
  Interest.sculpture: "Sculpture",
  Interest.paint: "Paint",
  Interest.bonusAll: "BonusAll",
  Interest.bonusLimited: "BonusLimited",
};

const interestIndices = const <Interest, int>{
  Interest.cute: 0,
  Interest.fun: 1,
  Interest.nature: 2,
  Interest.spooky: 3,
  Interest.tech: 4,
  Interest.elegant: 5,
  Interest.chair: 6,
  Interest.food: 7,
  Interest.domestic: 8,
  Interest.sculpture: 9,
  Interest.paint: 10,
  Interest.bonusAll: 30,
  Interest.bonusLimited: 31,
};

Interest interestByIndex(int index) {
  if (index >= 0 && index <= 10) {
    return Interest.values[index];
  } else if (index == 30 || index == 31) {
    return Interest.values[index-30];
  } else {
    return null;
  }
}

class InterestScore {
  final Interest interest;
  final int score;

  const InterestScore(this.interest, this.score);

  @override
  int get hashCode => interest.index ^ (score << 5);

  @override
  bool operator ==(other) =>
      other is InterestScore &&
      other.interest == interest &&
      other.score == score;

  @override
  String toString() => "InterestScore(${interestNames[interest]}, $score)";
}
