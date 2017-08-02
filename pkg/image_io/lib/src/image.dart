part of image;

/**
 * A 32-bit image buffer where pixels are encoded into 32-bit unsigned ints.
 * You can use the methods in color to encode/decode the RGBA channels of a
 * color for a pixel.
 *
 * Pixels are stored in 32-bit unsigned integers in aabbggrr format.
 * This is to be consistent with HTML canvas data.  You can use
 * [getBytes] to access the pixel at the byte (channel) level, where there
 * are four bytes per pixel in red, green, blue, and alpha order.
 *
 * If this image is a frame of an animation as decoded by the [decodeFrame]
 * method of [Decoder], then the [xOffset], [yOffset], [width] and [height]
 * coordinates determine area of the canvas this image should be drawn into,
 * as some frames of an animation only modify part of the canvas (recording
 * the part of the frame that actually changes).  The [decodeAnimation] method
 * will always return the fully composed animation, so these coordinate
 * properties are not used.
 */
class Image {
  /// 24-bit RGB image.
  static const int RGB = 3;
  /// 32-bit RGBA image.
  static const int RGBA = 4;

  /// When drawing this frame, the canvas should be left as it is.
  static const int DISPOSE_NONE = 0;
  /// When drawing this frame, the canvas should be cleared first.
  static const int DISPOSE_CLEAR = 1;

  /// No alpha blending should be done when drawing this frame (replace
  /// pixels in canvas).
  static const int BLEND_SOURCE = 0;
  /// Alpha blending should be used when drawing this frame (composited over
  /// the current canvas image).
  static const int BLEND_OVER = 1;

  /// Width of the image.
  final int width;
  /// Height of the image.
  final int height;
  /// x position at which to render the frame.
  int xOffset = 0;
  /// y position at which to render the frame.
  int yOffset = 0;
  /// How long this frame should be displayed, in milliseconds.
  /// A duration of 0 indicates no delay and the next frame will be drawn
  /// as quickly as it can.
  int duration = 0;
  /// Defines what should be done to the canvas when drawing this frame.
  int disposeMethod = DISPOSE_CLEAR;
  /// Defines the blending method (alpha compositing) to use when drawing this
  /// frame.
  int blendMethod = BLEND_OVER;
  /// Pixels are encoded into 4-byte integers, where each byte is an RGBA
  /// channel.
  final Uint32List data;

  /**
   * Create an image with the given dimensions and format.
   */
  Image(int width, int height, [this._format = RGBA]) :
    this.width = width,
    this.height = height,
    data = new Uint32List(width * height);

  /**
   * Create a copy of the image [other].
   */
  Image.from(Image other) :
    width = other.width,
    height = other.height,
    xOffset = other.xOffset,
    yOffset = other.yOffset,
    duration = other.duration,
    disposeMethod = other.disposeMethod,
    blendMethod = other.blendMethod,
    _format = other._format,
    data = new Uint32List.fromList(other.data);

  /**
   * Create an image from [bytes].
   *
   * [bytes] should be in RGB<A> format with a byte [0,255] for each channel.
   * The length of [bytes] should be <3|4> * (width * height).
   * [format] determines if there are 3 or 4 channels per pixel.
   *
   * For example, given an Html Canvas, you could create an image:
   * var bytes = canvas.getContext('2d').getImageData(0, 0,
   *   canvas.width, canvas.height).data;
   * Image image = new Image.fromBytes(canvas.width, canvas.height, bytes);
   */
  Image.fromBytes(int width, int height, List<int> bytes,
                  [this._format = RGBA]) :
    this.width = width,
    this.height = height,
    // Create a uint32 view of the byte buffer.
    // This assumes the system architecture is little-endian...
    data = bytes is Uint8List ? new Uint32List.view(bytes.buffer) :
            bytes is Uint8ClampedList ? new Uint32List.view(bytes.buffer) :
            bytes is Uint32List ? new Uint32List.view(bytes.buffer) :
            new Uint32List.view(new Uint8List.fromList(bytes).buffer);

  /**
   * Clone this image.
   */
  Image clone() => new Image.from(this);

  /**
   * Get the RGBA bytes from the image.  You can use this to access the
   * RGBA color channels directly, or to pass it to something like an
   * Html canvas context.
   *
   * For example, given an Html Canvas, you could draw this image into the
   * canvas:
   * Html.ImageData d = context2D.createImageData(image.width, image.height);
   * d.data.setRange(0, image.length, image.getBytes());
   * context2D.putImageData(data, 0, 0);
   */
  Uint8List getBytes() =>
    new Uint8List.view(data.buffer);

  /**
   * Get the format of the image, either [RGB] or [RGBA].
   */
  int get format => _format;

