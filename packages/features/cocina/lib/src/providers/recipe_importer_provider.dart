import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:domain/domain.dart';
import 'package:core/core.dart';
import 'package:uuid/uuid.dart';

enum RecipeImportState {
  initial,
  downloadingVideo,
  extractingAI,
  success,
  error
}

class RecipeImportNotifier extends StateNotifier<RecipeImportState> {
  final ExtractRecipeUseCase _extractUseCase;
  final TikTokService _tikTokService;
  
  Recipe? importedRecipe;
  String? errorMessage;
  String currentStatusMessage = '';

  RecipeImportNotifier({
    required ExtractRecipeUseCase extractUseCase,
    required TikTokService tikTokService,
  }) : _extractUseCase = extractUseCase,
       _tikTokService = tikTokService,
       super(RecipeImportState.initial);

  Future<void> importFromTikTokUrl(String url) async {
    state = RecipeImportState.downloadingVideo;
    currentStatusMessage = 'Conectando con TikTok...';
    errorMessage = null;

    try {
      // 1. Get Video info from API
      final info = await _tikTokService.getTikTokVideoInfo(url);
      if (info == null || !info.containsKey('data')) {
        throw Exception('No se pudo resolver la información del video de TikTok.');
      }

      // El endpoint de RapidAPI suele devolver 'play' para el video sin marca de agua
      final videoUrl = info['data']['play'] ?? info['data']['wmplay'];
      if (videoUrl == null) {
        throw Exception('No se encontró URL de descarga del video.');
      }

      currentStatusMessage = 'Descargando video en background...';
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('\${tempDir.path}/tiktok_video_\${const Uuid().v4()}.mp4');
      
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
      final recipe = await _extractUseCase.execute(mediaPath: filePath);
      
      if (recipe != null) {
        importedRecipe = recipe;
        currentStatusMessage = '¡Receta encontrada!';
        state = RecipeImportState.success;
      } else {
        throw Exception('La IA no pudo estructurar la receta o el formato no es válido.');
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
  return TikTokService('5bef8f8804msh689bebc06557fa2p1f4126jsn0b7a9680766c');
});

final recipeImportProvider = StateNotifierProvider<RecipeImportNotifier, RecipeImportState>((ref) {
  return RecipeImportNotifier(
    extractUseCase: ref.watch(extractRecipeUseCaseProvider),
    tikTokService: ref.watch(tikTokServiceProvider),
  );
});

class _GeminiExtractorAdapter implements IAIRecipeExtractor {
  final GeminiService gemini;
  _GeminiExtractorAdapter(this.gemini);

  @override
  Future<String?> extractRecipeJson({String? textContext, String? mediaPath}) {
    return gemini.extractRecipe(textContext: textContext, mediaPath: mediaPath);
  }
}
