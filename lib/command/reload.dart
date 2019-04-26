library msktool.command.reload;

import 'dart:developer';
import 'dart:isolate';
import 'package:msktool/command/base.dart';
import 'package:vm_service_lib/vm_service_lib_io.dart';

class ReloadCommand extends MSKCommand {
  @override
  String get description => "Hot-reloads the tool to pick up source code changes.";

  @override
  String get name => "reload";

  @override
  execute() async {
    final service = await Service.controlWebServer(enable: true);
    final client = await vmServiceConnectUri(service.serverUri.toString());
    final report = await client.reloadSources(Service.getIsolateID(Isolate.current));

    if (report.success) {
      printInfo("Done.");
    } else {
      printError(report.json);
    }

    client.dispose();
  }
}
