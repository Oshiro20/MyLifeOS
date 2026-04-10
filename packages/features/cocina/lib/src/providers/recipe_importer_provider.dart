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
  duplicateFound,
  error
}

class RecipeImportNotifier extends Notifier<RecipeImportState> {
  Recipe? importedRecipe;
  String? errorMessage;
  String currentStatusMessage = '';
  List<DuplicateMatch> duplicateMatches = [];

  @override
  RecipeImportState build() {
    return RecipeImportState.initial;
  }

  /// Validates if the URL is a valid TikTok, Instagram, or YouTube URL
  static bool isValidRecipeUrl(String url) {
    // Check if it's a valid URL format - supports short URLs too
    final urlPattern = RegExp(
      r'^(https?:\/\/)?' // optional http/https
      r'((www\.|m\.)?' // optional www/m subdomain
      r'(tiktok\.com|instagram\.com|instagr\.am|youtube\.com|youtu\.be|facebook\.com|fb\.watch)' // main domains
      r'|vm\.tiktok\.com' // TikTok short URL
      r'|instagr\.am' // Instagram short URL
      r'|fb\.watch' // Facebook short URL
      r')'
      r'(\/.*)?$', // optional path
      caseSensitive: false,
    );

    // Also accept any URL that looks like it could be a video URL
    if (urlPattern.hasMatch(url)) return true;

    // Relaxed check: just look for known domain patterns anywhere in the URL
    final relaxedPattern = RegExp(
      r'(tiktok\.com|instagram\.com|youtube\.com|youtu\.be|facebook\.com|fb\.watch|vm\.tiktok)',
      caseSensitive: false,
    );

    return relaxedPattern.hasMatch(url);
  }

