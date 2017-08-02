library msktool.plot_map_data;

import 'dart:async';
import 'dart:io';

import 'package:file/local.dart';
import 'package:msk_attr/msk_attr.dart';
import 'package:msk_pf/msk_pf.dart';
import 'package:msk_tex/msk_tex.dart';
import 'package:image/image.dart';

const lfs = const LocalFileSystem();

Future main(List<String> args) async {
  final islandName = args.first;

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

  T readField<T>(AttrCollection collection, String name) {
    return AttrCollectionHelper.readField(attr, collection,
        attr.lookupClassField(collection.classId, attrId(name)));
  }

  final islandRefSpec = new RefSpec.byName(attr, "island", islandName);
  final islandCollection = islandRefSpec.lookup();

  final islandStartWorldRefSpec =
      readField<CollectionKey>(islandCollection, "StartWorld")
          .withClass("world");
  final islandStartWorldCollection = islandStartWorldRefSpec.lookup();
  final islandStartWorldChildRefSpecs =
      readField<List<RefSpec>>(islandStartWorldCollection, "ChildRefSpecs");
  final mapRefSpec =
      readField<CollectionKey>(islandStartWorldCollection, "IslandMap")
          .withClass("map");
  final mapCollection = mapRefSpec.lookup();

  final String textureId = readField(mapCollection, "TextureName");
  final int width = readField(mapCollection, "Width") * 2;
  final int height = readField(mapCollection, "Length") * 2;
  final List<double> minCoord = readField(mapCollection, "MapMinCoord");
  final List<double> maxCoord = readField(mapCollection, "MapMaxCoord");

  final double mapX = minCoord[0];
  final double mapZ = minCoord[2];

  final double mapWidth = maxCoord[0] - mapX;
  final double mapLength = maxCoord[2] - mapZ;

  final double mapScaleX = (1.0 / mapWidth) * width.toDouble();
  final double mapScaleZ = (1.0 / mapLength) * height.toDouble();

  double physicalXToMap(double x) {
    return (x - mapX) * mapScaleX;
  }

  double physicalZToMap(double y) {
    return (y - mapZ) * mapScaleZ;
  }

  Iterable<RefSpec> childrenOfClass(ClassKey clazz) =>
      islandStartWorldChildRefSpecs.where((rs) => rs.classKey == clazz.key);

  AttrCollection lookup(RefSpec refSpec) => refSpec.lookup();

  final textureEntry = pf.findAllEntries(textureId).first;
  final textureLocation = pf.getEntryOffset(textureEntry);

  print("Loading texture...");
  final texture =
      await Texture.fromFile(textureLocation.file, textureLocation.offset);

  final textureImage =
      new Image.fromBytes(texture.width, texture.height, await texture.decoded);

  print("Rescaling image...");
  final scaledTextureImage = copyResize(textureImage, width, height, CUBIC);

  // Find fishing nodes
  final fishingBucketClass = attrId("fishingbucket");
  final fishingSpawnLocationClass = attrId("fishingspawnlocation");

  print("Fishing:");

  int index = 0;
  attr.lookupCollections(fishingBucketClass).forEach((fishingBucketCollection) {
    final parent = readField<RefSpec>(fishingBucketCollection, "ParentRefSpec");

    if (parent == islandStartWorldRefSpec) {
      final List<CollectionKey> spawnList =
          readField(fishingBucketCollection, "Tuning_FishingSpawnLocationList");
      spawnList.forEach((spawnLocationCollectionKey) {
        final spawnLocationCollection = spawnLocationCollectionKey
            .withClass(fishingSpawnLocationClass)
            .lookup();

        print(" - $spawnLocationCollectionKey #$index");
        print(
            "   Spawn Items: ${readField(spawnLocationCollection, "Tuning_FishingSpawnItems")}");

        // TODO: Vector Math's vec3
        final List<double> position =
            readField(spawnLocationCollection, "Position");
        final double minRadius =
            readField(spawnLocationCollection, "Tuning_SpawnRadiusMin");
        final double maxRadius =
            readField(spawnLocationCollection, "Tuning_SpawnRadiusMax");

        int imageX = physicalXToMap(position[0]).toInt();
        int imageY = physicalZToMap(position[2]).toInt();

        drawCircle(scaledTextureImage, imageX, imageY,
            (maxRadius * mapScaleX).toInt(), getColor(0x18, 0x4A, 0x8E));

        drawFilledCircle(scaledTextureImage, imageX, imageY,
            (minRadius * mapScaleX).toInt(), getColor(0x12, 0x38, 0x6B));

        drawString(
            scaledTextureImage, arial_24, imageX, imageY, index.toString());

        index++;
      });
    }
  });

  final grassClass = attrId("grass");

  print("");
  print("Grass:");

  final grassRewards =
      readField<CollectionKey>(islandStartWorldCollection, "Grass_reward")
          .withClass("grass_rewards")
          .lookup();
  for (int i = 1; i <= 4; i++) {
    print(" - Tier $i");
    print("   Rewards: ${readField(grassRewards, "Tuning${i}_RewardTypes")}");
    print("   Weights: ${readField(grassRewards, "Tuning${i}_RewardWeights")}");
    print("   Count: ${readField(grassRewards, "Tuning${i}_ResourceCount")}");
  }

  attr.lookupCollections(grassClass).forEach((grassCollection) {
    final parent = readField<RefSpec>(grassCollection, "ParentRefSpec");

    if (parent == islandStartWorldRefSpec) {
      print(" - ${attr.lookupName(grassCollection.id)}");
      // TODO: Vector Math's vec3
      final List<double> position = readField(grassCollection, "Position");

      int imageX = physicalXToMap(position[0]).toInt();
      int imageY = physicalZToMap(position[2]).toInt();

      drawFilledCircle(scaledTextureImage, imageX, imageY,
          (1.0 * mapScaleX).toInt(), getColor(255, 255, 255));

      drawCircle(scaledTextureImage, imageX, imageY, (1.0 * mapScaleX).toInt(),
          getColor(0, 255, 0));
    }
  });

  final prospectingCrystalClass = attrId("prospecting_crystal");
  final locatorNodeClass = attrId("locator_node");

  print("");
  print("Prospecting:");

  index = 0;
  attr.lookupCollections(prospectingCrystalClass).forEach((collection) {
    final parent = readField<RefSpec>(collection, "ParentRefSpec");

    if (parent == islandStartWorldRefSpec) {
      print(" - ${attr.lookupName(collection.id)} #$index");
      print("   Rewards: ${readField(collection, "Tuning_RewardTypes")}");
      print("   Weights: ${readField(collection, "Tuning_RewardWeights")}");
      print(
          "   Resource Range: ${readField(collection, "Tuning_ResourcesPerDigMin")} to ${readField(collection, "Tuning_ResourcesPerDigMax")}");
      print(
          "   Replenish Time: ${readField(collection, "Tuning_HotSpotReplenishInSeconds")} +-${readField(collection, "Tuning_HotSpotReplenishVariance")}");

      // TODO: Vector Math's vec3
      final List<double> position = readField(collection, "Position");

      int imageX = physicalXToMap(position[0]).toInt();
      int imageY = physicalZToMap(position[2]).toInt();

      int hashColor =
          ((attr.lookupName(collection.id).hashCode << 3) ^ collection.id) |
              0xFF000000;

      drawFilledCircle(scaledTextureImage, imageX, imageY,
          (1.0 * mapScaleX).toInt(), getColor(0, 255, 255));

      drawFilledCircle(scaledTextureImage, imageX, imageY,
          (0.75 * mapScaleX).toInt(), hashColor);

      drawString(
          scaledTextureImage, arial_24, imageX, imageY, index.toString());

      {
        final List<CollectionKey> nodes =
            readField(collection, "ProspectingNodes");
        print("   Nodes: ${nodes.length}");
        nodes
            .map((nodeKey) => nodeKey.withClass(locatorNodeClass))
            .forEach((nodeRefSpec) {
          final nodeCollection = nodeRefSpec.lookup();

          final List<double> position = readField(nodeCollection, "Position");

          int imageX = physicalXToMap(position[0]).toInt();
          int imageY = physicalZToMap(position[2]).toInt();

          drawFilledCircle(scaledTextureImage, imageX, imageY,
              (0.5 * mapScaleX).toInt(), hashColor);
        });
      }

      index++;
    }
  });

  final miningRockClass = attrId("mining_rock");

  print("");
  print("Mining:");

  index = 0;
  attr.lookupCollections(miningRockClass).forEach((collection) {
    final parent = readField<RefSpec>(collection, "ParentRefSpec");

    if (parent == islandStartWorldRefSpec) {
      print(" - ${attr.lookupName(collection.id)} #$index");
      print("   Rewards: ${readField(collection, "Tuning_RewardTypes")}");
      print("   Weights: ${readField(collection, "Tuning_RewardWeights")}");
      print(
          "   Resource Range: ${readField(collection, "Tuning_ResourcesPerStrikeMed")} to ${readField(collection, "Tuning_ResourcesPerStrikeMax")}");
      print(
          "   Replenish Time: ${readField(collection, "Tuning_HotSpotReplenishInSeconds")} +-${readField(collection, "Tuning_HotSpotReplenishVariance")}");

      // TODO: Vector Math's vec3
      final List<double> position = readField(collection, "Position");

      int imageX = physicalXToMap(position[0]).toInt();
      int imageY = physicalZToMap(position[2]).toInt();

      drawFilledCircle(scaledTextureImage, imageX, imageY,
          (1.0 * mapScaleX).toInt(), getColor(0x8E, 0x59, 0x18));

      drawString(
          scaledTextureImage, arial_24, imageX, imageY, index.toString());

      index++;
    }
  });

  final treeClass = attrId("tree");

  print("");
  print("Trees:");

  index = 0;
  attr.lookupCollections(treeClass).forEach((collection) {
    final parent = readField<RefSpec>(collection, "ParentRefSpec");

    if (parent == islandStartWorldRefSpec) {
      final treeTypeRefSpec = readField<RefSpec>(collection, "SavedTreeType");
      final treeTypeCollection = treeTypeRefSpec.lookup();

      print(" - ${attr.lookupName(collection.id)} #$index");
      print("   Saved Tree Type: $treeTypeRefSpec");
      print("   Fruits: ${readField(treeTypeCollection, "Tuning_FruitTypes")}");
      print(
          "   Fruit Weights: ${readField(treeTypeCollection, "Tuning_FruitWeights")}");
      print("   Woods: ${readField(treeTypeCollection, "Tuning_WoodTypes")}");
      print(
          "   Wood Weights: ${readField(treeTypeCollection, "Tuning_WoodWeights")}");

      // TODO: Vector Math's vec3
      final List<double> position = readField(collection, "Position");

      int imageX = physicalXToMap(position[0]).toInt();
      int imageY = physicalZToMap(position[2]).toInt();

      drawFilledCircle(scaledTextureImage, imageX, imageY,
          (1.0 * mapScaleX).toInt(), getColor(0x1C, 0x8D, 0x2E));

      drawFilledCircle(scaledTextureImage, imageX, imageY,
          (0.8 * mapScaleX).toInt(), getColor(0x8E, 0x59, 0x18));

      drawString(
          scaledTextureImage, arial_24, imageX, imageY, index.toString());

      index++;
    }
  });

  final clueClass = new ClassKey.byName(attr, "clue");

  print("");
  print("Clues:");

  childrenOfClass(clueClass).map(lookup).forEach((collection) {
    final parentClue = clueClass.withCollection(collection.parent);
    final scriptName = readField(collection, "ScriptName");

    print(" - ${attr.lookupName(collection.id)}");
    print("   Parent: $parentClue");
    print("   Script Name: $scriptName");

    // TODO: Vector Math's vec3
    final List<double> position = readField(collection, "Position");

    int imageX = physicalXToMap(position[0]).toInt();
    int imageY = physicalZToMap(position[2]).toInt();

    int hashColor =
        ((parentClue.hashCode << 3) ^ scriptName.hashCode) | 0xFF000000;

    drawFilledCircle(scaledTextureImage, imageX, imageY,
        (1.0 * mapScaleX).toInt(), hashColor);

    drawCircle(scaledTextureImage, imageX, imageY, (1.0 * mapScaleX).toInt(),
        getColor(255, 0, 0));
  });

  final triggerClass = new ClassKey.byName(attr, "trigger");

  print("");
  print("Triggers:");

  childrenOfClass(triggerClass).map(lookup).forEach((collection) {
    print(" - ${attr.lookupName(collection.id)}");

    // TODO: Vector Math's vec3
    final List<double> position = readField(collection, "Position");
    final List<double> boxHalfExtent = readField(collection, "BoxHalfExtent");

    int imageX = physicalXToMap(position[0]).toInt();
    int imageY = physicalZToMap(position[2]).toInt();

    int imageXHE = physicalXToMap(boxHalfExtent[0]).toInt();
    int imageYHE = physicalZToMap(boxHalfExtent[2]).toInt();

    imageX -= imageXHE;
    imageY -= imageYHE;
    imageXHE *= 2;
    imageYHE *= 2;

    int hashColor =
        (((position[0] * position[2]).round() << 3) ^ collection.id) |
            0xFF000000;

//    fillRect(scaledTextureImage, imageX, imageY, imageX + imageXHE,
//        imageY + imageYHE, (hashColor & 0xFFFFFF) | 0x3F000000);

    drawRect(scaledTextureImage, imageX, imageY, imageX + imageXHE,
        imageY + imageYHE, hashColor);
  });

  print("Displaying image...");
  final encodedPng = new PngEncoder().encodeImage(scaledTextureImage);
  final process = await Process.start("display", const ["-"]);

  process.stderr.listen(stderr.add);
  process.stdout.listen(stdout.add);

  process.stdin.add(encodedPng);
  await process.stdin.close();

  await process.exitCode;

  print("Done!");
}
