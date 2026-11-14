import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Utilidad compartida para comprimir y persistir imágenes localmente.
class ImageCompressionUtil {
  /// Comprime [originalFile] a JPEG y lo guarda en una carpeta persistente
  /// dentro de Documentos (`media/[subfolder]`) para que no lo borre el SO.
  static Future<File> compressImage({
    required File originalFile,
    int quality = 70,
    int maxWidth = 1024,
    int maxHeight = 1024,
    String subfolder = 'general',
    bool deleteOriginal = false,
  }) async {
    try {
      final targetDir = await _resolveMediaDirectory(originalFile, subfolder);
      final targetPath = p.join(
        targetDir.path,
        'img_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        originalFile.absolute.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        final compressedFile = File(result.path);
        final originalSize = await originalFile.length();
        final compressedSize = await compressedFile.length();
        if (originalSize > 0) {
          final reduction = ((1 - compressedSize / originalSize) * 100)
              .toStringAsFixed(1);
          debugPrint(
              '🗜️ [ImageCompression] Compressed: ${originalSize ~/ 1024}KB → ${compressedSize ~/ 1024}KB ($reduction% reduction)');
        }
        if (deleteOriginal &&
            await originalFile.exists() &&
            originalFile.absolute.path != compressedFile.absolute.path) {
          await originalFile.delete();
        }
        return compressedFile;
      }

      debugPrint(
          '⚠️ [ImageCompression] Compression returned null, using original');
      return originalFile;
    } catch (e) {
      debugPrint('❌ [ImageCompression] Error: $e, using original file');
      return originalFile;
    }
  }

  /// Comprime bytes en memoria sin crear archivo en disco.
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

  static Future<Directory> _resolveMediaDirectory(
    File originalFile,
    String subfolder,
  ) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory(p.join(docsDir.path, 'media', subfolder));
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }
      return mediaDir;
    } catch (_) {
      final fallbackDir =
          Directory(p.join(originalFile.parent.path, 'compressed'));
      if (!await fallbackDir.exists()) {
        await fallbackDir.create(recursive: true);
      }
      return fallbackDir;
    }
  }
}
