part of image;

class VP8FrameHeader {
  bool keyFrame;
  int profile; // uint8
  int show; // uint8
  int partitionLength; // uint32
}

class VP8PictureHeader {
  int width; // uint16
  int height; // uint16
  int xscale; // uint8
  int yscale; // uint8
  int colorspace; // uint8, 0 = YCbCr
  int clampType; // uint8
}

/**
 * Segment features
 */
class VP8SegmentHeader {
  bool useSegment = false;
  /// whether to update the segment map or not
  bool updateMap = false;
  /// absolute or delta values for quantizer and filter
  bool absoluteDelta = true;
  /// quantization changes
  Int8List quantizer = new Int8List(VP8.NUM_MB_SEGMENTS);
  /// filter strength for segments
  Int8List filterStrength = new Int8List(VP8.NUM_MB_SEGMENTS);
}

/**
 * All the probas associated to one band
 */
class VP8BandProbas {
  List<Uint8List> probas = new List<Uint8List>(VP8.NUM_CTX);
  VP8BandProbas() {
    for (int i = 0; i < VP8.NUM_CTX; ++i) {
      probas[i] = new Uint8List(VP8.NUM_PROBAS);
    }
  }
}

/**
 * Struct collecting all frame-persistent probabilities.
 */
class VP8Proba {
  Uint8List segments = new Uint8List(VP8.MB_FEATURE_TREE_PROBS);
  /// Type: 0:Intra16-AC  1:Intra16-DC   2:Chroma   3:Intra4
  List<List<VP8BandProbas>> bands = new List(VP8.NUM_TYPES);

  VP8Proba() {
    for (int i = 0; i < VP8.NUM_TYPES; ++i) {
      bands[i] = new List<VP8BandProbas>(VP8.NUM_BANDS);
      for (int j = 0; j < VP8.NUM_BANDS; ++j) {
        bands[i][j] = new VP8BandProbas();
      }
    }

    segments.fillRange(0, segments.length, 255);
  }
}

/**
 * Filter parameters
 */
class VP8FilterHeader {
  bool simple; // 0=complex, 1=simple
  int level; // [0..63]
  int sharpness; // [0..7]
  bool useLfDelta;
  Int32List refLfDelta = new Int32List(VP8.NUM_REF_LF_DELTAS);
  Int32List modeLfDelta = new Int32List(VP8.NUM_MODE_LF_DELTAS);
}

//------------------------------------------------------------------------------
// Informations about the macroblocks.

/**
 * filter specs
 */
class VP8FInfo {
  int fLimit = 0; // uint8_t, filter limit in [3..189], or 0 if no filtering
  int fInnerLevel = 0; // uint8_t, inner limit in [1..63]
  bool fInner = false; // uint8_t, do inner filtering?
  int hevThresh = 0; // uint8_t, high edge variance threshold in [0..2]
}

/**
 * Top/Left Contexts used for syntax-parsing
 */
class VP8MB{
  int nz = 0; // uint8_t, non-zero AC/DC coeffs (4bit for luma + 4bit for chroma)
  int nzDc = 0; // uint8_t, non-zero DC coeff (1bit)
}

/**
 * Dequantization matrices
 */
class VP8QuantMatrix {
  Int32List y1Mat = new Int32List(2);
  Int32List y2Mat = new Int32List(2);
  Int32List uvMat = new Int32List(2);

  int uvQuant; // U/V quantizer value
  int dither; // dithering amplitude (0 = off, max=255)
}

/**
 * Data needed to reconstruct a macroblock
 */
