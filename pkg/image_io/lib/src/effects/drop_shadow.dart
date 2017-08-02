part of image;

/**
 * Create a drop-shadow effect for the image.
 */
Image dropShadow(Image src, int hShadow, int vShadow, int blur,
                 {int shadowColor: 0xa0000000}) {
  if (blur < 0) {
    blur = 0;
  }

  int shadowWidth = src.width + blur * 2;
  int shadowHeight = src.height + blur * 2;
  int shadowOffsetX = -blur;
  int shadowOffsetY = -blur;

  int newImageWidth = shadowWidth;
  int newImageHeight = shadowHeight;
  int imageOffsetX = 0;
  int imageOffsetY = 0;

  if (shadowOffsetX + hShadow < 0) {
    imageOffsetX = -(shadowOffsetX + hShadow);
    shadowOffsetX = -shadowOffsetX;
    newImageWidth = imageOffsetX;
  }

  if (shadowOffsetY + vShadow < 0) {
    imageOffsetY = -(shadowOffsetY + vShadow);
    shadowOffsetY = -shadowOffsetY;
    newImageHeight += imageOffsetY;
  }

  if (shadowWidth + shadowOffsetX + hShadow > newImageWidth) {
    newImageWidth = shadowWidth + shadowOffsetX + hShadow;
  }

  if (shadowHeight + shadowOffsetY + vShadow > newImageHeight) {
    newImageHeight = shadowHeight + shadowOffsetY + vShadow;
  }

  Image dst = new Image(newImageWidth, newImageHeight);
  dst.fill(0x00ffffff);

  copyInto(dst, src, dstX: shadowOffsetX, dstY: shadowOffsetY);

  remapColors(dst, red: ALPHA, green: ALPHA, blue: ALPHA);

  scaleRGBA(dst, getRed(shadowColor), getGreen(shadowColor),
            getBlue(shadowColor), getAlpha(shadowColor));

  gaussianBlur(dst, blur);


  copyInto(dst, src, dstX: imageOffsetX, dstY: imageOffsetY);

  return dst;
}
