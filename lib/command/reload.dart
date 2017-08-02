library msktool.command.reload;

import 'dart:async';
import 'dart:developer';
import 'package:args/command_runner.dart';
import 'package:msktool/command/base.dart';
import 'package:vm_service_client/vm_service_client.dart';

class ReloadCommand extends MSKCommand {
  @override
  String get description => "Hot-reloads the tool to pick up source code changes.";

  @override
  String get name => "reload";

  @override
  execute() async {
    final service = await Service.controlWebServer(enable: true);
    final client = new VMServiceClient.connect(service.serverUri);
    final vm = await client.getVM();
    final VMRunnableIsolate isolate = await new Stream.fromIterable(vm.isolates)
        .asyncMap((ref) => ref.loadRunnable())
        .firstWhere((ref) => ref.rootLibrary.name == "msktool.bin");
    final report = await isolate.reloadSources();

    if (report.status) {
      printInfo("Done.");
    } else {
      printError(report.status);
    }

    await client.close();
  }
}
