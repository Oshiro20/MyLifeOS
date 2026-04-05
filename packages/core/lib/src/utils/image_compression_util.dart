import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Utility class for compressing images before storage.
/// Helps reduce storage usage while maintaining acceptable quality.
class ImageCompressionUtil {
  /// Compresses an image file to the specified target size.
  ///
  /// [originalFile] - The original image file to compress
  /// [quality] - Compression quality (1-100), lower = smaller file
  /// [maxWidth] - Maximum width in pixels (maintains aspect ratio)
  /// [maxHeight] - Maximum height in pixels (maintains aspect ratio)
  ///
  /// Returns the compressed file path, or the original if compression fails.
  static Future<File> compressImage({
    required File originalFile,
    int quality = 70,
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) async {
    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        originalFile.absolute.path,
        '${originalFile.parent.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        final originalSize = await originalFile.length();
        final compressedSize = await result.length();
        final reduction = ((1 - compressedSize / originalSize) * 100)
            .toStringAsFixed(1);

        debugPrint(
            '🗜️ [ImageCompression] Compressed: ${originalSize ~/ 1024}KB → ${compressedSize ~/ 1024}KB ($reduction% reduction)');

        return File(result.path);
      }

      debugPrint('⚠️ [ImageCompression] Compression returned null, using original');
      return originalFile;
    } catch (e) {
      debugPrint('❌ [ImageCompression] Error: $e, using original file');
      return originalFile;
    }
  }

  /// Compresses image bytes directly without creating a file.
  ///
  /// Returns compressed bytes or original if compression fails.
  static Future<Uint8List> compressImageBytes({
    required Uint8List imageBytes,
    int quality = 70,
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        imageBytes,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg,
      );

      debugPrint(
          '🗜️ [ImageCompression] Compressed bytes: ${imageBytes.length ~/ 1024}KB → ${result.length ~/ 1024}KB');

      return result;
    } catch (e) {
      debugPrint('❌ [ImageCompression] Error: $e, returning original bytes');
      return imageBytes;
    }
  }
}
