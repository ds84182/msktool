library msktool.command.pf.list;

import 'dart:async';
import 'package:msk_pf/msk_pf.dart';
import 'package:msktool/command/pf.dart';

class PFListCommand extends PFSubCommand {
  @override
  String get name => "list";

  @override
  String get description => "List the contents of the PFStatic.idx file.";

  @override
  List<String> get aliases => const [
    "ls", "l"
  ];

  String get path => argResults.rest.length >= 1 ? argResults.rest[0] : null;

  @override
  Future execute() async {
    var path = this.path ?? "/";
    path = pathContext.join("/", pathContext.normalize(path));
    final split = pathContext.split(path);

    printHeading("[$path]");
    indent();

    final context = await openPF();

    final data = context.handlePath(split);

    if (data == null) {
      printError("Could not find anything for directory $path");
      return;
    }

    if (data is PFEntry) {
      printError("Cannot list children of an entry");
      return;
    }

    PFContext.listFrom(data).forEach((data) {
      if (data is PFPackageHeader) {
        printInfo("${data.packageName}/");
      } else if (data is PFType) {
        printInfo("${data.name}/");
      } else if (data is PFEntry) {
        printInfo("${data.name}");
      } else {
        printWarning("Don't know how to print $data");
      }
    });
  }
}
