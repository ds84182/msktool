library msktool.scripting_commands;

import 'dart:async';

import 'package:msktool/script.dart';

Future<CommandResult> compile(List<String> files) {
  return runCommand(files.toList()..insert(0, 'compile'));
}
