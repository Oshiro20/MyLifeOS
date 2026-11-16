import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
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
    final rawInput = url.trim();
    final extractedUrl = TikTokService.extractFirstUrl(rawInput);
    final cleanUrl = extractedUrl ?? rawInput;
    if (cleanUrl.isEmpty) {
      errorMessage = 'Ingresa una URL válida de receta o video.';
      state = RecipeImportState.error;
      return;
    }

    state = RecipeImportState.downloadingVideo;
    currentStatusMessage = 'Analizando enlace de receta...';
    errorMessage = null;

    try {
      final tikTokService = ref.read(tikTokServiceProvider);
      final info = await tikTokService.getTikTokVideoInfo(cleanUrl);

      String? videoUrl;
      if (info != null) {
        if (info.containsKey('data') && info['data'] is Map) {
          final data = info['data'] as Map<String, dynamic>;
          videoUrl = data['video_link_nwm'] ??
              data['play'] ??
              data['wmplay'] ??
              data['hdplay'] ??
              data['url'];
        }
        videoUrl ??= info['url'] as String?;
        videoUrl ??= info['video_link_nwm'] ??
            info['play'] ??
            info['wmplay'] ??
            info['hdplay'];
      }

      if (videoUrl != null && videoUrl.isNotEmpty) {
        currentStatusMessage = 'Descargando video...';
        final tempFile = File(
            '${(await getTemporaryDirectory()).path}/tiktok_${DateTime.now().millisecondsSinceEpoch}.mp4');

        final response = await http
            .get(Uri.parse(videoUrl))
            .timeout(const Duration(seconds: 45));
        if (response.statusCode != 200) {
          throw Exception('Fallo al descargar el video.');
        }
        await tempFile.writeAsBytes(response.bodyBytes);

        try {
          await importFromVideoFile(tempFile.path, sourceUrl: cleanUrl);
        } finally {
          if (tempFile.existsSync()) tempFile.deleteSync();
        }
      } else {
        // Extracción alternativa pública vía oEmbed + OpenGraph / JSON-LD
        currentStatusMessage = 'Extrayendo metadatos y descripción del enlace...';
        final metadata =
            await tikTokService.extractPublicRecipeMetadata(rawInput);
        if (metadata == null) {
          throw Exception(
            'No se pudo leer este enlace automáticamente (puede ser privado o estar protegido).\n\n'
            'Usa "Galería", "Cámara", "Subir video" o pega el texto de la receta abajo.',
          );
        }

        String? tempThumbPath;
        if (metadata.thumbnailUrl != null) {
          try {
            final imgResp = await http
                .get(Uri.parse(metadata.thumbnailUrl!))
                .timeout(const Duration(seconds: 15));
            final contentType =
                (imgResp.headers['content-type'] ?? '').toLowerCase();
            final isValidImage =
                imgResp.statusCode == 200 &&
                imgResp.bodyBytes.length > 2048 &&
                (contentType.isEmpty || contentType.startsWith('image/'));
            if (isValidImage) {
              tempThumbPath =
                  '${(await getTemporaryDirectory()).path}/url_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
              await File(tempThumbPath).writeAsBytes(imgResp.bodyBytes);
            }
          } catch (_) {}
        }

        if (metadata.contextText.isEmpty && tempThumbPath == null) {
          throw Exception(
            'El enlace no expone el título ni la portada de la receta.\n\n'
            'Prueba tomando una captura de pantalla ("Galería"), subiendo el video descargado o pegando la descripción de ingredientes.',
          );
        }

        state = RecipeImportState.extractingAI;
        currentStatusMessage = 'El Chef IA está interpretando la receta...';

        try {
          final geminiService = ref.read(geminiProvider);
          final jsonString = await geminiService.extractRecipe(
            textContext: metadata.contextText.isNotEmpty
                ? metadata.contextText
                : null,
            mediaPath: tempThumbPath,
          );
          if (jsonString == null || jsonString.isEmpty) {
            throw Exception(
              'El enlace no contiene suficientes datos visibles para armar la receta.\n'
              'Prueba subiendo capturas, el video o pegando el texto de los ingredientes.',
            );
          }
          importFromJson(jsonString, sourceUrl: cleanUrl);
        } finally {
          if (tempThumbPath != null && File(tempThumbPath).existsSync()) {
            File(tempThumbPath).deleteSync();
          }
        }
      }

      if (state == RecipeImportState.success) {
        final historyService = ImportHistoryService();
        await historyService.saveImport(cleanUrl);
      }
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      debugPrint('❌ URL import error: $e');
      state = RecipeImportState.error;
    }
  }

  /// Extrae una receta estructurada directamente desde texto pegado por el usuario.
  Future<void> importFromText(String rawText) async {
    final clean = rawText.trim();
    if (clean.isEmpty) return;

    state = RecipeImportState.extractingAI;
    currentStatusMessage = 'El Chef IA está estructurando tu receta...';
    errorMessage = null;

    try {
      final geminiService = ref.read(geminiProvider);
      final jsonString = await geminiService.extractRecipe(textContext: clean);
      if (jsonString == null || jsonString.isEmpty) {
        throw Exception(
          'No se pudo interpretar el texto. Verifica tu conexión a internet e intenta de nuevo.',
        );
      }
      importFromJson(jsonString);
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
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

      // Call Gemini with all images using the dedicated method
      final geminiService = ref.read(geminiProvider);
      final jsonResult =
          await geminiService.extractRecipeFromImages(imagePaths);

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

  Future<void> importFromVideoFile(
    String filePath, {
    String? sourceUrl,
  }) async {
    state = RecipeImportState.extractingAI;
    currentStatusMessage = 'El Chef IA está extrayendo fotogramas del video...';
    errorMessage = null;

    final frames = <String>[];
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

      final tempDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final seenSizes = <int>{};

      for (final timeMs in [0, 3000, 7000, 12000]) {
        try {
          final framePath = await VideoThumbnail.thumbnailFile(
            video: filePath,
            thumbnailPath: '${tempDir.path}/thumb_${ts}_$timeMs.jpg',
            imageFormat: ImageFormat.JPEG,
            maxHeight: 960,
            timeMs: timeMs,
            quality: 80,
          );
          if (framePath != null) {
            final frameFile = File(framePath);
            if (frameFile.existsSync()) {
              final size = frameFile.lengthSync();
              if (size > 0 && seenSizes.add(size)) {
                frames.add(framePath);
              } else {
                frameFile.deleteSync();
              }
            }
          }
        } catch (_) {}
      }

      if (frames.isEmpty) {
        throw Exception('No se pudieron extraer fotogramas del video.');
      }

      currentStatusMessage =
          'El Chef IA está analizando ${frames.length} fotograma(s) del video...';
      final geminiService = ref.read(geminiProvider);

      final String? jsonString;
      if (frames.length > 1) {
        jsonString = await geminiService.extractRecipeFromImages(frames);
      } else {
        jsonString = await geminiService.extractRecipe(mediaPath: frames.first);
      }

      if (jsonString == null || jsonString.isEmpty) {
        throw Exception(
          'No se obtuvo respuesta de la IA.\n\n'
          'Verifica tu conexión a internet o prueba con capturas de pantalla de los ingredientes y pasos.',
        );
      }

      debugPrint(
          '📝 Gemini returned: ${jsonString.substring(0, jsonString.length > 200 ? 200 : jsonString.length)}...');

      final useCase = ref.read(extractRecipeUseCaseProvider);
      importedRecipe = useCase.parseFromJson(jsonString, sourceUrl: sourceUrl);

      currentStatusMessage = '¡Receta encontrada!';
      state = RecipeImportState.success;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      debugPrint('❌ Video import error: $e');
      state = RecipeImportState.error;
    } finally {
      for (final frame in frames) {
        final f = File(frame);
        if (f.existsSync()) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
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
  const apiKey = String.fromEnvironment('TIKTOK_API_KEY');
  if (apiKey.isEmpty) {
    debugPrint(
        'ℹ️ TIKTOK_API_KEY no configurada (usando extracción alternativa).');
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
