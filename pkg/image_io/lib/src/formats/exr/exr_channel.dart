part of image;

class ExrChannel {
  static const int TYPE_UINT = HdrImage.UINT;
  static const int TYPE_HALF = HdrImage.HALF;
  static const int TYPE_FLOAT = HdrImage.FLOAT;

  // Channel Names

  /// Luminance
  static const String Y = 'Y';
  /// Chroma RY
  static const String RY = 'RY';
  /// Chroma BY
  static const String BY = 'BY';
  /// Red for colored mattes
  static const String AR = 'AR';
  /// Green for colored mattes
  static const String AG = 'AG';
  /// Blue for colored mattes
  static const String AB = 'AB';
  /// Distance of the front of a sample from the viewer
  static const String Z = 'Z';
  /// Distance of the back of a sample from the viewer
  static const String ZBack = 'ZBack';
  /// Alpha/opacity
  static const String A = 'A';
  /// Red value of a sample
  static const String R = 'R';
  /// Green value of a sample
  static const String G = 'G';
  /// Blue value of a sample
  static const String B = 'B';
  /// A numerical identifier for the object represented by a sample.
  static const String ID = 'id';

  String name;
  int type;
  int size;
  bool pLinear;
  int xSampling;
  int ySampling;

  ExrChannel(InputBuffer input) {
    name = input.readString();
    if (name == null || name.isEmpty) {
      name = null;
      return;
    }
    type = input.readUint32();
    int i = input.readByte();
    assert(i == 0 || i == 1);
    pLinear = i == 1;
    input.skip(3);
    xSampling = input.readUint32();
    ySampling = input.readUint32();

    switch (type) {
      case TYPE_UINT:
        size = 4;
        break;
      case TYPE_HALF:
        size = 2;
        break;
      case TYPE_FLOAT:
        size = 4;
        break;
      default:
        throw new ImageException('EXR Invalid pixel type: $type');
    }
  }

  bool get isValid => name != null;
}
