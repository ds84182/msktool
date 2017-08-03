import 'dart:io';
import 'package:msktool/scripting_commands.dart' as command;
import 'package:msktool/script.dart';
import 'package:path/path.dart' as path;

main() async {
  await command.compile([
    path.join(scriptRoot, "eval_client.lua"),
  ]).then(throwOnCommandError);

  final commonPath = path.join(scriptRoot, "Common.luac");

  if (!new File(commonPath).existsSync())
    await runCommand(
            ["pf", "extract", "/WiiLuaFinal/LuaObjectData/Common", commonPath])
        .then(throwOnCommandError);

  await runCommand([
    "pf",
    "patch",
    "/WiiLuaFinal/LuaObjectData/Common",
    path.join(scriptRoot, "eval_client-ppc.luac"),
  ]).then(throwOnCommandError);
}
