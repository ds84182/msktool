//import 'package:msk_pf/msk_pf.dart';
//import 'package:msk_tex/msk_tex.dart';
//import 'package:file/local.dart';
//import 'package:image/image.dart';

library msktool.bin;

import 'dart:io';

import 'package:msktool/command.dart';
import 'package:path/path.dart' as p;

main(List<String> args) async {
//  final context = new PFContext(const LocalFileSystem().currentDirectory);
//  await context.open();
//  context.findAllEntries(0x6AF78CC0BE2926AF).forEach((entry) async {
//    print(entry.package.packageHeader.packageName);
//    final filePair = context.getEntryOffset(entry);
//    final texture = await Texture.fromFile(filePair.file, filePair.offset);
//    print([texture.width, texture.height, texture.format]);
//    final decoded = await texture.decoded;
//    final image = new Image.fromBytes(texture.width, texture.height, decoded);
//    final png = new PngEncoder().encodeImage(image);
//    await const LocalFileSystem().file("${entry.name}.png").writeAsBytes(png);
//  });

  if (args.length > 0 && args.first == "interactive") {
    var interactiveStackTrace;

    while (true) {
      try {
        stdout.write("${minimizePath(Directory.current.path)} # ");
        final line = stdin.readLineSync();
        if (line == null) break;

        // TODO: More intelligent command splitting
        final args = line.split(" ");

        if (args.length >= 1 && args.first == "stack") {
          print("Stack trace:");
          print("");
          print(interactiveStackTrace);
        } if (args.length >= 1 && args.first == "restart") {
          print("Restarting interactive mode...");
          return main(["interactive"]);
        } else {
          await makeCommandRunner(interactiveMode: true).run(args);
        }
      } catch (ex, stack) {
        print(ex);
        print("");
        print("Run `stack` for the stack trace.");
        interactiveStackTrace = stack;
      }
    }
  } else {
    return makeCommandRunner(interactiveMode: false).run(args);
  }
}

String minimizePath(String path) {
  final split = p.split(path);
  if (split.length <= 2) {
    // Root directory or directory right under root...
    return path;
  } else {
    return ".../${split.last}";
  }
}
