part of image;

/**
 * An exception thrown when there was a problem in the image library.
 */
class ImageException implements Exception {
  /// A message describing the error.
  final String message;

  ImageException(this.message);

  String toString() => 'ImageException: $message';
}
