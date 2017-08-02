library msktool.command.pf;

import 'dart:async';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:msk_pf/msk_pf.dart';
import 'package:msktool/command/base.dart';
import 'package:msktool/command/pf/create.dart';
import 'package:msktool/command/pf/extract.dart';
import 'package:msktool/command/pf/find.dart';
import 'package:msktool/command/pf/fix.dart';
import 'package:msktool/command/pf/list.dart';
import 'package:msktool/command/pf/patch.dart';
import 'package:msktool/command/pf/stat.dart';
import 'package:path/path.dart' as p;

class PFCommand extends MSKCommand {
  @override
  String get name => "pf";

  @override
  String get description =>
      "Command line utilities for working with PFStatic.idx files.";

  @override
  List<String> get aliases => const ["pfstatic"];

  String get pfDir => argResults["pfdir"];
  String get pfName => argResults["pfname"];

  PFCommand() {
    addSubcommand(new PFListCommand());
    addSubcommand(new PFStatCommand());
    addSubcommand(new PFExtractCommand());
    addSubcommand(new PFPatchCommand());
    addSubcommand(new PFCreateCommand());
    addSubcommand(new PFFixCommand());
    addSubcommand(new PFFindCommand());

    argParser.addOption(
      "pfdir",
      abbr: "p",
      help: "Path to directory that contains PFStatic.idx. "
          "If not given, the current directory and upwards are searched for it.",
    );

    argParser.addOption(
      "pfname",
      help: "Name of the PFStatic.idx file to work on.",
      defaultsTo: "PFStatic.idx"
    );
  }
}

p.Context pathContext = new p.Context(style: p.Style.posix);

final _pathToContextMap = <String, PFContext>{};

abstract class PFSubCommand extends MSKCommand {
  PFCommand get pfCommand {
    if (parent is PFCommand) {
      return parent;
    }
    var currentParent = parent.parent;
    while (currentParent != null && currentParent is! PFCommand) {
      currentParent = currentParent.parent;
    }
    return currentParent;
  }

  Future<PFContext> openPF() async {
    const fs = const LocalFileSystem();

    var path = pfCommand.pfDir != null ? p.canonicalize(pfCommand.pfDir) : null;
    final name = pfCommand.pfName;
    final key = "$path/\\$name";

    final cachedContext = _pathToContextMap[key];
    if (cachedContext != null) return cachedContext;

    Directory directory;

    if (path == null) {
      // Search upward
      directory = fs.currentDirectory;
      while (!await directory.childFile(name).exists()) {
        directory = directory.parent;
      }
    } else {
      directory = fs.directory(path);
    }

    File pfstatic = directory.childFile(name);

    if (!await pfstatic.exists()) {
      throw "Could not find $name in directory ${directory.uri}";
    }

    final context = new PFContext(directory);
    _pathToContextMap[key] = context;
    await context.open(name);
    return context;
  }
}
