import 'package:msktool/scripting_commands.dart' as command;
import 'package:msktool/script.dart';
import 'package:path/path.dart' as path;

main() async {
  await command.compile([
    path.join(scriptRoot, "eval_client.lua"),
  ]).then(throwOnCommandError);

  await runCommand([
    "pf",
    "patch",
    "/WiiLuaFinal/LuaObjectData/Common",
    path.join(scriptRoot, "eval_client-ppc.luac"),
  ]).then(throwOnCommandError);
}
