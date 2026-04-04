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
    // Primero intentar con variable de entorno
    final envKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (envKey.isNotEmpty) {
      return envKey;
    }
    // Fallback a hardcode (solo para desarrollo)
    debugPrint('⚠️ WARNING: GEMINI_API_KEY not set in .env file');
    return 'AIzaSyDxCMDUQMKg4Y3GcUV872rG85NvgUS0xS8';
  }

  Future<void> removeApiKey() async {}

  Future<GenerativeModel?> _getModel({bool useVision = false}) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      return null;
    }

    // Choose model based on requirements
    final modelName = 'gemini-flash-latest';
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
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
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
  /// Instructs Gemini to act as a chef and return a structured JSON representing the Recipe.
  Future<String?> extractRecipe({
    String? textContext,
    String? mediaPath,
  }) async {
    final useVision = mediaPath != null;
    final model = await _getModel(useVision: useVision);
    if (model == null) return null;

    final prompt = '''
Eres un chef experto y analista gastronómico. Tu objetivo es extraer la receta exacta que se muestra o se describe en el contenido proporcionado.
Extrae la receta y devuélvela EXACTAMENTE como un objeto JSON estructurado, sin usar Markdown ni backticks (```json).

El formato del JSON debe ser rigurosamente el siguiente:
{
  "name": "Nombre descriptivo de la receta",
  "description": "Una breve descripción de 1 a 2 oraciones de la receta y qué la hace especial.",
  "durationMinutes": <entero estimado de minutos totales de preparación y cocción, ej: 45>,
  "servings": <entero estimado de porciones, asume 2 si no es claro>,
  "ingredients": [
    {
      "ingredientName": "Nombre claro del ingrediente (ej. Pollo, Cebolla, Sal)",
      "quantity": <número flotante, ej. 1.0, 500.0, 0.5. Si dicen "una pizca", pon 1.0>,
      "unit": "unidades" | "gramos" | "kilos" | "litros" | "mililitros" | "tazas" | "cucharadas" | "cucharaditas" | "pizca" | "al gusto"
    }
  ],
  "instructions": [
    "Paso 1 preciso...",
    "Paso 2 preciso...",
    "Paso 3 preciso..."
  ],
  "tags": ["Fácil", "Desayuno", "Vegetariano"] // 2 a 4 tags relevantes
}

Instrucciones adicionales:
1. Si falta información como el tiempo o porciones, infiérelos con sentido común.
2. Si el texto o video está en otro idioma, TRADÚCELO todo al ESPAÑOL en tu respuesta JSON.
3. Si la orden no tiene ninguna referencia a una receta o ingredientes, devuelve el JSON con valores por defecto pero con "description" indicando "No se detectó una receta válida".
${textContext != null && textContext.isNotEmpty ? '\nEl usuario ha proporcionado el siguiente texto o enlace como contexto inicial:\n"$textContext"' : ''}
''';

    final content = <Content>[];
    if (mediaPath != null) {
      final file = File(mediaPath);
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        final mimeType = _getMimeType(mediaPath);
        // Gemini supports video/mp4, image/jpeg, etc.
        content.add(Content.multi([
          TextPart(prompt),
          DataPart(mimeType, bytes),
        ]));
      } else {
        content.add(Content.text(prompt));
      }
    } else {
      content.add(Content.text(prompt));
    }

    try {
      final response = await model.generateContent(content);
      return response.text;
    } catch (e) {
      throw Exception('Error en Gemini al extraer la receta: $e');
    }
  }

  /// Genera texto a partir de un prompt libre.
  /// Útil para análisis financiero, insights del día, etc.
  Future<String?> generateText({required String prompt}) async {
    final model = await _getModel();
    if (model == null) return null;
    try {
      final response =
          await model.generateContent([Content.text(prompt)]);
      return response.text;
    } catch (e) {
      throw Exception('Error en Gemini generateText: $e');
    }
  }
}
