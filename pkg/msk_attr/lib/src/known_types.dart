library msk.attr.src.known_types;

import 'dart:core';
import 'dart:core' as core show bool;
import 'package:msk_attr/src/attr_data.dart';
import 'package:msk_attr/src/field_data.dart';

class AttrTypeInfo<T> extends AttrType {
  final String name;

  const AttrTypeInfo(int id, int size, this.name) : super.raw(id, size);

  @override
  String toString() => name;
}

class EAReflection {
  const EAReflection._();

  static const _prefix = "EA.Reflection";

  static const bool =
      const AttrTypeInfo<core.bool>(0x3BCDD142, 1, "$_prefix.Bool");
  static const uint8 = const AttrTypeInfo<int>(0x35974F8E, 1, "$_prefix.UInt8");
  static const int8 = const AttrTypeInfo<int>(0x042518CB, 1, "$_prefix.Int8");
  static const uint16 =
      const AttrTypeInfo<int>(0xE43231B3, 2, "$_prefix.UInt16");
  static const int16 = const AttrTypeInfo<int>(0x4865F950, 2, "$_prefix.Int16");
  static const uint32 =
      const AttrTypeInfo<int>(0xE2322E6D, 4, "$_prefix.UInt32");
  static const int32 = const AttrTypeInfo<int>(0x4665F672, 4, "$_prefix.Int32");
  static const float =
      const AttrTypeInfo<double>(0xC193B8C8, 4, "$_prefix.Float");
  static const text =
      const AttrTypeInfo<String>(0x8C8B227B, 4, "$_prefix.Text");

  static const types = const [
    bool,
    uint8,
    int8,
    uint16,
    int16,
    uint32,
    int32,
    float,
    text,
  ];
}

class Attrib {
  const Attrib._();

  static const _prefix = "Attrib";
  static const _prefixTypes = "$_prefix.Types";

  // TODO: Vector3
  static const vector3 =
      const AttrTypeInfo<List<double>>(0x99853726, 12, "$_prefixTypes.Vector3");
  static const refSpec =
      const AttrTypeInfo<RefSpec>(0x65833771, 8, "$_prefix.RefSpec");
  static const collectionKey = const AttrTypeInfo<CollectionKey>(
      0x67F6372A, 4, "$_prefix.CollectionKey");
  // TODO: Vector4
  static const floatColor = const AttrTypeInfo<List<double>>(
      0x7E839EE8, 16, "$_prefixTypes.FloatColour");

  static const types = const [vector3, refSpec, collectionKey, floatColor];
}

class MySims {
  const MySims._();

  static const _prefix = "MySims";

  static const interestScore = const AttrTypeInfo<InterestScore>(
      0x4455CAA1, 8, "$_prefix.InterestScore");
  // TODO: Actual types for these:
  static const assetSpec =
      const AttrTypeInfo<String>(0xD7CEB540, 8, "$_prefix.AssetSpec");
  static const uiTexture =
      const AttrTypeInfo<String>(0xB39B07A2, 8, "$_prefix.UITexture");
  static const halString =
      const AttrTypeInfo<String>(0xEC86BE65, 4, "$_prefix.HALString");
  static const fishingSpawnItemInfo =
      const AttrTypeInfo<List>(0xE809F065, 12, "$_prefix.FishingSpawnItemInfo");
  static const blockCost =
      const AttrTypeInfo<BlockCost>(0x9BDC11C5, 8, "$_prefix.BlockCost");

  static const types = const [
    interestScore,
    assetSpec,
    uiTexture,
    halString,
    fishingSpawnItemInfo,
    blockCost,
  ];
}
