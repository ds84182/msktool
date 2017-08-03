library msktool.command.pf.fix;

import 'dart:async';
import 'dart:math';
import 'package:msktool/command/pf.dart';

class PFFixCommand extends PFSubCommand {
  @override
  String get name => "fix";

  @override
  String get description => "Fixes the PFStatic file data.";

  @override
  List<String> get aliases => const [
    "f", "fi"
  ];

  @override
  Future execute() async {
    final context = await openPF();
    context.fix();

    // TODO: writePF code
    final random = new Random();
    final fileId = (random.nextInt(1 << 32) << 31) | random.nextInt(1 << 32);
    final fileIdString = fileId.toRadixString(36);
    final filename = ".$fileIdString-temp.idx";
    await context.save(filename);
    await context.file(filename).rename("PFStatic.idx");
  }
}