  /**
   * Set the format of the image, either [RGB] or [RGBA].  The format is used
   * for informational purposes and has no effect on the actual stored data,
   * which is always in 4-byte RGBA format.
   */
  void set format(int f) {
    if (f == _format) {
      return;
    }
    if (f != RGB && f != RGBA) {
      throw new ImageException('Invalid image format: $f');
    }
    _format = f;
  }

  /**
   * How many color channels does the image have, 3 or 4?
   * Note that internally, images always have 4 8-bit channels.
   */
  int get numChannels => _format;

  /**
   * Set all of the pixels of the image to the given [color].
   */
  Image fill(int color) {
    data.fillRange(0, data.length, color);
    return this;
  }

  /**
   * Add the colors of [other] to the pixels of this image.
   */
  Image operator+(Image other) {
    int h = Math.min(height, other.height);
    int w = Math.min(width, other.width);
    for (int y = 0; y < h; ++y) {
      for (int x = 0; x < w; ++x) {
        int c1 = getPixel(x, y);
        int r1 = getRed(c1);
        int g1 = getGreen(c1);
        int b1 = getBlue(c1);
        int a1 = getAlpha(c1);

        int c2 = other.getPixel(x, y);
        int r2 = getRed(c2);
        int g2 = getGreen(c2);
        int b2 = getBlue(c2);
        int a2 = getAlpha(c2);

        setPixel(x, y, getColor(r1 + r2, g1 + g2, b1 + b2, a1 + a2));
      }
    }
    return this;
  }

  /**
   * Subtract the colors of [other] from the pixels of this image.
   */
  Image operator-(Image other) {
    int h = Math.min(height, other.height);
    int w = Math.min(width, other.width);
    for (int y = 0; y < h; ++y) {
      for (int x = 0; x < w; ++x) {
        int c1 = getPixel(x, y);
        int r1 = getRed(c1);
        int g1 = getGreen(c1);
        int b1 = getBlue(c1);
        int a1 = getAlpha(c1);

        int c2 = other.getPixel(x, y);
        int r2 = getRed(c2);
        int g2 = getGreen(c2);
        int b2 = getBlue(c2);
        int a2 = getAlpha(c2);

        setPixel(x, y, getColor(r1 - r2, g1 - g2, b1 - b2, a1 - a2));
      }
    }
    return this;
  }

  /**
   * Multiply the colors of [other] with the pixels of this image.
   */
  Image operator*(Image other) {
    int h = Math.min(height, other.height);
    int w = Math.min(width, other.width);
    for (int y = 0; y < h; ++y) {
      for (int x = 0; x < w; ++x) {
        int c1 = getPixel(x, y);
        int r1 = getRed(c1);
        int g1 = getGreen(c1);
        int b1 = getBlue(c1);
        int a1 = getAlpha(c1);

        int c2 = other.getPixel(x, y);
        int r2 = getRed(c2);
        int g2 = getGreen(c2);
        int b2 = getBlue(c2);
        int a2 = getAlpha(c2);

        setPixel(x, y, getColor(r1 * r2, g1 * g2, b1 * b2, a1 * a2));
      }
    }
    return this;
  }

  /**
   * OR the colors of [other] to the pixels of this image.
   */
  Image operator|(Image other) {
    int h = Math.min(height, other.height);
    int w = Math.min(width, other.width);
    for (int y = 0; y < h; ++y) {
      for (int x = 0; x < w; ++x) {
        int c1 = getPixel(x, y);
        int r1 = getRed(c1);
        int g1 = getGreen(c1);
        int b1 = getBlue(c1);
        int a1 = getAlpha(c1);

        int c2 = other.getPixel(x, y);
        int r2 = getRed(c2);
        int g2 = getGreen(c2);
        int b2 = getBlue(c2);
        int a2 = getAlpha(c2);

        setPixel(x, y, getColor(r1 | r2, g1 | g2, b1 | b2, a1 | a2));
      }
    }
    return this;
  }

  /**
   * AND the colors of [other] with the pixels of this image.
   */
  Image operator&(Image other) {
    int h = Math.min(height, other.height);
    int w = Math.min(width, other.width);
    for (int y = 0; y < h; ++y) {
      for (int x = 0; x < w; ++x) {
        int c1 = getPixel(x, y);
        int r1 = getRed(c1);
        int g1 = getGreen(c1);
        int b1 = getBlue(c1);
        int a1 = getAlpha(c1);

        int c2 = other.getPixel(x, y);
        int r2 = getRed(c2);
        int g2 = getGreen(c2);
        int b2 = getBlue(c2);
        int a2 = getAlpha(c2);

        setPixel(x, y, getColor(r1 & r2, g1 & g2, b1 & b2, a1 & a2));
      }
    }
    return this;
  }

