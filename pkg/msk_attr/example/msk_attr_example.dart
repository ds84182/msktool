// Copyright (c) 2017, dwayne. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:file/local.dart';
import 'package:msk_attr/msk_attr.dart';
import 'package:msk_attr/src/attr_bin.dart';
import 'package:msk_attr/src/attr_id_hash.dart';

const fs = const LocalFileSystem();

main(List<String> args) async {
  final context = new AttrContext();
  await parseLogFile(context, fs.file(args[0]));

  print("");
  print("Classes: ${context.classes.length}");
  print("Seen Types: ${context.types.length}");
  print("Collections: ${context.classes.fold(0, (a, b) => a + context.lookupCollections(b.id).length)}");

  final context2 = new AttrContext();
  await readAttrVault(context2, fs.file(args[1]).openSync());

  print("Vault Classes: ${context2.classes.length}");
  print("Vault Types: ${context2.types.length}");

  await readAttrBin(context, fs.file(args[2]).openSync());

  context.lookupCollection(attrId("grass"), attrId("grass_animal02")).fields.forEach(print);

  print(attrId("ChildRefSpec").toRadixString(16));
  print(attrId("ChildRefSpecs").toRadixString(16));
  print(attrId("ChildRefSpecs_0x00000000").toRadixString(16));
  print(attrId("ChildRefSpecs[0006]").toRadixString(16));

  print(attrId("_0x00000000").toRadixString(16));
  print(attrId("[00000]").toRadixString(16));
  print(attrId("=:+-#").toRadixString(16));

  print(attrIdArrayIndex(attrId("ChildRefSpecs"), 0).toRadixString(16));
  print(attrId("ChildRefSpecs[00000]").toRadixString(16));
}
