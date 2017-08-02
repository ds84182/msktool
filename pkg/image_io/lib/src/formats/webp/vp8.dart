part of image;

/**
 * WebP lossy format.
 */
class VP8 {
  InputBuffer input;
  WebPInfo webp;

  VP8(InputBuffer input, this.webp) :
    this.input = input;

  bool decodeHeader() {
    int bits = input.readUint24();

    final bool keyFrame = (bits & 1) == 0;
    if (!keyFrame) {
      return false;
    }

    if (((bits >> 1) & 7) > 3) {
      return false; // unknown profile
    }

    if (((bits >> 4) & 1) == 0) {
      return false; // first frame is invisible!
    }

    _frameHeader.keyFrame = (bits & 1) == 0;
    _frameHeader.profile = (bits >> 1) & 7;
    _frameHeader.show = (bits >> 4) & 1;
    _frameHeader.partitionLength = (bits >> 5);

    int signature = input.readUint24();
    if (signature != VP8_SIGNATURE) {
      return false;
    }

    webp.width = input.readUint16();
    webp.height = input.readUint16();

    return true;
  }

  Image decode() {
    if (!_getHeaders()) {
      return null;
    }

    output = new Image(webp.width, webp.height);

    // Will allocate memory and prepare everything.
    if (!_initFrame()) {
      return null;
    }

    // Main decoding loop
    if (!_parseFrame()) {
      return null;
    }

    return output;
  }

  bool _getHeaders() {
    if (!decodeHeader()) {
      return false;
    }

    _proba = new VP8Proba();
    for (int i = 0; i < NUM_MB_SEGMENTS; ++i) {
      _dqm[i] = new VP8QuantMatrix();
    }

    _picHeader.width = webp.width;
    _picHeader.height = webp.height;
    _picHeader.xscale = (webp.width >> 8) >> 6;
    _picHeader.yscale = (webp.height >> 8) >> 6;

    _cropTop = 0;
    _cropLeft = 0;
    _cropRight = webp.width;
    _cropBottom = webp.height;

    _mbWidth = (webp.width + 15) >> 4;
    _mbHeight = (webp.height + 15) >> 4;

    _segment = 0;

    br = new VP8BitReader(input.subset(_frameHeader.partitionLength));
    input.skip(_frameHeader.partitionLength);

    _picHeader.colorspace = br.get();
    _picHeader.clampType = br.get();

    if (!_parseSegmentHeader(_segmentHeader, _proba)) {
      return false;
    }

    // Filter specs
    if (!_parseFilterHeader()) {
      return false;
    }

    if (!_parsePartitions(input)) {
      return false;
    }

    // quantizer change
    _parseQuant();

    // Frame buffer marking
    br.get();   // ignore the value of update_proba_

    _parseProba();

    return true;
  }

  bool _parseSegmentHeader(VP8SegmentHeader hdr, VP8Proba proba) {
    hdr.useSegment = br.get() != 0;
    if (hdr.useSegment) {
      hdr.updateMap = br.get() != 0;
      if (br.get() != 0) {   // update data
        hdr.absoluteDelta = br.get() != 0;
        for (int s = 0; s < NUM_MB_SEGMENTS; ++s) {
          hdr.quantizer[s] = br.get() != 0 ? br.getSignedValue(7) : 0;
        }
        for (int s = 0; s < NUM_MB_SEGMENTS; ++s) {
          hdr.filterStrength[s] = br.get() != 0 ? br.getSignedValue(6) : 0;
        }
      }
      if (hdr.updateMap) {
        for (int s = 0; s < MB_FEATURE_TREE_PROBS; ++s) {
          proba.segments[s] = br.get() != 0 ? br.getValue(8) : 255;
        }
      }
    } else {
      hdr.updateMap = false;
    }

    return true;
  }

  bool _parseFilterHeader() {
    VP8FilterHeader hdr = _filterHeader;
    hdr.simple = br.get() != 0;
    hdr.level = br.getValue(6);
    hdr.sharpness = br.getValue(3);
    hdr.useLfDelta = br.get() != 0;
    if (hdr.useLfDelta) {
      if (br.get() != 0) {   // update lf-delta?
        for (int i = 0; i < NUM_REF_LF_DELTAS; ++i) {
          if (br.get() != 0) {
            hdr.refLfDelta[i] = br.getSignedValue(6);
          }
        }

        for (int i = 0; i < NUM_MODE_LF_DELTAS; ++i) {
          if (br.get() != 0) {
            hdr.modeLfDelta[i] = br.getSignedValue(6);
          }
        }
      }
    }

    _filterType = (hdr.level == 0) ? 0 : hdr.simple ? 1 : 2;

    return true;
  }

  /**
   * This function returns VP8_STATUS_SUSPENDED if we don't have all the
   * necessary data in 'buf'.
   * This case is not necessarily an error (for incremental decoding).
   * Still, no bitreader is ever initialized to make it possible to read
   * unavailable memory.
   * If we don't even have the partitions' sizes, than VP8_STATUS_NOT_ENOUGH_DATA
   * is returned, and this is an unrecoverable error.
   * If the partitions were positioned ok, VP8_STATUS_OK is returned.
   */
  bool _parsePartitions(InputBuffer input) {
    int sz = 0;
    int bufEnd = input.length;

    _numPartitions = 1 << br.getValue(2);
    int lastPart = _numPartitions - 1;
    int partStart = lastPart * 3;
    if (bufEnd < partStart) {
      // we can't even read the sizes with sz[]! That's a failure.
      return false;
    }

    for (int p = 0; p < lastPart; ++p) {
      InputBuffer szb = input.peekBytes(3, sz);
      final int psize = szb[0] | (szb[1] << 8) | (szb[2] << 16);
      int partEnd = partStart + psize;
      if (partEnd > bufEnd) {
        partEnd = bufEnd;
      }

      InputBuffer pin = input.subset(partEnd - partStart, position: partStart);
      _partitions[p] = new VP8BitReader(pin);
      partStart = partEnd;
      sz += 3;
    }

    InputBuffer pin = input.subset(bufEnd - partStart,
                                   position: input.position + partStart);
    _partitions[lastPart] = new VP8BitReader(pin);

    // Init is ok, but there's not enough data
    return (partStart < bufEnd) ? true : false;
  }

  void _parseQuant() {
    final int base_q0 = br.getValue(7);
    final int dqy1_dc = br.get() != 0 ? br.getSignedValue(4) : 0;
    final int dqy2_dc = br.get() != 0 ? br.getSignedValue(4) : 0;
    final int dqy2_ac = br.get() != 0 ? br.getSignedValue(4) : 0;
    final int dquv_dc = br.get() != 0 ? br.getSignedValue(4) : 0;
    final int dquv_ac = br.get() != 0 ? br.getSignedValue(4) : 0;

    VP8SegmentHeader hdr = _segmentHeader;

    for (int i = 0; i < NUM_MB_SEGMENTS; ++i) {
      int q;
      if (hdr.useSegment) {
        q = hdr.quantizer[i];
        if (!hdr.absoluteDelta) {
          q += base_q0;
        }
      } else {
        if (i > 0) {
          _dqm[i] = _dqm[0];
          continue;
        } else {
          q = base_q0;
        }
      }

      VP8QuantMatrix m = _dqm[i];
      m.y1Mat[0] = DC_TABLE[_clip(q + dqy1_dc, 127)];
      m.y1Mat[1] = AC_TABLE[_clip(q + 0,       127)];

      m.y2Mat[0] = DC_TABLE[_clip(q + dqy2_dc, 127)] * 2;
      // For all x in [0..284], x*155/100 is bitwise equal to (x*101581) >> 16.
      // The smallest precision for that is '(x*6349) >> 12' but 16 is a good
      // word size.
      m.y2Mat[1] = (AC_TABLE[_clip(q + dqy2_ac, 127)] * 101581) >> 16;
      if (m.y2Mat[1] < 8) {
        m.y2Mat[1] = 8;
      }

      m.uvMat[0] = DC_TABLE[_clip(q + dquv_dc, 117)];
      m.uvMat[1] = AC_TABLE[_clip(q + dquv_ac, 127)];

      m.uvQuant = q + dquv_ac;   // for dithering strength evaluation
    }
  }

  void _parseProba() {
    VP8Proba proba = _proba;
    for (int t = 0; t < NUM_TYPES; ++t) {
      for (int b = 0; b < NUM_BANDS; ++b) {
        for (int c = 0; c < NUM_CTX; ++c) {
          for (int p = 0; p < NUM_PROBAS; ++p) {
            final int v = br.getBit(COEFFS_UPDATE_PROBA[t][b][c][p]) != 0 ?
                br.getValue(8) : COEFFS_PROBA_0[t][b][c][p];
                proba.bands[t][b].probas[c][p] = v;
          }
        }
      }
    }

    _useSkipProba = br.get() != 0;
    if (_useSkipProba) {
      _skipP = br.getValue(8);
    }
  }

  /**
   * Precompute the filtering strength for each segment and each i4x4/i16x16
   * mode.
   */
  void _precomputeFilterStrengths() {
    if (_filterType > 0) {
      VP8FilterHeader hdr = _filterHeader;
      for (int s = 0; s < NUM_MB_SEGMENTS; ++s) {
        // First, compute the initial level
        int baseLevel;
        if (_segmentHeader.useSegment) {
          baseLevel = _segmentHeader.filterStrength[s];
          if (!_segmentHeader.absoluteDelta) {
            baseLevel += hdr.level;
          }
        } else {
          baseLevel = hdr.level;
        }

        for (int i4x4 = 0; i4x4 <= 1; ++i4x4) {
          VP8FInfo info = _fStrengths[s][i4x4];
          int level = baseLevel;
          if (hdr.useLfDelta) {
            level += hdr.refLfDelta[0];
            if (i4x4 != 0) {
              level += hdr.modeLfDelta[0];
            }
          }

          level = (level < 0) ? 0 : (level > 63) ? 63 : level;
          if (level > 0) {
            int ilevel = level;
            if (hdr.sharpness > 0) {
              if (hdr.sharpness > 4) {
                ilevel >>= 2;
              } else {
                ilevel >>= 1;
              }

              if (ilevel > 9 - hdr.sharpness) {
                ilevel = 9 - hdr.sharpness;
              }
            }

            if (ilevel < 1) {
              ilevel = 1;
            }

            info.fInnerLevel = ilevel;
            info.fLimit = 2 * level + ilevel;
            info.hevThresh = (level >= 40) ? 2 : (level >= 15) ? 1 : 0;
          } else {
            info.fLimit = 0;  // no filtering
          }

          info.fInner = i4x4 != 0;
        }
      }
    }
  }