  /**
   * Modula the colors of [other] with the pixels of this image.
   */
  Image operator%(Image other) {
    int h = Math.min(height, other.height);
    int w = Math.min(width, other.width);
    for (int y = 0; y < h; ++y) {
      for (int x = 0; x < w; ++x) {
        int c1 = getPixel(x, y);
        int r1 = getRed(c1);
        int g1 = getGreen(c1);
        int b1 = getBlue(c1);
        int a1 = getAlpha(c1);

        int c2 = other.getPixel(x, y);
        int r2 = getRed(c2);
        int g2 = getGreen(c2);
        int b2 = getBlue(c2);
        int a2 = getAlpha(c2);

        setPixel(x, y, getColor(r1 % r2, g1 % g2, b1 % b2, a1 % a2));
      }
    }
    return this;
  }

  /**
   * The size of the image buffer.
   */
  int get length => data.length;

  /**
   * Get a pixel from the buffer.
   */
  int operator[](int index) => data[index];

  /**
   * Set a pixel in the buffer.
   */
  void operator[]=(int index, int color) {
    data[index] = color;
  }

  /**
   * Get the buffer index for the [x], [y] pixel coordinates.
   */
  int index(int x, int y) => y * width + x;

  /**
   * Is the given pixel coordinates within the resolution of the image.
   */
  bool boundsSafe(int x, int y) =>
    x >= 0 && x < width && y >= 0 && y < height;

  /**
   * Get the pixel from the given [x], [y] coordinate.
   */
  int getPixel(int x, int y) =>
    boundsSafe(x, y) ? data[y * width + x] : 0;

  int getPixelUnsafe(int x, int y) => data[y * width + x];

  /**
   * Get the pixel using the given [interpolation] type for non-integer pixel
   * coordinates.
   */
  int getPixelInterpolate(double fx, double fy, [int interpolation = LINEAR]) {
    if (interpolation == CUBIC) {
      return getPixelCubic(fx, fy);
    } else if (interpolation == LINEAR) {
      return getPixelLinear(fx, fy);
    }
    return getPixel(fx.toInt(), fy.toInt());
  }

  /**
   * Get the pixel using linear interpolation for non-integer pixel
   * coordinates.
   */
  int getPixelLinear(double fx, double fy) {
    int x = fx.toInt() - (fx >= 0 ? 0 : 1);
    int nx = x + 1;
    int y = fy.toInt() - (fy >= 0 ? 0 : 1);
    int ny = y + 1;
    double dx = fx - x;
    double dy = fy - y;

    int _linear(int Icc, int Inc, int Icn, int Inn) {
      return (Icc + dx * (Inc - Icc + dy * (Icc + Inn - Icn - Inc)) +
              dy * (Icn - Icc)).toInt();
    }

    int Icc = getPixel(x, y);
    int Inc = getPixel(nx, y);
    int Icn = getPixel(x, ny);
    int Inn = getPixel(nx, ny);

    return getColor(
        _linear(getRed(Icc), getRed(Inc), getRed(Icn), getRed(Inn)),
        _linear(getGreen(Icc), getGreen(Inc), getGreen(Icn), getGreen(Inn)),
        _linear(getBlue(Icc), getBlue(Inc), getBlue(Icn), getBlue(Inn)),
        _linear(getAlpha(Icc), getAlpha(Inc), getAlpha(Icn), getAlpha(Inn)));
  }

