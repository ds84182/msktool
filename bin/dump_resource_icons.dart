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
  final resourceIconDir = lfs.currentDirectory.childDirectory("resource_icons");

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

  T readField<T>(AttrCollection collection, String name) {
    return AttrCollectionHelper.readField(attr, collection,
        attr.lookupClassField(collection.classId, attrId(name)));
  }

  final textureLoadPool = new Pool(8);
  final textureDecodePool = new Pool(8);

  final resourceClass = new ClassKey.byName(attr, "resource");
  final baseEssenceCollection = new CollectionKey.byName(attr, "base_essences");

  final resourceTasks = resourceClass.lookupCollections()
      .where((collection) => collection.parent == baseEssenceCollection.key)
      .map((collection) async {
        final collectionKey = new CollectionKey(attr, collection.id);
        final collectionName = collectionKey.toString();

        final uiImage = pf.findAllEntries(readField<String>(collection, "UIImage")).single;

        final location = pf.getEntryOffset(uiImage);

        final texture = await textureLoadPool.withResource(() => Texture.fromFile(location.file, location.offset));
        final image = new Image.fromBytes(texture.width, texture.height, await textureDecodePool.withResource(() => texture.decoded));
        final List<int> png = await loadBalancer.run(encodePng, image);

        await resourceIconDir.childFile("$collectionName.png").writeAsBytes(png);

        print(collectionName);
      })
      .toList();

  await Future.wait(resourceTasks);

  await loadBalancer.close();
  await textureLoadPool.close();
  await textureDecodePool.close();

  sw.stop();

  print("Done: Exported ${resourceTasks.length} textures in ${sw.elapsedMilliseconds/1000.0} seconds");
}