  bool _initFrame() {
    if (webp._alphaData != null) {
      _alphaData = webp._alphaData;
    }

    _fStrengths = new List<List<VP8FInfo>>(NUM_MB_SEGMENTS);
    for (int i = 0; i < NUM_MB_SEGMENTS; ++i) {
      _fStrengths[i] = [new VP8FInfo(), new VP8FInfo()];
    }

    _yuvT = new List<VP8TopSamples>(_mbWidth);
    for (int i = 0; i < _mbWidth; ++i) {
      _yuvT[i] = new VP8TopSamples();
    }

    _yuvBlock = new Uint8List(YUV_SIZE);

    _intraT = new Uint8List(4 * _mbWidth);

    _cacheYStride = 16 * _mbWidth;
    _cacheUVStride = 8 * _mbWidth;

    final int extra_rows = FILTER_EXTRA_ROWS[_filterType];
    final int extra_y = extra_rows * _cacheYStride;
    final int extra_uv = (extra_rows ~/ 2) * _cacheUVStride;

    _cacheY = new InputBuffer(new Uint8List(16 * _cacheYStride + extra_y),
                         offset: extra_y);

    _cacheU = new InputBuffer(new Uint8List(8 * _cacheUVStride + extra_uv),
                         offset: extra_uv);

    _cacheV = new InputBuffer(new Uint8List(8 * _cacheUVStride + extra_uv),
                         offset: extra_uv);

    _tmpY = new InputBuffer(new Uint8List(webp.width));

    final int uvWidth = (webp.width + 1) >> 1;
    _tmpU = new InputBuffer(new Uint8List(uvWidth));
    _tmpV = new InputBuffer(new Uint8List(uvWidth));

    // Define the area where we can skip in-loop filtering, in case of cropping.
    //
    // 'Simple' filter reads two luma samples outside of the macroblock
    // and filters one. It doesn't filter the chroma samples. Hence, we can
    // avoid doing the in-loop filtering before crop_top/crop_left position.
    // For the 'Complex' filter, 3 samples are read and up to 3 are filtered.
    // Means: there's a dependency chain that goes all the way up to the
    // top-left corner of the picture (MB #0). We must filter all the previous
    // macroblocks.
    {
      final int extraPixels = FILTER_EXTRA_ROWS[_filterType];
      if (_filterType == 2) {
        // For complex filter, we need to preserve the dependency chain.
        _tlMbX = 0;
        _tlMbY = 0;
      } else {
        // For simple filter, we can filter only the cropped region.
        // We include 'extra_pixels' on the other side of the boundary, since
        // vertical or horizontal filtering of the previous macroblock can
        // modify some abutting pixels.
        _tlMbX = (_cropLeft - extraPixels) ~/ 16;
        _tlMbY = (_cropTop - extraPixels) ~/ 16;
        if (_tlMbX < 0) {
          _tlMbX = 0;
        }
        if (_tlMbY < 0) {
          _tlMbY = 0;
        }
      }

      // We need some 'extra' pixels on the right/bottom.
      _brMbY = (_cropBottom + 15 + extraPixels) ~/ 16;
      _brMbX = (_cropRight + 15 + extraPixels) ~/ 16;
      if (_brMbX > _mbWidth) {
        _brMbX = _mbWidth;
      }
      if (_brMbY > _mbHeight) {
        _brMbY = _mbHeight;
      }
    }

    _mbInfo = new List<VP8MB>(_mbWidth + 1);
    _mbData = new List<VP8MBData>(_mbWidth);
    _fInfo = new List<VP8FInfo>(_mbWidth);

    for (int i = 0; i < _mbWidth; ++i) {
      _mbInfo[i] = new VP8MB();
      _mbData[i] = new VP8MBData();
    }
    _mbInfo[_mbWidth] = new VP8MB();

    _precomputeFilterStrengths();

    // Init critical function pointers and look-up tables.
    _dsp = new VP8Filter();
    return true;
  }

  bool _parseFrame() {
    for (_mbY = 0; _mbY < _brMbY; ++_mbY) {
      // Parse bitstream for this row.
      VP8BitReader tokenBr = _partitions[_mbY & (_numPartitions - 1)];
      for (; _mbX < _mbWidth; ++_mbX) {
        if (!_decodeMB(tokenBr)) {
          return false;
        }
      }

      // Prepare for next scanline
      VP8MB left = _mbInfo[0];
      left.nz = 0;
      left.nzDc = 0;
      _intraL.fillRange(0, _intraL.length, B_DC_PRED);
      _mbX = 0;

      // Reconstruct, filter and emit the row.
      if (!_processRow()) {
        return false;
      }
    }

    return true;
  }

  bool _processRow() {
    _reconstructRow();

    bool useFilter = (_filterType > 0) && (_mbY >= _tlMbY) && (_mbY <= _brMbY);
    return _finishRow(useFilter);
  }

  void _reconstructRow() {
    int mb_y = _mbY;
    InputBuffer y_dst = new InputBuffer(_yuvBlock, offset: Y_OFF);
    InputBuffer u_dst = new InputBuffer(_yuvBlock, offset: U_OFF);
    InputBuffer v_dst = new InputBuffer(_yuvBlock, offset: V_OFF);

    for (int mb_x = 0; mb_x < _mbWidth; ++mb_x) {
      VP8MBData block = _mbData[mb_x];

      // Rotate in the left samples from previously decoded block. We move four
      // pixels at a time for alignment reason, and because of in-loop filter.
      if (mb_x > 0) {
        for (int j = -1; j < 16; ++j) {
          y_dst.memcpy(j * BPS - 4, 4, y_dst, j * BPS + 12);
        }

        for (int j = -1; j < 8; ++j) {
          u_dst.memcpy(j * BPS - 4, 4, u_dst, j * BPS + 4);
          v_dst.memcpy(j * BPS - 4, 4, v_dst, j * BPS + 4);
        }
      } else {
        for (int j = 0; j < 16; ++j) {
          y_dst[j * BPS - 1] = 129;
        }

        for (int j = 0; j < 8; ++j) {
          u_dst[j * BPS - 1] = 129;
          v_dst[j * BPS - 1] = 129;
        }

        // Init top-left sample on left column too
        if (mb_y > 0) {
          y_dst[-1 - BPS] = u_dst[-1 - BPS] = v_dst[-1 - BPS] = 129;
        }
      }

      // bring top samples into the cache
      VP8TopSamples top_yuv = _yuvT[mb_x];
      Int16List coeffs = block.coeffs;
      int bits = block.nonZeroY;

      if (mb_y > 0) {
        y_dst.memcpy(-BPS, 16, top_yuv.y);
        u_dst.memcpy(-BPS, 8, top_yuv.u);
        v_dst.memcpy(-BPS, 8, top_yuv.v);
      } else if (mb_x == 0) {
        // we only need to do this init once at block (0,0).
        // Afterward, it remains valid for the whole topmost row.
        y_dst.memset(-BPS - 1, 16 + 4 + 1, 127);
        u_dst.memset(-BPS - 1, 8 + 1, 127);
        v_dst.memset(-BPS - 1, 8 + 1, 127);
      }

      // predict and add residuals
      if (block.isIntra4x4) {   // 4x4
        InputBuffer topRight = new InputBuffer.from(y_dst, offset: -BPS + 16);
        Uint32List topRight32 = topRight.toUint32List();

        if (mb_y > 0) {
          if (mb_x >= _mbWidth - 1) { // on rightmost border
            topRight.memset(0, 4, top_yuv.y[15]);
          } else {
            topRight.memcpy(0, 4, _yuvT[mb_x + 1].y);
          }
        }

        // replicate the top-right pixels below
        int p = topRight32[0];
        topRight32[3 * BPS] = p;
        topRight32[2 * BPS] = p;
        topRight32[BPS] = p;

        // predict and add residuals for all 4x4 blocks in turn.
        for (int n = 0; n < 16; ++n, bits = (bits << 2) & 0xffffffff) {
          InputBuffer dst = new InputBuffer.from(y_dst, offset: kScan[n]);

          VP8Filter.PredLuma4[block.imodes[n]](dst);

          _doTransform(bits, new InputBuffer(coeffs, offset: n * 16), dst);
        }
      } else { // 16x16
        int predFunc = _checkMode(mb_x, mb_y, block.imodes[0]);

        VP8Filter.PredLuma16[predFunc](y_dst);
        if (bits != 0) {
          for (int n = 0; n < 16; ++n, bits = (bits << 2) & 0xffffffff) {
            InputBuffer dst = new InputBuffer.from(y_dst, offset: kScan[n]);

            _doTransform(bits, new InputBuffer(coeffs, offset: n * 16), dst);
          }
        }
      }

      // Chroma
      int bits_uv = block.nonZeroUV;
      int pred_func = _checkMode(mb_x, mb_y, block.uvmode);
      VP8Filter.PredChroma8[pred_func](u_dst);
      VP8Filter.PredChroma8[pred_func](v_dst);

      InputBuffer c1 = new InputBuffer(coeffs, offset: 16 * 16);
      _doUVTransform(bits_uv, c1, u_dst);

      InputBuffer c2 = new InputBuffer(coeffs, offset: 20 * 16);
      _doUVTransform(bits_uv >> 8, c2, v_dst);

      // stash away top samples for next block
      if (mb_y < _mbHeight - 1) {
        top_yuv.y.setRange(0, 16, y_dst.toUint8List(), 15 * BPS);
        top_yuv.u.setRange(0, 8, u_dst.toUint8List(), 7 * BPS);
        top_yuv.v.setRange(0, 8, v_dst.toUint8List(), 7 * BPS);
      }

      // Transfer reconstructed samples from yuv_b_ cache to final destination.
      int y_out = mb_x * 16; // dec->cache_y_ +
      int u_out = mb_x * 8; // dec->cache_u_ +
      int v_out = mb_x * 8; // _dec->cache_v_ +

      for (int j = 0; j < 16; ++j) {
        int start = y_out + j * _cacheYStride;
        _cacheY.memcpy(start, 16, y_dst, j * BPS);
      }

      for (int j = 0; j < 8; ++j) {
        int start = u_out + j * _cacheUVStride;
        _cacheU.memcpy(start, 8, u_dst, j * BPS);

        start = v_out + j * _cacheUVStride;
        _cacheV.memcpy(start, 8, v_dst, j * BPS);
      }
    }
  }

