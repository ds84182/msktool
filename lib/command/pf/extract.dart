library msktool.command.pf.extract;

import 'dart:async';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:msk_pf/msk_pf.dart';
import 'package:msktool/command/pf.dart';

class PFExtractCommand extends PFSubCommand {
  @override
  String get name => "extract";

  @override
  String get description => "Extracts the data from an entry to a file on the filesystem.";

  @override
  List<String> get aliases => const [
    "e", "ex"
  ];

  String get path => argResults.rest.length >= 1 ? argResults.rest[0] : null;
  String get target => argResults.rest.length >= 2 ? argResults.rest[1] : null;

  Future extractEntry(PFContext context, PFEntry entry, String target) async {
    const fs = const LocalFileSystem();

    final targetType = await fs.type(target);
    File targetFile;

    if (targetType == FileSystemEntityType.directory) {
      targetFile = fs.directory(target).childFile(entry.name);
    } else {
      targetFile = fs.file(target);
    }

    await context.readEntry(entry).pipe(targetFile.openWrite());
  }

  @override
  Future execute() async {
    var path = this.path;
    if (path == null) {
      print(" ! Path expected");
      print("");
      printUsage();
      return;
    }
    path = pathContext.join("/", pathContext.normalize(path));
    final split = pathContext.split(path);

    final target = this.target;
    if (target == null) {
      print(" ! Target expected");
      print("");
      printUsage();
      return;
    }

    print("Extracting $path to $target");

    final context = await openPF();

    final data = context.handlePath(split);

    if (data == null) {
      print(" ! Could not find $path");
      return;
    }

    if (data is PFEntry) {
      await extractEntry(context, data, target);
    } else {
      for (final data in PFContext.listFrom(data)) {
        // TODO: Recurse into other data types
        if (data is PFEntry) {
          printInfo(data.name);
          await extractEntry(context, data, pathContext.join(target, data.name));
        }
      }
      return;
    }

    print("Done");
  }
}
