library msk.attr.src.attr_field_parser;

import 'attr_data.dart';

import 'dart:typed_data';
import 'package:msk_attr/msk_attr.dart';
import 'package:msk_util/msk_util.dart';

import 'field_data.dart';

final resourceClass = attrId("resource");
final fishingSpawnItemClass = attrId("fishingspawnitem");

final tempData = new ByteData(8);

dynamic readTypeAt(AttrContext context, AttrType type, int offset, ByteData data) {
  if (type.id == 0xC193B8C8) {
    // EA.Reflection.Float
    return data.getFloat32(offset, BE);
  } else if (type.id == 0xE43231B3) {
    // EA.Reflection.UInt16
    return read16BE(data, offset);
  } else if (type.id == 0x4865F950) {
    // EA.Reflection.Int16
    return read16BE(data, offset).toSigned(16);
  } else if (type.id == 0xE2322E6D) {
    // EA.Reflection.UInt32
    return read32BE(data, offset);
  } else if (type.id == 0x4665F672) {
    // EA.Reflection.Int32
    return read32BE(data, offset).toSigned(32);
  } else if (type.id == 0x3BCDD142) {
    // EA.Reflection.Bool
    return data.getUint8(offset) != 0;
  } else if (type.id == 0x35974F8E) {
    // EA.Reflection.UInt8
    return data.getUint8(offset);
  } else if (type.id == 0x042518CB) {
    // EA.Reflection.Int8
    return data.getUint8(offset).toSigned(8);
  } else if (type.id == 0x8C8B227B) {
    // EA.Reflection.Text
    int hash = read32BE(data, offset);
    return context.lookupString(hash);
  } else if (type.id == 0x99853726) {
    // Attrib.Types.Vector3
    return [
      data.getFloat32(offset + 0, BE),
      data.getFloat32(offset + 4, BE),
      data.getFloat32(offset + 8, BE),
    ];
  } else if (type.id == 0x65833771) {
    // Attrib.RefSpec
    int clazz = read32BE(data, offset + 0);
    int collection = read32BE(data, offset + 4);
    // return context.lookupName(clazz) + ':' + context.lookupName(collection);
    return new RefSpec(context, clazz, collection);
  } else if (type.id == 0x67F6372A) {
    // Attrib.CollectionKey
    int collection = read32BE(data, offset + 0);
    // return context.lookupName(collection);
    return new CollectionKey(context, collection);
  } else if (type.id == 0x4455CAA1) {
    // MySims.InterestScore
    const Map<int, String> interests = const {
      0: "Cute",
      1: "Fun",
      2: "Nature",
      3: "Spooky",
      4: "Tech",
      5: "Elegant",
      6: "Chair",
      7: "Food",
      8: "Domestic",
      9: "Sculpture",
      10: "Paint",
      30: "BonusAll",
      31: "BonusLimited",
    };
    int interestId = read32BE(data, offset + 0);
    int score = read32BE(data, offset + 4);
    return [interests[interestId] ?? interestId.toString(), score];
  } else if (type.id == 0xD7CEB540 || type.id == 0xB39B07A2) {
    // MySims.AssetSpec
    // MySims.UITexture
    return read64BE(data, offset + 0)
        .toRadixString(16)
        .toUpperCase()
        .padLeft(16, '0');
  } else if (type.id == 0xE809F065) {
    // MySims.FishingSpawnItemInfo
    int resource = read32BE(data, offset + 0);
    int fishingspawnitem = read32BE(data, offset + 4);
    int weight = read32BE(data, offset + 8);
    return [
      new RefSpec(context, resourceClass, resource),
      new RefSpec(context, fishingSpawnItemClass, fishingspawnitem),
      weight
    ];
  } else if (type.id == 0x7E839EE8) {
    // Attrib.Types.FloatColour
    return [
      data.getFloat32(offset + 0, BE),
      data.getFloat32(offset + 4, BE),
      data.getFloat32(offset + 8, BE),
      data.getFloat32(offset + 12, BE),
    ];
  }

  return data.buffer.asUint8List(offset, type.size);
}

dynamic _readFieldRaw(AttrContext context, AttrType type, AttrCollectionField collectionField) {
  final fieldData = collectionField.inlineData;
  final data = collectionField.data;

  if (type.size <= 4) {
    write32BE(tempData, 0, fieldData);
    return readTypeAt(context, type, 0, tempData);
  } else {
    return readTypeAt(context, type, fieldData & 0xFFFF, data);
  }
}

dynamic readField(AttrContext context, AttrField field, AttrCollection collection, AttrCollectionField collectionField) {
  final fieldData = collectionField.inlineData;
  final data = collectionField.data;

  if (field.flags.contains(AttrFlag.fixedArray)) {
    return new List.generate(fieldData >> 16, (i) {
      return readTypeAt(context, field.type, (fieldData & 0xFFFF) + (i * field.type.size), data);
    });
  }

  if (field.flags.contains(AttrFlag.array)) {
    final size = fieldData >> 16;

    final fieldNames = new List.generate(size, (i) {
      return attrIdArrayIndex(field.id, i);
    });

    final array = new List(size);

    collection.fields.forEach((collectionField) {
      int index = fieldNames.indexOf(collectionField.id);
      if (index >= 0) {
        array[index] = _readFieldRaw(context, field.type, collectionField);
      }
    });

    return array;
  }

  return _readFieldRaw(context, field.type, collectionField);
}