  static const List<int> kScan = const [
    0 +  0 * BPS,  4 +  0 * BPS, 8 +  0 * BPS, 12 +  0 * BPS,
    0 +  4 * BPS,  4 +  4 * BPS, 8 +  4 * BPS, 12 +  4 * BPS,
    0 +  8 * BPS,  4 +  8 * BPS, 8 +  8 * BPS, 12 +  8 * BPS,
    0 + 12 * BPS,  4 + 12 * BPS, 8 + 12 * BPS, 12 + 12 * BPS ];

  static int _checkMode(int mb_x, int mb_y, int mode) {
    if (mode == B_DC_PRED) {
      if (mb_x == 0) {
        return (mb_y == 0) ? B_DC_PRED_NOTOPLEFT : B_DC_PRED_NOLEFT;
      } else {
        return (mb_y == 0) ? B_DC_PRED_NOTOP : B_DC_PRED;
      }
    }
    return mode;
  }

  void _doTransform(int bits, InputBuffer src, InputBuffer dst) {
    switch (bits >> 30) {
      case 3:
        _dsp.transform(src, dst, false);
        break;
      case 2:
        _dsp.transformAC3(src, dst);
        break;
      case 1:
        _dsp.transformDC(src, dst);
        break;
      default:
        break;
    }
  }

  void _doUVTransform(int bits, InputBuffer src, InputBuffer dst) {
    if (bits & 0xff != 0) { // any non-zero coeff at all?
      if (bits & 0xaa != 0) { // any non-zero AC coefficient?
        // note we don't use the AC3 variant for U/V
        _dsp.transformUV(src, dst);
      } else {
        _dsp.transformDCUV(src, dst);
      }
    }
  }

  // vertical position of a MB
  int MACROBLOCK_VPOS(int mb_y) => mb_y * 16;

  /**
   * kFilterExtraRows[] = How many extra lines are needed on the MB boundary
   * for caching, given a filtering level.
   * Simple filter:  up to 2 luma samples are read and 1 is written.
   * Complex filter: up to 4 luma samples are read and 3 are written. Same for
   *                U/V, so it's 8 samples total (because of the 2x upsampling).
   */
  static const List<int> kFilterExtraRows = const [ 0, 2, 8 ];

  void _doFilter(int mbX, int mbY) {
    final int yBps = _cacheYStride;
    VP8FInfo fInfo = _fInfo[mbX];
    InputBuffer yDst = new InputBuffer.from(_cacheY, offset: mbX * 16);
    final int ilevel = fInfo.fInnerLevel;
    final int limit = fInfo.fLimit;
    if (limit == 0) {
      return;
    }

    if (_filterType == 1) {   // simple
      if (mbX > 0) {
        _dsp.simpleHFilter16(yDst, yBps, limit + 4);
      }
      if (fInfo.fInner) {
        _dsp.simpleHFilter16i(yDst, yBps, limit);
      }
      if (mbY > 0) {
        _dsp.simpleVFilter16(yDst, yBps, limit + 4);
      }
      if (fInfo.fInner) {
        _dsp.simpleVFilter16i(yDst, yBps, limit);
      }
    } else {    // complex
      final int uvBps = _cacheUVStride;
      InputBuffer uDst = new InputBuffer.from(_cacheU, offset: mbX * 8);
      InputBuffer vDst = new InputBuffer.from(_cacheV, offset: mbX * 8);

      final int hevThresh = fInfo.hevThresh;
      if (mbX > 0) {
        _dsp.hFilter16(yDst, yBps, limit + 4, ilevel, hevThresh);
        _dsp.hFilter8(uDst, vDst, uvBps, limit + 4, ilevel, hevThresh);
      }
      if (fInfo.fInner) {
        _dsp.hFilter16i(yDst, yBps, limit, ilevel, hevThresh);
        _dsp.hFilter8i(uDst, vDst, uvBps, limit, ilevel, hevThresh);
      }
      if (mbY > 0) {
        _dsp.vFilter16(yDst, yBps, limit + 4, ilevel, hevThresh);
        _dsp.vFilter8(uDst, vDst, uvBps, limit + 4, ilevel, hevThresh);
      }
      if (fInfo.fInner) {
        _dsp.vFilter16i(yDst, yBps, limit, ilevel, hevThresh);
        _dsp.vFilter8i(uDst, vDst, uvBps, limit, ilevel, hevThresh);
      }
    }
  }

  /**
   * Filter the decoded macroblock row (if needed)
   */
  void _filterRow() {
    for (int mbX = _tlMbX; mbX < _brMbX; ++mbX) {
      _doFilter(mbX, _mbY);
    }
  }

  void _ditherRow() {
  }


  /**
   * This function is called after a row of macroblocks is finished decoding.
   * It also takes into account the following restrictions:
   *
   * * In case of in-loop filtering, we must hold off sending some of the bottom
   *    pixels as they are yet unfiltered. They will be when the next macroblock
   *    row is decoded. Meanwhile, we must preserve them by rotating them in the
   *    cache area. This doesn't hold for the very bottom row of the uncropped
   *    picture of course.
   *  * we must clip the remaining pixels against the cropping area. The VP8Io
   *    struct must have the following fields set correctly before calling put():
   */
  bool _finishRow(bool useFilter) {
    final int extraYRows = kFilterExtraRows[_filterType];
    final int ySize = extraYRows * _cacheYStride;
    final int uvSize = (extraYRows ~/ 2) * _cacheUVStride;
    InputBuffer yDst = new InputBuffer.from(_cacheY, offset: -ySize);
    InputBuffer uDst = new InputBuffer.from(_cacheU, offset: -uvSize);
    InputBuffer vDst = new InputBuffer.from(_cacheV, offset: -uvSize);
    final int mbY = _mbY;
    final bool isFirstRow = (mbY == 0);
    final bool isLastRow = (mbY >= _brMbY - 1);
    int yStart = MACROBLOCK_VPOS(mbY);
    int yEnd = MACROBLOCK_VPOS(mbY + 1);

    if (useFilter) {
      _filterRow();
    }

    if (_dither) {
      _ditherRow();
    }

    if (!isFirstRow) {
      yStart -= extraYRows;
      _y = new InputBuffer.from(yDst);
      _u = new InputBuffer.from(uDst);
      _v = new InputBuffer.from(vDst);
    } else {
      _y = new InputBuffer.from(_cacheY);
      _u = new InputBuffer.from(_cacheU);
      _v = new InputBuffer.from(_cacheV);
    }

    if (!isLastRow) {
      yEnd -= extraYRows;
    }

    if (yEnd > _cropBottom) {
      yEnd = _cropBottom;    // make sure we don't overflow on last row.
    }

    _a = null;
    if (_alphaData != null && yStart < yEnd) {
      _a = _decompressAlphaRows(yStart, yEnd - yStart);
      if (_a == null) {
        return false;
      }
    }

    if (yStart < _cropTop) {
      final int deltaY = _cropTop - yStart;
      yStart = _cropTop;

      _y.offset += _cacheYStride * deltaY;
      _u.offset += _cacheUVStride * (deltaY >> 1);
      _v.offset += _cacheUVStride * (deltaY >> 1);

      if (_a != null) {
        _a.offset += webp.width * deltaY;
      }
    }

    if (yStart < yEnd) {
      _y.offset += _cropLeft;
      _u.offset += _cropLeft >> 1;
      _v.offset += _cropLeft >> 1;
      if (_a != null) {
        _a.offset += _cropLeft;
      }

      _put(yStart - _cropTop, _cropRight - _cropLeft, yEnd - yStart);
    }

    // rotate top samples if needed
    if (!isLastRow) {
      _cacheY.memcpy(-ySize, ySize, yDst, 16 * _cacheYStride);
      _cacheU.memcpy(-uvSize, uvSize, uDst, 8 * _cacheUVStride);
      _cacheV.memcpy(-uvSize, uvSize, vDst, 8 * _cacheUVStride);
    }

    return true;
  }

  bool _put(int mbY, int mbW, int mbH) {
    if (mbW <= 0 || mbH <= 0) {
      return false;
    }

    int numLinesOut = _emitFancyRGB(mbY, mbW, mbH);
    _emitAlphaRGB(mbY, mbW, mbH);

    //_lastY += numLinesOut;

    return true;
  }

  int _clip8(int v) {
    int d = ((v & XOR_YUV_MASK2) == 0) ? (v >> YUV_FIX2) : (v < 0) ? 0 : 255;
    return d;
  }

  int _yuvToR(int y, int v) {
    return _clip8(kYScale * y + kVToR * v + kRCst);
  }

  int _yuvToG(int y, int u, int v) {
    return _clip8(kYScale * y - kUToG * u - kVToG * v + kGCst);
  }

  int _yuvToB(int y, int u) {
    return _clip8(kYScale * y + kUToB * u + kBCst);
  }

