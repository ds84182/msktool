library hkxread.src.classes.hk_world_object;

import 'package:hkxread/src/classes/hk_array.dart';
import 'package:hkxread/src/classes/hk_linked_collidable.dart';
import 'package:hkxread/src/classes/hk_property.dart';
import 'package:hkxread/src/classes/hk_referenced_object.dart';
import 'package:hkxread/src/parser.dart';
import 'package:hkxread/src/serializable.dart';

// Size: 8 bytes (base) + 4 + 4 + 4 + 8 + 48 + 12 bytes = 88 bytes
class HkWorldObject extends HkReferencedObject {
  int userdata;
  HkLinkedCollidable collidable;
  HkArray<HkProperty> properties;

  @override
  void read(DataStream data, ObjectReader reader) {
    super.read(data, reader);
    // Object doesn't have a VTable because it doesn't create any new virtual
    // methods, only overrides from parent
    data.skipBytes(4); // world ptr
    userdata = data.uint32();
    data.skipBytes(4); // name ptr (unused)
    data.skipBytes(4 + 2 + 2); // multithreadLock (all no save)
    collidable = new HkLinkedCollidable()..read(data, reader);
    properties = new HkArray<HkProperty>(
        (data, reader) => new HkProperty()..read(data, reader))
      ..read(data, reader);
  }
}
