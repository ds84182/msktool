library hkxread.src.classes.hk_array;

import 'package:collection/collection.dart';
import 'package:hkxread/src/classes/hk_object_ptr.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 12 bytes
class HkArray<T> extends DelegatingList<T> implements Serializable {
  final T Function(DataStream data, ObjectReader reader) factory;

  HkArray(this.factory) : super(<T>[]);

  @override
  void read(DataStream data, ObjectReader reader) {
    data.skipBytes(4); // Check size before using local fixup
    int length = data.uint32();
    final capacityAndFlags = data.uint32();
    assert(capacityAndFlags & 0xC0000000 != 0);
    assert(capacityAndFlags & 0x3FFFFFFF == length);

    this.length = length;

    if (length > 0) {
      data.doAtomic(() {
        final oldOffset = data.offset;
        data.goto(oldOffset - 12);
        final dataOffset = reader.getLocalFixupOffset(data);
        data.goto(dataOffset);
        for (int i = 0; i < length; i++) {
          this[i] = factory(data, reader);
        }
        data.goto(oldOffset);
      });
    }
  }

  static HkObjectPtr<T> objectPtrFactory<T>(
      DataStream data, ObjectReader reader) {
    return new HkObjectPtr<T>()..read(data, reader);
  }

  static Null throwFactory(DataStream data, ObjectReader reader) {
    throw new UnsupportedError("Cannot inflate HkArray data");
  }
}
