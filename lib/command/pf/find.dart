library msktool.command.pf.find;

import 'dart:async';
import 'package:msk_pf/msk_pf.dart';
import 'package:msktool/command/pf.dart';

class PFFindCommand extends PFSubCommand {
  @override
  String get name => "find";

  @override
  String get description => "Finds an entry in the PFStatic.idx file.";

  String get entryName => argResults.rest.length >= 1 ? argResults.rest[0] : null;

  @override
  Future execute() async {
    var entryName = this.entryName;

    printHeading("[$entryName]");
    indent();

    final context = await openPF();

    context.findAllEntries(entryName).forEach((entry) {
      printInfo(PFContext.makePath(entry).join("/"));
    });
  }
}
