library msktool.command.attr.list;

import 'dart:async';
import 'package:msk_attr/msk_attr.dart';
import 'package:msk_attr/src/attr_id_hash.dart'; // TODO: Export me!
import 'package:msktool/command/attr.dart';

class AttrListCommand extends AttrSubCommand {
  @override
  String get description => "Lists some things. TODO: Desc here.";

  @override
  String get name => "list";

  @override
  List<String> get aliases => const ["ls", "l"];

  @override
  Future execute() async {
    final path = argResults.rest.isEmpty ? '' : argResults.rest.first;

    handlePath(path, await open());
  }

  void handlePath(String path, AttrContext context) {
    final split = path.trim().split(':');

    if (split.length == 1 && split.first.isEmpty) {
      // List all classes
      printHeading("Classes:");
      indent();
      context.classes.forEach((clazz) {
        printInfo(context.lookupName(clazz.id));
      });
      unindent();
    } else if (split.length == 1) {
      // List all fields and collections

      final classId = attrId(split[0]);

      printHeading("Fields:");
      indent();
      context.lookupClassFields(classId).forEach((field) {
        printInfo(
            "${context.lookupName(field.id)} ${context.lookupName(field.type.id)} ${field.flags}");
      });
      unindent();

      printHeading("Collections:");
      indent();
      context.lookupCollections(classId).forEach((collection) {
        printInfo(context.lookupName(collection.id));
      });
      unindent();
    } else if (split.length == 2) {
      // List all fields defined in the collection (and useful data)
      final classId = attrId(split[0]);
      final collectionId = attrId(split[1]);

      final collection = context.lookupCollection(classId, collectionId);

      printInfo(
          "Parent: ${context.lookupName(collection.parent)} ${collection.parent}");
      printInfo("Flags: ${collection.flags}");

      final children = context
          .lookupCollections(classId)
          .where((c) => c.parent == collectionId)
          .toList(growable: false);

      if (children.isNotEmpty) {
        printHeading("Children:");
        indent();
        children.forEach((child) {
          final childRefSpec = new RefSpec.fromCollection(context, child);
          printInfo("$childRefSpec");
        });
        unindent();
      }

      printHeading("Fields:");
      indent();
      collection.fields.forEach((collectionField) {
        final field = context.lookupClassField(classId, collectionField.id);

        if (field != null) {
          printInfo("${context.lookupName(collectionField.id)}: "
              "${AttrCollectionHelper.readField(
                  context, collection, field)}");
        } else {
          printInfo(
              "${context.lookupName(collectionField.id) ?? collectionField.id}: ${collectionField.inlineData}");
        }
      });
      unindent();
    }
  }
}
