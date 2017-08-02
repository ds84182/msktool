library msktool.command.compile;

import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:msktool/command/base.dart';
import 'package:path/path.dart' as p;

class CompileCommand extends MSKCommand {
  @override
  String get description => "Compiles a Lua source file for PPC Big Endian.";

  @override
  String get name => "compile";

  @override
  Future execute() async {
    if (argResults.rest.isEmpty) {
      throw "No scripts specified.";
    }

    printHeading("Compiling ${argResults.rest.length} scripts...");
    indent();
    var futures = argResults.rest.map((inputPath) async {
      final path = p.canonicalize(inputPath);
      final name = p.basenameWithoutExtension(path);
      final directory = p.dirname(path);

      final result = await Process.run("luac", [
        '-o',
        p.join(directory, '$name-native.luac'),
        path,
      ]);

      if (result.exitCode != 0) {
        printError("An error occurred when compiling '$inputPath' to native code:\n"
            "\n"
            "${result.stderr}");
        return null;
      }

      return inputPath;
    });

    final successfulCompiles = (await Future.wait(futures))
        .where((s) => s != null)
        .toList();

    unindent();

    if (successfulCompiles.isEmpty) {
      printError("All scripts failed to compile.");
      return;
    }

    printHeading("Retargeting ${successfulCompiles.length} scripts to PPC...");
    indent();
    futures = successfulCompiles.map((inputPath) async {
      // PowerPC Lua 5.1:
      // @v51ebi04s04o04f04

      final path = p.canonicalize(inputPath);
      final name = p.basenameWithoutExtension(path);
      final directory = p.dirname(path);

      final result = await Process.run("lua5.3", [
        'convert_bytecode.lua',
        p.join(directory, '$name-native.luac'),
        '@v51ebi04s04o04f04',
      ], workingDirectory: p.canonicalize("/home/dwayne/luavmgit/LuaVM"));

      if (result.exitCode != 0) {
        printError("An error occurred while retargeting $inputPath to PPC:\n"
            "\n"
            "${result.stderr}");
        return null;
      }

      // Rename the file
      await new File(p.join(directory, "$name-native.luac-conv.bc"))
          .rename(p.join(directory, "$name-ppc.luac"));

      return inputPath;
    });

    final successfulRetargets = (await Future.wait(futures))
        .where((s) => s != null)
        .toList();

    unindent();

    if (successfulRetargets.isEmpty) {
      printError("All scripts failed to retarget to PPC.");
      return;
    }

    if (successfulRetargets.length != argResults.rest.length) {
      printWarning("Some scripts failed to compile or retarget.");
    }
  }
}
