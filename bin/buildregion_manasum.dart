library msktool.buildregion_manasum;

import 'dart:async';
import 'dart:io';

import 'package:file/local.dart';
import 'package:msk_attr/msk_attr.dart';

const lfs = const LocalFileSystem();

Future main() async {
  final context = await readContextFromGameRoot(lfs.currentDirectory);

  T readField<T>(AttrCollection collection, String name) {
    return AttrCollectionHelper.readField(context, collection,
        context.lookupClassField(collection.classId, attrId(name)));
  }

  AttrCollection lookup(RefSpec refSpec) => refSpec.lookup();

  final buildableRegionClass = new ClassKey.byName(context, "buildable_region");
  final blockClass = new ClassKey.byName(context, "block");

  buildableRegionClass.lookupCollections().forEach((collection) {
    final collectionRefSpec = new RefSpec.fromCollection(context, collection);
    final children = readField<List<RefSpec>>(collection, "ChildRefSpecs");

    if (children != null) {
      print(" - $collectionRefSpec:");

      Iterable<RefSpec> childrenOfClass(ClassKey clazz) =>
          children.where((rs) => rs.classKey == clazz.key);

      int sum = 0;
      int needed = 0;

      childrenOfClass(blockClass).forEach((refspec) {
        final collection = lookup(refspec);

        bool ghost = readField(collection, "GhostedBlock");
        bool deletable = readField(collection, "IsDeletable");
        int cost = readField(collection, "Cost") ?? 0;

        print(
            "    - $refspec { ghost: $ghost, deletable: $deletable, cost: $cost }");

        if (deletable && !ghost) {
          sum += cost;
        }

        if (ghost) {
          needed += -cost;
        }
      });

      print("   Sum: $sum, Needed: $needed");
    }
  });
}
