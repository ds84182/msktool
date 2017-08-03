library msktool.command.pf.create;

import 'dart:async';
import 'dart:math';
import 'package:file/local.dart';
import 'package:msk_pf/msk_pf.dart';
import 'package:msktool/command/pf.dart';

class PFCreateCommand extends PFSubCommand {
  @override
  String get name => "create";

  @override
  String get description => "Create a new entry and patches it with the data from the given file.";

  @override
  List<String> get aliases => const [
    "c", "cr"
  ];

  String get path => argResults.rest.length >= 1 ? argResults.rest[0] : null;
  String get source => argResults.rest.length >= 2 ? argResults.rest[1] : null;

  @override
  Future execute() async {
    var path = this.path;
    if (path == null) {
      printError("Path expected");
      return;
    }
    path = pathContext.join("/", pathContext.normalize(path));
    final split = pathContext.split(path);

    final source = this.source;
    if (source == null) {
      printError("Source expected");
      return;
    }

    printInfo("Creating $path with data from $source");

    final context = await openPF();

    final data = context.handlePath(split);

    if (data != null) {
      printError("An object already exists at $path");
      return;
    }

    final type = context.handlePath(split.take(split.length-1).toList());

    if (type != null && type is! PFType) {
      printError("Could not find parent for `$path`!");
      return;
    }

    PFEntry entry = new PFEntry()
      ..id = PFContext.createId(split.last)
      ..type = type
      ..package = (type as PFType).package;
    context.addEntry(entry);

    const fs = const LocalFileSystem();

    final sourceFile = fs.file(source);

    await context.patchEntry(entry, await sourceFile.length(), sourceFile.openRead());

    // TODO: writePF code
    final random = new Random();
    final fileId = (random.nextInt(1 << 32) << 31) | random.nextInt(1 << 32);
    final fileIdString = fileId.toRadixString(36);
    final filename = ".$fileIdString-temp.idx";
    await context.save(filename);
    await context.file(filename).rename("PFStatic.idx");
  }
}
