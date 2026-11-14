import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'connectivity_service.dart';
import 'offline_cache_service.dart';
import 'wallet_cloud_service.dart';

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

  /// Llama directamente a la API REST de Gemini cuando existe [apiKey] local (`--dart-define`).
  static Future<String?> callGeminiDirectRest({
    required String apiKey,
    required String userMessage,
    String? systemPrompt,
    List<Map<String, String>> mediaItems = const [],
    List<Map<String, String>> history = const [],
    bool expectJson = false,
  }) async {
    if (apiKey.isEmpty) return null;

    final contents = <Map<String, dynamic>>[];
    for (final msg in history) {
      final text = msg['text'] ?? '';
      if (text.isEmpty) continue;
      contents.add({
        'role': msg['role'] == 'model' ? 'model' : 'user',
        'parts': [
          {'text': text}
        ],
      });
    }

    final currentParts = <Map<String, dynamic>>[
      {'text': userMessage},
      for (final item in mediaItems)
        if ((item['base64'] ?? '').isNotEmpty)
          {
            'inlineData': {
              'mimeType': item['mimeType'] ?? 'image/jpeg',
              'data': item['base64'],
            }
          },
    ];
    contents.add({
      'role': 'user',
      'parts': currentParts,
    });

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_defaultModel:generateContent?key=$apiKey',
    );
    final payload = <String, dynamic>{
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt}
          ],
        },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.4,
        'topK': 32,
        'topP': 1,
        'maxOutputTokens': 4096,
        if (expectJson) 'responseMimeType': 'application/json',
      },
    };

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Gemini REST HTTP ${response.statusCode}',
        uri: uri,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) return null;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return null;
    final content =
        (candidates.first as Map<String, dynamic>)['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) return null;
    return parts
        .whereType<Map<String, dynamic>>()
        .map((p) => p['text']?.toString() ?? '')
        .join();
  }

  /// Genera texto simple con soporte de caché offline y fallback vía Render Cloud.
  Future<String?> generateText({
    required String prompt,
    String? cacheKey,
  }) async {
    final effectiveCacheKey = cacheKey ?? 'text_${prompt.hashCode}';

    return _generateWithCache(
      cacheKey: effectiveCacheKey,
      apiCall: () async {
        return _executePrompt(prompt: prompt);
      },
    );
  }

  /// Ejecuta un prompt (y opcionalmente archivos multimedia) usando API key local si está
  /// configurada, o el proxy seguro de Render (`/api/ai/generate`) como canal principal/fallback.
  Future<String?> _executePrompt({
    required String prompt,
    List<String> mediaPaths = const [],
    bool expectJson = false,
  }) async {
    final mediaItems = <Map<String, String>>[];
    for (final path in mediaPaths) {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        mediaItems.add({
          'base64': base64Encode(bytes),
          'mimeType': _getMimeType(path),
        });
      }
    }

    if (_apiKey.isNotEmpty) {
      try {
        final text = await callGeminiDirectRest(
          apiKey: _apiKey,
          userMessage: prompt,
          mediaItems: mediaItems,
          expectJson: expectJson,
        );
        if (text != null && text.isNotEmpty) return text;
      } catch (e) {
        debugPrint('[GeminiService] Direct call failed, trying Render proxy: $e');
      }
    }

    return WalletCloudService.generateAI(
      userMessage: prompt,
      expectJson: expectJson,
      mediaItems: mediaItems.isNotEmpty ? mediaItems : null,
    );
  }

  /// Extrae una receta desde un texto o un archivo multimedia (video/imagen).
  /// Instructs Gemini to act as a professional chef and return structured JSON.
  Future<String?> extractRecipe({
    String? textContext,
    String? mediaPath,
  }) async {

    final prompt = '''
👨‍🍳 ROL DEL SISTEMA

Actúa como un Chef Profesional + Analista de Video de Cocina.

Tu especialidad:
• análisis de videos de cocina (TikTok, YouTube, Reels, Facebook, Instagram)
• interpretación de recetas implícitas
• inferencia culinaria profesional
• estandarización de recetas para apps

-----------------------------------------------------

📋 TU MISIÓN

Analiza DETENIDAMENTE el video/imagen de cocina proporcionado y extrae UNA RECETA COMPLETA Y ESTRUCTURADA.

🔍 PASOS DE ANÁLISIS (SIGUE CADA UNO):

PASO 0 - CONTEXTO DEL VIDEO

Antes de extraer, determina:
• ¿El video está completo, acelerado, resumido o es un timelapse?
• ¿Hay cortes rápidos entre pasos?
• ¿Los ingredientes son visibles o solo se mencionan brevemente?

Si el video está RESUMIDO o ACELERADO:
→ Reconstruye los pasos faltantes con lógica culinaria
→ Infiere ingredientes ocultos pero esenciales para la receta
→ Estima tiempos realistas basados en la técnica

-----------------------------------------------------

PASO 1 - IDENTIFICA EL PLATO
• ¿Qué tipo de plato es? (desayuno, almuerzo, cena, snack, postre, mazamorra, bebida)
• ¿Cuál es la cocina? (peruana, italiana, asiática, etc.)
• ¿Cuál es el nombre de la receta?

PASO 2 - DETECTA TODOS LOS INGREDIENTES
• Observa CADA ingrediente que aparece en el video
• Para CADA ingrediente identifica:
  - NOMBRE exacto (en español)
  - CANTIDAD como número (si dicen "una", pon 1; si no es claro, infiere)
  - UNIDAD de medida válida
  - PREPARACIÓN si es visible (entero, licuado, picado, molido, fresco, etc.)
• Si no dicen cantidad exacta → INFIÉRELA lógicamente según porción/tamaño
• NO inventes ingredientes que no aparecen EXCEPTO los esenciales
• Si hacen arroz chaufa pero no mencionan aceite → agrega aceite como ingrediente INFERIDO
• SÍ estima cantidades cuando no sean explícitas

PASO 3 - DETECTA LOS PASOS DE PREPARACIÓN
• Identifica el ORDEN EXACTO de cada paso
• Describe cada paso de forma CLARA y DETALLADA
• Incluye: qué se hace, con qué ingrediente, a qué temperatura, por cuánto tiempo
• Mínimo 3 pasos, máximo 15 pasos
• Separa acciones importantes (no mezcles pasos)

PASO 4 - ESTIMA TIEMPOS Y PORCIONES (¡CRÍTICO!)
• ⏱️ TIEMPO PREPARACIÓN: minutos de corte/mezcla/preparación (NUNCA 0, mínimo 1)
• 🔥 TIEMPO COCCIÓN: minutos de fuego/horno/etc. (NUNCA 0, mínimo 1)
• ⏱️ TIEMPO TOTAL: preparación + cocción (en minutos, realista: 15-180)
  - NO pongas 30 por defecto. CALCULA basándote en lo que ves.
  - Si ves que corta vegetales → prep ~5-10 min
  - Si ves que fríe/hornea → cocción ~10-45 min
• 👥 PORCIONES: para cuántas personas alcanza (entero: 1-12)
  - OBSERVA cuántos platos/porciones se sirven en el video
  - Si no se ve claro, INFIERE según la cantidad de ingredientes:
    * 1-2 tazas de arroz → 2-3 porciones
    * 1 pollo entero → 4-6 porciones
    * Postre individual → 1 porción
  - NO pongas 4 por defecto. CALCULA o INFIERE lógicamente.

PASO 5 - DETECTA UTENSILIOS
• Observa qué herramientas usa: sartén, olla, horno, licuadora, etc.
• Agrega 2-5 utensilios principales

PASO 6 - CLASIFICACIÓN
• Dificultad: "Fácil" (≤5 pasos), "Media" (6-10), "Difícil" (>10)
• Tipo de comida: Debes usar EXACTAMENTE uno de estos valores:
  "Desayuno" | "Almuerzo" | "Cena" | "Entrada" | "Sopa" | "Seco" | "Postre" | "Mazamorra" | "Bebida" | "Snack"
  - Postre: tartas, flanes, alfajores, etc.
  - Mazamorra: mazamorras, gelatinas, puddings
  - Entrada: ceviches, causa, tiradito, etc.
  - Sopa: caldos, cremas, aguaditos, etc.
  - Seco: platos fuertes con salsa espesa
  - Bebida: jugos, chicha, limonada, emoliente
  - Snack: botanas, pasabocas
• Cocina: según estilo (peruana, italiana, asiática, etc.)
• Tags: 3-5 tags relevantes

PASO 7 - ESTIMA CALORÍAS
• Calcula calorías aproximadas por porción según ingredientes

-----------------------------------------------------

📝 FORMATO DE SALIDA (JSON PURO - SIN MARKDOWN):

{
  "nombre_receta": "Nombre completo del plato",
  "descripcion": "Descripción atractiva de 2-3 oraciones",
  "porciones": 4,
  "tiempo_preparacion_min": 15,
  "tiempo_coccion_min": 30,
  "tiempo_total_min": 45,
  "dificultad": "Fácil",
  "tipo_comida": "Postre",
  "cocina": "Peruana",
  "ingredientes": [
    {
      "nombre": "Arroz",
      "cantidad": 2.0,
      "unidad": "tazas"
    }
  ],
  "ingredientes_inferidos": ["aceite", "sal", "pimienta"],
  "pasos": [
    {
      "numero": 1,
      "descripcion": "Descripción detallada del paso"
    }
  ],
  "utensilios": ["sartén", "cuchara de madera"],
  "calorias_aproximadas": 350,
  "tags": ["fácil", "rápido", "peruano"],
  "video_context": "resumido",
  "observaciones": "Los tiempos fueron inferidos según ingredientes.",
  "nivel_confianza": "Alto"
}

-----------------------------------------------------

⚠️ REGLAS OBLIGATORIAS:

1. Devuelve ÚNICAMENTE el JSON. NADA de texto antes o después. Sin markdown. Sin backticks.
2. TODOS los campos son obligatorios incluyendo "ingredientes_inferidos" y "video_context".
3. "ingredientes" debe tener AL MENOS 2 ingredientes reales.
4. "pasos" debe tener AL MENOS 3 pasos claros y detallados.
5. "cantidad" debe ser un NÚMERO (float), no texto. Ejemplo: 2.0, 0.5, 1.0
6. "unidad" en ESPAÑOL: "unidades", "gramos", "kilos", "mililitros", "tazas", "cucharadas", "cucharaditas", "pizca", "litros", "al gusto"
7. "tiempo_total_min" debe ser realista: entre 15 y 180 minutos. NO uses valores por defecto.
8. "porciones" debe ser entero: 1 a 12. CALCULA o INFIERE, no uses 4 por defecto.
9. "tiempo_preparacion_min" y "tiempo_coccion_min" deben ser >= 1. NUNCA 0.
10. "nivel_confianza":
   - "Alto" → video claro, ingredientes visibles, pasos completos
   - "Medio" → video resumido, algunas inferencias necesarias
   - "Bajo" → video muy corto, muchas suposiciones
11. "video_context":
    - "completo" → video muestra toda la preparación
    - "resumido" → video acelerado o con cortes
    - "timelapse" → video muy rápido tipo timelapse
    - "solo_resultado" → solo muestra el plato final
12. "observaciones" → indica qué datos fueron inferidos vs visibles y qué ingredientes esenciales se agregaron
13. "ingredientes_inferidos" → lista de ingredientes esenciales que NO aparecen en el video pero son necesarios (aceite, sal, pimienta, agua, etc.)
14. Si ves texto en el video (nombres, cantidades), ÚSALO.
15. Si el video muestra postre/mazamorra/plato dulce, adáptalo accordingly.
16. Si no estás seguro de algo, INFIÉRELO lógicamente pero completa TODOS los campos.
17. Si el video está resumido → reconstruye pasos faltantes con lógica culinaria.

${textContext != null && textContext.isNotEmpty ? '''
📌 CONTEXTO ADICIONAL DEL USUARIO:
"$textContext"
Usa esta información como referencia adicional.
''' : ''}

🎥 AHORA ANALIZA EL VIDEO/IMAGEN ADJUNTO Y DEVUELVE LA RECETA COMPLETA EN FORMATO JSON.''';

    try {
      debugPrint('🤖 Calling Gemini recipe extraction (${mediaPath ?? "text only"})');
      final result = await _executePrompt(
        prompt: prompt,
        mediaPaths: mediaPath != null ? [mediaPath] : const [],
        expectJson: true,
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException(
            'La IA tardó demasiado en responder. Intenta con un video más corto o imágenes más claras.',
            const Duration(seconds: 60),
          );
        },
      );

      if (result != null && result.isNotEmpty) {
        debugPrint('✅ Gemini response length: ${result.length} chars');
      } else {
        debugPrint('⚠️ Gemini returned null or empty response');
      }

      return result;
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception(e.message ?? 'Timeout al extraer la receta');
      }
      debugPrint('❌ Gemini extractRecipe error: $e');
      if (e.toString().contains('DataInspection') ||
          e.toString().contains('blocked')) {
        throw Exception(
            'Gemini bloqueó el análisis. Verifica que el video sea de cocina.');
      }
      throw Exception('Error en Gemini al extraer la receta: $e');
    }
  }

  /// Extracts a recipe from multiple images (photos of cookbook pages, screenshots, etc.)
  /// Returns structured JSON with the recipe.
  Future<String?> extractRecipeFromImages(List<String> imagePaths) async {
    final prompt = '''
👨‍ ERES UN CHEF PROFESIONAL + EXPERTO EN OCR Y ANÁLISIS DE IMÁGENES.

📋 TU MISIÓN:
Analiza las IMÁGENES proporcionadas y extrae UNA RECETA COMPLETA Y ESTRUCTURADA.

🔍 INSTRUCCIONES:
1. Lee TODO el texto visible en las imágenes (OCR)
2. Identifica ingredientes, cantidades, unidades y pasos
3. Si hay múltiples imágenes, combina la información de todas
4. Si falta información, infiérelo con lógica culinaria

📝 FORMATO JSON:
{
  "nombre_receta": "Nombre del plato",
  "descripcion": "Descripción de 2-3 oraciones",
  "porciones": 4,
  "tiempo_preparacion_min": 15,
  "tiempo_coccion_min": 30,
  "tiempo_total_min": 45,
  "dificultad": "Fácil",
  "tipo_comida": "Almuerzo",
  "cocina": "Peruana",
  "ingredientes": [
    {"nombre": "Arroz", "cantidad": 2.0, "unidad": "tazas"}
  ],
  "pasos": [
    {"numero": 1, "descripcion": "Paso detallado"}
  ],
  "utensilios": ["olla", "cuchara"],
  "calorias_aproximadas": 350,
  "tags": ["fácil", "peruano"],
  "observaciones": "Texto extraído de imagen.",
  "nivel_confianza": "Alto",
  "ingredientes_inferidos": [],
  "video_context": "imagen"
}

⚠️ REGLAS:
- Devuelve SOLO JSON, sin markdown ni backticks
- TODOS los campos obligatorios
- "cantidad" debe ser NÚMERO (float)
- "unidad" en español
- Mínimo 2 ingredientes, 3 pasos

📸 ANALIZA LAS IMÁGENES Y DEVUELVE LA RECETA EN JSON.''';

    try {
      return await _executePrompt(
        prompt: prompt,
        mediaPaths: imagePaths,
        expectJson: true,
      ).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw TimeoutException(
            'La IA tardó demasiado en responder. Intenta con imágenes más claras.',
            const Duration(seconds: 45),
          );
        },
      );
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception(e.message ?? 'Timeout al extraer receta de imágenes');
      }
      throw Exception('Error en IA al extraer receta de imágenes: $e');
    }
  }

  /// Analiza una foto de múltiples productos de despensa.
  Future<String?> analyzePantryItems({
    required String photoPath,
  }) async {
    final cacheKey = await _mediaCacheKey('pantry_multiple', photoPath);

    return _generateWithCache(
      cacheKey: cacheKey,
      apiCall: () async {
        final file = File(photoPath);
        if (!await file.exists()) return null;

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
        return _executePrompt(
          prompt: prompt,
          mediaPaths: [photoPath],
          expectJson: true,
        );
      },
    );
  }

  /// Analiza un solo producto de despensa con detalle.
  Future<String?> analyzeSinglePantryItem({
    required String photoPath,
  }) async {
    final cacheKey = await _mediaCacheKey('pantry_single', photoPath);

    return _generateWithCache(
      cacheKey: cacheKey,
      apiCall: () async {
        final file = File(photoPath);
        if (!await file.exists()) return null;

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
        return _executePrompt(
          prompt: prompt,
          mediaPaths: [photoPath],
          expectJson: true,
        );
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
        return _executePrompt(prompt: prompt);
      },
    );
  }

  /// Evalúa una comida (imagen o descripción) para dar consejos nutricionales.
  Future<String?> evaluateMeal({
    String? photoPath,
    String? description,
  }) async {
    final cacheKey = await _mediaCacheKey(
      'meal_eval',
      photoPath ?? '',
      extra: description,
    );

    return _generateWithCache(
      cacheKey: cacheKey,
      apiCall: () async {
        final prompt = '''
Eres un Food Coach experto. Analiza la comida proporcionada.
Si hay imagen, identifícala. Si hay descripción: "${description ?? ''}".

Dime:
1. Una calificación de salud (1-10).
2. Estimación rápida de Proteína, Carbohidratos y Grasas.
3. Un consejo para mejorarla.

Responde en formato Markdown amigable y conciso.
''';
        final mediaPaths = <String>[];
        if (photoPath != null && await File(photoPath).exists()) {
          mediaPaths.add(photoPath);
        }
        return _executePrompt(prompt: prompt, mediaPaths: mediaPaths);
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
        final prompt = '''
Genera un "Insight MyLifeOS" para hoy.
Selecciona aleatoriamente entre: un pensamiento estoico, un tip de productividad técnica o una frase de bienestar.
Mantén la respuesta en 3 líneas máximo en Markdown.
''';
        return _executePrompt(prompt: prompt);
      },
    );
  }

  /// Genera JSON estructurado (con soporte opcional de imágenes y caché).
  Future<String?> generateJsonText({
    required String prompt,
    List<String> mediaPaths = const [],
    String? cacheKey,
  }) async {
    Future<String?> call() => _executePrompt(
          prompt: prompt,
          mediaPaths: mediaPaths,
          expectJson: true,
        );
    if (cacheKey != null) {
      return _generateWithCache(cacheKey: cacheKey, apiCall: call);
    }
    return call();
  }

  /// Evalúa una comida con respuesta JSON estricta compatible con MealEvaluation.
  Future<String?> evaluateMealStructured({
    String? photoPath,
    required String description,
  }) async {
    final mediaPaths = (photoPath != null && photoPath.isNotEmpty)
        ? [photoPath]
        : const <String>[];
    final prompt = '''
Eres un nutricionista experto y empático. Evalúa esta comida:
"$description"

Responde ÚNICAMENTE con un objeto JSON válido con estas claves exactas:
{
  "classification": "healthy",
  "healthScore": 0.85,
  "positiveFactors": ["Alta proteína", "Buena fibra"],
  "negativeFactors": [],
  "feedback": "Resumen claro y breve en español de máximo 2 oraciones.",
  "recommendation": "Un consejo práctico y accionable en español."
}

Reglas:
- "classification" DEBE ser exactamente uno de: "healthy", "balanced", "junk".
- "healthScore" DEBE ser un número decimal entre 0.0 y 1.0 (ej: 0.85 para healthy, 0.55 para balanced, 0.25 para junk).
- Sin markdown ni texto fuera del JSON.
''';
    return _executePrompt(
      prompt: prompt,
      mediaPaths: mediaPaths,
      expectJson: true,
    );
  }

  /// Sugiere el Outfit del Día (OOTD) en JSON estructurado usando IDs reales.
  Future<String?> suggestOutfitOfTheDayJson({
    required List<Map<String, dynamic>> garments,
    required String weatherContext,
    String? userProfileContext,
  }) async {
    final profileText = (userProfileContext != null && userProfileContext.isNotEmpty)
        ? userProfileContext
        : 'Estilo versátil y cómodo';
    final prompt = '''
Eres un estilista personal experto. Selecciona el mejor Outfit del Día usando ÚNICAMENTE prendas de este inventario limpio.

CLIMA ACTUAL: $weatherContext
PERFIL DEL USUARIO: $profileText

PRENDAS DISPONIBLES (JSON):
${jsonEncode(garments)}

Devuelve ÚNICAMENTE un JSON válido con esta estructura exacta (usa los "id" exactos del inventario o null si no aplica):
{
  "top_id": "id_prenda_superior_o_vestido",
  "bottom_id": "id_prenda_inferior_o_null",
  "shoes_id": "id_calzado_o_null",
  "explanation": "Breve explicación personalizada del porqué combina bien con el clima y perfil."
}
''';
    return _executePrompt(
      prompt: prompt,
      expectJson: true,
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

  Future<String> _mediaCacheKey(
    String prefix,
    String path, {
    String? extra,
  }) async {
    String contentSignature = path;
    if (path.isNotEmpty) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          contentSignature = sha256.convert(bytes).toString();
        }
      } catch (_) {}
    }
    return '${prefix}_${contentSignature}_${extra ?? ''}';
  }

  String _getMimeType(String path) {
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.mp4')) return 'video/mp4';
    return 'application/octet-stream';
  }
}

// ── Provider ────────────────────────────────────────────────────────────────

final geminiProvider = Provider<GeminiService>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  final cache = ref.watch(offlineCacheProvider);

  // Opcional en desarrollo (--dart-define=GEMINI_API_KEY).
  // En producción sin key local, GeminiService usa automáticamente el proxy seguro en Render.
  const apiKey = String.fromEnvironment('GEMINI_API_KEY');

  debugPrint(
      '🔑 Gemini Mode: ${apiKey.isNotEmpty ? "Direct REST + Render fallback" : "Render Cloud Proxy"}');

  return GeminiService(
    connectivity: connectivity,
    cache: cache,
    apiKey: apiKey,
  );
});
