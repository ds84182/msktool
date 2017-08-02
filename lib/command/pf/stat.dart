library msktool.command.pf.stat;

import 'dart:async';
import 'package:msk_pf/msk_pf.dart';
import 'package:msktool/command/pf.dart';

class PFStatCommand extends PFSubCommand {
  @override
  String get name => "stat";

  @override
  String get description => "Display the status of an entry.";

  @override
  List<String> get aliases => const [
    "s", "st"
  ];

  String get path => argResults.rest.length >= 1 ? argResults.rest[0] : null;

  @override
  Future execute() async {
    var path = this.path ?? "/";
    path = pathContext.join("/", pathContext.normalize(path));
    final split = pathContext.split(path);

    print("[$path]");

    final context = await openPF();

    final data = context.handlePath(split);

    if (data == null) {
      print(" ! Could not find $path");
      return;
    }

    if (data is PFHeader) {
      print(" * Type: Root");
      print(" * Magic: ${new String.fromCharCodes(data.magic)}");
      print(" * Version: ${data.versionMajor}.${data.versionMinor}");
      print(" * Children: ${data.packageHeaders.length} packages");
    } else if (data is PFPackageHeader) {
      print(" * Type: Package");
      print(" * Package Data Location: ${data.packagePath}${data.packageName}.package");
      print(" * ID: ${data.id.toRadixString(16).padLeft(8, '0')}");
      print(" * Flags: ${data.flags.toRadixString(16).padLeft(8, '0')}");
      print(" * Unknown1: ${data.package.unknown1.toRadixString(16).padLeft(8, '0')}");
      print(" * Children: ${data.package.types.length} types; ${data.package.entries.length} entries");
    } else if (data is PFType) {
      print(" * Type: Type");
      print(" * ID: ${data.id.toRadixString(16).padLeft(8, '0')}");
      print(" * Entry Format: ${data.entryFormat}");
      print(" * Compressed: ${data.entryFormat == 2}");
      print(" * Unknown2: ${data.unknown2.toRadixString(16).padLeft(8, '0')}");
      print(" * Children: ${data.count} entries");
    } else if (data is PFEntry) {
      print(" * Type: ${data is PFCompressedEntry ? "Compressed " : ""}Entry");
      print(" * ID: ${data.id.toRadixString(16).padLeft(16, '0').toUpperCase()}");
      print(" * Name: ${data.name}");
      print(" * Offset: ${data.fileOffset.toRadixString(16).padLeft(8, '0')}");
      if (data is PFCompressedEntry)
        print(" * Compressed Size: ${data.compressedSize}");
      print(" * Size: ${data.size}");
    }
  }
}
