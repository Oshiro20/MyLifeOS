import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_rembg/local_rembg.dart';

final backgroundRemoverServiceProvider =
    Provider<BackgroundRemoverService>((ref) {
  return BackgroundRemoverService();
});

class BackgroundRemoverService {
  /// Recibe la ruta de una foto, le quita el fondo, la guarda recortada,
  /// y devuelve la nueva ruta con la imagen procesada. Devuelve null si falla.
  Future<String?> removeBackground(String imagePath) async {
    try {
      LocalRembgResultModel result = await LocalRembg.removeBackground(
        imagePath: imagePath,
        cropTheImage: false,
      );

      if (result.status == 1 && result.imageBytes != null) {
        final file = File(imagePath);
        final dir = file.parent;
        final newFileName = 'rmbg_${DateTime.now().millisecondsSinceEpoch}.png';
        final newFile = File('${dir.path}/$newFileName');
        await newFile.writeAsBytes(result.imageBytes!);
        return newFile.path;
      }
    } catch (e) {
      // Ignoramos el error silenciosamente y devolvemos la ruta original o null,
      // para no quebrar la subida de ropa si falla la librería.
      debugPrint('Error interno al remover fondo: $e');
    }
    return null;
  }
}
