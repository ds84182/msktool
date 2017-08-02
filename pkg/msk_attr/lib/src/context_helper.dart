library msk.attr.src.context_helper;

import 'dart:async';

import 'package:file/file.dart';
import 'package:msk_attr/msk_attr.dart';

Future<AttrContext> readContextFromGameRoot(Directory gameRoot, {String suffix: 'z'}) async {
  final context = new AttrContext();
  
  final gameData = gameRoot.childDirectory('GameData');
  final vaults = gameData.childDirectory('Vaults');
  
  await parseLogFile(context, vaults.childFile('attribdb$suffix.log'));
  print("Log done.");

  final bin = await vaults.childFile('attribdb$suffix.bin').open();
  await readAttrBin(context, bin);
  await bin.close();
  print("Bin done.");

  return context;
}
