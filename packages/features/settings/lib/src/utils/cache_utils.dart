import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Limpia el caché y retorna el espacio liberado.
Future<String> clearImageCache() async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final compressedDir = Directory('${appDir.path}/compressed');

    if (!compressedDir.existsSync()) {
      return 'No hay caché para limpiar';
    }

    int totalSize = 0;
    int fileCount = 0;

    await for (final file in compressedDir.list()) {
      if (file is File) {
        totalSize += await file.length();
        await file.delete();
        fileCount++;
      }
    }

    // Eliminar directorio si está vacío
    if (await compressedDir.list().isEmpty) {
      await compressedDir.delete();
    }

    return '✅ $fileCount archivos eliminados (${_formatSize(totalSize)} liberados)';
  } catch (e) {
    return '❌ Error al limpiar caché: $e';
  }
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
