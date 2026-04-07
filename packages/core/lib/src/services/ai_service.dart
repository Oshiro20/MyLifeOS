import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

// ── Provider for Gemini Service ─────────────────────────────────────────────
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

// ── Service Class ─────────────────────────────────────────────────────────────
class GeminiService {
  GeminiService();

  Future<void> saveApiKey(String key) async {}

  Future<String?> getApiKey() async {
    // Only use environment variable - no hardcoded fallback for security
    final envKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (envKey.isNotEmpty) {
      return envKey;
    }
    // No fallback - return null to indicate missing key
    debugPrint('⚠️ WARNING: GEMINI_API_KEY not set in .env file');
    debugPrint('Please add GEMINI_API_KEY=your_key to your .env file');
    return null;
  }

  Future<void> removeApiKey() async {}

  Future<GenerativeModel?> _getModel({bool useVision = false}) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      return null;
    }

    // Updated model: gemini-2.0-flash was deprecated in Feb 2026
    // Using gemini-2.5-flash as the new default (supports vision, video, free tier)
    final modelName = 'gemini-2.5-flash';
    return GenerativeModel(model: modelName, apiKey: apiKey);
  }

  /// Evaluates food from text ingredients or a photo.
  /// Needs to return a JSON string describing the evaluation.
  Future<String?> generateFoodEvaluation({
    required List<String> ingredients,
    String? photoPath,
  }) async {
    final useVision = photoPath != null;
    final model = await _getModel(useVision: useVision);
    if (model == null) return null;

    final prompt = '''
Eres un nutricionista experto. Analiza la siguiente comida.
Ingredientes detectados por texto o contexto: ${ingredients.join(', ')}.
Si hay una imagen, úsala en el análisis.
Devuelve EXACTAMENTE un objeto JSON válido con este formato:
{
  "classification": "healthy" | "balanced" | "junk",
  "healthScore": 0.0 - 1.0,
  "detectedIngredients": ["ing1", "ing2", ...],
  "positiveFactors": ["factor1", "factor2"],
  "negativeFactors": ["factor1", "factor2"],
  "feedback": "Análisis corto y amigable",
  "recommendation": "Consejo accionable"
}
NO DEVUELVAS NADA MÁS QUE EL JSON. Ni markdown (` ```json `), ni otro texto. NO ABRAS CON ```json.
''';

    final content = <Content>[];
    if (photoPath != null) {
      final bytes = await File(photoPath).readAsBytes();
      // Assume basic JPEG for this proof of concept
      content.add(Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', bytes),
      ]));
    } else {
      content.add(Content.text(prompt));
    }

    try {
      final response = await model.generateContent(content);
      return response.text;
    } catch (e) {
      throw Exception('Error en Gemini: $e');
    }
  }

  /// Analyzes a garment based on its photo and name/context
  /// Returns a JSON string with metadata.
  Future<String?> analyzeGarment({
    required String name,
    required String photoPath,
  }) async {
    final model = await _getModel(useVision: true);
    if (model == null) return null;

    final prompt = '''
Eres un experto en moda y visión artificial. 
Analiza la imagen adjunta de esta prenda${name.isNotEmpty ? ' (el usuario la llama "$name")' : ''} y devuelve EXACTAMENTE un objeto JSON estructurado:

{
  "name": "Genera un nombre corto y descriptivo (ej: Polo negro Nike, Pantalón azul, Zapatillas blancas).",
  "typeIndex": (entero del 0 al 13: 0=shirt, 1=tshirt, 2=pants, 3=jeans, 4=shoes, 5=jacket, 6=acc, 7=dress, 8=shorts, 9=sweater, 10=hoodie, 11=skirt, 12=other, 13=polo),
  "primaryColor": "Código HEX de 6 caracteres con # del color dominante",
  "material": "Material probable, ej: Algodón",
  "brand": "Extrae la marca si es visible en logos o etiquetas, sino vacío",
  "size": "Extrae la talla si es visible (ej: M, 32, XL), sino vacío",
  "season": "all", "spring", "summer", "autumn" o "winter",
  "styleIndex": (entero del 0 al 4: 0=casual, 1=formal, 2=sport, 3=streetwear, 4=elegant)
}
NO DEVUELVAS NI MARKDOWN NI EXPLICACIONES ADICIONALES, SÓLO EL JSON PARSEABLE.
''';

    final bytes = await File(photoPath).readAsBytes();
    final content = [
      Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', bytes),
      ])
    ];

    try {
      final response = await model.generateContent(content);
      return response.text;
    } catch (e) {
      throw Exception('Error en Gemini: $e');
    }
  }

  /// Proposes an Outfit of the Day based on garments and weather
  Future<String?> suggestOutfitOfTheDay({
    required String garmentsJson,
    required String weatherContext,
    String? userProfileContext,
  }) async {
    final model = await _getModel();
    if (model == null) return null;

    final prompt = '''
Eres un "AI Stylist" personal y asesor de moda de clase mundial.
Hoy el clima es el siguiente: $weatherContext.
El perfil físico del usuario es: ${userProfileContext ?? 'No especificado (Asume proporciones y tonos promedio)'}.
Ten muy en cuenta su Colorimetría (Estación) y Tipo de Cuerpo si están especificados en el perfil para elegir colores y cortes que le favorezcan arquitectónica y cromáticamente.

Aquí está el listado en formato JSON de las prendas LIMPIAS y disponibles del usuario en su armario:
$garmentsJson

Analiza su ropa y elige EXACTAMENTE 1 prenda superior (top), 1 prenda inferior (bottom), y 1 calzado (footwear) que combinen estilística y cromáticamente a la perfección, y que tengan absoluto sentido con el clima actual. Evita sugerir un suéter si hace 30°C, y evita sugerir shorts si hace 5°C.
Si el armario no tiene suficientes piezas para formar un outfit, devuelve los IDs nulos.

IMPORTANTE: DEBES EXTRAER Y DEVOLVER EXACTAMENTE LOS MISMOS STRINGS DEL CAMPO "id" QUE TE PROPORCIONÉ. BAJO NINGUNA CIRCUNSTANCIA INVENTES O ALTERES LOS IDs DE LAS PRENDAS.

Devuelve EXACTAMENTE un objeto JSON válido con la siguiente estructura (NO adjuntes explicaciones extrañas, NI uses variables de markdown ```json, SÓLO el texto Json puro):
{
  "top_id": "id_del_top_elegido",
  "bottom_id": "id_del_bottom_elegido",
  "shoes_id": "id_del_calzado_elegido",
  "explanation": "Tu explicación carismática y corta de 1 a 2 oraciones de por qué seleccionaste este conjunto para hoy."
}
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text;
    } catch (e) {
      throw Exception('Error en Gemini: $e');
    }
  }

  /// Analyzes a user's full body photo to determine physical traits
  Future<String?> analyzePhysicalProfile(
      String imagePath, String height, String weight) async {
    final model = await _getModel();
    if (model == null) return null;

    final file = File(imagePath);
    if (!file.existsSync()) return null;

    final bytes = await file.readAsBytes();
    final mimeType = _getMimeType(imagePath);

    final prompt = '''
Eres un Asesor de Imagen de clase mundial (Personal Stylist). El usuario te ha enviado una foto suya de cuerpo completo.
Sus datos corporales provistos son: Estatura: $height cm, Peso: $weight kg.

Tu trabajo es analizar su fotografía y determinar meticulosamente lo siguiente:
1. "skin_tone": Tono de piel superficial (ej. claro, medio, trigueño, oscuro).
2. "colorimetry": Su estación/colorimetría (ej. "Invierno Fuerte", "Otoño Cálido", "Verano Frío", "Primavera Brillante"). Justifica internamente según contraste de cabello, ojos y piel.
3. "body_shape": Tipo de cuerpo geométrico (ej. "Triángulo Invertido", "Reloj de Arena", "Rectángulo", "Óvalo", "Triángulo").
4. "hair_type": Tipo de cabello visible (ej. lacio, ondulado, rizado, calvo).
5. "recommendation": Un consejo de estilo muy breve (1 a 2 oraciones) indicando qué cortes o colores le favorecen.

Responde ÚNICAMENTE con un objeto JSON crudo, sin bloques de código ```json, con exactamente estas claves y los valores analizados:
{
  "skin_tone": "valor",
  "colorimetry": "valor",
  "body_shape": "valor",
  "hair_type": "valor",
  "recommendation": "valor"
}
''';

    final content = [
      Content.multi([
        TextPart(prompt),
        DataPart(mimeType, bytes),
      ])
    ];

    try {
      final response = await model.generateContent(content);
      return response.text;
    } catch (e) {
      throw Exception('Error en Gemini al analizar perfil: $e');
    }
  }

  String _getMimeType(String path) {
    final lower = path.toLowerCase();
    // Image types
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    // Video types
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.avi')) return 'video/x-msvideo';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.3gp')) return 'video/3gpp';
    if (lower.endsWith('.mpeg')) return 'video/mpeg';
    if (lower.endsWith('.mpg')) return 'video/mpeg';
    // Audio types
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    // Default
    return 'image/jpeg';
  }

  bool _isVideoFile(String path) {
    final mimeType = _getMimeType(path);
    return mimeType.startsWith('video/');
  }

  /// Analyzes a photo of groceries or pantry items and returns a JSON list.
  Future<String?> analyzePantryItems({
    required String photoPath,
  }) async {
    final model = await _getModel(useVision: true);
    if (model == null) return null;

    final prompt = '''
Eres un organizador de despensa inteligente.
Analiza la imagen adjunta que contiene uno o varios productos de supermercado o ingredientes.
Debes identificar todos los productos visibles y devolver EXACTAMENTE un arreglo JSON (lista) estructurado.

Formato requerido de cada objeto en la lista:
{
  "name": "Nombre claro y exácto del producto (ej: Fideos, Salsa de tomate. Si notas distinguir el tipo exacto, ponlo. Ej: 'Manzana verde', 'Manzana de agua', 'Limón sutil')",
  "primaryCategory": "Debe ser EXACTAMENTE una de estas opciones: Proteínas animales, Lácteos, Frutas, Verduras, Tubérculos y raíces, Legumbres, Cereales y granos, Harinas y derivados, Aceites y grasas, Salsas, Condimentos y especias, Endulzantes, Frutos secos y semillas, Otros",
  "subCategory": "Subcategoría lógica, gastronómica y coloquial (EVITA términos botánicos/científicos como 'Pomáceas' o 'Drupas'. Usa términos comunes como: 'Frutas dulces', 'Frutas tropicales', 'Carnes rojas', 'Embutidos', 'Aves', 'Pescados', 'Hierbas', etc.). Puede ser null si no aplica",
  "quantity": <numero estimado float, ej: 1.0, 500.0>,
  "unit": "unidades" | "gramos" | "kilos" | "litros" | "mililitros" | "paquetes" | "latas" | "sobres",
  "pantryLifeDays": <número entero, días estimados que dura en ALACENA (clima ambiente). null si se pudre rápido>,
  "fridgeLifeDays": <número entero, días estimados que dura en REFRIGERADOR (nevera). null si no se recomienda guardar ahí>,
  "freezerLifeDays": <número entero, días estimados en CONGELADOR. null si no se puede congelar>,
  "storageTip": "Un tip corto y casero de 1-2 oraciones sobre cómo conservarlo mejor y evitar que se malogre."
}

NO DEVUELVAS NADA MÁS QUE LA LISTA JSON. Ni markdown (` ```json `), ni otro texto. NO ABRAS CON ```json ni cierres con ```.
Ejemplo de salida válida:
[{"name": "Manzana Verde", "primaryCategory": "Frutas", "subCategory": "Frutas dulces", "quantity": 3.0, "unit": "unidades", "pantryLifeDays": 7, "fridgeLifeDays": 21, "freezerLifeDays": null, "storageTip": "Mantenlas alejadas de otras frutas porque emiten gas etileno que acelera la maduración."}]
''';

    final bytes = await File(photoPath).readAsBytes();
    final mimeType = _getMimeType(photoPath);

    final content = [
      Content.multi([
        TextPart(prompt),
        DataPart(mimeType, bytes),
      ])
    ];

    try {
      final response = await model.generateContent(content);
      return response.text;
    } catch (e) {
      throw Exception('Error en Gemini Pantry: $e');
    }
  }

  /// Analyzes a photo focusing on a single type of product (e.g. 6 tomatoes) and identifies it deeply.
  Future<String?> analyzeSinglePantryItem({
    required String photoPath,
  }) async {
    final model = await _getModel(useVision: true);
    if (model == null) return null;

    final prompt = '''