  void _yuvToRgb(int y, int u, int v, InputBuffer rgb) {
    rgb[0] = _yuvToR(y, v);
    rgb[1] = _yuvToG(y, u, v);
    rgb[2] = _yuvToB(y, u);
  }

  void _yuvToRgba(int y, int u, int v, InputBuffer rgba) {
    _yuvToRgb(y, u, v, rgba);
    rgba[3] = 0xff;
  }

  void _upsample(InputBuffer topY, InputBuffer bottomY,
                 InputBuffer topU, InputBuffer topV,
                 InputBuffer curU, InputBuffer curV,
                 InputBuffer topDst, InputBuffer bottomDst,
                 int len) {
    int LOAD_UV(int u, int v) => ((u) | ((v) << 16));

    final int lastPixelPair = (len - 1) >> 1;
    int tl_uv = LOAD_UV(topU[0], topV[0]); // top-left sample
    int l_uv  = LOAD_UV(curU[0], curV[0]); // left-sample

    final int uv0 = (3 * tl_uv + l_uv + 0x00020002) >> 2;
    _yuvToRgba(topY[0], uv0 & 0xff, (uv0 >> 16), topDst);

    if (bottomY != null) {
      final int uv0 = (3 * l_uv + tl_uv + 0x00020002) >> 2;
      _yuvToRgba(bottomY[0], uv0 & 0xff, (uv0 >> 16), bottomDst);
    }

    for (int x = 1; x <= lastPixelPair; ++x) {
      final int t_uv = LOAD_UV(topU[x], topV[x]); // top sample
      final int uv   = LOAD_UV(curU[x], curV[x]); // sample
      // precompute invariant values associated with first and second diagonals
      final int avg = tl_uv + t_uv + l_uv + uv + 0x00080008;
      final int diag_12 = (avg + 2 * (t_uv + l_uv)) >> 3;
      final int diag_03 = (avg + 2 * (tl_uv + uv)) >> 3;

      int uv0 = (diag_12 + tl_uv) >> 1;
      int uv1 = (diag_03 + t_uv) >> 1;

      _yuvToRgba(topY[2 * x - 1], uv0 & 0xff, (uv0 >> 16),
          new InputBuffer.from(topDst, offset: (2 * x - 1) * 4));

      _yuvToRgba(topY[2 * x - 0], uv1 & 0xff, (uv1 >> 16),
              new InputBuffer.from(topDst, offset: (2 * x - 0) * 4));

      if (bottomY != null) {
        uv0 = (diag_03 + l_uv) >> 1;
        uv1 = (diag_12 + uv) >> 1;

        _yuvToRgba(bottomY[2 * x - 1], uv0 & 0xff, (uv0 >> 16),
            new InputBuffer.from(bottomDst, offset: (2 * x - 1) * 4));

        _yuvToRgba(bottomY[2 * x], uv1 & 0xff, (uv1 >> 16),
                new InputBuffer.from(bottomDst, offset: (2 * x + 0) * 4));
      }

      tl_uv = t_uv;
      l_uv = uv;
    }

    if ((len & 1) == 0) {
      final int uv0 = (3 * tl_uv + l_uv + 0x00020002) >> 2;
      _yuvToRgba(topY[len - 1], uv0 & 0xff, (uv0 >> 16),
           new InputBuffer.from(topDst, offset: (len - 1) * 4));

      if (bottomY != null) {
        final int uv0 = (3 * l_uv + tl_uv + 0x00020002) >> 2;
        _yuvToRgba(bottomY[len - 1], uv0 & 0xff, (uv0 >> 16),
             new InputBuffer.from(bottomDst, offset: (len - 1) * 4));
      }
    }
  }

  void _emitAlphaRGB(int mbY, int mbW, int mbH) {
    if (_a == null) {
      return;
    }

    final int stride = webp.width * 4;
    InputBuffer alpha = new InputBuffer.from(_a);
    int startY = mbY;
    int numRows = mbH;

    // Compensate for the 1-line delay of the fancy upscaler.
    // This is similar to EmitFancyRGB().
    if (startY == 0) {
      // We don't process the last row yet. It'll be done during the next call.
      --numRows;
    } else {
      --startY;
      // Fortunately, *alpha data is persistent, so we can go back
      // one row and finish alpha blending, now that the fancy upscaler
      // completed the YUV->RGB interpolation.
      alpha.offset -= webp.width;
    }

    InputBuffer dst = new InputBuffer(output.getBytes(), offset: startY * stride + 3);

    if (_cropTop + mbY + mbH == _cropBottom) {
      // If it's the very last call, we process all the remaining rows!
      numRows = _cropBottom - _cropTop - startY;
    }

    for (int y = 0; y < numRows; ++y) {
      for (int x = 0; x < mbW; ++x) {
        final int alphaValue = alpha[x];
        dst[4 * x] = alphaValue & 0xff;
      }

      alpha.offset += webp.width;
      dst.offset += stride;
    }
  }


  int _emitFancyRGB(int mbY, int mbW, int mbH) {
    int numLinesOut = mbH;   // a priori guess
    InputBuffer dst = new InputBuffer(output.getBytes(), offset: mbY * webp.width * 4);
    InputBuffer curY = new InputBuffer.from(_y);
    InputBuffer curU = new InputBuffer.from(_u);
    InputBuffer curV = new InputBuffer.from(_v);
    int y = mbY;
    final int yEnd = mbY + mbH;
    final int uvW = (mbW + 1) >> 1;
    final int stride = webp.width * 4;
    InputBuffer topU = new InputBuffer.from(_tmpU);
    InputBuffer topV = new InputBuffer.from(_tmpV);

    if (y == 0) {
      // First line is special cased. We mirror the u/v samples at boundary.
      _upsample(curY, null, curU, curV, curU, curV, dst, null, mbW);
    } else {
      // We can finish the left-over line from previous call.
      _upsample(_tmpY, curY, topU, topV, curU, curV,
                new InputBuffer.from(dst, offset: -stride), dst, mbW);
      ++numLinesOut;
    }

    // Loop over each output pairs of row.
    topU.buffer = curU.buffer;
    topV.buffer = curV.buffer;
    for (; y + 2 < yEnd; y += 2) {
      topU.offset = curU.offset;
      topV.offset = curV.offset;
      curU.offset += _cacheUVStride;
      curV.offset += _cacheUVStride;
      dst.offset += 2 * stride;
      curY.offset += 2 * _cacheYStride;
      _upsample(new InputBuffer.from(curY, offset: -_cacheYStride), curY,
          topU, topV, curU, curV,
          new InputBuffer.from(dst, offset: -stride), dst, mbW);
    }

    // move to last row
    curY.offset += _cacheYStride;
    if (_cropTop + yEnd < _cropBottom) {
      // Save the unfinished samples for next call (as we're not done yet).
      _tmpY.memcpy(0, mbW, curY);
      _tmpU.memcpy(0, uvW, curU);
      _tmpV.memcpy(0, uvW, curV);
      // The fancy upsampler leaves a row unfinished behind
      // (except for the very last row)
      numLinesOut--;
    } else {
      // Process the very last row of even-sized picture
      if ((yEnd & 1) == 0) {
        _upsample(curY, null, curU, curV, curU, curV,
            new InputBuffer.from(dst, offset: stride), null, mbW);
      }
    }

    return numLinesOut;
  }

  InputBuffer _decompressAlphaRows(int row, int numRows) {
    final int width = webp.width;
    final int height = webp.height;

    if (row < 0 || numRows <= 0 || row + numRows > height) {
      return null;    // sanity check.
    }

    if (row == 0) {
      _alphaPlane = new Uint8List(width * height);
      _alpha = new WebPAlpha(_alphaData, width, height);
    }

    if (!_alpha.isAlphaDecoded) {
      if (!_alpha.decode(row, numRows, _alphaPlane)) {
        return null;
      }
    }

    // Return a pointer to the current decoded row.
    return new InputBuffer(_alphaPlane, offset: row * width);
  }

  bool _decodeMB(VP8BitReader tokenBr) {
    VP8MB left = _mbInfo[0];
    VP8MB mb = _mbInfo[1 + _mbX];
    VP8MBData block = _mbData[_mbX];
    bool skip;

    // Note: we don't save segment map (yet), as we don't expect
    // to decode more than 1 keyframe.
    if (_segmentHeader.updateMap) {
      // Hardcoded tree parsing
      _segment = br.getBit(_proba.segments[0]) == 0 ?
            br.getBit(_proba.segments[1]) :
            2 + br.getBit(_proba.segments[2]);
    }

    skip = _useSkipProba ? br.getBit(_skipP) != 0 : false;

    _parseIntraMode();

    if (!skip) {
      skip = _parseResiduals(mb, tokenBr);
    } else {
      left.nz = mb.nz = 0;
      if (!block.isIntra4x4) {
        left.nzDc = mb.nzDc = 0;
      }
      block.nonZeroY = 0;
      block.nonZeroUV = 0;
    }

    if (_filterType > 0) {  // store filter info
      _fInfo[_mbX] = _fStrengths[_segment][block.isIntra4x4 ? 1 : 0];
      VP8FInfo finfo = _fInfo[_mbX];
      finfo.fInner = finfo.fInner || !skip;
    }

    return true;
  }