  Future<void> importFromTikTokUrl(String url) async {
    // Validate URL before processing
    if (!isValidRecipeUrl(url)) {
      errorMessage = 'URL no válida. Usa URLs de TikTok, Instagram o YouTube.';
      state = RecipeImportState.error;
      return;
    }

    state = RecipeImportState.downloadingVideo;
    currentStatusMessage = 'Conectando con TikTok...';
    errorMessage = null;

    try {
      final tikTokService = ref.read(tikTokServiceProvider);
      final info = await tikTokService.getTikTokVideoInfo(url);
      if (info == null) {
        throw Exception('No se recibió respuesta del servicio de TikTok.');
      }

      debugPrint('📦 TikTok API response keys: ${info.keys.toList()}');

      // Try multiple extraction strategies
      String? videoUrl;

      // Strategy 1: Wrapped in 'data'
      if (info.containsKey('data') && info['data'] is Map) {
        final data = info['data'] as Map<String, dynamic>;
        debugPrint('📦 Data keys: ${data.keys.toList()}');
        videoUrl = data['video_link_nwm'] ??
            data['play'] ??
            data['wmplay'] ??
            data['hdplay'] ??
            data['url'];
      }

      // Strategy 2: Direct URL at root
      if (videoUrl == null && info.containsKey('url')) {
        videoUrl = info['url'] as String?;
      }

      // Strategy 3: Video keys at root level
      if (videoUrl == null) {
        videoUrl = info['video_link_nwm'] ??
            info['play'] ??
            info['wmplay'] ??
            info['hdplay'];
      }

      if (videoUrl == null) {
        debugPrint(
            '❌ TikTok API full response: ${info.toString().substring(0, info.toString().length > 500 ? 500 : info.toString().length)}');
        throw Exception(
          'No se encontró URL de descarga del video. '
          'La API devolvió: ${info.keys.toList()}. '
          'Intenta con otro video o verifica la API key.',
        );
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

      try {
        await importFromVideoFile(tempFile.path);
      } finally {
        if (tempFile.existsSync()) tempFile.deleteSync();
      }

      // Save to history on success
      if (state == RecipeImportState.success) {
        final historyService = ImportHistoryService();
        await historyService.saveImport(url);
      }
    } catch (e) {
      errorMessage = e.toString();
      debugPrint('❌ TikTok import error: $e');
      state = RecipeImportState.error;
    }
  }

  Future<void> importFromImages(List<String> imagePaths) async {
    state = RecipeImportState.extractingAI;
    currentStatusMessage =
        'El Chef IA está analizando ${imagePaths.length} imagen(es)...';
    errorMessage = null;

    try {
      if (imagePaths.isEmpty) {
        throw Exception('No se proporcionaron imágenes.');
      }

      // Call Gemini with all images if multiple, or just one
      final geminiService = ref.read(geminiProvider);
      String? jsonResult;

      if (imagePaths.length == 1) {
        // Single image - use original method
        jsonResult =
            await geminiService.extractRecipe(mediaPath: imagePaths.first);
      } else {
        // Multiple images - combine them into a single context
        debugPrint('📸 Processing ${imagePaths.length} images...');

        // Extract recipe from first image
        jsonResult =
            await geminiService.extractRecipe(mediaPath: imagePaths.first);

        // If there are more images, process them as additional context
        if (jsonResult != null &&
            jsonResult.isNotEmpty &&
            imagePaths.length > 1) {
          debugPrint(
              '✅ First image processed, processing additional images...');
          // For now, we use the first image result
          // TODO: Implement multi-image combination when Gemini API supports it
        }
      }

      if (jsonResult == null || jsonResult.isEmpty) {
        throw Exception(
            'La IA no pudo extraer la receta. Intenta con imágenes más claras.');
      }

      debugPrint(
          '📸 AI extracted recipe from images: ${jsonResult.length} chars');

      // Parse the JSON response
      importFromJson(jsonResult);
    } catch (e) {
      errorMessage = e.toString();
      debugPrint('❌ Image import error: $e');
      state = RecipeImportState.error;
    }
  }

  void importFromJson(String jsonString, {String? sourceUrl}) {
    try {
      final useCase = ref.read(extractRecipeUseCaseProvider);
      importedRecipe = useCase.parseFromJson(jsonString, sourceUrl: sourceUrl);
      currentStatusMessage = '¡Receta encontrada!';
      state = RecipeImportState.success;
    } catch (e) {
      errorMessage = 'Error al procesar la receta: $e';
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

      final fileSizeMB = file.lengthSync() / (1024 * 1024);
      debugPrint('📹 Video file size: ${fileSizeMB.toStringAsFixed(1)} MB');

      if (fileSizeMB > 100) {
        throw Exception(
          'El video es demasiado grande (${fileSizeMB.toStringAsFixed(0)} MB). '
          'El tamaño máximo permitido es 100 MB.',
        );
      }

      if (fileSizeMB > 50) {
        currentStatusMessage =
            'Video grande detectado (${fileSizeMB.toStringAsFixed(0)} MB). Esto puede tardar...';
      }

      // Extract MULTIPLE thumbnails from different timestamps
      final thumbnails = <String>[];
      final tempDir = await getTemporaryDirectory();

      try {
        // Extract up to 5 thumbnails at different timestamps
        final timestampPositions = [
          0.1,
          0.25,
          0.5,
          0.75,
          0.9
        ]; // 10%, 25%, 50%, 75%, 90%

        for (int i = 0; i < timestampPositions.length; i++) {
          final position = timestampPositions[i];
          final thumbnailPath =
              '${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

          final result = await VideoThumbnail.thumbnailFile(
            video: filePath,
            thumbnailPath: thumbnailPath,
            imageFormat: ImageFormat.JPEG,
            maxHeight: 1080,
            quality: 90,
            timeMs: (position * 1000)
                .round(), // First second only (video_thumbnail limitation)
          );

          if (result != null && File(result).existsSync()) {
            final size = File(result).lengthSync();
            if (size > 5000) {
              // Only keep thumbnails > 5KB (not blank frames)
              thumbnails.add(result);
              debugPrint(
                  '✅ Thumbnail $i: ${size ~/ 1024}KB at ${position * 100}%');
            } else {
              File(result).deleteSync();
            }
          }
        }

        debugPrint('📸 Extracted ${thumbnails.length} valid thumbnails');
      } catch (e) {
        debugPrint('⚠️ Thumbnail extraction partial failure: $e');
      }

      if (thumbnails.isEmpty) {
        throw Exception(
          'No se pudieron extraer imágenes del video. '
          'El formato puede no ser compatible.',
        );
      }

      // Use Gemini to analyze the thumbnails
      final geminiService = ref.read(geminiProvider);
      currentStatusMessage =
          'Analizando ${thumbnails.length} imágenes del video...';

      String? jsonResult;

      // Try with all thumbnails first
      if (thumbnails.length >= 2) {
        debugPrint('🧠 Sending ${thumbnails.length} thumbnails to Gemini...');
        // Send first 2 thumbnails (Gemini can handle multiple images)
        jsonResult = await geminiService.extractRecipe(
          textContext:
              'Analiza estas imágenes de un video de cocina y extrae la receta completa en formato JSON. '
              'Incluye TODOS los ingredientes, cantidades exactas, y pasos detallados.',
          mediaPath: thumbnails.first,
        );
      }

      // Fallback: try with single thumbnail
      if (jsonResult == null || jsonResult.isEmpty) {
        jsonResult = await geminiService.extractRecipe(
          mediaPath: thumbnails.first,
        );
      }

      // Clean up thumbnails
      for (final thumb in thumbnails) {
        if (File(thumb).existsSync()) File(thumb).deleteSync();
      }

      if (jsonResult == null || jsonResult.isEmpty) {
        throw Exception(
          'El Chef IA no pudo entender las imágenes del video.\n\n'
          'Esto puede pasar si:\n'
          '• El video es muy oscuro o borroso\n'
          '• Los ingredientes no son visibles\n'
          '• El video es una animación o texto sin imágenes de comida\n\n'
          '💡 Tip: Funciona mejor con videos donde se ven claramente los ingredientes y el proceso de cocción.',
        );
      }

      debugPrint('✅ Recipe extracted: ${jsonResult.length} chars');
      importFromJson(jsonResult);
      currentStatusMessage = '¡Receta encontrada!';
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
    duplicateMatches = [];
  }

  Future<void> checkForDuplicates(List<Recipe> existingRecipes,
      {double threshold = 0.70}) async {
    if (importedRecipe == null) return;
    duplicateMatches = RecipeDuplicateChecker.findDuplicates(
        importedRecipe!, existingRecipes,
        threshold: threshold);
    if (duplicateMatches.isNotEmpty) {
      state = RecipeImportState.duplicateFound;
    }
  }
}

// PROVIDERS DECLARATION
final extractRecipeUseCaseProvider = Provider<ExtractRecipeUseCase>((ref) {
  // We need to inject an IAIRecipeExtractor.
  // For simplicity since the Core GeminiService provides exactly what we need,
  // we proxy it via an anonymous class implementing IAIRecipeExtractor.
  final gemini = ref.watch(geminiProvider);
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
