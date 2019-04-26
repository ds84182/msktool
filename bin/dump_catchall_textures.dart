library msktool.dump_resource_icons;

import 'dart:async';

import 'package:file/local.dart';
import 'package:image/image.dart';
import 'package:isolate/isolate_runner.dart';
import 'package:isolate/load_balancer.dart';
import 'package:msk_attr/msk_attr.dart';
import 'package:msk_pf/msk_pf.dart';
import 'package:msk_tex/msk_tex.dart';
import 'package:pool/pool.dart';

const lfs = const LocalFileSystem();

List<int> encodePng(Image image) {
  return new PngEncoder().encodeImage(image);
}

Future main(List<String> args) async {
  final resourceIconDir = lfs.currentDirectory.childDirectory("catchall_textures");

  await resourceIconDir.create();

  final pf = new PFContext(lfs.currentDirectory);
  AttrContext attr;

  print("Opening PFStatic and attribdbz...");
  await Future.wait<dynamic>([
    pf.open().then((_) => print("PFStatic opened!")),
    readContextFromGameRoot(lfs.currentDirectory).then((context) {
      attr = context;
      print("attribdbz opened!");
    })
  ]);

  final sw = new Stopwatch()..start();

  final loadBalancer = await LoadBalancer.create(8, IsolateRunner.spawn);

  final textureLoadPool = new Pool(8);
  final textureDecodePool = new Pool(8);

  final tasks = pf.findPackage("CatchAll").package.entries
      .where((entry) => entry.type.name == "TextureData")
      .map((entry) async {
    final location = pf.getEntryOffset(entry);

    final texture = await textureLoadPool.withResource(() => Texture.fromFile(location.file, location.offset));
    final image = new Image.fromBytes(texture.width, texture.height, await textureDecodePool.withResource(() => texture.decoded));
    final List<int> png = await loadBalancer.run(encodePng, image);

    await resourceIconDir.childFile("${entry.name}.png").writeAsBytes(png);

    print(entry.name);
  }).toList();

  await Future.wait(tasks);

  await loadBalancer.close();
  await textureLoadPool.close();
  await textureDecodePool.close();

  sw.stop();

  print("Done: Exported ${tasks.length} textures in ${sw.elapsedMilliseconds/1000.0} seconds");
}
