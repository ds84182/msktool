library msktool.command.base;

import 'dart:async';
import 'dart:io';
import 'package:args/args.dart';
import 'package:args/command_runner.dart';

enum CommandOutputType { heading, info, error, warning }

const commandOutputTypePrefix = const {
  CommandOutputType.heading: "-",
  CommandOutputType.info: "*",
  CommandOutputType.warning: "~",
  CommandOutputType.error: "!",
};

class CommandOutput {
  final CommandOutputType type;
  final int indent;
  final String data;

  const CommandOutput(this.type, this.data, {this.indent: 0});

  String format({int width}) {
    final prefix = " " + ("  " * indent) + commandOutputTypePrefix[type] + " ";
    final prefixLength = prefix.length;
    final blankPrefix = " " * prefixLength;
    var lines = data.split('\n');

    if (width != null) {
      final actualWidth = width - prefixLength;
      lines = lines.expand((str) sync* {
        if (str.length <= actualWidth) {
          yield str;
        } else {
          int i = 0;
          while (str.length-i > actualWidth) {
            yield str.substring(i, i + actualWidth);
            i += actualWidth;
          }
          if (i <= str.length) {
            yield str.substring(i);
          }
        }
      }).toList();
    }

    lines[0] = prefix + lines[0];
    for (int i = 1; i < lines.length; i++) {
      lines[i] = blankPrefix + lines[i];
    }

    return lines.join("\n");
  }
}

class CommandResult<T> {
  Type get type => T;

  T data;

  Object exception;
  StackTrace stackTrace;

  List<CommandOutput> output = [];
}

abstract class MSKCommand<T> extends Command<CommandResult<T>> {
  CommandResult<T> _pendingResult;
  int _indent = 0;

  void output(CommandOutput out) {
    _pendingResult.output.add(out);

    if (runner is MSKCommandRunner) {
      (runner as MSKCommandRunner).handleOutput(out);
    }
  }

  indent() => _indent += 1;
  unindent() => _indent -= 1;

  void printHeading(value) {
    output(new CommandOutput(
      CommandOutputType.heading,
      value.toString(),
      indent: _indent,
    ));
  }

  void printInfo(value) {
    output(new CommandOutput(
      CommandOutputType.info,
      value.toString(),
      indent: _indent,
    ));
  }

  void printWarning(value) {
    output(new CommandOutput(
      CommandOutputType.warning,
      value.toString(),
      indent: _indent,
    ));
  }

  void printError(value) {
    output(new CommandOutput(
      CommandOutputType.error,
      value.toString(),
      indent: _indent,
    ));
  }

  @override
  Future<CommandResult<T>> run() async {
    _pendingResult = new CommandResult<T>();

    try {
      _pendingResult.data = await execute();
    } catch (ex, stack) {
      _pendingResult.exception = ex;
      _pendingResult.stackTrace = stack;
    }
    return _pendingResult;
  }

  FutureOr<T> execute() {
    throw "Leaf command $runtimeType forgot to override execute.";
  }
}

class MSKCommandRunner extends CommandRunner<CommandResult> {
  MSKCommandRunner(String executableName, String description)
      : super(executableName, description);

  void handleOutput(CommandOutput output) {
    final width = stdout.hasTerminal ? stdout.terminalColumns : null;

    if (output.type == CommandOutputType.warning ||
        output.type == CommandOutputType.error) {
      stderr.writeln(output.format(width: width));
    } else {
      stdout.writeln(output.format(width: width));
    }
  }

  @override
  Future<CommandResult> runCommand(ArgResults topLevelResults) async {
    final result = await super.runCommand(topLevelResults);

    if (result != null && result.exception != null) {
      print(result.exception);
      print(result.stackTrace);
    }

    return result;
  }
}
