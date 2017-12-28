import 'dart:io';
import 'package:msktool/scripting_commands.dart' as command;
import 'package:msktool/script.dart';
import 'package:path/path.dart' as path;

String bin2lua(List<int> bytes) => bytes.map((byte) => "\\$byte").join();

main() async {
  final commonPath = path.join(scriptRoot, "Common.luac");
  final commonFile = new File(commonPath);
  final evalClientScriptPath = path.join(scriptRoot, "eval_client.lua");
  final evalClientPath = path.join(scriptRoot, "eval_client-ppc.luac");
  final evalClientFile = new File(evalClientPath);
  final finalCommonScriptPath = path.join(scriptRoot, "final_common.lua");
  final finalCommonScriptFile = new File(finalCommonScriptPath);
  final finalCommonPath = path.join(scriptRoot, "final_common-ppc.luac");

  await command.compile([
    evalClientScriptPath,
  ]).then(throwOnCommandError);

  if (!await commonFile.exists())
    await runCommand(
            ["pf", "extract", "/WiiLuaFinal/LuaObjectData/Common", commonPath])
        .then(throwOnCommandError);

  // Create a script that runs both Common AND eval_client using loadstring:

  final finalCommonScript = """
loadstring("${bin2lua(await commonFile.readAsBytes())}", "=Common")()
loadstring("${bin2lua(await evalClientFile.readAsBytes())}", "=eval_client")()
""";

  await finalCommonScriptFile.writeAsString(finalCommonScript);

  await command.compile([
    finalCommonScriptPath,
  ]).then(throwOnCommandError);

  await runCommand([
    "pf",
    "patch",
    "/WiiLuaFinal/LuaObjectData/Common",
    finalCommonPath,
  ]).then(throwOnCommandError);
}
