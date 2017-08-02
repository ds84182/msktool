part of image;

class ExrPxr24Compressor extends ExrCompressor {
  ExrPxr24Compressor(ExrPart header, this._maxScanLineSize, this._numScanLines) :
    super._(header) {
  }

  int numScanLines() => _numScanLines;

  Uint8List compress(InputBuffer inPtr, int x, int y,
                     [int width, int height]) {
    throw new ImageException('Pxr24 compression not yet supported.');
  }

  Uint8List uncompress(InputBuffer inPtr, int x, int y,
                       [int width, int height]) {
    List<int> data = _zlib.convert(inPtr.toUint8List());
    if (data == null) {
      throw new ImageException('Error decoding pxr24 compressed data');
    }

    if (_output == null) {
      _output = new OutputBuffer(size: _numScanLines * _maxScanLineSize);
    }
    _output.rewind();

    int tmpEnd = 0;
    List<int> ptr = [0, 0, 0, 0];
    Uint32List pixel = new Uint32List(1);
    Uint8List pixelBytes = new Uint8List.view(pixel.buffer);

    if (width == null) {
      width = _header.width;
    }
    if (height == null) {
      height = _header._linesInBuffer;
    }

    int minX = x;
    int maxX = x + width - 1;
    int minY = y;
    int maxY = y + height - 1;

    if (maxX > _header.width) {
      maxX = _header.width - 1;
    }
    if (maxY > _header.height) {
      maxY = _header.height - 1;
    }

    decodedWidth = (maxX - minX) + 1;
    decodedHeight = (maxY - minY) + 1;

    int numChannels = _header.channels.length;
    for (int yi = minY; yi <= maxY; ++yi) {

      for (int ci = 0; ci < numChannels; ++ci) {
        ExrChannel ch = _header.channels[ci];
        if ((y % ch.ySampling) != 0) {
          continue;
        }

        int n = _numSamples(ch.xSampling, minX, maxX);
        pixel[0] = 0;

        switch (ch.type) {
          case ExrChannel.TYPE_UINT:
            ptr[0] = tmpEnd;
            ptr[1] = ptr[0] + n;
            ptr[2] = ptr[1] + n;
            tmpEnd = ptr[2] + n;
            for (int j = 0; j < n; ++j) {
              int diff = (data[ptr[0]++] << 24) |
                         (data[ptr[1]++] << 16) |
                         (data[ptr[2]++] << 8);
              pixel[0] += diff;
              for (int k = 0; k < 4; ++k) {
                _output.writeByte(pixelBytes[k]);
              }
            }
            break;
          case ExrChannel.TYPE_HALF:
            ptr[0] = tmpEnd;
            ptr[1] = ptr[0] + n;
            tmpEnd = ptr[1] + n;
            for (int j = 0; j < n; ++j) {
              int diff = (data[ptr[0]++] << 8) | data[ptr[1]++];
              pixel[0] += diff;

              for (int k = 0; k < 2; ++k) {
                _output.writeByte(pixelBytes[k]);
              }
            }
            break;
          case ExrChannel.TYPE_FLOAT:
            ptr[0] = tmpEnd;
            ptr[1] = ptr[0] + n;
            ptr[2] = ptr[1] + n;
            tmpEnd = ptr[2] + n;
            for (int j = 0; j < n; ++j) {
              int diff = (data[ptr[0]++] << 24) |
                         (data[ptr[1]++] << 16) |
                         (data[ptr[2]++] << 8);
              pixel[0] += diff;
              for (int k = 0; k < 4; ++k) {
                _output.writeByte(pixelBytes[k]);
              }
            }
            break;
        }
      }
    }

    return _output.getBytes();
  }

  ZLibDecoder _zlib = new ZLibDecoder();
  int _maxScanLineSize;
  int _numScanLines;
  OutputBuffer _output;
}