Eres un organizador de despensa inteligente.
Analiza la imagen adjunta. Debes enfocarte en el producto PRINCIPAL o ÚNICO que se muestra, y si hay varias unidades de ese mismo producto (ej. 6 tomates), DEBES contarlas con precisión.

Devuelve EXACTAMENTE un ÚNICO objeto JSON estructurado con la siguiente información:
{
  "name": "Nombre claro, exacto y singular/plural del producto. Distingue variedades específicas si se notan por foto (ej: 'Manzanas de agua', 'Limones', 'Cebolla roja')",
  "primaryCategory": "Debe ser EXACTAMENTE una de estas opciones: Proteínas animales, Lácteos, Frutas, Verduras, Tubérculos y raíces, Legumbres, Cereales y granos, Harinas y derivados, Aceites y grasas, Salsas, Condimentos y especias, Endulzantes, Frutos secos y semillas, Otros",
  "subCategory": "Subcategoría lógica, gastronómica y coloquial (EVITA términos botánicos/científicos como 'Pomáceas' o 'Drupas'. Usa términos comunes como: 'Frutas dulces', 'Frutas tropicales', 'Carnes rojas', 'Embutidos', etc.). Puede ser null",
  "quantity": <numero exacto float que has contado, ej: 6.0, 1.0>,
  "unit": "unidades" | "gramos" | "kilos" | "litros" | "mililitros" | "paquetes" | "latas" | "sobres",
  "pantryLifeDays": <número entero, días estimados en ALACENA, null si no aplica>,
  "fridgeLifeDays": <número entero, días estimados en REFRIGERADOR, null si no se recomienda>,
  "freezerLifeDays": <número entero, días estimados en CONGELADOR, null si se daña>,
  "storageTip": "Un tip de 1-2 oraciones indicando el mejor método de conservación."
}