  bool _parseResiduals(VP8MB mb, VP8BitReader tokenBr) {
    var bands = _proba.bands;
    List<VP8BandProbas> acProba;
    VP8QuantMatrix q = _dqm[_segment];
    VP8MBData block = _mbData[_mbX];
    InputBuffer dst = new InputBuffer(block.coeffs);
    int di = 0;
    VP8MB leftMb = _mbInfo[0];
    int tnz;
    int lnz;
    int nonZeroY = 0;
    int nonZeroUV = 0;
    int outTopNz;
    int outLeftNz;
    int first;

    dst.memset(0, dst.length, 0);

    if (!block.isIntra4x4) {    // parse DC
      InputBuffer dc = new InputBuffer(new Int16List(16));
      final int ctx = mb.nzDc + leftMb.nzDc;
      final int nz = _getCoeffs(tokenBr, bands[1], ctx, q.y2Mat, 0, dc);
      mb.nzDc = leftMb.nzDc = (nz > 0) ? 1 : 0;
      if (nz > 1) {   // more than just the DC -> perform the full transform
        _transformWHT(dc, dst);
      } else {        // only DC is non-zero -> inlined simplified transform
        final int dc0 = (dc[0] + 3) >> 3;
        for (int i = 0; i < 16 * 16; i += 16) {
          dst[i] = dc0;
        }
      }

      first = 1;
      acProba = bands[0];
    } else {
      first = 0;
      acProba = bands[3];
    }

    tnz = mb.nz & 0x0f;
    lnz = leftMb.nz & 0x0f;
    for (int y = 0; y < 4; ++y) {
      int l = lnz & 1;
      int nzCoeffs = 0;
      for (int x = 0; x < 4; ++x) {
        final int ctx = l + (tnz & 1);
        final int nz = _getCoeffs(tokenBr, acProba, ctx, q.y1Mat, first, dst);
        l = (nz > first) ? 1 : 0;
        tnz = (tnz >> 1) | (l << 7);
        nzCoeffs = _nzCodeBits(nzCoeffs, nz, dst[0] != 0 ? 1 : 0);
        dst.offset += 16;
      }

      tnz >>= 4;
      lnz = (lnz >> 1) | (l << 7);
      nonZeroY = (nonZeroY << 8) | nzCoeffs;
    }
    outTopNz = tnz;
    outLeftNz = lnz >> 4;

    for (int ch = 0; ch < 4; ch += 2) {
      int nzCoeffs = 0;
      tnz = mb.nz >> (4 + ch);
      lnz = leftMb.nz >> (4 + ch);
      for (int y = 0; y < 2; ++y) {
        int l = lnz & 1;
        for (int x = 0; x < 2; ++x) {
          final int ctx = l + (tnz & 1);
          final int nz = _getCoeffs(tokenBr, bands[2], ctx, q.uvMat, 0, dst);
          l = (nz > 0) ? 1 : 0;
          tnz = (tnz >> 1) | (l << 3);
          nzCoeffs = _nzCodeBits(nzCoeffs, nz, dst[0] != 0 ? 1 : 0);
          dst.offset += 16;
        }

        tnz >>= 2;
        lnz = (lnz >> 1) | (l << 5);
      }

      // Note: we don't really need the per-4x4 details for U/V blocks.
      nonZeroUV |= nzCoeffs << (4 * ch);
      outTopNz |= (tnz << 4) << ch;
      outLeftNz |= (lnz & 0xf0) << ch;
    }

    mb.nz = outTopNz;
    leftMb.nz = outLeftNz;

    block.nonZeroY = nonZeroY;
    block.nonZeroUV = nonZeroUV;

    // We look at the mode-code of each block and check if some blocks have less
    // than three non-zero coeffs (code < 2). This is to avoid dithering flat and
    // empty blocks.
    block.dither = (nonZeroUV & 0xaaaa) != 0 ? 0 : q.dither;

    // will be used for further optimization
    return (nonZeroY | nonZeroUV) == 0;
  }

  void _transformWHT(InputBuffer src, InputBuffer out) {
    Int32List tmp = new Int32List(16);

    int oi = 0;
    for (int i = 0; i < 4; ++i) {
      final int a0 = src[0 + i] + src[12 + i];
      final int a1 = src[4 + i] + src[ 8 + i];
      final int a2 = src[4 + i] - src[ 8 + i];
      final int a3 = src[0 + i] - src[12 + i];
      tmp[0  + i] = a0 + a1;
      tmp[8  + i] = a0 - a1;
      tmp[4  + i] = a3 + a2;
      tmp[12 + i] = a3 - a2;
    }

    for (int i = 0; i < 4; ++i) {
      final int dc = tmp[0 + i * 4] + 3;    // w/ rounder
      final int a0 = dc             + tmp[3 + i * 4];
      final int a1 = tmp[1 + i * 4] + tmp[2 + i * 4];
      final int a2 = tmp[1 + i * 4] - tmp[2 + i * 4];
      final int a3 = dc             - tmp[3 + i * 4];
      out[oi + 0] = (a0 + a1) >> 3;
      out[oi + 16] = (a3 + a2) >> 3;
      out[oi + 32] = (a0 - a1) >> 3;
      out[oi + 48] = (a3 - a2) >> 3;

      oi += 64;
    }
  }

  int _nzCodeBits(int nz_coeffs, int nz, int dc_nz) {
    nz_coeffs <<= 2;
    nz_coeffs |= (nz > 3) ? 3 : (nz > 1) ? 2 : dc_nz;
    return nz_coeffs;
  }

  static const List<int> kBands = const [
     0, 1, 2, 3, 6, 4, 5, 6, 6, 6, 6, 6, 6, 6, 6, 7, 0];

  static const List<int> kCat3 = const [ 173, 148, 140 ];
  static const List<int> kCat4 = const [ 176, 155, 140, 135 ];
  static const List<int> kCat5 = const [ 180, 157, 141, 134, 130 ];
  static const List<int> kCat6 = const [ 254, 254, 243, 230, 196, 177, 153,
                                         140, 133, 130, 129 ];
  static const List<List<int>> kCat3456 = const [ kCat3, kCat4, kCat5, kCat6 ];
  static const List<int> kZigzag = const [ 0, 1, 4, 8,  5, 2, 3, 6,  9, 12,
                                           13, 10,  7, 11, 14, 15 ];

  /**
   * See section 13-2: http://tools.ietf.org/html/rfc6386#section-13.2
   */
  int _getLargeValue(VP8BitReader br, List<int> p) {
    int v;
    if (br.getBit(p[3]) == 0) {
      if (br.getBit(p[4]) == 0) {
        v = 2;
      } else {
        v = 3 + br.getBit(p[5]);
      }
    } else {
      if (br.getBit(p[6]) == 0) {
        if (br.getBit(p[7]) == 0) {
          v = 5 + br.getBit(159);
        } else {
          v = 7 + 2 * br.getBit(165);
          v += br.getBit(145);
        }
      } else {
        final int bit1 = br.getBit(p[8]);
        final int bit0 = br.getBit(p[9 + bit1]);
        final int cat = 2 * bit1 + bit0;
        v = 0;
        List<int> tab = kCat3456[cat];
        for (int i = 0, len = tab.length; i < len; ++i) {
          v += v + br.getBit(tab[i]);
        }
        v += 3 + (8 << cat);
      }
    }
    return v;
  }


  /**
   * Returns the position of the last non-zero coeff plus one
   */
  int _getCoeffs(VP8BitReader br, List<VP8BandProbas> prob,
                 int ctx, List<int> dq, int n, InputBuffer out) {
    // n is either 0 or 1 here. kBands[n] is not necessary for extracting '*p'.
    List<int> p = prob[n].probas[ctx];
    for (; n < 16; ++n) {
      if (br.getBit(p[0]) == 0) {
        return n;  // previous coeff was last non-zero coeff
      }

      while (br.getBit(p[1]) == 0) { // sequence of zero coeffs
        p = prob[kBands[++n]].probas[0];
        if (n == 16) {
          return 16;
        }
      }

      { // non zero coeff
        List<Uint8List> p_ctx = prob[kBands[n + 1]].probas;
        int v;
        if (br.getBit(p[2]) == 0) {
          v = 1;
          p = p_ctx[1];
        } else {
          v = _getLargeValue(br, p);
          p = p_ctx[2];
        }

        out[kZigzag[n]] = br.getSigned(v) * dq[n > 0 ? 1 : 0];
      }
    }
    return 16;
  }

  void _parseIntraMode() {
    int ti = 4 * _mbX;
    int li = 0;
    Uint8List top = _intraT;
    Uint8List left = _intraL;

    VP8MBData block = _mbData[_mbX];

    // decide for B_PRED first
    block.isIntra4x4 = br.getBit(145) == 0;
    if (!block.isIntra4x4) {
      // Hardcoded 16x16 intra-mode decision tree.
      final int ymode =
          br.getBit(156) != 0 ?
              (br.getBit(128) != 0 ? TM_PRED : H_PRED) :
              (br.getBit(163) != 0 ? V_PRED : DC_PRED);
      block.imodes[0] = ymode;

      top.fillRange(ti, ti + 4, ymode);
      left.fillRange(li, li + 4, ymode);
    } else {
      Uint8List modes = block.imodes;
      int mi = 0;
      for (int y = 0; y < 4; ++y) {
        int ymode = left[y];
        for (int x = 0; x < 4; ++x) {
          List<int> prob = kBModesProba[top[ti + x]][ymode];

          // Generic tree-parsing
          int b = br.getBit(prob[0]);
          int i = kYModesIntra4[b];

          while (i > 0) {
            i = kYModesIntra4[2 * i + br.getBit(prob[i])];
          }

          ymode = -i;
          top[ti + x] = ymode;
        }

        modes.setRange(mi, mi + 4, top, ti);

        mi += 4;
        left[y] = ymode;
      }
    }

    // Hardcoded UVMode decision tree
    block.uvmode = br.getBit(142) == 0 ? DC_PRED
        : br.getBit(114) == 0 ? V_PRED
            : br.getBit(183) != 0 ? TM_PRED : H_PRED;
  }

  // Main data source
  VP8BitReader br;

  Image output;

  VP8Filter _dsp;

  // headers
  VP8FrameHeader _frameHeader = new VP8FrameHeader();
  VP8PictureHeader _picHeader = new VP8PictureHeader();
  VP8FilterHeader _filterHeader = new VP8FilterHeader();
  VP8SegmentHeader _segmentHeader = new VP8SegmentHeader();

  int _cropLeft;
  int _cropRight;
  int _cropTop;
  int _cropBottom;

