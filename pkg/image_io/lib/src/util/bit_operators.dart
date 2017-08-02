part of image;

int _shiftR(int v, int n) {
  // dart2js can't handle binary operations on negative numbers, so
  // until that issue is fixed (issues 16506, 1533), we'll have to do it
  // the slow way.
  return (v / _SHIFT_BITS[n]).floor();
}

int _shiftL(int v, int n) {
  // dart2js can't handle binary operations on negative numbers, so
  // until that issue is fixed (issues 16506, 1533), we'll have to do it
  // the slow way.
  return (v * _SHIFT_BITS[n]);
}

const List<int> _SHIFT_BITS = const [
  1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384,
  32768, 65536];


/**
 * Binary conversion of a uint8 to an int8.  This is equivalent in C to
 * typecasting an unsigned char to a char.
 */
int _uint8ToInt8(int d) {
  __uint8[0] = d;
  return __uint8ToInt8[0];
}

/**
 * Binary conversion of a uint16 to an int16.  This is equivalent in C to
 * typecasting an unsigned short to a short.
 */
int _uint16ToInt16(int d) {
  __uint16[0] = d;
  return __uint16ToInt16[0];
}

/**
 * Binary conversion of a uint32 to an int32.  This is equivalent in C to
 * typecasting an unsigned int to signed int.
 */
int _uint32ToInt32(int d) {
  __uint32[0] = d;
  return __uint32ToInt32[0];
}

/**
 * Binary conversion of a uint32 to an float32.  This is equivalent in C to
 * typecasting an unsigned int to float.
 */
double _uint32ToFloat32(int d) {
  __uint32[0] = d;
  return __uint32ToFloat32[0];
}

/**
 * Binary conversion of an int32 to a uint32. This is equivalent in C to
 * typecasting an int to an unsigned int.
 */
int _int32ToUint32(int d) {
  __int32[0] = d;
  return __int32ToUint32[0];
}

/**
 * Binary conversion of a float32 to an uint32.  This is equivalent in C to
 * typecasting a float to unsigned int.
 */
int _float32ToUint32(double d) {
  __float32[0] = d;
  return __float32ToUint32[0];
}

final Uint8List __uint8 = new Uint8List(1);
final Int8List __uint8ToInt8 = new Int8List.view(__uint8.buffer);

final Uint16List __uint16 = new Uint16List(1);
final Int16List __uint16ToInt16 = new Int16List.view(__uint16.buffer);

final Uint32List __uint32 = new Uint32List(1);
final Int32List __uint32ToInt32 = new Int32List.view(__uint32.buffer);
final Float32List __uint32ToFloat32 = new Float32List.view(__uint32.buffer);

final Int32List __int32 = new Int32List(1);
final Uint32List __int32ToUint32 = new Uint32List.view(__int32.buffer);

final Float32List __float32 = new Float32List(1);
final Uint32List __float32ToUint32 = new Uint32List.view(__float32.buffer);
