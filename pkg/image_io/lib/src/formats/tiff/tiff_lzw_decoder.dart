part of image;

class LzwDecoder {
  void decode(InputBuffer p, List<int> out) {
    this._out = out;
    int outLen = out.length;
    _outPointer = 0;
    _data = p.buffer;
    _dataLength = _data.length;
    _bytePointer = p.offset;

    if (_data[0] == 0x00 && _data[1] == 0x01) {
      throw new ImageException('Invalid LZW Data');
    }

    _initializeStringTable();

    _bitPointer = 0;
    _nextData = 0;
    _nextBits = 0;

    int oldCode = 0;
    int num = 0;

    int code = _getNextCode();
    while ((code != 257) && _outPointer < outLen) {
      if (code == 256) {
        _initializeStringTable();
        num++;
        code = _getNextCode();
        _bufferLength = 0;
        if (code == 257) {
          break;
        }

        _out[_outPointer++] = code;
        oldCode = code;
      } else {
        if (code < _tableIndex) {
          _getString(code);
          for (int i = _bufferLength - 1; i >= 0; --i) {
            _out[_outPointer++] = _buffer[i];
          }
          _addString(oldCode, _buffer[_bufferLength - 1]);
          oldCode = code;
        } else {
          _getString(oldCode);
          for (int i = _bufferLength - 1; i >= 0; --i) {
            _out[_outPointer++] = _buffer[i];
          }
          _out[_outPointer++] = _buffer[_bufferLength - 1];
          _addString(oldCode, _buffer[_bufferLength - 1]);

          oldCode = code;
        }
      }

      num++;
      code = _getNextCode();
    }
  }

  void _addString(int string, int newString) {
    _table[_tableIndex] = newString;
    _prefix[_tableIndex] = string;
    _tableIndex++;

    if (_tableIndex == 511) {
      _bitsToGet = 10;
    } else if (_tableIndex == 1023) {
      _bitsToGet = 11;
    } else if (_tableIndex == 2047) {
      _bitsToGet = 12;
    }
  }

  void _getString(int code) {
    _bufferLength = 0;
    int c = code;
    _buffer[_bufferLength++] = _table[c];
    c = _prefix[c];
    while (c != NO_SUCH_CODE) {
      _buffer[_bufferLength++] = _table[c];
      c = _prefix[c];
    }
  }

  /**
   * Returns the next 9, 10, 11 or 12 bits
   */
  int _getNextCode() {
    if (_bytePointer >= _dataLength) {
      return 257;
    }

    while (_nextBits < _bitsToGet) {
      if (_bytePointer >= _dataLength) {
        return 257;
      }
      _nextData = (((_nextData << 8) + _data[_bytePointer++])) & 0xffffffff;
      _nextBits += 8;
    }

    _nextBits -= _bitsToGet;
    int code = (_nextData >> _nextBits) & AND_TABLE[_bitsToGet - 9];

    return code;
  }

  /**
   * Initialize the string table.
   */
  void _initializeStringTable() {
    _table = new Uint8List(LZ_MAX_CODE + 1);
    _prefix = new Uint32List(LZ_MAX_CODE + 1);
    _prefix.fillRange(0, _prefix.length, NO_SUCH_CODE);

    for (int i = 0; i < 256; i++) {
      _table[i] = i;
    }

    _bitsToGet = 9;

    _tableIndex = 258;
  }

  int _bitsToGet = 9;
  int _bytePointer = 0;
  int _bitPointer = 0;
  int _nextData = 0;
  int _nextBits = 0;
  Uint8List _data;
  int _dataLength;

  List<int> _out;
  int _outPointer;

  Uint8List _buffer = new Uint8List(4096);
  Uint8List _table;
  Uint32List _prefix;
  int _tableIndex;
  int _bufferLength;

  static const int LZ_MAX_CODE = 4095;
  static const int NO_SUCH_CODE = 4098;
  static const List<int> AND_TABLE = const [511, 1023, 2047, 4095];
}