  /// Width in macroblock units.
  int _mbWidth;
  /// Height in macroblock units.
  int _mbHeight;

  // Macroblock to process/filter, depending on cropping and filter_type.
  int _tlMbX; // top-left MB that must be in-loop filtered
  int _tlMbY;
  int _brMbX; // last bottom-right MB that must be decoded
  int _brMbY;

  // number of partitions.
  int _numPartitions;
  // per-partition boolean decoders.
  List<VP8BitReader> _partitions = new List<VP8BitReader>(MAX_NUM_PARTITIONS);

  // Dithering strength, deduced from decoding options
  bool _dither = false; // whether to use dithering or not
  VP8Random _ditheringRand; // random generator for dithering

  // dequantization (one set of DC/AC dequant factor per segment)
  List<VP8QuantMatrix> _dqm = new List<VP8QuantMatrix>(NUM_MB_SEGMENTS);

  // probabilities
  VP8Proba _proba;
  bool _useSkipProba;
  int _skipP;

  // Boundary data cache and persistent buffers.
  /// top intra modes values: 4 * _mbWidth
  Uint8List _intraT;
  /// left intra modes values
  Uint8List _intraL = new Uint8List(4);

  /// uint8, segment of the currently parsed block
  int _segment;
  /// top y/u/v samples
  List<VP8TopSamples> _yuvT;

  /// contextual macroblock info (mb_w_ + 1)
  List<VP8MB> _mbInfo;
  /// filter strength info
  List<VP8FInfo> _fInfo;
  /// main block for Y/U/V (size = YUV_SIZE)
  Uint8List _yuvBlock;

  /// macroblock row for storing unfiltered samples
  InputBuffer _cacheY;
  InputBuffer _cacheU;
  InputBuffer _cacheV;
  int _cacheYStride;
  int _cacheUVStride;

  InputBuffer _tmpY;
  InputBuffer _tmpU;
  InputBuffer _tmpV;

  InputBuffer _y;
  InputBuffer _u;
  InputBuffer _v;
  InputBuffer _a;

  /// main memory chunk for the above data. Persistent.
  Uint8List _mem;

  // Per macroblock non-persistent infos.
  /// current position, in macroblock units
  int _mbX = 0;
  int _mbY = 0;
  /// parsed reconstruction data
  List<VP8MBData> _mbData;

  /// 0=off, 1=simple, 2=complex
  int _filterType;
  /// precalculated per-segment/type
  List<List<VP8FInfo>> _fStrengths;

  // Alpha
  /// alpha-plane decoder object
  WebPAlpha _alpha;
  /// compressed alpha data (if present)
  InputBuffer _alphaData;
  /// true if alpha_data_ is decoded in alpha_plane_
  int _isAlphaDecoded;
  /// output. Persistent, contains the whole data.
  Uint8List _alphaPlane;

  // extensions
  int _layerColorspace;
  /// compressed layer data (if present)
  Uint8List _layerData;

  static int _clip(int v, int M) {
    return v < 0 ? 0 : v > M ? M : v;
  }

  static const List<int> kYModesIntra4 = const [
    -B_DC_PRED, 1,
    -B_TM_PRED, 2,
    -B_VE_PRED, 3,
    4, 6,
    -B_HE_PRED, 5,
    -B_RD_PRED, -B_VR_PRED,
    -B_LD_PRED, 7,
    -B_VL_PRED, 8,
    -B_HD_PRED, -B_HU_PRED ];

  static const List<List<List<int>>> kBModesProba = const [
     const [ const [ 231, 120, 48, 89, 115, 113, 120, 152, 112 ],
       const [ 152, 179, 64, 126, 170, 118, 46, 70, 95 ],
       const [ 175, 69, 143, 80, 85, 82, 72, 155, 103 ],
       const [ 56, 58, 10, 171, 218, 189, 17, 13, 152 ],
       const [ 114, 26, 17, 163, 44, 195, 21, 10, 173 ],
       const [ 121, 24, 80, 195, 26, 62, 44, 64, 85 ],
       const [ 144, 71, 10, 38, 171, 213, 144, 34, 26 ],
       const [ 170, 46, 55, 19, 136, 160, 33, 206, 71 ],
       const [ 63, 20, 8, 114, 114, 208, 12, 9, 226 ],
       const [ 81, 40, 11, 96, 182, 84, 29, 16, 36 ] ],
       const [ const [ 134, 183, 89, 137, 98, 101, 106, 165, 148 ],
         const [ 72, 187, 100, 130, 157, 111, 32, 75, 80 ],
         const [ 66, 102, 167, 99, 74, 62, 40, 234, 128 ],
         const [ 41, 53, 9, 178, 241, 141, 26, 8, 107 ],
         const [ 74, 43, 26, 146, 73, 166, 49, 23, 157 ],
         const [ 65, 38, 105, 160, 51, 52, 31, 115, 128 ],
         const [ 104, 79, 12, 27, 217, 255, 87, 17, 7 ],
         const [ 87, 68, 71, 44, 114, 51, 15, 186, 23 ],
         const [ 47, 41, 14, 110, 182, 183, 21, 17, 194 ],
         const [ 66, 45, 25, 102, 197, 189, 23, 18, 22 ] ],
         const [ const [ 88, 88, 147, 150, 42, 46, 45, 196, 205 ],
           const [ 43, 97, 183, 117, 85, 38, 35, 179, 61 ],
           const [ 39, 53, 200, 87, 26, 21, 43, 232, 171 ],
           const [ 56, 34, 51, 104, 114, 102, 29, 93, 77 ],
           const [ 39, 28, 85, 171, 58, 165, 90, 98, 64 ],
           const [ 34, 22, 116, 206, 23, 34, 43, 166, 73 ],
           const [ 107, 54, 32, 26, 51, 1, 81, 43, 31 ],
           const [ 68, 25, 106, 22, 64, 171, 36, 225, 114 ],
           const [ 34, 19, 21, 102, 132, 188, 16, 76, 124 ],
           const [ 62, 18, 78, 95, 85, 57, 50, 48, 51 ] ],
           const [ const [ 193, 101, 35, 159, 215, 111, 89, 46, 111 ],
             const [ 60, 148, 31, 172, 219, 228, 21, 18, 111 ],
             const [ 112, 113, 77, 85, 179, 255, 38, 120, 114 ],
             const [ 40, 42, 1, 196, 245, 209, 10, 25, 109 ],
             const [ 88, 43, 29, 140, 166, 213, 37, 43, 154 ],
             const [ 61, 63, 30, 155, 67, 45, 68, 1, 209 ],
             const [ 100, 80, 8, 43, 154, 1, 51, 26, 71 ],
             const [ 142, 78, 78, 16, 255, 128, 34, 197, 171 ],
             const [ 41, 40, 5, 102, 211, 183, 4, 1, 221 ],
             const [ 51, 50, 17, 168, 209, 192, 23, 25, 82 ] ],
             const [ const [ 138, 31, 36, 171, 27, 166, 38, 44, 229 ],
               const [ 67, 87, 58, 169, 82, 115, 26, 59, 179 ],
               const [ 63, 59, 90, 180, 59, 166, 93, 73, 154 ],
               const [ 40, 40, 21, 116, 143, 209, 34, 39, 175 ],
               const [ 47, 15, 16, 183, 34, 223, 49, 45, 183 ],
               const [ 46, 17, 33, 183, 6, 98, 15, 32, 183 ],
               const [ 57, 46, 22, 24, 128, 1, 54, 17, 37 ],
               const [ 65, 32, 73, 115, 28, 128, 23, 128, 205 ],
               const [ 40, 3, 9, 115, 51, 192, 18, 6, 223 ],
               const [ 87, 37, 9, 115, 59, 77, 64, 21, 47 ] ],
               const [ const [ 104, 55, 44, 218, 9, 54, 53, 130, 226 ],
                 const [ 64, 90, 70, 205, 40, 41, 23, 26, 57 ],
                 const [ 54, 57, 112, 184, 5, 41, 38, 166, 213 ],
                 const [ 30, 34, 26, 133, 152, 116, 10, 32, 134 ],
                 const [ 39, 19, 53, 221, 26, 114, 32, 73, 255 ],
                 const [ 31, 9, 65, 234, 2, 15, 1, 118, 73 ],
                 const [ 75, 32, 12, 51, 192, 255, 160, 43, 51 ],
                 const [ 88, 31, 35, 67, 102, 85, 55, 186, 85 ],
                 const [ 56, 21, 23, 111, 59, 205, 45, 37, 192 ],
                 const [ 55, 38, 70, 124, 73, 102, 1, 34, 98 ] ],
                 const [ const [ 125, 98, 42, 88, 104, 85, 117, 175, 82 ],
                   const [ 95, 84, 53, 89, 128, 100, 113, 101, 45 ],
                   const [ 75, 79, 123, 47, 51, 128, 81, 171, 1 ],
                   const [ 57, 17, 5, 71, 102, 57, 53, 41, 49 ],
                   const [ 38, 33, 13, 121, 57, 73, 26, 1, 85 ],
                   const [ 41, 10, 67, 138, 77, 110, 90, 47, 114 ],
                   const [ 115, 21, 2, 10, 102, 255, 166, 23, 6 ],
                   const [ 101, 29, 16, 10, 85, 128, 101, 196, 26 ],
                   const [ 57, 18, 10, 102, 102, 213, 34, 20, 43 ],
                   const [ 117, 20, 15, 36, 163, 128, 68, 1, 26 ] ],
                   const [ const [ 102, 61, 71, 37, 34, 53, 31, 243, 192 ],
                     const [ 69, 60, 71, 38, 73, 119, 28, 222, 37 ],
                     const [ 68, 45, 128, 34, 1, 47, 11, 245, 171 ],
                     const [ 62, 17, 19, 70, 146, 85, 55, 62, 70 ],
                     const [ 37, 43, 37, 154, 100, 163, 85, 160, 1 ],
                     const [ 63, 9, 92, 136, 28, 64, 32, 201, 85 ],
                     const [ 75, 15, 9, 9, 64, 255, 184, 119, 16 ],
                     const [ 86, 6, 28, 5, 64, 255, 25, 248, 1 ],
                     const [ 56, 8, 17, 132, 137, 255, 55, 116, 128 ],
                     const [ 58, 15, 20, 82, 135, 57, 26, 121, 40 ] ],
                     const [ const [ 164, 50, 31, 137, 154, 133, 25, 35, 218 ],
                       const [ 51, 103, 44, 131, 131, 123, 31, 6, 158 ],
                       const [ 86, 40, 64, 135, 148, 224, 45, 183, 128 ],
                       const [ 22, 26, 17, 131, 240, 154, 14, 1, 209 ],
                       const [ 45, 16, 21, 91, 64, 222, 7, 1, 197 ],
                       const [ 56, 21, 39, 155, 60, 138, 23, 102, 213 ],
                       const [ 83, 12, 13, 54, 192, 255, 68, 47, 28 ],
                       const [ 85, 26, 85, 85, 128, 128, 32, 146, 171 ],
                       const [ 18, 11, 7, 63, 144, 171, 4, 4, 246 ],
                       const [ 35, 27, 10, 146, 174, 171, 12, 26, 128 ] ],
                       const [ const [ 190, 80, 35, 99, 180, 80, 126, 54, 45 ],
                         const [ 85, 126, 47, 87, 176, 51, 41, 20, 32 ],
                         const [ 101, 75, 128, 139, 118, 146, 116, 128, 85 ],
                         const [ 56, 41, 15, 176, 236, 85, 37, 9, 62 ],
                         const [ 71, 30, 17, 119, 118, 255, 17, 18, 138 ],
                         const [ 101, 38, 60, 138, 55, 70, 43, 26, 142 ],
                         const [ 146, 36, 19, 30, 171, 255, 97, 27, 20 ],
                         const [ 138, 45, 61, 62, 219, 1, 81, 188, 64 ],
                         const [ 32, 41, 20, 117, 151, 142, 20, 21, 163 ],
                         const [ 112, 19, 12, 61, 195, 128, 48, 4, 24 ] ] ];

