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
    errorMessage = null;

    try {
      String platform = 'TikTok';
      if (url.contains('facebook.com') || url.contains('fb.watch')) {
        platform = 'Facebook';
        currentStatusMessage = 'Conectando con Facebook...';
      } else if (url.contains('instagram.com')) {
        platform = 'Instagram';
        currentStatusMessage = 'Conectando con Instagram...';
      } else {
        currentStatusMessage = 'Conectando con TikTok...';
      }

      // For now, we'll pass the URL as context to Gemini with the video/image
      // The AI will analyze whatever media is provided plus the URL context
      // Direct video download from FB/IG requires different APIs
      debugPrint('🌐 Detected platform: $platform');
      debugPrint('🔗 URL: $url');

      // Pass URL as text context - Gemini can sometimes extract info from URLs
      // User can also upload video manually which will be processed
      throw Exception(
          'Para videos de $platform, por favor usa la opción "Subir video desde Galería".\n\nDescarga el video de $platform y súbelo aquí para que el Chef IA lo analice.');
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
      // Extract thumbnail from video first frame
      final thumbnailPath = '${filePath}_thumb.jpg';
      final thumbnailBytes = await VideoThumbnail.thumbnailFile(
        video: filePath,
        thumbnailPath: thumbnailPath,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 1080,
        quality: 80,
      );

      final imagePath = thumbnailPath ?? filePath;

      debugPrint('📸 Video thumbnail: $imagePath');

      final extractUseCase = ref.read(extractRecipeUseCaseProvider);
      final recipe = await extractUseCase.execute(mediaPath: imagePath);

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
