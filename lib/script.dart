import 'dart:async';
import 'dart:io' show Platform;
import 'package:file/chroot.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:msktool/command.dart';
import 'package:msktool/command/base.dart';
import 'package:path/path.dart' as path;

export 'package:msktool/command/base.dart' show CommandResult;

final _internalRunner = makeCommandRunner();

Future<CommandResult> runCommand(List<String> args) =>
    _internalRunner.run(args);

void throwOnCommandError(CommandResult result) {
  if (result.exception != null) {
    throw "Command exception: ${result.exception}\n${result.stackTrace}";
  }
}

final String scriptRoot = path.canonicalize(path.join(path.fromUri(Platform.script), ".."));

final FileSystem scriptRootFS = new ChrootFileSystem(
  const LocalFileSystem(),
  scriptRoot,
);