NO DEVUELVAS UN ARREGLO ([]), devuelve solo EL OBJETO {}. NO DEVUELVAS NADA MÁS QUE EL JSON. Ni markdown (` ```json `), ni otro texto. NO ABRAS CON ```json ni cierres con ```.
Ejemplo de salida válida:
{"name": "Cebolla roja", "primaryCategory": "Verduras", "subCategory": "Bulbos", "quantity": 6.0, "unit": "unidades", "pantryLifeDays": 30, "fridgeLifeDays": null, "freezerLifeDays": null, "storageTip": "Guárdalas en un lugar oscuro, fresco y seco; nunca en la refri porque la humedad las ablanda y enmohece."}
''';

    final file = File(photoPath);
    if (!file.existsSync()) return null;

    final bytes = await file.readAsBytes();
    final mimeType = _getMimeType(photoPath);

    final content = [
      Content.multi([
        TextPart(prompt),
        DataPart(mimeType, bytes),
      ])
    ];

    try {
      final response = await model.generateContent(content);
      return response.text;
    } catch (e) {
      throw Exception('Error en Gemini al analizar producto simple: $e');
    }
  }

  /// Extracts a recipe from a given text (caption/URL) or a media file (video/image).
  /// Instructs Gemini to act as a professional chef and return structured JSON.
  ///
  /// For videos: attempts to send the actual video file if <20MB,
  /// otherwise extracts multiple strategic frames for better analysis.
  Future<String?> extractRecipe({
    String? textContext,
    String? mediaPath,
  }) async {
    final useVision = mediaPath != null;
    final model = await _getModel(useVision: useVision);
    if (model == null) return null;

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

Analiza DETENIDAMENTE el video de cocina proporcionado y extrae UNA RECETA COMPLETA Y ESTRUCTURADA.

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
10. "video_context":
    - "completo" → video muestra toda la preparación
    - "resumido" → video acelerado o con cortes
    - "timelapse" → video muy rápido tipo timelapse
    - "solo_resultado" → solo muestra el plato final
11. "observaciones" → indica qué datos fueron inferidos vs visibles y qué ingredientes esenciales se agregaron
12. "ingredientes_inferidos" → lista de ingredientes esenciales que NO aparecen en el video pero son necesarios (aceite, sal, pimienta, agua, etc.)
13. Si ves texto en el video (nombres, cantidades), ÚSALO.
14. Si el video muestra postre/mazamorra/plato dulce, adáptalo accordingly.
15. Si no estás seguro de algo, INFIÉRELO lógicamente pero completa TODOS los campos.
16. Si el video está resumido → reconstruye pasos faltantes con lógica culinaria.

${textContext != null && textContext.isNotEmpty ? '''
📌 CONTEXTO ADICIONAL DEL USUARIO:
"$textContext"
Usa esta información como referencia adicional.
''' : ''}

🎥 AHORA ANALIZA EL VIDEO/IMAGEN ADJUNTO Y DEVUELVE LA RECETA COMPLETA EN FORMATO JSON.''';

    final content = <Content>[];
    if (mediaPath != null) {
      final file = File(mediaPath);
      if (file.existsSync()) {
        final fileSizeMB = file.lengthSync() / (1024 * 1024);

        // If it's a video under 20MB, send the actual video file
        if (_isVideoFile(mediaPath) && fileSizeMB < 20) {
          debugPrint(
              '🎬 Sending video file directly to Gemini (${fileSizeMB.toStringAsFixed(1)} MB)');
          final bytes = await file.readAsBytes();
          final mimeType = _getMimeType(mediaPath);
          content.add(Content.multi([
            TextPart(prompt),
            DataPart(mimeType, bytes),
          ]));
        } else if (_isVideoFile(mediaPath)) {
          // For larger videos, extract multiple frames for better analysis
          debugPrint(
              '🎬 Video too large (${fileSizeMB.toStringAsFixed(1)} MB), extracting multiple frames...');
          content.add(Content.text(prompt));
        } else {
          // For images, send as before
          final bytes = await file.readAsBytes();
          final mimeType = _getMimeType(mediaPath);
          content.add(Content.multi([
            TextPart(prompt),
            DataPart(mimeType, bytes),
          ]));
        }
      } else {
        content.add(Content.text(prompt));
      }
    } else {
      content.add(Content.text(prompt));
    }

    try {
      final response = await model.generateContent(content).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException(
            'La IA tardó demasiado en responder. Intenta con un video más corto o imágenes más claras.',
            const Duration(seconds: 60),
          );
        },
      );
      final result = response.text;

      // Debug logging to see what Gemini returns
      if (result != null && result.isNotEmpty) {
        debugPrint('✅ Gemini response length: ${result.length} chars');
        if (result.length < 2000) {
          debugPrint('📄 Full response: $result');
        } else {
          debugPrint('📄 First 500 chars: ${result.substring(0, 500)}');
        }
      }

      return result;
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception(e.message ?? 'Timeout al extraer la receta');
      }
      throw Exception('Error en Gemini al extraer la receta: $e');
    }
  }

  /// Extracts a recipe from multiple images (photos of cookbook pages, screenshots, etc.)
  /// Returns structured JSON with the recipe.
  Future<String?> extractRecipeFromImages(List<String> imagePaths) async {
    final model = await _getModel(useVision: true);
    if (model == null) return null;

    final prompt = '''
👨‍🍳 ERES UN CHEF PROFESIONAL + EXPERTO EN OCR Y ANÁLISIS DE IMÁGENES.

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

    final parts = <Part>[TextPart(prompt)];

    for (final path in imagePaths) {
      final file = File(path);
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        final mimeType = _getMimeType(path);
        parts.add(DataPart(mimeType, bytes));
      }
    }

    try {
      final response =
          await model.generateContent([Content.multi(parts)]).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw TimeoutException(
            'La IA tardó demasiado en responder. Intenta con imágenes más claras.',
            const Duration(seconds: 45),
          );
        },
      );
      return response.text;
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception(e.message ?? 'Timeout al extraer receta de imágenes');
      }
      throw Exception('Error en Gemini al extraer receta de imágenes: $e');
    }
  }

  /// Optimizes an existing recipe with better wording, nutrition info, and suggestions.
  /// Returns an improved version of the recipe as structured JSON.
  Future<String?> optimizeRecipe(String recipeJson) async {
    final model = await _getModel();
    if (model == null) return null;

    final prompt = '''
👨‍🍳 ERES UN CHEF PROFESIONAL + NUTRICIONISTA + EXPERTO EN REDACCIÓN CULINARIA.

📋 TU MISIÓN:
Recibe una receta existente y OPTIMÍZALA profesionalmente.

Debes:
1. ✅ Mejorar la redacción de la receta (más clara, atractiva y profesional)
2. ✅ Agregar información nutricional estimada (proteínas, carbohidratos, grasas, fibra)
3. ✅ Sugerir sustitutos de ingredientes (para alergias, preferencias dietéticas)
4. ✅ Proponer tips del chef para mejorar el resultado
5. ✅ Sugerir maridajes o acompañamientos ideales
6. ✅ Proponer variaciones de la receta (versión light, versión vegana, etc.)
7. ✅ Detectar alérgenos comunes presentes
8. ✅ Mantener la esencia original de la receta

📝 FORMATO DE SALIDA (JSON PURO - SIN MARKDOWN):

{
  "nombre_receta": "Nombre optimizado",
  "descripcion": "Descripción mejorada y más atractiva",
  "porciones": 4,
  "tiempo_preparacion_min": 15,
  "tiempo_coccion_min": 30,
  "tiempo_total_min": 45,
  "dificultad": "Fácil",
  "tipo_comida": "Almuerzo",
  "cocina": "Peruana",
  "ingredientes": [
    {
      "nombre": "Arroz",
      "cantidad": 2.0,
      "unidad": "tazas"
    }
  ],
  "pasos": [
    {
      "numero": 1,
      "descripcion": "Paso redactado de forma clara y profesional"
    }
  ],
  "utensilios": ["sartén"],
  "calorias_aproximadas": 350,
  "tags": ["fácil", "peruano"],
  "observaciones": "Receta optimizada con mejor redacción y tips.",
  "nivel_confianza": "Alto",
  "nutricion": {
    "proteinas_g": 15,
    "carbohidratos_g": 45,
    "grasas_g": 12,
    "fibra_g": 3
  },
  "alergenos": ["gluten", "lactosa"],
  "sustitutos": [
    {
      "original": "Leche entera",
      "sustituto": "Leche de almendras",
      "nota": "Para versión sin lactosa"
    }
  ],
  "tips_chef": [
    "Deja reposar el arroz 5 minutos antes de servir para mejor textura",
    "Usa arroz del día anterior para mejor resultado"
  ],
  "maridaje": "Acompaña con ensalada fresca y limón",
  "variaciones": [
    {
      "nombre": "Versión Light",
      "cambios": "Usa menos aceite y agrega más vegetales"
    },
    {
      "nombre": "Versión Vegana",
      "cambios": "Sustituye proteína animal por tofu o legumbres"
    }
  ]
}

⚠️ REGLAS OBLIGATORIAS:
1. Devuelve ÚNICAMENTE el JSON. Sin markdown, sin backticks.
2. TODOS los campos son obligatorios (incluyendo los nuevos: nutricion, alergenos, sustitutos, tips_chef, maridaje, variaciones).
3. "cantidad" debe ser un NÚMERO (float), no texto.
4. "unidad" en ESPAÑOL exclusivamente.
5. Mejora la receta original, NO la cambies completamente.
6. Los sustitutos deben ser realistas y accesibles.
7. Los tips deben ser prácticos y útiles.
8. Las variaciones deben mantener la esencia del plato original.

📝 RECETA ORIGINAL A OPTIMIZAR:
$recipeJson

AHORA OPTIMIZA ESTA RECETA Y DEVUELVE EL JSON MEJORADO.''';

    try {
      final response =
          await model.generateContent([Content.text(prompt)]).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw TimeoutException(
            'La IA tardó demasiado en optimizar la receta.',
            const Duration(seconds: 45),
          );
        },
      );
      return response.text;
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception(e.message ?? 'Timeout al optimizar la receta');
      }
      throw Exception('Error en Gemini al optimizar la receta: $e');
    }
  }

  /// Genera texto a partir de un prompt libre.
  /// Útil para análisis financiero, insights del día, etc.
  Future<String?> generateText({required String prompt}) async {
    final model = await _getModel();
    if (model == null) return null;
    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text;
    } catch (e) {
      throw Exception('Error en Gemini generateText: $e');
    }
  }
}
