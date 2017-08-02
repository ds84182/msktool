library msktool.command.attr;

import 'dart:async';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:msk_attr/msk_attr.dart';
import 'package:msktool/command/attr/list.dart';
import 'package:msktool/command/base.dart';
import 'package:path/path.dart' as p;

class AttrCommand extends MSKCommand {
  @override
  String get name => "attr";

  @override
  String get description =>
      "Command line utilities for working with attribdb files.";

  @override
  List<String> get aliases => const ["attrib"];

  String get gameRoot => argResults["root"];
  String get suffix => argResults["suffix"];

  AttrCommand() {
    addSubcommand(new AttrListCommand());

    argParser.addOption(
      "root",
      abbr: "r",
      help: "Path to the game root, the directory that contains PFStatic.idx. "
          "If not given, the current directory and upwards are searched for it.",
    );

    argParser.addOption(
        "suffix",
        abbr: 's',
        help: "Suffix of the accessed attribute database.",
        defaultsTo: "z"
    );
  }
}

p.Context pathContext = new p.Context(style: p.Style.posix);

final _pathToContextMap = <String, AttrContext>{};

abstract class AttrSubCommand extends MSKCommand {
  AttrCommand get attrCommand {
    if (parent is AttrCommand) {
      return parent;
    }
    var currentParent = parent.parent;
    while (currentParent != null && currentParent is! AttrCommand) {
      currentParent = currentParent.parent;
    }
    return currentParent;
  }

  Future<AttrContext> open() async {
    const fs = const LocalFileSystem();

    var path = attrCommand.gameRoot != null ? p.canonicalize(attrCommand.gameRoot) : null;
    final suffix = attrCommand.suffix;
    final key = "$path/\\$suffix";

    final cachedContext = _pathToContextMap[key];
    if (cachedContext != null) return cachedContext;

    Directory directory;

    if (path == null) {
      // Search upward
      directory = fs.currentDirectory;
      while (!await directory.childFile("PFStatic.idx").exists()) {
        directory = directory.parent;
      }
    } else {
      directory = fs.directory(path);
    }

//    File pfstatic = directory.childFile(name);
//
//    if (!await pfstatic.exists()) {
//      throw "Could not find $name in directory ${directory.uri}";
//    }

    final context = await readContextFromGameRoot(directory, suffix: suffix);
    _pathToContextMap[key] = context;
    return context;
  }
}
