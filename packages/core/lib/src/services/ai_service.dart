import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
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
        'maxOutputTokens': 8192,
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
    final content = (candidates.first as Map<String, dynamic>)['content']
        as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) return null;
    return parts
        .whereType<Map<String, dynamic>>()
        .map((p) => p['text']?.toString() ?? '')
        .join();
  }

  /// Genera hash determinístico entre ejecuciones para claves de caché.
  static String _stableHash(String input) =>
      sha256.convert(utf8.encode(input)).toString().substring(0, 20);

  /// Genera texto simple con soporte de caché offline y fallback vía Render Cloud.
  Future<String?> generateText({
    required String prompt,
    String? cacheKey,
  }) async {
    final effectiveCacheKey = cacheKey ?? 'text_${_stableHash(prompt)}';

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
    if (!await _connectivity.isOnline()) {
      debugPrint(
          '[GeminiService] Sin conexión a internet; omitiendo llamada remota.');
      return null;
    }

    final mediaItems = <Map<String, String>>[];
    for (final path in mediaPaths) {
      final file = File(path);
      if (await file.exists()) {
        final mime = _getMimeType(path);
        var bytes = await file.readAsBytes();
        // Comprimir imágenes > 700KB en memoria para evitar timeouts o payloads HTTP 413
        if (mime.startsWith('image/') && bytes.length > 700 * 1024) {
          try {
            final compressed = await FlutterImageCompress.compressWithList(
              bytes,
              minWidth: 1280,
              minHeight: 1280,
              quality: 75,
              format: CompressFormat.jpeg,
            );
            if (compressed.isNotEmpty && compressed.length < bytes.length) {
              bytes = compressed;
            }
          } catch (e) {
            debugPrint('[GeminiService] Compresión en memoria omitida: $e');
          }
        }
        mediaItems.add({
          'base64': base64Encode(bytes),
          'mimeType': mime,
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
        debugPrint(
            '[GeminiService] Direct call failed, trying Render proxy: $e');
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

Analiza DETENIDAMENTE el video/imagen/texto de cocina proporcionado:
• Si muestra **UN plato** (aunque incluya su salsa o guarnición), extrae **1 objeto JSON** completo.
• Si muestra o lista **2 O MÁS recetas independientes** (por ejemplo: "3 desayunos rápidos", "4 jugos", "2 postres sin horno", etc.), devuelve un objeto con la clave `"recetas": [ { ... }, { ... } ]` manteniendo cada receta separada con sus propios ingredientes, pasos y categoría. No mezcles recetas distintas en una sola.

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
• Incluye: qué se hace, con qué ingrediente, a qué temperatura, y **EXACTAMENTE por cuánto tiempo**
• Si un paso requiere **refrigeración, congelación, reposo o marinado** (ej. gelatinas, postres fríos, masas, carnes), especifica OBLIGATORIAMENTE el tiempo exacto en horas o minutos dentro del texto del paso (ej: "Refrigerar durante 3 horas hasta que cuaje firme"), NUNCA pongas solo "hasta que cuaje"
• Mínimo 3 pasos, máximo 15 pasos
• Separa acciones importantes (no mezcles pasos)

PASO 4 - ESTIMA TIEMPOS Y PORCIONES (¡CRÍTICO!)
• ⏱️ TIEMPO PREPARACIÓN: minutos activos de corte/mezcla/disolución/armado (mínimo 1)
• 🔥 TIEMPO COCCIÓN: minutos reales al fuego/horno/licuadora/batidora (`0` si es receta fría sin calor, como gelatinas o batidos)
• ❄️ TIEMPO REFRIGERACIÓN/REPOSO: minutos de refrigeradora, congelador o reposo pasivo (`0` si se sirve de inmediato; si una gelatina tarda 3 h en refri, pon `180`)
• ⏱️ TIEMPO TOTAL: `tiempo_preparacion_min + tiempo_coccion_min + tiempo_refrigeracion_min` (NO pongas 30 por defecto; CALCULA cada componente con realismo)
  - Si ves que corta vegetales → prep ~5-10 min
  - Si ves que fríe/hornea → cocción ~10-45 min
  - Si lleva gelatina, agar o cuajado en nevera → indica tiempo_refrigeracion_min realista (ej. 120-240 min) y escríbelo en el paso correspondiente
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
• Tipo de comida ("tipo_comida"): Debes usar EXACTAMENTE uno de estos valores según el TIPO DE PLATO (evita usar "Almuerzo" o "Cena"):
  "Desayuno" | "Entrada" | "Sopa" | "Seco" | "Postre" | "Mazamorra" | "Bebida" | "Jugo" | "Snack"
  - Seco: platos fuertes / segundos / fondos (arroces, guisos, pastas, carnes, pescados, arroz chaufa, lomo saltado)
  - Sopa: caldos, cremas, aguaditos, ramen, chupe
  - Entrada: ceviches, causa, tiradito, ensaladas, aperitivos
  - Desayuno: panqueques, avena, huevos revueltos, tostadas, desayunos completos
  - Postre: tortas, tartas, flanes, alfajores, brownies, helados
  - Mazamorra: mazamorras, arroz con leche, gelatinas, puddings
  - Jugo: jugos naturales, extractos, batidos, smoothies
  - Bebida: refrescos, chicha, limonada, emoliente, infusiones, cócteles
  - Snack: piqueos, botanas, pasabocas, barritas
• Cocina: según estilo (Peruana, Italiana, Asiática, Mexicana, Internacional, etc.)
• Tags: 3-5 tags relevantes

PASO 7 - ESTIMA CALORÍAS
• Calcula calorías aproximadas por porción según ingredientes

-----------------------------------------------------

📝 FORMATO DE SALIDA (JSON PURO - SIN MARKDOWN):
(Si hay 2 o más recetas independientes en el video/texto, envuélvelas en {"recetas": [ ... ]} usando este mismo esquema por cada receta):

{
  "nombre_receta": "Nombre completo del plato",
  "descripcion": "Descripción atractiva de 2-3 oraciones",
  "porciones": 4,
  "tiempo_preparacion_min": 15,
  "tiempo_coccion_min": 30,
  "tiempo_refrigeracion_min": 0,
  "tiempo_total_min": 45,
  "dificultad": "Fácil",
  "tipo_comida": "Seco",
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
  "objetivo_nutricional": "normal | bajar_peso | ganar_musculo | ligera | personalizado",
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
7. "tiempo_total_min" debe ser realista: `tiempo_preparacion_min + tiempo_coccion_min + tiempo_refrigeracion_min` (puede ir desde 3 min en jugos hasta 360+ min si lleva varias horas de refrigeración o marinado). NO uses valores por defecto.
8. "porciones" debe ser entero: 1 a 12. CALCULA o INFIERE, no uses 4 por defecto.
9. "tiempo_preparacion_min" debe ser >= 1; "tiempo_coccion_min" puede ser 0 en recetas sin fuego/horno; "tiempo_refrigeracion_min" debe ser 0 salvo que requiera frío o reposo prolongado.
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
16. Si el texto o imagen sí identifican el plato, completa TODOS los campos respetando FIELMENTE ese plato (el "nombre_receta" y los ingredientes deben corresponder al plato indicado en el contexto o visible en la imagen).
17. REGLA ESTRICTA ANTI-ALUCINACIÓN: Si NO ves ninguna imagen/video adjunto ni recibiste un título o descripción clara de un plato específico (por ejemplo, solo un enlace genérico o texto vacío sin receta), NUNCA inventes ni sustituyas otra receta distinta o viral (como pastas, postres o ejemplos aleatorios). En ese caso devuelve ÚNICAMENTE:
{"error_extraccion": "No hay información suficiente visible del plato en el enlace o imagen para extraer la receta."}

${textContext != null && textContext.isNotEmpty ? '''
📌 CONTEXTO DEL VIDEO/ENLACE (OBLIGATORIO RESPETAR ESTE PLATO):
"$textContext"
Identifica y extrae EXCLUSIVAMENTE la receta de ese plato/contexto. No la reemplaces por otra receta.
''' : ''}

🎥 AHORA ANALIZA EL VIDEO/IMAGEN Y CONTEXTO ADJUNTO Y DEVUELVE LA RECETA COMPLETA EN FORMATO JSON.''';

    try {
      debugPrint(
          '🤖 Calling Gemini recipe extraction (${mediaPath ?? "text only"})');
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

  /// Clasifica automáticamente un lote de recetas guardadas sin categoría usando Gemini.
  /// Clasifica recetas con categoría culinaria (`tipo_comida`), meta nutricional (`objetivo`) y calorías.
  Future<Map<String, ({String? mealType, String? goal, int? calories})>>
      categorizeRecipesDetailedWithGemini(
    List<
            ({
              String id,
              String name,
              List<String> ingredients,
              String description
            })>
        recipes,
  ) async {
    if (recipes.isEmpty) return const {};
    final subset = recipes.take(30).toList();
    final catalogText = subset
        .map((r) =>
            '- id="${r.id}" | nombre="${r.name}" | ingredientes=[${r.ingredients.take(8).join(", ")}]${r.description.isNotEmpty ? ' | desc="${r.description}"' : ''}')
        .join('\n');

    final prompt = '''
Clasifica cada receta en:
1) "tipo": UNO de ["Desayuno", "Entrada", "Sopa", "Seco", "Postre", "Mazamorra", "Bebida", "Jugo", "Snack"]
2) "objetivo": UNO de ["normal", "bajar_peso", "ganar_musculo", "ligera", "personalizado"]
   - Platos con frituras/balance casero estándar -> "normal"
   - Ensaladas/plancha/bajo en grasa/infusiones sin azúcar -> "bajar_peso"
   - Alta proteína (pollo/pescado/carne/huevos/menestras/quinua/avena) -> "ganar_musculo"
   - Sopas livianas/vapor/cremas suaves -> "ligera"
3) "kcal": calorías aproximadas por porción (entero)

Recetas:
$catalogText

Devuelve ÚNICAMENTE un JSON válido con clave = id exacto:
{"id_1": {"tipo": "Seco", "objetivo": "ganar_musculo", "kcal": 520}}
''';

    final raw = await _executePrompt(prompt: prompt, expectJson: true)
        .timeout(const Duration(seconds: 30));
    if (raw == null || raw.isEmpty) return const {};

    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start == -1 || end <= start) return const {};
      final decoded = jsonDecode(raw.substring(start, end + 1));
      if (decoded is! Map) return const {};
      final out = <String, ({String? mealType, String? goal, int? calories})>{};
      for (final entry in decoded.entries) {
        if (entry.key == null || entry.value == null) continue;
        final k = entry.key.toString();
        if (entry.value is Map) {
          final m = Map<String, dynamic>.from(entry.value as Map);
          out[k] = (
            mealType: m['tipo']?.toString(),
            goal: m['objetivo']?.toString(),
            calories: (m['kcal'] as num?)?.round(),
          );
        } else {
          out[k] = (
            mealType: entry.value.toString(),
            goal: null,
            calories: null,
          );
        }
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  /// Sugiere sustitutos concretos usando ingredientes actuales de la despensa cuando falta algo al cocinar.
  Future<String?> suggestIngredientSubstitutesGemini({
    required String recipeName,
    required List<String> missingIngredients,
    required List<String> pantryNames,
  }) async {
    if (missingIngredients.isEmpty) return null;
    final prompt = '''
Eres un chef práctico peruano. El usuario va a cocinar "$recipeName" y le falta o tiene duda con:
${missingIngredients.map((m) => '- $m').join('\n')}

Lo que SÍ tiene en su despensa:
${pantryNames.take(40).join(', ')}

Sugiere sustituciones concretas y cortas (1 línea por ingrediente, priorizando lo que ya tiene en su despensa o alternativas caseras simples en español, sin relleno).''';

    return _executePrompt(prompt: prompt, expectJson: false)
        .timeout(const Duration(seconds: 25));
  }

  /// Propone 2 recetas express de rescate usando ingredientes por vencer o listos/cocidos.
  Future<String?> suggestRescueRecipesGemini({
    required List<String> priorityIngredients,
    required List<String> allPantryNames,
    required String goalLabel,
  }) async {
    if (priorityIngredients.isEmpty) return null;
    final prompt = '''
Chef peruano práctico. Meta nutricional del usuario: $goalLabel.
Ingredientes URGENTES (por vencer o ya cocidos/listos para usar):
${priorityIngredients.map((p) => '- $p').join('\n')}

Otros ingredientes disponibles en despensa:
${allPantryNames.take(35).join(', ')}

Propón 2 ideas EXPRESS (5-15 min) para aprovecharlos HOY sin desperdiciar comida. Responde directo en español con viñetas claras (Nombre, Tiempo, Qué usas de tu refri, Pasos breves).''';

    return _executePrompt(prompt: prompt, expectJson: false)
        .timeout(const Duration(seconds: 25));
  }

  /// Valida con IA qué ingredientes faltantes de [recipeName] están cubiertos
  /// por variantes en [pantryItems] (`direct`) o pueden sustituirse (`substitute`).
  Future<
      List<
          ({
            String recipeIngredient,
            String pantryItemName,
            String matchType,
            double? estimatedPantryQty,
            String reason,
          })>> validatePantryAgainstRecipeGemini({
    required String recipeName,
    required List<({String name, double quantity, String unit})>
        missingIngredients,
    required List<({String name, double quantity, String unit, String preparation})>
        pantryItems,
  }) async {
    if (missingIngredients.isEmpty || pantryItems.isEmpty) return const [];

    final missingList = missingIngredients
        .map((m) => '- "${m.name}" (${m.quantity} ${m.unit})')
        .join('\n');
    final pantryList = pantryItems
        .take(50)
        .map((p) =>
            '- "${p.name}" (${p.quantity} ${p.unit}${p.preparation.isNotEmpty ? ', estado: ${p.preparation}' : ''})')
        .join('\n');

    final prompt = '''
Eres un chef práctico peruano. Analiza la receta "$recipeName".
Ingredientes de la receta marcados como faltantes:
$missingList

Lo que el usuario SÍ tiene en su despensa:
$pantryList

Para cada ingrediente faltante que SÍ esté cubierto (por otro nombre/estado) o pueda sustituirse de forma gastronómicamente coherente con lo que hay en despensa:
- "type": "direct" si es esencialmente el mismo ingrediente en otro formato (ej. "Menestra lentejas baby" cocida cubre "Lentejas baby"; "Ajos molidos" cubre "Pasta de ajos"; "Pierna de pollo" cubre "Pollo en presas").
- "type": "substitute" SOLO si es un reemplazo culinario realmente compatible en sabor, aroma o cuerpo en cocina peruana (ej. "Tomate" picado por "Ají especial (panca)" en aderezo; "Leche" evaporada por crema).
- REGLA CRÍTICA: NO fuerces sustitutos culinariamente incompatibles ni repitas el mismo ingrediente de despensa como comodín para todo. Por ejemplo, NO sustituyas "Pasta de ajos" / "Ajos" por "Tomate", ni comino/pimienta/sal por vegetales. Si no hay equivalente ni sustituto válido en la despensa, OMITE ese ingrediente del JSON.
- "pantryItem": nombre EXACTO del producto de la despensa arriba listada.
- "useQty": número realista en la unidad de despensa (sin exceder el stock disponible; considera usos previos si repites producto).
- "reason": explicación breve en español (máx. 8 palabras).

Devuelve ÚNICAMENTE una lista JSON (si no hay matches válidos, devuelve []):
[{"recipeIngredient": "...", "pantryItem": "...", "type": "direct", "useQty": 1.0, "reason": "..."}]''';

    final raw = await _executePrompt(prompt: prompt, expectJson: true)
        .timeout(const Duration(seconds: 28));
    if (raw == null || raw.isEmpty) return const [];

    try {
      final start = raw.indexOf('[');
      final end = raw.lastIndexOf(']');
      if (start == -1 || end <= start) return const [];
      final decoded = jsonDecode(raw.substring(start, end + 1));
      if (decoded is! List) return const [];
      final out = <({
        String recipeIngredient,
        String pantryItemName,
        String matchType,
        double? estimatedPantryQty,
        String reason,
      })>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final rIng = map['recipeIngredient']?.toString().trim() ?? '';
        final pItem = map['pantryItem']?.toString().trim() ?? '';
        final mType =
            (map['type']?.toString().toLowerCase().trim() == 'substitute')
                ? 'substitute'
                : 'direct';
        final qty = (map['useQty'] as num?)?.toDouble();
        final reason = map['reason']?.toString().trim() ?? '';
        if (rIng.isNotEmpty && pItem.isNotEmpty) {
          out.add((
            recipeIngredient: rIng,
            pantryItemName: pItem,
            matchType: mType,
            estimatedPantryQty: qty,
            reason: reason,
          ));
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Retorna un mapa `recipeId -> etiqueta de MealType` (ej. 'Seco', 'Sopa', 'Postre').
  Future<Map<String, String>> categorizeRecipesWithGemini(
    List<
            ({
              String id,
              String name,
              List<String> ingredients,
              String description
            })>
        recipes,
  ) async {
    final detailed = await categorizeRecipesDetailedWithGemini(recipes);
    return {
      for (final e in detailed.entries)
        if (e.value.mealType != null) e.key: e.value.mealType!,
    };
  }

  /// Extracts a recipe from multiple images (photos of cookbook pages, screenshots, etc.)
  /// Returns structured JSON with the recipe.
  Future<String?> extractRecipeFromImages(
    List<String> imagePaths, {
    String? textContext,
  }) async {
    final prompt = '''
👨‍ ERES UN CHEF PROFESIONAL + EXPERTO EN OCR Y ANÁLISIS DE IMÁGENES.

📋 TU MISIÓN:
Analiza las IMÁGENES proporcionadas:
• Si muestran UN plato, devuelve 1 objeto JSON.
• Si muestran 2 o más recetas independientes (ej. varias fichas o un carrusel con varios platos distintos), devuelve {"recetas": [ { ... }, { ... } ]} separando cada receta correctamente.

🔍 INSTRUCCIONES:
1. Lee TODO el texto visible en las imágenes (OCR)
2. Identifica ingredientes, cantidades, unidades y pasos
3. Si todas las fotos son del mismo plato, combina la información en una sola receta
4. Clasifica "tipo_comida" usando EXACTAMENTE uno de: "Desayuno" | "Entrada" | "Sopa" | "Seco" | "Postre" | "Mazamorra" | "Bebida" | "Jugo" | "Snack" (usa "Seco" para platos principales/fondos, no uses "Almuerzo"/"Cena")
5. Si requiere refrigeración, congelación o reposo, indica SIEMPRE las horas o minutos exactos dentro del paso correspondiente y en "tiempo_refrigeracion_min" (0 si no requiere frío/reposo)
6. Si falta información, infiérelo con lógica culinaria manteniendo el mismo plato mostrado

📝 FORMATO JSON (o {"recetas": [ ... ]} si hay múltiples recetas):
{
  "nombre_receta": "Nombre del plato",
  "descripcion": "Descripción de 2-3 oraciones",
  "porciones": 4,
  "tiempo_preparacion_min": 15,
  "tiempo_coccion_min": 30,
  "tiempo_refrigeracion_min": 0,
  "tiempo_total_min": 45,
  "dificultad": "Fácil",
  "tipo_comida": "Seco",
  "cocina": "Peruana",
  "ingredientes": [
    {"nombre": "Arroz", "cantidad": 2.0, "unidad": "tazas"}
  ],
  "pasos": [
    {"numero": 1, "descripcion": "Paso detallado"}
  ],
  "utensilios": ["olla", "cuchara"],
  "calorias_aproximadas": 350,
  "objetivo_nutricional": "normal | bajar_peso | ganar_musculo | ligera | personalizado",
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
- NUNCA inventes una receta diferente a la mostrada en las imágenes. Si no puedes ver ninguna imagen o las imágenes no contienen comida ni receta legible, devuelve ÚNICAMENTE:
{"error_extraccion": "No se detectó ninguna receta legible en las imágenes adjuntas."}

${textContext != null && textContext.isNotEmpty ? '''
📌 CONTEXTO / DESCRIPCIÓN DEL VIDEO (RESPETAR ESTE PLATO):
"$textContext"
''' : ''}

📸 ANALIZA LAS IMÁGENES Y DEVUELVE LA RECETA EN JSON.''';

    try {
      return await _executePrompt(
        prompt: prompt,
        mediaPaths: imagePaths,
        expectJson: true,
      ).timeout(
        const Duration(seconds: 75),
        onTimeout: () {
          throw TimeoutException(
            'La IA tardó demasiado en responder. Intenta con imágenes más claras o menos fotos.',
            const Duration(seconds: 75),
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
Analiza esta imagen de productos de despensa (pueden ser varios, nuevos o ya abiertos/usados).
Identifica cada producto y extrae la siguiente información en formato JSON (una lista de objetos):

- name: nombre del producto (ej: Sillao, Arroz, Leche, Atún)
- primaryCategory: una de estas exactas: [Proteínas animales, Lácteos, Frutas, Verduras, Tubérculos y raíces, Legumbres, Cereales y granos, Harinas y derivados, Aceites y grasas, Salsas, Condimentos y especias, Endulzantes, Frutos secos y semillas, Otros]
- subCategory: descripción corta (ej: Integral, Entera, Botella vidrio)
- packageQuantity: número de capacidad total impresa en la etiqueta si se ve (ej: 500 si dice 500ml, o igual a quantity si es a granel)
- quantity: cantidad RESTANTE real estimada dentro del envase. ¡IMPORTANTE!: si la botella, bolsa o frasco se ve parcialmente usado/abierto (ej. botella de 500 ml a la mitad), pon el restante estimado (250), NO el total de la etiqueta
- unit: una de estas exactas: [kg, g, l, ml, unidades, tazas, cucharadas, oz]
- isOpened: boolean (true si parece abierto o parcialmente consumido, false si está nuevo/sellado)
- fillLevelPercent: entero de 5 a 100 con el porcentaje aproximado que queda dentro (ej: 100 si lleno, 50 si va por la mitad, 25 si queda un cuarto)
- opaqueContainer: boolean (true si el envase es opaco o botella muy oscura/lata/caja donde no se distingue cuánto líquido o contenido queda adentro)
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
Analiza este producto de despensa en detalle (puede estar nuevo o ya abierto/usado).
Extrae la información en formato JSON (un solo objeto):

- name: nombre del producto (ej: Sillao, Aceite de oliva, Leche)
- primaryCategory: una de estas exactas: [Proteínas animales, Lácteos, Frutas, Verduras, Tubérculos y raíces, Legumbres, Cereales y granos, Harinas y derivados, Aceites y grasas, Salsas, Condimentos y especias, Endulzantes, Frutos secos y semillas, Otros]
- subCategory: descripción corta
- packageQuantity: número con la capacidad total impresa en la etiqueta si es visible (ej: 500 si dice 500ml)
- quantity: cantidad RESTANTE real estimada dentro del envase. Si ves el frasco/botella/bolsa parcialmente vacío (ej. etiqueta 500 ml pero lleno al 40%), calcula la cantidad restante (200)
- unit: una de estas exactas: [kg, g, l, ml, unidades, tazas, cucharadas, oz]
- isOpened: boolean (true si el producto se ve abierto o parcialmente consumido)
- fillLevelPercent: entero de 5 a 100 con el porcentaje visual restante (100 si lleno/sellado)
- opaqueContainer: boolean (true si el envase es opaco o vidrio muy oscuro donde no se alcanza a ver el nivel interno)
- pantryLifeDays: días que dura en alacena
- fridgeLifeDays: días que dura en refrigerador
- freezerLifeDays: días que dura en congelador
- storageTip: consejo corto de conservación (menciona si conviene refrigerar tras abrir)

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
    final cacheKey =
        'outfit_${occasion}_${_stableHash(garmentsDescription.join('|'))}';

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

  /// Evalúa una comida con respuesta JSON estricta compatible con MealEvaluation
  /// incluyendo macros estimados (kcal, proteína, carbos, grasas, fibra) según
  /// el método de cocción y contexto real de receta/porciones.
  Future<String?> evaluateMealStructured({
    String? photoPath,
    required String description,
    String? mealName,
    String? mealSlotLabel,
    String? cookingMethodLabel,
    double servings = 1.0,
    String? recipeContext,
  }) async {
    final mediaPaths = (photoPath != null && photoPath.isNotEmpty)
        ? [photoPath]
        : const <String>[];
    final extraLines = <String>[
      if (mealName != null && mealName.trim().isNotEmpty)
        'Nombre del plato: "${mealName.trim()}"',
      if (mealSlotLabel != null && mealSlotLabel.isNotEmpty)
        'Horario: $mealSlotLabel',
      if (cookingMethodLabel != null && cookingMethodLabel.isNotEmpty)
        'Método de cocción: $cookingMethodLabel (AJUSTA calorías y grasas según esto: ej. frito suma aceite absorbido, sancochado/plancha no).',
      'Porciones servidas: $servings',
      if (recipeContext != null && recipeContext.trim().isNotEmpty)
        'Contexto de la receta (cantidades/preparación):\n${recipeContext.trim()}',
    ].join('\n');

    final prompt = '''
Eres un nutricionista peruano experto y práctico. Evalúa nutricionalmente esta comida:
Ingredientes/Descripción: "$description"
$extraLines

Responde ÚNICAMENTE con un objeto JSON válido con estas claves exactas:
{
  "classification": "healthy",
  "healthScore": 0.85,
  "caloriesKcal": 520,
  "proteinGrams": 36.0,
  "carbsGrams": 48.0,
  "fatGrams": 16.0,
  "fiberGrams": 7.5,
  "detectedCookingMethod": "stewed",
  "positiveFactors": ["Alta proteína", "Buena fibra"],
  "negativeFactors": [],
  "feedback": "Resumen claro y breve en español de máximo 2 oraciones.",
  "recommendation": "Un consejo práctico y accionable en español."
}

Reglas:
- "classification" DEBE ser exactamente uno de: "healthy", "balanced", "junk".
- "healthScore" DEBE ser decimal entre 0.0 y 1.0 (ej: 0.85 healthy, 0.55 balanced, 0.25 junk).
- Estima "caloriesKcal", "proteinGrams", "carbsGrams", "fatGrams" y "fiberGrams" realistas para la porción consumida ($servings) tomando en cuenta el método de cocción.
- "detectedCookingMethod" debe ser uno de: "raw", "boiled", "grilled", "stewed", "baked", "fried".
- Sin markdown ni texto fuera del JSON.
''';
    return _executePrompt(
      prompt: prompt,
      mediaPaths: mediaPaths,
      expectJson: true,
    );
  }

  /// Genera una revisión semanal del nutricionista IA basada en consumo real.
  Future<String?> reviewWeeklyNutritionGemini({
    required String summaryContext,
    required String goalLabel,
  }) async {
    final prompt = '''
Eres un nutricionista deportivo y clínico peruano. Meta del usuario: $goalLabel.
Datos reales de su alimentación reciente:
$summaryContext

Dame un análisis breve y directo en español con:
1. Un diagnóstico corto (2 líneas) de su patrón actual.
2. Exactamente 3 ajustes prácticos para mejorar la próxima semana (incluyendo qué frutas/verduras o preparaciones sumar a sus compras).
Sé concreto y evita rodeos.''';
    return _executePrompt(prompt: prompt, expectJson: false)
        .timeout(const Duration(seconds: 25));
  }

  /// Sugiere el Outfit del Día (OOTD) en JSON estructurado usando IDs reales.
  Future<String?> suggestOutfitOfTheDayJson({
    required List<Map<String, dynamic>> garments,
    required String weatherContext,
    String? userProfileContext,
  }) async {
    final profileText =
        (userProfileContext != null && userProfileContext.isNotEmpty)
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
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
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
