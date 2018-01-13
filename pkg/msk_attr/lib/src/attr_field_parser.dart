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
  if (type == EAReflection.float) {
    // EA.Reflection.Float
    return data.getFloat32(offset, BE);
  } else if (type == EAReflection.uint16) {
    // EA.Reflection.UInt16
    return read16BE(data, offset);
  } else if (type == EAReflection.int16) {
    // EA.Reflection.Int16
    return read16BE(data, offset).toSigned(16);
  } else if (type == EAReflection.uint32) {
    // EA.Reflection.UInt32
    return read32BE(data, offset);
  } else if (type == EAReflection.int32) {
    // EA.Reflection.Int32
    return read32BE(data, offset).toSigned(32);
  } else if (type == EAReflection.bool) {
    // EA.Reflection.Bool
    return data.getUint8(offset) != 0;
  } else if (type == EAReflection.uint8) {
    // EA.Reflection.UInt8
    return data.getUint8(offset);
  } else if (type == EAReflection.int8) {
    // EA.Reflection.Int8
    return data.getUint8(offset).toSigned(8);
  } else if (type == EAReflection.text) {
    // EA.Reflection.Text
    int hash = read32BE(data, offset);
    return context.lookupString(hash);
  } else if (type == Attrib.vector3) {
    // Attrib.Types.Vector3
    // TODO: vector_math
    return [
      data.getFloat32(offset + 0, BE),
      data.getFloat32(offset + 4, BE),
      data.getFloat32(offset + 8, BE),
    ];
  } else if (type == Attrib.refSpec) {
    // Attrib.RefSpec
    int clazz = read32BE(data, offset + 0);
    int collection = read32BE(data, offset + 4);
    return new RefSpec(context, clazz, collection);
  } else if (type == Attrib.collectionKey) {
    // Attrib.CollectionKey
    int collection = read32BE(data, offset + 0);
    return new CollectionKey(context, collection);
  } else if (type == MySims.interestScore) {
    // MySims.InterestScore
    int interestId = read32BE(data, offset + 0);
    int score = read32BE(data, offset + 4);
    return new InterestScore(interestByIndex(interestId), score);
  } else if (type == MySims.assetSpec || type == MySims.uiTexture) {
    // MySims.AssetSpec
    // MySims.UITexture
    // TODO: Classes for these
    return read64BE(data, offset + 0)
        .toRadixString(16)
        .toUpperCase()
        .padLeft(16, '0');
  } else if (type == MySims.halString) {
    // MySims.HALString
    // TODO: Classes for these
    return read32BE(data, offset + 0)
        .toRadixString(16)
        .toUpperCase()
        .padLeft(8, '0');
  } else if (type == MySims.fishingSpawnItemInfo) {
    // MySims.FishingSpawnItemInfo
    int resource = read32BE(data, offset + 0);
    int fishingspawnitem = read32BE(data, offset + 4);
    int weight = read32BE(data, offset + 8);
    // TODO: FishingSpawnItemInfo class
    return [
      new RefSpec(context, resourceClass, resource),
      new RefSpec(context, fishingSpawnItemClass, fishingspawnitem),
      weight
    ];
  } else if (type == Attrib.floatColor) {
    // Attrib.Types.FloatColour
    // TODO: FloatColor class
    return [
      data.getFloat32(offset + 0, BE),
      data.getFloat32(offset + 4, BE),
      data.getFloat32(offset + 8, BE),
      data.getFloat32(offset + 12, BE),
    ];
  } else if (type == MySims.blockCost) {
    // MySims.BlockCost
    return new BlockCost(
      context,
      read32BE(data, offset + 0),
      read32BE(data, offset + 4),
    );
  }

  return data.buffer.asUint8List(offset, type.size);
}

dynamic _readFieldRaw(AttrContext context, AttrType type, AttrCollectionField collectionField, {bool inlined: true}) {
  final fieldData = collectionField.inlineData;
  final data = collectionField.data;

  if (type.size <= 4 && inlined) {
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
        array[index] = _readFieldRaw(context, field.type, collectionField, inlined: false);
      }
    });

    return array;
  }

  return _readFieldRaw(context, field.type, collectionField);
}
