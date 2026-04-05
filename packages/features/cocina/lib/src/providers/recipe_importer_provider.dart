import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:domain/domain.dart';
import 'package:core/core.dart';

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
      // 1. Get Video info from API
      final info = await tikTokService.getTikTokVideoInfo(url);
      if (info == null || !info.containsKey('data')) {
        throw Exception(
            'No se pudo resolver la información del video de TikTok.');
      }

      final data = info['data'] as Map<String, dynamic>;
      // Try multiple possible keys for video URL
      final videoUrl = data['play'] ??
          data['wmplay'] ??
          data['hdplay'] ??
          data['no_watermark'] ??
          data['no_watermark_hd'];

      debugPrint('🔍 Found videoUrl key: ${videoUrl != null ? "YES" : "NO"}');

      if (videoUrl == null) {
        throw Exception(
            'No se encontró URL de descarga del video. Keys disponibles: ${data.keys}');
      }

      currentStatusMessage = 'Descargando video en background...';
      final tempFile = File(
          '${(await getTemporaryDirectory()).path}/tiktok_video_${DateTime.now().millisecondsSinceEpoch}.mp4');

      final response = await http.get(Uri.parse(videoUrl));
      if (response.statusCode != 200) {
        throw Exception('Fallo al descargar el video de TikTok.');
      }
      await tempFile.writeAsBytes(response.bodyBytes);

      // 2. Extraer con IA
      await importFromVideoFile(tempFile.path);

      // Limpiar cache
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
    } catch (e) {
      errorMessage = e.toString();
      state = RecipeImportState.error;
    }
  }

  Future<void> importFromVideoFile(String filePath) async {
    state = RecipeImportState.extractingAI;
    currentStatusMessage = 'El Chef IA está analizando el video...';
    errorMessage = null;

    try {
      final extractUseCase = ref.read(extractRecipeUseCaseProvider);
      final recipe = await extractUseCase.execute(mediaPath: filePath);

      if (recipe != null) {
        importedRecipe = recipe;
        currentStatusMessage = '¡Receta encontrada!';
        state = RecipeImportState.success;
      } else {
        throw Exception(
            'La IA no pudo estructurar la receta o el formato no es válido.');
      }
    } catch (e) {
      errorMessage = e.toString();
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
