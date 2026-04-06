import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:domain/domain.dart';
import 'package:core/core.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

enum RecipeImportState {
  initial,
  downloadingVideo,
  extractingAI,
  success,
  error
}

class RecipeImportNotifier extends Notifier<RecipeImportState> {
  Recipe? importedRecipe;
  String? errorMessage;
  String currentStatusMessage = '';

  @override
  RecipeImportState build() {
    return RecipeImportState.initial;
  }

  Future<void> importFromTikTokUrl(String url) async {
    state = RecipeImportState.downloadingVideo;
    currentStatusMessage = 'Conectando con TikTok...';
    errorMessage = null;

    try {
      final tikTokService = ref.read(tikTokServiceProvider);
      final info = await tikTokService.getTikTokVideoInfo(url);
      if (info == null || !info.containsKey('data')) {
        throw Exception(
            'No se pudo resolver la información del video de TikTok.');
      }

      final data = info['data'] as Map<String, dynamic>;
      final videoUrl = data['video_link_nwm'] ??
          data['play'] ??
          data['wmplay'] ??
          data['hdplay'];

      if (videoUrl == null) {
        throw Exception(
            'No se encontró URL de descarga del video. Keys: ${data.keys}');
      }

      debugPrint('🎬 Video URL found: $videoUrl');
      currentStatusMessage = 'Descargando video...';
      final tempFile = File(
          '${(await getTemporaryDirectory()).path}/tiktok_${DateTime.now().millisecondsSinceEpoch}.mp4');

      final response = await http.get(Uri.parse(videoUrl));
      if (response.statusCode != 200) {
        throw Exception('Fallo al descargar el video.');
      }
      await tempFile.writeAsBytes(response.bodyBytes);
      debugPrint('✅ Video downloaded: ${tempFile.path}');

      await importFromVideoFile(tempFile.path);

      if (tempFile.existsSync()) tempFile.deleteSync();
    } catch (e) {
      errorMessage = e.toString();
      debugPrint('❌ TikTok import error: $e');
      state = RecipeImportState.error;
    }
  }

  Future<void> importFromVideoFile(String filePath) async {
    state = RecipeImportState.extractingAI;
    currentStatusMessage = 'El Chef IA está analizando el video...';
    errorMessage = null;

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('El archivo de video no existe: $filePath');
      }

      debugPrint(
          '📹 Video file size: ${(file.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB');

      // Try to extract thumbnail, fallback to video file itself
      String imagePath = filePath;
      try {
        final thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: filePath,
          thumbnailPath:
              '${(await getTemporaryDirectory()).path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
          imageFormat: ImageFormat.JPEG,
          maxHeight: 1080,
          quality: 85,
        );

        if (thumbnailPath != null && File(thumbnailPath).existsSync()) {
          imagePath = thumbnailPath;
          debugPrint('✅ Thumbnail extracted: ${imagePath}');
        } else {
          debugPrint(
              '⚠️ Thumbnail extraction returned null, using original video');
        }
      } catch (e) {
        debugPrint('⚠️ Thumbnail extraction failed: $e, using original video');
      }

      final extractUseCase = ref.read(extractRecipeUseCaseProvider);
      debugPrint('🔍 Sending to AI: $imagePath');

      final recipe = await extractUseCase.execute(mediaPath: imagePath);

      if (recipe != null) {
        importedRecipe = recipe;
        currentStatusMessage = '¡Receta encontrada!';
        state = RecipeImportState.success;
      } else {
        throw Exception(
            'La IA no pudo estructurar la receta. Intenta con otro video más claro.');
      }
    } catch (e) {
      errorMessage = e.toString();
      debugPrint('❌ Video import error: $e');
      state = RecipeImportState.error;
    }
  }

  void reset() {
    state = RecipeImportState.initial;
    importedRecipe = null;
    errorMessage = null;
    currentStatusMessage = '';
  }
}

// PROVIDERS DECLARATION
final extractRecipeUseCaseProvider = Provider<ExtractRecipeUseCase>((ref) {
  // We need to inject an IAIRecipeExtractor.
  // For simplicity since the Core GeminiService provides exactly what we need,
  // we proxy it via an anonymous class implementing IAIRecipeExtractor.
  final gemini = ref.watch(geminiServiceProvider);
  return ExtractRecipeUseCase(
    _GeminiExtractorAdapter(gemini),
  );
});

final tikTokServiceProvider = Provider<TikTokService>((ref) {
  final apiKey = dotenv.env['TIKTOK_API_KEY'] ?? '';
  if (apiKey.isEmpty) {
    // Log warning in development but don't crash
    debugPrint('⚠️ WARNING: TIKTOK_API_KEY not set in .env file');
    debugPrint(
        'Get your key from: https://rapidapi.com/DataCrawler/api/tiktok-scraper7');
  }
  return TikTokService(apiKey);
});

final recipeImportProvider =
    NotifierProvider<RecipeImportNotifier, RecipeImportState>(() {
  return RecipeImportNotifier();
});

class _GeminiExtractorAdapter implements IAIRecipeExtractor {
  final GeminiService gemini;
  _GeminiExtractorAdapter(this.gemini);

  @override
  Future<String?> extractRecipeJson({String? textContext, String? mediaPath}) {
    return gemini.extractRecipe(textContext: textContext, mediaPath: mediaPath);
  }
}
