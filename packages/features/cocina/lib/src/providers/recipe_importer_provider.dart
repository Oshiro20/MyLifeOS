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
      videoUrl ??= info['video_link_nwm'] ??
          info['play'] ??
          info['wmplay'] ??
          info['hdplay'];

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

      final extractUseCase = ref.read(extractRecipeUseCaseProvider);
      
      debugPrint('📸 Processing ${imagePaths.length} images...');
      
      final recipe = await extractUseCase.execute(mediaPaths: imagePaths);
      
      if (recipe == null) {
        throw Exception(
            'La IA no pudo extraer la receta. Intenta con imágenes más claras.');
      }
      
      importedRecipe = recipe;
      currentStatusMessage = '¡Receta encontrada!';
      state = RecipeImportState.success;
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

      // Strategy: Extract 1 thumbnail, send video directly if <20MB (Gemini supports it)
      String mediaPath = filePath;
      String? thumbnailPath;

      try {
        thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: filePath,
          thumbnailPath:
              '${(await getTemporaryDirectory()).path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
          imageFormat: ImageFormat.JPEG,
          maxHeight: 1080,
          quality: 85,
        );

        if (thumbnailPath != null && File(thumbnailPath).existsSync()) {
          if (fileSizeMB < 20) {
            // Gemini CAN process video files directly under ~20MB
            mediaPath = filePath;
            File(thumbnailPath).deleteSync();
            thumbnailPath = null;
            debugPrint(
                '🎬 Using video file directly (${fileSizeMB.toStringAsFixed(1)} MB)');
          } else {
            // Use thumbnail for larger videos
            mediaPath = thumbnailPath;
            debugPrint('✅ Using thumbnail: $mediaPath');
          }
        } else {
          debugPrint(
              '⚠️ Thumbnail extraction returned null, using original video');
        }
      } catch (e) {
        debugPrint('⚠️ Thumbnail extraction failed: $e, using original video');
      }

      final extractUseCase = ref.read(extractRecipeUseCaseProvider);
      debugPrint(
          '🔍 Sending to AI: $mediaPath (${fileSizeMB.toStringAsFixed(1)} MB)');

      Recipe? recipe = await extractUseCase.execute(mediaPaths: [mediaPath]);

      if (recipe == null && mediaPath == filePath) {
        debugPrint('⚠️ Initial video processing failed. Generating multiple thumbnails for fallback...');
        currentStatusMessage = 'Analizando cuadros del video...';
        
        final List<String> fallbackThumbnails = [];
        for (int timeMs in [1000, 5000, 10000]) {
          try {
            final path = await VideoThumbnail.thumbnailFile(
              video: filePath,
              thumbnailPath: '${(await getTemporaryDirectory()).path}/thumb_${timeMs}_${DateTime.now().millisecondsSinceEpoch}.jpg',
              imageFormat: ImageFormat.JPEG,
              timeMs: timeMs,
              quality: 85,
            );
            if (path != null && File(path).existsSync()) {
              fallbackThumbnails.add(path);
            }
          } catch (e) {
            debugPrint('⚠️ Thumbnail generation failed at ${timeMs}ms: $e');
          }
        }
        
        if (fallbackThumbnails.isNotEmpty) {
          debugPrint('📸 Fallback triggered. Sending ${fallbackThumbnails.length} thumbnails to AI...');
          recipe = await extractUseCase.execute(mediaPaths: fallbackThumbnails);
          
          for (final thumb in fallbackThumbnails) {
             if (File(thumb).existsSync()) File(thumb).deleteSync();
          }
        }
      }

      if (recipe != null) {
        importedRecipe = recipe;
        currentStatusMessage = '¡Receta encontrada!';
        state = RecipeImportState.success;
      } else {
        throw Exception(
          'La IA no pudo estructurar la receta. Intenta con otro video más claro.',
        );
      }

      // Clean up thumbnail
      if (thumbnailPath != null && File(thumbnailPath).existsSync()) {
        File(thumbnailPath).deleteSync();
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
  Future<String?> extractRecipeJson({String? textContext, List<String>? mediaPaths}) {
    return gemini.extractRecipe(textContext: textContext, mediaPaths: mediaPaths);
  }
}
