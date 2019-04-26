library hkxread.src.wavefront_builder;

import 'dart:math' as math;

import 'package:typed_data/typed_data.dart';
import 'package:vector_math/vector_math.dart';

class WavefrontBuilder {
  Float32Buffer _vertexPosBuffer = new Float32Buffer(512);
  Uint16Buffer _indexBuffer = new Uint16Buffer(512);

  WavefrontBuilder() {
    _vertexPosBuffer.length = 0;
    _indexBuffer.length = 0;
  }

  WavefrontBuilder.cloneOf(WavefrontBuilder other)
      : _vertexPosBuffer = new Float32Buffer(other._vertexPosBuffer.length)
          ..setAll(0, other._vertexPosBuffer),
        _indexBuffer = new Uint16Buffer(other._indexBuffer.length)
          ..setAll(0, other._indexBuffer);

  WavefrontBuilder.fromData(List<double> vertexPos, List<int> index)
      : _vertexPosBuffer = new Float32Buffer(vertexPos.length)
          ..setAll(0, vertexPos),
        _indexBuffer = new Uint16Buffer(index.length)..setAll(0, index);

  WavefrontBuilder clone() => new WavefrontBuilder.cloneOf(this);

  int addPosition(double x, double y, double z) {
    final i = _vertexPosBuffer.length;
    _vertexPosBuffer
      ..length += 3
      ..[i + 0] = x
      ..[i + 1] = y
      ..[i + 2] = z;
    return (i ~/ 3) + 1;
  }

  int addPositionVec(Vector3 vec) {
    final i = _vertexPosBuffer.length;
    _vertexPosBuffer.addAll(vec.storage);
    return (i ~/ 3) + 1;
  }

  void addFace(int a, int b, int c) {
    final i = _indexBuffer.length;
    _indexBuffer
      ..length += 3
      ..[i + 0] = a
      ..[i + 1] = b
      ..[i + 2] = c;
  }

  void transform(Matrix4 matrix) {
    for (int i = 0; i < _vertexPosBuffer.length; i += 3) {
      matrix.transform3(new Vector3.fromBuffer(_vertexPosBuffer.buffer, i * 4));
    }
  }

  Iterable<String> build() sync* {
    for (int i = 0; i < _vertexPosBuffer.length; i += 3) {
      yield "v ${_vertexPosBuffer[i]} ${_vertexPosBuffer[i + 1]} ${_vertexPosBuffer[i + 2]}";
    }
    for (int i = 0; i < _indexBuffer.length; i += 3) {
      yield "f ${_indexBuffer[i]} ${_indexBuffer[i + 1]} ${_indexBuffer[i + 2]}";
    }
  }
}

class WavefrontModels {
  const WavefrontModels._();

  static final cylinder = new WavefrontBuilder.fromData(
    const <double>[
      0.0, 0.0, -1.0, //
      0.0, 1.0, -1.0, //
      math.sqrt1_2, 0.0, -math.sqrt1_2, //
      math.sqrt1_2, 1.0, -math.sqrt1_2, //
      1.0, 0.0, 0.0, //
      1.0, 1.0, 0.0, //
      math.sqrt1_2, 0.0, math.sqrt1_2, //
      math.sqrt1_2, 1.0, math.sqrt1_2, //
      -0.0, 0.0, 1.0, //
      -0.0, 1.0, 1.0, //
      -math.sqrt1_2, 0.0, math.sqrt1_2, //
      -math.sqrt1_2, 1.0, math.sqrt1_2, //
      -1.0, 0.0, -0.0, //
      -1.0, 1.0, -0.0, //
      -math.sqrt1_2, 0.0, -math.sqrt1_2, //
      -math.sqrt1_2, 1.0, -math.sqrt1_2, //
    ],
    const <int>[
      2, 3, 1, //
      4, 5, 3, //
      6, 7, 5, //
      8, 9, 7, //
      10, 11, 9, //
      12, 13, 11, //
      14, 8, 6, //
      14, 15, 13, //
      16, 1, 15, //
      7, 11, 15, //
      2, 4, 3, //
      4, 6, 5, //
      6, 8, 7, //
      8, 10, 9, //
      10, 12, 11, //
      12, 14, 13, //
      6, 4, 2, //
      2, 16, 6, //
      14, 12, 10, //
      10, 8, 14, //
      6, 16, 14, //
      14, 16, 15, //
      16, 2, 1, //
      15, 1, 3, //
      3, 5, 15, //
      7, 9, 11, //
      11, 13, 15, //
      15, 5, 7, //
    ],
  );

  static final _z = new Vector3(0.0, 1.0, 0.0);

  static WavefrontBuilder cylinderBetween(Vector3 a, Vector3 b,
      [double radius = 1.0]) {
    final matrix = new Matrix4.identity();

    matrix.translate(b);

    final p = a - b;
    final t = _z.cross(p);
    if (t.length != 0.0) {
      final angle = math.acos(_z.dot(p) / p.length);
      matrix.rotate(t, angle);
    }

    matrix.scale(radius, p.length, radius);

    return cylinder.clone()
      ..transform(matrix);
  }

  static final cube = new WavefrontBuilder.fromData(
    const <double>[
      -1.000000, -1.000000, 1.000000, //
      -1.000000, 1.000000, 1.000000, //
      -1.000000, -1.000000, -1.000000, //
      -1.000000, 1.000000, -1.000000, //
      1.000000, -1.000000, 1.000000, //
      1.000000, 1.000000, 1.000000, //
      1.000000, -1.000000, -1.000000, //
      1.000000, 1.000000, -1.000000, //
    ],
    const <int>[
      2, 3, 1, //
      4, 7, 3, //
      8, 5, 7, //
      6, 1, 5, //
      7, 1, 3, //
      4, 6, 8, //
      2, 4, 3, //
      4, 8, 7, //
      8, 6, 5, //
      6, 2, 1, //
      7, 5, 1, //
      4, 2, 6, //
    ],
  );
}