  static const List COEFFS_PROBA_0 = const [
  const [ const [ const [ 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128 ],
      const [ 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128 ],
      const [ 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128 ]
    ],
    const [ const [ 253, 136, 254, 255, 228, 219, 128, 128, 128, 128, 128 ],
      const [ 189, 129, 242, 255, 227, 213, 255, 219, 128, 128, 128 ],
      const [ 106, 126, 227, 252, 214, 209, 255, 255, 128, 128, 128 ]
    ],
    const [ const [ 1, 98, 248, 255, 236, 226, 255, 255, 128, 128, 128 ],
      const [ 181, 133, 238, 254, 221, 234, 255, 154, 128, 128, 128 ],
      const [ 78, 134, 202, 247, 198, 180, 255, 219, 128, 128, 128 ],
    ],
    const [ const [ 1, 185, 249, 255, 243, 255, 128, 128, 128, 128, 128 ],
      const [ 184, 150, 247, 255, 236, 224, 128, 128, 128, 128, 128 ],
      const [ 77, 110, 216, 255, 236, 230, 128, 128, 128, 128, 128 ],
    ],
    const [ const [ 1, 101, 251, 255, 241, 255, 128, 128, 128, 128, 128 ],
      const [ 170, 139, 241, 252, 236, 209, 255, 255, 128, 128, 128 ],
      const [ 37, 116, 196, 243, 228, 255, 255, 255, 128, 128, 128 ]
    ],
    const [ const [ 1, 204, 254, 255, 245, 255, 128, 128, 128, 128, 128 ],
      const [ 207, 160, 250, 255, 238, 128, 128, 128, 128, 128, 128 ],
      const [ 102, 103, 231, 255, 211, 171, 128, 128, 128, 128, 128 ]
    ],
    const [ const [ 1, 152, 252, 255, 240, 255, 128, 128, 128, 128, 128 ],
      const [ 177, 135, 243, 255, 234, 225, 128, 128, 128, 128, 128 ],
      const [ 80, 129, 211, 255, 194, 224, 128, 128, 128, 128, 128 ]
    ],
    const [ const [ 1, 1, 255, 128, 128, 128, 128, 128, 128, 128, 128 ],
      const [ 246, 1, 255, 128, 128, 128, 128, 128, 128, 128, 128 ],
      const [ 255, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128 ]
    ]
  ],
  const [ const [ const [ 198, 35, 237, 223, 193, 187, 162, 160, 145, 155, 62 ],
      const [ 131, 45, 198, 221, 172, 176, 220, 157, 252, 221, 1 ],
      const [ 68, 47, 146, 208, 149, 167, 221, 162, 255, 223, 128 ]
    ],
    const [ const [ 1, 149, 241, 255, 221, 224, 255, 255, 128, 128, 128 ],
      const [ 184, 141, 234, 253, 222, 220, 255, 199, 128, 128, 128 ],
      const [ 81, 99, 181, 242, 176, 190, 249, 202, 255, 255, 128 ]
    ],
    const [ const [ 1, 129, 232, 253, 214, 197, 242, 196, 255, 255, 128 ],
      const [ 99, 121, 210, 250, 201, 198, 255, 202, 128, 128, 128 ],
      const [ 23, 91, 163, 242, 170, 187, 247, 210, 255, 255, 128 ]
    ],
    const [ const [ 1, 200, 246, 255, 234, 255, 128, 128, 128, 128, 128 ],
      const [ 109, 178, 241, 255, 231, 245, 255, 255, 128, 128, 128 ],
      const [ 44, 130, 201, 253, 205, 192, 255, 255, 128, 128, 128 ]
    ],
    const [ const [ 1, 132, 239, 251, 219, 209, 255, 165, 128, 128, 128 ],
      const [ 94, 136, 225, 251, 218, 190, 255, 255, 128, 128, 128 ],
      const [ 22, 100, 174, 245, 186, 161, 255, 199, 128, 128, 128 ]
    ],
    const [ const [ 1, 182, 249, 255, 232, 235, 128, 128, 128, 128, 128 ],
      const [ 124, 143, 241, 255, 227, 234, 128, 128, 128, 128, 128 ],
      const [ 35, 77, 181, 251, 193, 211, 255, 205, 128, 128, 128 ]
    ],
    const [ const [ 1, 157, 247, 255, 236, 231, 255, 255, 128, 128, 128 ],
      const [ 121, 141, 235, 255, 225, 227, 255, 255, 128, 128, 128 ],
      const [ 45, 99, 188, 251, 195, 217, 255, 224, 128, 128, 128 ]
    ],
    const [ const [ 1, 1, 251, 255, 213, 255, 128, 128, 128, 128, 128 ],
      const [ 203, 1, 248, 255, 255, 128, 128, 128, 128, 128, 128 ],
      const [ 137, 1, 177, 255, 224, 255, 128, 128, 128, 128, 128 ]
    ]
  ],
  const [ const [ const [ 253, 9, 248, 251, 207, 208, 255, 192, 128, 128, 128 ],
      const [ 175, 13, 224, 243, 193, 185, 249, 198, 255, 255, 128 ],
      const [ 73, 17, 171, 221, 161, 179, 236, 167, 255, 234, 128 ]
    ],
    const [ const [ 1, 95, 247, 253, 212, 183, 255, 255, 128, 128, 128 ],
      const [ 239, 90, 244, 250, 211, 209, 255, 255, 128, 128, 128 ],
      const [ 155, 77, 195, 248, 188, 195, 255, 255, 128, 128, 128 ]
    ],
    const [ const [ 1, 24, 239, 251, 218, 219, 255, 205, 128, 128, 128 ],
      const [ 201, 51, 219, 255, 196, 186, 128, 128, 128, 128, 128 ],
      const [ 69, 46, 190, 239, 201, 218, 255, 228, 128, 128, 128 ]
    ],
    const [ const [ 1, 191, 251, 255, 255, 128, 128, 128, 128, 128, 128 ],
      const [ 223, 165, 249, 255, 213, 255, 128, 128, 128, 128, 128 ],
      const [ 141, 124, 248, 255, 255, 128, 128, 128, 128, 128, 128 ]
    ],
    const [ const [ 1, 16, 248, 255, 255, 128, 128, 128, 128, 128, 128 ],
      const [ 190, 36, 230, 255, 236, 255, 128, 128, 128, 128, 128 ],
      const [ 149, 1, 255, 128, 128, 128, 128, 128, 128, 128, 128 ]
    ],
    const [ const [ 1, 226, 255, 128, 128, 128, 128, 128, 128, 128, 128 ],
      const [ 247, 192, 255, 128, 128, 128, 128, 128, 128, 128, 128 ],
      const [ 240, 128, 255, 128, 128, 128, 128, 128, 128, 128, 128 ]
    ],
    const [ const [ 1, 134, 252, 255, 255, 128, 128, 128, 128, 128, 128 ],
      const [ 213, 62, 250, 255, 255, 128, 128, 128, 128, 128, 128 ],
      const [ 55, 93, 255, 128, 128, 128, 128, 128, 128, 128, 128 ]
    ],
    const [ const [ 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128 ],
      const [ 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128 ],
      const [ 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128 ]
    ]
  ],
  const [ const [ const [ 202, 24, 213, 235, 186, 191, 220, 160, 240, 175, 255 ],
      const [ 126, 38, 182, 232, 169, 184, 228, 174, 255, 187, 128 ],
      const [ 61, 46, 138, 219, 151, 178, 240, 170, 255, 216, 128 ]
    ],
    const [ const [ 1, 112, 230, 250, 199, 191, 247, 159, 255, 255, 128 ],
      const [ 166, 109, 228, 252, 211, 215, 255, 174, 128, 128, 128 ],
      const [ 39, 77, 162, 232, 172, 180, 245, 178, 255, 255, 128 ]
    ],
    const [ const [ 1, 52, 220, 246, 198, 199, 249, 220, 255, 255, 128 ],
      const [ 124, 74, 191, 243, 183, 193, 250, 221, 255, 255, 128 ],
      const [ 24, 71, 130, 219, 154, 170, 243, 182, 255, 255, 128 ]
    ],
    const [ const [ 1, 182, 225, 249, 219, 240, 255, 224, 128, 128, 128 ],
      const [ 149, 150, 226, 252, 216, 205, 255, 171, 128, 128, 128 ],
      const [ 28, 108, 170, 242, 183, 194, 254, 223, 255, 255, 128 ]
    ],
    const [ const [ 1, 81, 230, 252, 204, 203, 255, 192, 128, 128, 128 ],
      const [ 123, 102, 209, 247, 188, 196, 255, 233, 128, 128, 128 ],
      const [ 20, 95, 153, 243, 164, 173, 255, 203, 128, 128, 128 ]
    ],
    const [ const [ 1, 222, 248, 255, 216, 213, 128, 128, 128, 128, 128 ],
      const [ 168, 175, 246, 252, 235, 205, 255, 255, 128, 128, 128 ],
      const [ 47, 116, 215, 255, 211, 212, 255, 255, 128, 128, 128 ]
    ],
    const [ const [ 1, 121, 236, 253, 212, 214, 255, 255, 128, 128, 128 ],
      const [ 141, 84, 213, 252, 201, 202, 255, 219, 128, 128, 128 ],
      const [ 42, 80, 160, 240, 162, 185, 255, 205, 128, 128, 128 ]
    ],
    const [ const [ 1, 1, 255, 128, 128, 128, 128, 128, 128, 128, 128 ],
      const [ 244, 1, 255, 128, 128, 128, 128, 128, 128, 128, 128 ],
      const [ 238, 1, 255, 128, 128, 128, 128, 128, 128, 128, 128 ]
    ]
  ] ];


