import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connectivity_service.dart';
import 'offline_cache_service.dart';

enum GenerativeModelType {
  gemini15Flash,
  gemini15Pro,
  gemini20Flash,
}

class GeminiService {
  final ConnectivityService _connectivity;
  final OfflineCacheService _cache;
  final String _apiKey;

  static const String _defaultModel = 'gemini-2.5-flash';

  GeminiService({
    required ConnectivityService connectivity,
    required OfflineCacheService cache,
    required String apiKey,
  })  : _connectivity = connectivity,
        _cache = cache,
        _apiKey = apiKey;

  String get apiKey => _apiKey;

  Future<GenerativeModel?> _getModel({bool useVision = false}) async {
    if (_apiKey.isEmpty) {
      debugPrint('[GeminiService] Error: API Key is empty');
      return null;
    }
    return GenerativeModel(
      model: _defaultModel,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.4,
        topK: 32,
        topP: 1,
        maxOutputTokens: 4096,
      ),
    );
  }

  /// Genera texto simple con soporte de caché offline.
  Future<String?> generateText({
    required String prompt,
    String? cacheKey,
  }) async {
    final effectiveCacheKey = cacheKey ?? 'text_${prompt.hashCode}';

    return _generateWithCache(
      cacheKey: effectiveCacheKey,
      apiCall: () async {
        final model = await _getModel();
        if (model == null) return null;

        final content = [Content.text(prompt)];
        final response = await model.generateContent(content);
        return response.text;
      },
    );
  }

  /// Extrae una receta desde un texto o una imagen/video.
  Future<String?> extractRecipe({
    String? textContext,
    String? mediaPath,
  }) async {
    final cacheKey = mediaPath != null
        ? 'recipe_media_${mediaPath.hashCode}'
        : 'recipe_text_${textContext?.hashCode ?? 0}';

    return _generateWithCache(
      cacheKey: cacheKey,
      apiCall: () async {
        final useVision = mediaPath != null;
        final model = await _getModel(useVision: useVision);
        if (model == null) return null;

        final prompt = '''
Eres un Chef experto y nutricionista. Tu tarea es extraer o crear una receta detallada basada en la información proporcionada.
Si es una IMAGEN o VIDEO, analiza los ingredientes y el proceso.
Si es TEXTO, estructura la receta.

La respuesta DEBE ser ÚNICAMENTE un objeto JSON válido (empezando con '{' y terminando con '}'). NO envuelvas en markdown (sin ` ```json `), ni incluyas explicaciones.

Usa exactamente esta estructura:
{
  "name": "Nombre de la receta",
  "description": "Breve descripción",
  "durationMinutes": 30,
  "servings": 2,
  "calorias_aproximadas": 500,
  "ingredients": [
    {
      "ingredientName": "Nombre ingrediente",
      "quantity": 1.5,
      "unit": "unidades"
    }
  ],
  "instructions": [
    "Paso 1...",
    "Paso 2..."
  ],
  "tips_chef": [
    "Tip 1"
  ]
}

IMPORTANTE para "ingredientName": Usa SOLO el nombre base del ingrediente como lo buscarías en un supermercado.
- NO incluir instrucciones de corte, preparación, estado o forma (ej: 'cortado en cubitos', 'pelado', 'rallado', 'en tiras', 'de lomo fino cortado en tiras gruesas').
- Ejemplo correcto: 'Tomate', 'Cebolla roja', 'Pechuga de pollo', 'Lomo fino de res'.
- Ejemplo incorrecto: 'Tomate cortado en cubitos', 'Cebolla roja pelada', 'Lomo fino de res cortado en tiras gruesas'.

Contexto adicional: ${textContext ?? 'Ninguno'}
''';

        final contentList = <Content>[];
        if (mediaPath != null) {
          final file = File(mediaPath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final mimeType = _getMimeType(mediaPath);
            contentList.add(Content.multi([
              TextPart(prompt),
              DataPart(mimeType, bytes),
            ]));
          } else {
            contentList.add(Content.text(prompt));
          }
        } else {
          contentList.add(Content.text(prompt));
        }

        final response = await model.generateContent(contentList);
        return response.text;
      },
    );
  }

  /// Analiza una foto de múltiples productos de despensa.
  Future<String?> analyzePantryItems({
    required String photoPath,
  }) async {
    const cacheKey = 'pantry_analysis_multiple';

    return _generateWithCache(
      cacheKey: cacheKey,
      apiCall: () async {
        final model = await _getModel(useVision: true);
        if (model == null) return null;

        final prompt = '''
Analiza esta imagen de productos de despensa (pueden ser varios). 
Identifica cada producto y extrae la siguiente información en un formato JSON (una lista de objetos):

- name: nombre del producto (ej: Arroz, Leche, Atún)
- primaryCategory: una de estas exactas: [Proteínas animales, Lácteos, Frutas, Verduras, Tubérculos y raíces, Legumbres, Cereales y granos, Harinas y derivados, Aceites y grasas, Salsas, Condimentos y especias, Endulzantes, Frutos secos y semillas, Otros]
- subCategory: descripción corta (ej: Integral, Entera, en lata)
- quantity: cantidad numérica estimada (ej: 1, 0.5, 3)
- unit: una de estas exactas: [kg, g, l, ml, unidades, tazas, cucharadas, oz]
- pantryLifeDays: días aproximados que dura en la alacena antes de vencer (número entero)

La respuesta DEBE ser solo el JSON, sin bloques de código markdown ni texto adicional.
''';

        final file = File(photoPath);
        if (!await file.exists()) return null;

        final bytes = await file.readAsBytes();
        final content = Content.multi([
          TextPart(prompt),
          DataPart(_getMimeType(photoPath), bytes),
        ]);

        final response = await model.generateContent([content]);
        return response.text;
      },
    );
  }

  /// Analiza un solo producto de despensa con detalle.
  Future<String?> analyzeSinglePantryItem({
    required String photoPath,
  }) async {
    const cacheKey = 'pantry_analysis_single';

    return _generateWithCache(
      cacheKey: cacheKey,
      apiCall: () async {
        final model = await _getModel(useVision: true);
        if (model == null) return null;

        final prompt = '''
Analiza este producto de despensa en detalle. 
Extrae la información en formato JSON (un solo objeto):

- name: nombre del producto
- primaryCategory: una de estas exactas: [Proteínas animales, Lácteos, Frutas, Verduras, Tubérculos y raíces, Legumbres, Cereales y granos, Harinas y derivados, Aceites y grasas, Salsas, Condimentos y especias, Endulzantes, Frutos secos y semillas, Otros]
- subCategory: descripción corta
- quantity: cantidad numérica estimada
- unit: una de estas exactas: [kg, g, l, ml, unidades, tazas, cucharadas, oz]
- pantryLifeDays: días que dura en alacena
- fridgeLifeDays: días que dura en refrigerador
- freezerLifeDays: días que dura en congelador
- storageTip: consejo corto de conservación

La respuesta DEBE ser solo el JSON.
''';

        final file = File(photoPath);
        if (!await file.exists()) return null;

        final bytes = await file.readAsBytes();
        final content = Content.multi([
          TextPart(prompt),
          DataPart(_getMimeType(photoPath), bytes),
        ]);

        final response = await model.generateContent([content]);
        return response.text;
      },
    );
  }

  /// Sugiere un outfit basado en la ocasión y las prendas del usuario.
  Future<String?> suggestOutfitOfTheDay({
    required String occasion,
    required List<String> garmentsDescription,
    String? userProfileContext,
  }) async {
    final cacheKey = 'outfit_${occasion}_${garmentsDescription.hashCode}';

    return _generateWithCache(
      cacheKey: cacheKey,
      apiCall: () async {
        final model = await _getModel();
        if (model == null) return null;

        final prompt = '''
Eres un asesor de imagen personal (Styler AI). 
Basado en la ocasión: "$occasion" y el perfil del usuario: "${userProfileContext ?? 'Desconocido'}",
sugiere el mejor outfit posible usando estas prendas que el usuario tiene:
${garmentsDescription.join('\n')}

Devuelve una respuesta corta, elegante y con estilo en formato Markdown.
Incluye:
- La combinación sugerida.
- Por qué funciona.
- Un tip de accesorio.
''';

        final content = [Content.text(prompt)];
        final response = await model.generateContent(content);
        return response.text;
      },
    );
  }

  /// Evalúa una comida (imagen o descripción) para dar consejos nutricionales.
  Future<String?> evaluateMeal({
    String? photoPath,
    String? description,
  }) async {
    final cacheKey = 'meal_eval_${photoPath.hashCode}_${description.hashCode}';

    return _generateWithCache(
      cacheKey: cacheKey,
      apiCall: () async {
        final model = await _getModel(useVision: photoPath != null);
        if (model == null) return null;

        final prompt = '''
Eres un Food Coach experto. Analiza la comida proporcionada.
Si hay imagen, identifícala. Si hay descripción: "${description ?? ''}".

Dime:
1. Una calificación de salud (1-10).
2. Estimación rápida de Proteína, Carbohidratos y Grasas.
3. Un consejo para mejorarla.

Responde en formato Markdown amigable y conciso.
''';

        final contentList = <Content>[];
        if (photoPath != null) {
          final file = File(photoPath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            contentList.add(Content.multi([
              TextPart(prompt),
              DataPart(_getMimeType(photoPath), bytes),
            ]));
          } else {
            contentList.add(Content.text(prompt));
          }
        } else {
          contentList.add(Content.text(prompt));
        }

        final response = await model.generateContent(contentList);
        return response.text;
      },
    );
  }

  /// Genera una frase o insight diario (Estoico, Motivación, Productividad).
  Future<String?> generateDailyInsight() async {
    final dateKey = DateTime.now().toIso8601String().split('T').first;
    final cacheKey = 'daily_insight_$dateKey';

    return _generateWithCache(
      cacheKey: cacheKey,
      apiCall: () async {
        final model = await _getModel();
        if (model == null) return null;

        final prompt = '''
Genera un "Insight MyLifeOS" para hoy.
Selecciona aleatoriamente entre: un pensamiento estoico, un tip de productividad técnica o una frase de bienestar.
Mantén la respuesta en 3 líneas máximo en Markdown.
''';

        final content = [Content.text(prompt)];
        final response = await model.generateContent(content);
        return response.text;
      },
    );
  }

  /// Orquestador de llamadas con lógica de conectividad y caché.
  Future<String?> _generateWithCache({
    required String cacheKey,
    required Future<String?> Function() apiCall,
  }) async {
    // 1. Verificar si estamos online
    final isOnline = await _connectivity.isOnline();

    if (!isOnline) {
      debugPrint('[GeminiService] Offline - Buscando en caché para: $cacheKey');
      return await _cache.loadString(cacheKey);
    }

    try {
      // 2. Intentar llamada a la API
      final result = await apiCall();

      if (result != null && result.isNotEmpty) {
        // 3. Guardar en caché si tuvo éxito
        await _cache.saveString(cacheKey, result);
        return result;
      }

      // 4. Si la API falló pero tenemos algo en caché, devolver eso
      return await _cache.loadString(cacheKey);
    } catch (e) {
      debugPrint('[GeminiService] Error en API: $e');
      return await _cache.loadString(cacheKey);
    }
  }

  String _getMimeType(String path) {
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.mp4')) return 'video/mp4';
    return 'application/octet-stream';
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

// Nota: Reemplazar con tu propia lógica de obtención de API KEY (secuencia de entorno, etc.)
final geminiProvider = Provider<GeminiService>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  final cache = ref.watch(
      offlineCacheProvider); // Asumiendo que offlineCacheProvider está en offline_cache_service.dart o exportado.

  // En una app real, esto vendría de --dart-define o un secret store
  const apiKey = String.fromEnvironment('GEMINI_API_KEY');

  return GeminiService(
    connectivity: connectivity,
    cache: cache,
    apiKey: apiKey,
  );
});