class VP8MBData {
  /// 384 coeffs = (16+4+4) * 4*4
  Int16List coeffs = new Int16List(384);
  bool isIntra4x4; // true if intra4x4
  /// one 16x16 mode (#0) or sixteen 4x4 modes
  Uint8List imodes = new Uint8List(16);
  /// chroma prediction mode
  int uvmode;
  // bit-wise info about the content of each sub-4x4 blocks (in decoding order).
  // Each of the 4x4 blocks for y/u/v is associated with a 2b code according to:
  //   code=0 -> no coefficient
  //   code=1 -> only DC
  //   code=2 -> first three coefficients are non-zero
  //   code=3 -> more than three coefficients are non-zero
  // This allows to call specialized transform functions.
  int nonZeroY;
  int nonZeroUV;
  /// uint8_t, local dithering strength (deduced from non_zero_*)
  int dither;
}

/**
 * Saved top samples, per macroblock. Fits into a cache-line.
 */
class VP8TopSamples {
  Uint8List y = new Uint8List(16);
  Uint8List u = new Uint8List(8);
  Uint8List v = new Uint8List(8);
}

class VP8Random {
  int _index1;
  int _index2;
  Uint32List _table = new Uint32List(RANDOM_TABLE_SIZE);
  int _amplitude;

  /**
   * Initializes random generator with an amplitude 'dithering' in range [0..1].
   */
  VP8Random(double dithering) {
    _table.setRange(0, RANDOM_TABLE_SIZE, _RANDOM_TABLE);
    _index1 = 0;
    _index2 = 31;
    _amplitude = (dithering < 0.0) ? 0 :
                 (dithering > 1.0) ? (1 << RANDOM_DITHER_FIX) :
                 ((1 << RANDOM_DITHER_FIX) * dithering).toInt();
  }

  /**
   * Returns a centered pseudo-random number with 'num_bits' amplitude.
   * (uses D.Knuth's Difference-based random generator).
   * 'amp' is in RANDOM_DITHER_FIX fixed-point precision.
   */
  int randomBits2(int numBits, int amp) {
    int diff = _table[_index1] - _table[_index2];
    if (diff < 0) {
      diff += (1 << 31);
    }

    _table[_index1] = diff;

    if (++_index1 == RANDOM_TABLE_SIZE) {
      _index1 = 0;
    }
    if (++_index2 == RANDOM_TABLE_SIZE) {
      _index2 = 0;
    }

    // sign-extend, 0-center
    diff = (diff << 1) >> (32 - numBits);
    // restrict range
    diff = (diff * amp) >> RANDOM_DITHER_FIX;
    // shift back to 0.5-center
    diff += 1 << (numBits - 1);

    return diff;
  }

  int randomBits(int numBits) {
    return randomBits2(numBits, _amplitude);
  }

  /// fixed-point precision for dithering
  static const int RANDOM_DITHER_FIX = 8;
  static const int RANDOM_TABLE_SIZE = 55;

  // 31b-range values
  static const List<int> _RANDOM_TABLE = const [
    0x0de15230, 0x03b31886, 0x775faccb, 0x1c88626a, 0x68385c55, 0x14b3b828,
    0x4a85fef8, 0x49ddb84b, 0x64fcf397, 0x5c550289, 0x4a290000, 0x0d7ec1da,
    0x5940b7ab, 0x5492577d, 0x4e19ca72, 0x38d38c69, 0x0c01ee65, 0x32a1755f,
    0x5437f652, 0x5abb2c32, 0x0faa57b1, 0x73f533e7, 0x685feeda, 0x7563cce2,
    0x6e990e83, 0x4730a7ed, 0x4fc0d9c6, 0x496b153c, 0x4f1403fa, 0x541afb0c,
    0x73990b32, 0x26d7cb1c, 0x6fcc3706, 0x2cbb77d8, 0x75762f2a, 0x6425ccdd,
    0x24b35461, 0x0a7d8715, 0x220414a8, 0x141ebf67, 0x56b41583, 0x73e502e3,
    0x44cab16f, 0x28264d42, 0x73baaefb, 0x0a50ebed, 0x1d6ab6fb, 0x0d3ad40b,
    0x35db3b68, 0x2b081e83, 0x77ce6b95, 0x5181e5f0, 0x78853bbc, 0x009f9494,
    0x27e5ed3c];
}
