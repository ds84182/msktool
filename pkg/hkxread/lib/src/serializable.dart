library hkxread.src.serializable;

import 'package:hkxread/src/parser.dart';

abstract class Serializable {
  void read(DataStream data, ObjectReader objectReader);
  // TODO: write
}

abstract class ObjectReader {
  const ObjectReader();

  int get dataBase;
  T readObject<T>(DataStream data);
  int getGlobalFixupOffset(DataStream data);
  int getLocalFixupOffset(DataStream data);

  T readObjectAt<T>(DataStream data, int offset) {
    return data.doAtomic(() {
      final oldOffset = data.offset;
      data.goto(offset);
      final object = readObject<T>(data);
      data.goto(oldOffset);
      return object;
    });
  }

  T readObjectFromGlobalFixup<T>(DataStream data) {
    final offset = getGlobalFixupOffset(data);
    return readObjectAt<T>(data, offset);
  }
}
