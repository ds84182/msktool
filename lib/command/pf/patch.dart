library msktool.command.pf.patch;

import 'dart:async';
import 'dart:math';
import 'package:file/local.dart';
import 'package:msk_pf/msk_pf.dart';
import 'package:msktool/command/pf.dart';

class PFPatchCommand extends PFSubCommand {
  @override
  String get name => "patch";

  @override
  String get description => "Patches an entry to contain the data within the given file.";

  @override
  List<String> get aliases => const [
    "p", "pc"
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

    printInfo("Patching $path with $source");

    final context = await openPF();

    final data = context.handlePath(split);

    if (data == null) {
      printError("Could not find $path");
      return;
    }

    if (data is! PFEntry) {
      printError("Object at path `$path` is not an entry!");
      return;
    }

    PFEntry entry = data;

    const fs = const LocalFileSystem();

    final sourceFile = fs.file(source);

    await context.patchEntry(entry, await sourceFile.length(), sourceFile.openRead());

    final random = new Random();
    final fileId = (random.nextInt(1 << 32) << 31) | random.nextInt(1 << 32);
    final fileIdString = fileId.toRadixString(36);
    final filename = ".$fileIdString-temp.idx";
    await context.save(filename);
    await context.fs.file(filename).rename("PFStatic.idx");
  }
}
