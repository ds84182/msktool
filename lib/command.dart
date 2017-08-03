library msktool.command;

import 'dart:async';
import 'package:args/command_runner.dart';
import 'package:msktool/command/attr.dart';
import 'package:msktool/command/base.dart';
import 'package:msktool/command/shell.dart';
import 'package:msktool/command/compile.dart';
import 'package:msktool/command/pf.dart';
import 'package:msktool/command/reload.dart';

CommandRunner makeCommandRunner({bool interactiveMode: false}) {
  final commandRunner = new MSKCommandRunner("msktool", "Tools to handle files from My Sims Kingdom.");
  commandRunner
    ..addCommand(new AttrCommand())
    ..addCommand(new PFCommand())
    ..addCommand(new CompileCommand());
  if (interactiveMode) {
    commandRunner
      ..addCommand(new ReloadCommand())
      ..addCommand(new ShellCommand());
  }
  return commandRunner;
}