  /**
   * Get the pixel using cubic interpolation for non-integer pixel
   * coordinates.
   */
  int getPixelCubic(double fx, double fy) {
    int x = fx.toInt() - (fx >= 0.0 ? 0 : 1);
    int px = x - 1;
    int nx = x + 1;
    int ax = x + 2;
    int y = fy.toInt() - (fy >= 0.0 ? 0 : 1);
    int py = y - 1;
    int ny = y + 1;
    int ay = y + 2;

    var dx = fx - x;
    var dy = fy - y;

    double _cubic(double dx, double Ipp, double Icp, double Inp, double Iap) =>
        Icp + 0.5 * (dx * (-Ipp + Inp) +
        dx * dx * (2 * Ipp - 5 * Icp + 4 * Inp - Iap) +
        dx * dx * dx * (-Ipp + 3 * Icp - 3 * Inp + Iap));

    int Ipp = getPixel(px, py);
    int Icp = getPixel(x, py);
    int Inp = getPixel(nx, py);
    int Iap = getPixel(ax, py);
    double Ip0 = _cubic(dx, getRed(Ipp).toDouble(), getRed(Icp).toDouble(), getRed(Inp).toDouble(), getRed(Iap).toDouble());
    double Ip1 = _cubic(dx, getGreen(Ipp).toDouble(), getGreen(Icp).toDouble(), getGreen(Inp).toDouble(), getGreen(Iap).toDouble());
    double Ip2 = _cubic(dx, getBlue(Ipp).toDouble(), getBlue(Icp).toDouble(), getBlue(Inp).toDouble(), getBlue(Iap).toDouble());
    double Ip3 = _cubic(dx, getAlpha(Ipp).toDouble(), getAlpha(Icp).toDouble(), getAlpha(Inp).toDouble(), getAlpha(Iap).toDouble());

    int Ipc = getPixel(px, y);
    int Icc = getPixel(x, y);
    int Inc = getPixel(nx, y);
    int Iac = getPixel(ax, y);
    double Ic0 = _cubic(dx, getRed(Ipc).toDouble(), getRed(Icc).toDouble(), getRed(Inc).toDouble(), getRed(Iac).toDouble());
    double Ic1 = _cubic(dx, getGreen(Ipc).toDouble(), getGreen(Icc).toDouble(), getGreen(Inc).toDouble(), getGreen(Iac).toDouble());
    double Ic2 = _cubic(dx, getBlue(Ipc).toDouble(), getBlue(Icc).toDouble(), getBlue(Inc).toDouble(), getBlue(Iac).toDouble());
    double Ic3 = _cubic(dx, getAlpha(Ipc).toDouble(), getAlpha(Icc).toDouble(), getAlpha(Inc).toDouble(), getAlpha(Iac).toDouble());

    int Ipn = getPixel(px, ny);
    int Icn = getPixel(x, ny);
    int Inn = getPixel(nx, ny);
    int Ian = getPixel(ax, ny);
    double In0 = _cubic(dx, getRed(Ipn).toDouble(), getRed(Icn).toDouble(), getRed(Inn).toDouble(), getRed(Ian).toDouble());
    double In1 = _cubic(dx, getGreen(Ipn).toDouble(), getGreen(Icn).toDouble(), getGreen(Inn).toDouble(), getGreen(Ian).toDouble());
    double In2 = _cubic(dx, getBlue(Ipn).toDouble(), getBlue(Icn).toDouble(), getBlue(Inn).toDouble(), getBlue(Ian).toDouble());
    double In3 = _cubic(dx, getAlpha(Ipn).toDouble(), getAlpha(Icn).toDouble(), getAlpha(Inn).toDouble(), getAlpha(Ian).toDouble());

    int Ipa = getPixel(px, ay);
    int Ica = getPixel(x, ay);
    int Ina = getPixel(nx, ay);
    int Iaa = getPixel(ax, ay);
    double Ia0 = _cubic(dx, getRed(Ipa).toDouble(), getRed(Ica).toDouble(), getRed(Ina).toDouble(), getRed(Iaa).toDouble());
    double Ia1 = _cubic(dx, getGreen(Ipa).toDouble(), getGreen(Ica).toDouble(), getGreen(Ina).toDouble(), getGreen(Iaa).toDouble());
    double Ia2 = _cubic(dx, getBlue(Ipa).toDouble(), getBlue(Ica).toDouble(), getBlue(Ina).toDouble(), getBlue(Iaa).toDouble());
    double Ia3 = _cubic(dx, getAlpha(Ipa).toDouble(), getAlpha(Ica).toDouble(), getAlpha(Ina).toDouble(), getAlpha(Iaa).toDouble());

    double c0 = _cubic(dy, Ip0, Ic0, In0, Ia0);
    double c1 = _cubic(dy, Ip1, Ic1, In1, Ia1);
    double c2 = _cubic(dy, Ip2, Ic2, In2, Ia2);
    double c3 = _cubic(dy, Ip3, Ic3, In3, Ia3);

    return getColor(c0.toInt(), c1.toInt(), c2.toInt(), c3.toInt());
  }

  /**
   * Set the pixel at the given [x], [y] coordinate to the [color].
   *
   * This simply replaces the existing color, it does not do any alpha
   * blending.  Use [drawPixel] for that.
   */
  void setPixel(int x, int y, int color) {
    if (boundsSafe(x, y)) {
      data[y * width + x] = color;
    }
  }

  /**
   * Set the pixel at the given [x], [y] coordinate to the color
   * [r], [g], [b], [a].
   *
   * This simply replaces the existing color, it does not do any alpha
   * blending.  Use [drawPixel] for that.
   */
  void setPixelRGBA(int x, int y, int r, int g, int b, [int a = 0xff]) {
    if (boundsSafe(x, y)) {
      data[y * width + x] = getColor(r, g, b, a);
    }
  }

  /**
   * Return the average gray value of the image.
   */
  int getWhiteBalance() {
    final len = data.length;
    int r = 0;
    int g = 0;
    int b = 0;
    for (int i = 0; i < len; ++i) {
      r += getRed(data[i]);
      g += getGreen(data[i]);
      b += getBlue(data[i]);
    }

    r ~/= len;
    g ~/= len;
    b ~/= len;

    return (r + g + b) ~/ 3;
  }

  /// Format of the image.
  int _format;
}