  static const List COEFFS_UPDATE_PROBA = const [
    const [ const [ const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 176, 246, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 223, 241, 252, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 249, 253, 253, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 244, 252, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 234, 254, 254, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 253, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 246, 254, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 239, 253, 254, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 254, 255, 254, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 248, 254, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 251, 255, 254, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 253, 254, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 251, 254, 254, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 254, 255, 254, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 254, 253, 255, 254, 255, 255, 255, 255, 255, 255 ],
      const [ 250, 255, 254, 255, 254, 255, 255, 255, 255, 255, 255 ],
      const [ 254, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ]
    ],
    const [ const [ const [ 217, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 225, 252, 241, 253, 255, 255, 254, 255, 255, 255, 255 ],
      const [ 234, 250, 241, 250, 253, 255, 253, 254, 255, 255, 255 ]
    ],
    const [ const [ 255, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 223, 254, 254, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 238, 253, 254, 254, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 248, 254, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 249, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 253, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 247, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 253, 254, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 252, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 254, 254, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 253, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 254, 253, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 250, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 254, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ]
    ],
    const [ const [ const [ 186, 251, 250, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 234, 251, 244, 254, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 251, 251, 243, 253, 254, 255, 254, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 253, 254, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 236, 253, 254, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 251, 253, 253, 254, 254, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 254, 254, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 254, 254, 254, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 254, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 254, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 254, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ]
    ],
    const [ const [ const [ 248, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 250, 254, 252, 254, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 248, 254, 249, 253, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 253, 253, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 246, 253, 253, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 252, 254, 251, 254, 254, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 254, 252, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 248, 254, 253, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 253, 255, 254, 254, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 251, 254, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 245, 251, 254, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 253, 253, 254, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 251, 253, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 252, 253, 254, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 252, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 249, 255, 254, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 254, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 255, 253, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 250, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ],
    const [ const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 254, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ],
      const [ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 ]
    ] ] ];

  // Paragraph 14.1
  static const List<int> DC_TABLE = const [ // uint8
      4,     5,   6,   7,   8,   9,  10,  10,
      11,   12,  13,  14,  15,  16,  17,  17,
      18,   19,  20,  20,  21,  21,  22,  22,
      23,   23,  24,  25,  25,  26,  27,  28,
      29,   30,  31,  32,  33,  34,  35,  36,
      37,   37,  38,  39,  40,  41,  42,  43,
      44,   45,  46,  46,  47,  48,  49,  50,
      51,   52,  53,  54,  55,  56,  57,  58,
      59,   60,  61,  62,  63,  64,  65,  66,
      67,   68,  69,  70,  71,  72,  73,  74,
      75,   76,  76,  77,  78,  79,  80,  81,
      82,   83,  84,  85,  86,  87,  88,  89,
      91,   93,  95,  96,  98, 100, 101, 102,
      104, 106, 108, 110, 112, 114, 116, 118,
      122, 124, 126, 128, 130, 132, 134, 136,
      138, 140, 143, 145, 148, 151, 154, 157];

  static const List<int> AC_TABLE = const [ // uint16
       4,     5,   6,   7,   8,   9,  10,  11,
       12,   13,  14,  15,  16,  17,  18,  19,
       20,   21,  22,  23,  24,  25,  26,  27,
       28,   29,  30,  31,  32,  33,  34,  35,
       36,   37,  38,  39,  40,  41,  42,  43,
       44,   45,  46,  47,  48,  49,  50,  51,
       52,   53,  54,  55,  56,  57,  58,  60,
       62,   64,  66,  68,  70,  72,  74,  76,
       78,   80,  82,  84,  86,  88,  90,  92,
       94,   96,  98, 100, 102, 104, 106, 108,
       110, 112, 114, 116, 119, 122, 125, 128,
       131, 134, 137, 140, 143, 146, 149, 152,
       155, 158, 161, 164, 167, 170, 173, 177,
       181, 185, 189, 193, 197, 201, 205, 209,
       213, 217, 221, 225, 229, 234, 239, 245,
       249, 254, 259, 264, 269, 274, 279, 284];

  /**
   * FILTER_EXTRA_ROWS = How many extra lines are needed on the MB boundary
   * for caching, given a filtering level.
   * Simple filter:  up to 2 luma samples are read and 1 is written.
   * Complex filter: up to 4 luma samples are read and 3 are written. Same for
   *               U/V, so it's 8 samples total (because of the 2x upsampling).
   */
  static const List<int> FILTER_EXTRA_ROWS = const [ 0, 2, 8 ];

  static const int VP8_SIGNATURE = 0x2a019d;

  static const int MB_FEATURE_TREE_PROBS = 3;
  static const int NUM_MB_SEGMENTS = 4;
  static const int NUM_REF_LF_DELTAS = 4;
  static const int NUM_MODE_LF_DELTAS = 4;    // I4x4, ZERO, *, SPLIT
  static const int MAX_NUM_PARTITIONS = 8;

  static const int B_DC_PRED = 0;   // 4x4 modes
  static const int B_TM_PRED = 1;
  static const int B_VE_PRED = 2;
  static const int B_HE_PRED = 3;
  static const int B_RD_PRED = 4;
  static const int B_VR_PRED = 5;
  static const int B_LD_PRED = 6;
  static const int B_VL_PRED = 7;
  static const int B_HD_PRED = 8;
  static const int B_HU_PRED = 9;
  static const int NUM_BMODES = B_HU_PRED + 1 - B_DC_PRED;

  // Luma16 or UV modes
  static const int DC_PRED = B_DC_PRED;
  static const int V_PRED = B_VE_PRED;
  static const int H_PRED = B_HE_PRED;
  static const int TM_PRED = B_TM_PRED;
  static const int B_PRED = NUM_BMODES;

  // special modes
  static const int B_DC_PRED_NOTOP = 4;
  static const int B_DC_PRED_NOLEFT = 5;
  static const int B_DC_PRED_NOTOPLEFT = 6;
  static const int NUM_B_DC_MODES = 7;

  // Probabilities
  static const int NUM_TYPES = 4;
  static const int NUM_BANDS = 8;
  static const int NUM_CTX = 3;
  static const int NUM_PROBAS = 11;

  static const int BPS = 32; // this is the common stride used by yuv[]
  static const int YUV_SIZE = (BPS * 17 + BPS * 9);
  static const int Y_SIZE = (BPS * 17);
  static const int Y_OFF = (BPS * 1 + 8);
  static const int U_OFF = (Y_OFF + BPS * 16 + BPS);
  static const int V_OFF = (U_OFF + 16);

  static const int YUV_FIX = 16; // fixed-point precision for RGB->YUV
  static const int YUV_HALF = 1 << (YUV_FIX - 1);
  static const int YUV_MASK = (256 << YUV_FIX) - 1;
  static const int YUV_RANGE_MIN = -227; // min value of r/g/b output
  static const int YUV_RANGE_MAX = 256 + 226; // max value of r/g/b output
  static const int YUV_FIX2 = 14; // fixed-point precision for YUV->RGB
  static const int YUV_HALF2 = 1 << (YUV_FIX2 - 1);
  static const int YUV_MASK2 = (256 << YUV_FIX2) - 1;
  static const int XOR_YUV_MASK2 = (-YUV_MASK2 - 1);

  // These constants are 14b fixed-point version of ITU-R BT.601 constants.
  static const int kYScale = 19077;    // 1.164 = 255 / 219
  static const int kVToR = 26149;    // 1.596 = 255 / 112 * 0.701
  static const int kUToG = 6419;    // 0.391 = 255 / 112 * 0.886 * 0.114 / 0.587
  static const int kVToG = 13320;    // 0.813 = 255 / 112 * 0.701 * 0.299 / 0.587
  static const int kUToB = 33050;    // 2.018 = 255 / 112 * 0.886
  static const int kRCst = (-kYScale * 16 - kVToR * 128 + YUV_HALF2);
  static const int kGCst = (-kYScale * 16 + kUToG * 128 + kVToG * 128 + YUV_HALF2);
  static const int kBCst = (-kYScale * 16 - kUToB * 128 + YUV_HALF2);
}
