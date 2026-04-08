import 'dart:convert';
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

      // Save to history on success
      if (state == RecipeImportState.success) {
        final historyService = ImportHistoryService();
        await historyService.saveImport(url);
      }

      if (tempFile.existsSync()) tempFile.deleteSync();
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
      // Call Gemini with all images
      final geminiService = ref.read(geminiServiceProvider);
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
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      // Support both old and new JSON formats
      final name =
          decoded['name'] ?? decoded['nombre_receta'] ?? 'Receta Importada';
      final description =
          decoded['description'] ?? decoded['descripcion'] ?? '';

      int durationMinutes;
      if (decoded['durationMinutes'] != null) {
        durationMinutes = decoded['durationMinutes'] as int;
      } else if (decoded['tiempo_total_min'] != null) {
        durationMinutes = decoded['tiempo_total_min'] as int;
      } else {
        durationMinutes = 30;
      }

      final servings = decoded['servings'] ?? decoded['porciones'];
      final servingsInt =
          servings is int ? servings : (servings is num ? servings.toInt() : 2);

      // Ingredients
      List<dynamic> rawIngredients =
          decoded['ingredients'] ?? decoded['ingredientes'] ?? [];
      final ingredients = <RecipeIngredient>[];
      final recipeId = DateTime.now().millisecondsSinceEpoch.toString();

      for (int i = 0; i < rawIngredients.length; i++) {
        final item = rawIngredients[i] as Map<String, dynamic>;
        final ingName =
            item['ingredientName'] ?? item['nombre'] ?? 'Ingrediente $i';
        final rawQty = item['quantity'] ?? item['cantidad'];
        final qty = rawQty is num
            ? rawQty.toDouble()
            : (rawQty is String ? double.tryParse(rawQty) ?? 1.0 : 1.0);
        final unit = item['unit'] ?? item['unidad'] ?? 'unidades';

        ingredients.add(RecipeIngredient(
          id: '${recipeId}_ing_$i',
          recipeId: recipeId,
          ingredientName: ingName,
          quantity: qty,
          unit: unit,
        ));
      }

      // Instructions
      List<dynamic> rawInstructions =
          decoded['instructions'] ?? decoded['pasos'] ?? [];
      if (decoded['pasos'] != null) {
        final pasosList = decoded['pasos'] as List<dynamic>;
        pasosList.sort((a, b) {
          final numA = (a as Map)['numero'] as int? ?? 0;
          final numB = (b as Map)['numero'] as int? ?? 0;
          return numA.compareTo(numB);
        });
        rawInstructions = pasosList
            .map((p) => (p as Map)['descripcion'] ?? p.toString())
            .toList();
      }
      final instructions = rawInstructions.map((e) => e.toString()).toList();

      // Tags
      final rawTags = decoded['tags'] as List<dynamic>? ?? [];
      final tags = rawTags.map((e) => e.toString()).toList();

      // Campos adicionales
      final utensilios = (decoded['utensilios'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final ingredientesInferidos =
          (decoded['ingredientes_inferidos'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
      final caloriasAproximadas = decoded['calorias_aproximadas'] as int?;

      // Nutricion
      NutritionInfo? nutrition;
      if (decoded['nutricion'] != null) {
        final nutriData = decoded['nutricion'] as Map<String, dynamic>;
        nutrition = NutritionInfo(
          proteinasG: (nutriData['proteinas_g'] as num?)?.toDouble() ?? 0,
          carbohidratosG:
              (nutriData['carbohidratos_g'] as num?)?.toDouble() ?? 0,
          grasasG: (nutriData['grasas_g'] as num?)?.toDouble() ?? 0,
          fibraG: (nutriData['fibra_g'] as num?)?.toDouble() ?? 0,
        );
      }

      final alergenos = (decoded['alergenos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      final sustitutos = <IngredientSubstitute>[];
      if (decoded['sustitutos'] != null) {
        final sustitutosData = decoded['sustitutos'] as List<dynamic>;
        for (final sust in sustitutosData) {
          if (sust is Map<String, dynamic>) {
            sustitutos.add(IngredientSubstitute(
              original: sust['original'] as String? ?? '',
              sustituto: sust['sustituto'] as String? ?? '',
              nota: sust['nota'] as String?,
            ));
          }
        }
      }

      final tipsChef = (decoded['tips_chef'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final maridaje = decoded['maridaje'] as String?;

      final variaciones = <RecipeVariation>[];
      if (decoded['variaciones'] != null) {
        final variacionesData = decoded['variaciones'] as List<dynamic>;
        for (final varData in variacionesData) {
          if (varData is Map<String, dynamic>) {
            variaciones.add(RecipeVariation(
              nombre: varData['nombre'] as String? ?? '',
              cambios: varData['cambios'] as String? ?? '',
            ));
          }
        }
      }

      importedRecipe = Recipe(
        id: recipeId,
        name: name,
        description: description,
        durationMinutes: durationMinutes,
        servings: servingsInt,
        instructions: instructions,
        ingredients: ingredients,
        tags: tags,
        createdAt: DateTime.now(),
        utensilios: utensilios,
        ingredientesInferidos: ingredientesInferidos,
        caloriasAproximadas: caloriasAproximadas,
        nutrition: nutrition,
        alergenos: alergenos,
        sustitutos: sustitutos,
        tipsChef: tipsChef,
        maridaje: maridaje,
        variaciones: variaciones,
        fuenteUrl: sourceUrl,
        fuenteLabel: sourceUrl != null ? 'TikTok/Video' : 'Chef IA',
      );

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

      // Check video size limit (100 MB)
      if (fileSizeMB > 100) {
        throw Exception(
          'El video es demasiado grande (${fileSizeMB.toStringAsFixed(0)} MB). '
          'El tamaño máximo permitido es 100 MB. '
          'Por favor, usa un video más corto o de menor calidad.',
        );
      }

      // Warn if video is very large but still under limit
      if (fileSizeMB > 50) {
        currentStatusMessage =
            'Video grande detectado (${fileSizeMB.toStringAsFixed(0)} MB). Esto puede tardar un poco...';
      }

      // Try to extract thumbnail, fallback to video file itself
      String mediaPath = filePath;
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
          // For videos under 20MB, we'll send the actual video file
          // For larger videos, use the thumbnail as fallback
          if (fileSizeMB < 20) {
            mediaPath = filePath; // Send actual video
            debugPrint(
                '🎬 Using video file directly (${fileSizeMB.toStringAsFixed(1)} MB)');
          } else {
            mediaPath = thumbnailPath; // Use thumbnail
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
      debugPrint('🔍 Sending to AI: $mediaPath');

      final recipe = await extractUseCase.execute(mediaPath: mediaPath);

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
