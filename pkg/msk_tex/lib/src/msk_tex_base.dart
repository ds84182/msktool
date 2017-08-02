import 'dart:async';
import 'dart:typed_data';
import 'package:file/file.dart';
import 'package:async/async.dart';
import 'package:msk_util/msk_util.dart';

/// Checks if you are awesome. Spoiler: you are.
class Awesome {
  bool get isAwesome => true;
}

abstract class TextureFormat {
  final int index;
  final String name;

  /// The amount of bytes needed to form a 2x2 pixel region
  final int blockSize;

  const TextureFormat({this.index, this.name, this.blockSize});

  // Decodes to an ABGR array of pixels
  Uint32List decode(Uint8List data, int width, int height);

  static const I4 = const I4TextureFormat();

  static TextureFormat from(int format) {
    switch (format) {
      case 0x00:
        return const I4TextureFormat();
      case 0x01:
        return const I8TextureFormat();
      case 0x0E:
        return const CMPRTextureFormat();
      default:
        throw "Unknown texture format ${format.toRadixString(16).toUpperCase()}";
    }
  }
}

class I4TextureFormat extends TextureFormat {
  const I4TextureFormat() : super(index: 0x00, name: "I4", blockSize: 2);

  @override
  Uint32List decode(Uint8List data, int width, int height) {
    final pixelCount = width * height;
    final pixels = new Uint32List(pixelCount);
    int pixelIndex = 0;

    while (pixelIndex < pixelCount) {
      final b = data[pixelIndex >> 1];
      final k1 = (b & 0xF) * 0x11;
      final k2 = (b >> 4) * 0x11;
      pixels[pixelIndex] = 0xFF000000 | (k1 << 16) | (k1 << 8) | k1;
      pixels[pixelIndex + 1] = 0xFF000000 | (k2 << 16) | (k2 << 8) | k2;
      pixelIndex += 2;
    }

    return pixels;
  }
}

class I8TextureFormat extends TextureFormat {
  const I8TextureFormat() : super(index: 0x01, name: "I8", blockSize: 1);

  @override
  Uint32List decode(Uint8List data, int width, int height) {
    final pixelCount = width * height;
    final pixels = new Uint32List(pixelCount);
    int pixelIndex = 0;

    while (pixelIndex < pixelCount) {
      final b = data[pixelIndex >> 1];
      pixels[pixelIndex] = 0xFF000000 | (b << 16) | (b << 8) | b;
      pixelIndex += 1;
    }

    return pixels;
  }
}

class CMPRTextureFormat extends TextureFormat {
  const CMPRTextureFormat() : super(index: 0x0E, name: "CMPR", blockSize: 8);

  @override
  Uint32List decode(Uint8List data, int width, int height) {
    final pixelCount = width * height;
    final pixels = new Uint32List(pixelCount);
    // TODO: Rewrite to use pixel index maybe?
    // int pixelIndex = 0;
    int dataIndex = 0;

    int makeABGR(int r, int g, int b, [int a = 255]) {
      return (a << 24) | (b << 16) | (g << 8) | r;
    }

    int ilerp(int a, int b, num k) {
      return (a * (1 - k) + b * k).toInt();
    }

    int clerp(int a, int b, num k) {
      return ilerp(a & 0xFF000000, b & 0xFF000000, k) & 0xFF000000 |
          ilerp(a & 0xFF0000, b & 0xFF0000, k) & 0xFF0000 |
          ilerp(a & 0xFF00, b & 0xFF00, k) & 0xFF00 |
          ilerp(a & 0xFF, b & 0xFF, k) & 0xFF;
    }

    void plotPixel(int x, int y, int px) {
      pixels[y * height + x] = px;
    }

    void decodeDXT1Block(int dx, int dy) {
      final rgb565_a = (data[dataIndex + 0] << 8) | data[dataIndex + 1];
      final rgb565_b = (data[dataIndex + 2] << 8) | data[dataIndex + 3];

      final palette0 = makeABGR(
        (((rgb565_a >> 11) & 0x1F) * 255 + 15) ~/ 31,
        (((rgb565_a >> 5) & 0x3F) * 255 + 31) ~/ 63,
        ((rgb565_a & 0x1F) * 255 + 15) ~/ 31,
      );

      final palette1 = makeABGR(
        (((rgb565_b >> 11) & 0x1F) * 255 + 15) ~/ 31,
        (((rgb565_b >> 5) & 0x3F) * 255 + 31) ~/ 63,
        ((rgb565_b & 0x1F) * 255 + 15) ~/ 31,
      );

      final lerpCoeffA = rgb565_a > rgb565_b ? 1.0 / 3.0 : 1.0 / 2.0;
      const lerpCoeffB = 2.0 / 3.0;

      final palette2 = clerp(palette0, palette1, lerpCoeffA);
      var palette3 = clerp(palette0, palette1, lerpCoeffB);

      if (rgb565_a <= rgb565_b) {
        palette3 &= 0x00FFFFFF;
      }

      dataIndex += 4;

      for (int y = 0; y < 4; y++) {
        var b = data[dataIndex + y];
        for (int x = 0; x < 4; x++) {
          final pidx = b & 0x3;
          b >>= 2;
          plotPixel(
              (3 - x) + dx,
              y + dy,
              pidx == 0
                  ? palette0
                  : pidx == 1 ? palette1 : pidx == 2 ? palette2 : palette3);
        }
      }

      dataIndex += 4;
    }

    void decodeDXT1MainBlock(int x, int y) {
      decodeDXT1Block(x, y);
      decodeDXT1Block(x + 4, y);
      decodeDXT1Block(x, y + 4);
      decodeDXT1Block(x + 4, y + 4);
    }

    void decodeDXT1Image() {
      for (int y = 0; y < height; y += 8) {
        for (int x = 0; x < width; x += 8) {
          decodeDXT1MainBlock(x, y);
        }
      }
    }

    decodeDXT1Image();

    return pixels;
  }
}

typedef FutureOr<Uint8List> TextureDataLoader();

class Texture {
  final int width;
  final int height;
  final TextureFormat format;
  final _textureDataMemoizer = new AsyncMemoizer<Uint8List>();
  final TextureDataLoader _textureDataLoader;

  Texture._(this.width, this.height, this.format, this._textureDataLoader);

  Future<Uint8List> get textureData =>
      _textureDataMemoizer.runOnce(_textureDataLoader);

  Future<Uint32List> _decoded;
  Future<Uint32List> get decoded =>
      _decoded ?? textureData.then((data) => format.decode(data, width, height));

  static Future<Texture> fromFile(File file, [int offset]) async {
    final raf = await file.open();
    if (offset != null) await raf.setPosition(offset);

    final header = new ByteData(0x40);
    await raf.readInto(header.buffer.asUint8List());

    // TODO: We should probably close and reopen the raf

    return new Texture._(
      read16BE(header, 0x18),
      read16BE(header, 0x1A),
      TextureFormat.from(read32BE(header, 0x1C)),
      () async {
        final data = await raf.read(read32BE(header, 0x8));
        await raf.close();
        return data;
      },
    );
  }
}
