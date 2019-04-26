library msktool.command.shell;

import 'dart:io';

import 'package:msktool/command/base.dart';

class ShellCommand extends MSKCommand {
  @override
  String get description => "Runs a shell command";

  @override
  String get name => "shell";

  @override
  execute() async {
    final process = await Process.start("sh", ["-c", argResults.rest.join(" ")], runInShell: true);

    final stderrSub = process.stderr.listen(stderr.add);
    final stdoutSub = process.stdout.listen(stdout.add);
    // final stdinSub = stdin.listen(process.stdin.add);

    await process.exitCode;

    await stderrSub.cancel();
    await stdoutSub.cancel();
    // await stdinSub.cancel();
  }
}
