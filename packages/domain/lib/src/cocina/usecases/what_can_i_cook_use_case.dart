import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../entities/inventory_ingredient.dart';
import '../entities/recipe.dart';
import '../repositories/i_ai_recipe_extractor.dart';

/// Use case that uses Gemini AI to suggest recipes based on available inventory
/// Returns a list of recipe suggestions with full details
class WhatCanICookUseCase {
  final IAIRecipeExtractor aiExtractor;

  WhatCanICookUseCase(this.aiExtractor);

  Future<List<RecipeSuggestion>> execute({
    required List<InventoryIngredient> inventory,
    int maxSuggestions = 5,
    List<String>? dislikedIngredients,
  }) async {
    if (inventory.isEmpty) {
      throw Exception(
          'No tienes ingredientes en tu inventario. Agrega algunos primero.');
    }

    // Build inventory description for AI
    final inventoryDescription = inventory.map((item) {
      return '- ${item.name}: ${item.quantity} ${item.unit}${item.preparation.isNotEmpty ? ' (${item.preparation})' : ''}';
    }).join('\n');

    // Build disliked ingredients warning
    String dislikedWarning = '';
    if (dislikedIngredients != null && dislikedIngredients.isNotEmpty) {
      dislikedWarning = '''
⛔ INGREDIENTES QUE EL USUARIO NO LE GUSTAN (NO USAR EN LAS RECETAS):
${dislikedIngredients.map((e) => '- $e').join('\n')}

Si una receta normalmente usa estos ingredientes, SUSTITUYELOS por algo similar que el usuario sí quiera.
Ejemplo: si no le gusta la cebolla, usa cebollín o ajo en su lugar.
''';
    }

    final prompt = '''
👨‍🍳 ERES UN CHEF PROFESIONAL ESPECIALIZADO EN COCINA DE APROVECHAMIENTO.

📋 TU MISIÓN:
El usuario tiene estos ingredientes disponibles en su cocina/inventario:

$inventoryDescription

Basándote en estos ingredientes, sugiere $maxSuggestions recetas REALISTAS y ATRACTIVAS que pueda cocinar AHORA MISMO.

🔍 REGLAS IMPORTANTES:
1. Usa SOLAMENTE los ingredientes disponibles (o la mayoría de ellos)
2. Puedes sugerir ingredientes adicionales mínimos que todo mundo tiene (aceite, sal, pimienta, agua)
3. Cada receta debe ser diferente y creativa
4. Prioriza recetas que usen ingredientes que están por vencer
5. Sé específico con cantidades y pasos

📝 FORMATO DE SALIDA (JSON PURO - SIN MARKDOWN):

[
  {
    "nombre_receta": "Nombre del plato",
    "descripcion": "Descripción atractiva de 2-3 oraciones",
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
    "ingredientes_inferidos": ["aceite", "sal"],
    "pasos": [
      {"numero": 1, "descripcion": "Paso detallado"}
    ],
    "utensilios": ["olla", "cuchara"],
    "calorias_aproximadas": 350,
    "tags": ["fácil", "peruano"],
    "ingredientes_disponibles": 8,
    "ingredientes_totales": 10,
    "nivel_confianza": "Alto",
    "observaciones": "Puedes cocinar esto ahora con lo que tienes"
  }
]

⚠️ REGLAS OBLIGATORIAS:
1. Devuelve ÚNICAMENTE el array JSON. Sin markdown, sin backticks.
2. TODOS los campos son obligatorios en cada receta.
3. "cantidad" debe ser NÚMERO (float).
4. "unidad" en ESPAÑOL.
5. "ingredientes_disponibles": cuántos ingredientes de la receta están en el inventario
6. "ingredientes_totales": total de ingredientes en la receta
7. Mínimo 3 ingredientes, 3 pasos por receta.
8. "tiempo_total_min" realista: 15-180 minutos.
9. "porciones" entero: 1-12.
10. NO uses ingredientes que el usuario no le gustan. Si son esenciales, sustitúyelos.

${dislikedWarning.isNotEmpty ? dislikedWarning : ''}

🍳 AHORA SUGIERE LAS RECETAS BASADO EN EL INVENTARIO DEL USUARIO.''';

    try {
      final jsonString = await aiExtractor.extractRecipeJson(
        textContext: prompt,
        mediaPath: null,
      );

      if (jsonString == null || jsonString.isEmpty) {
        throw Exception('La IA no pudo generar sugerencias');
      }

      // Debug: log raw response
      debugPrint('📄 WhatCanICook raw response (${jsonString.length} chars)');
      if (jsonString.length < 1000) {
        debugPrint('📄 Full: $jsonString');
      } else {
        debugPrint('📄 First 1000: ${jsonString.substring(0, 1000)}');
      }

      // Try multiple extraction strategies in order of preference
      dynamic decoded;
      List<String> extractionAttempts = [
        _extractJsonFromResponse(jsonString, expectList: true),
        _aggressiveJsonClean(jsonString),
        _bruteForceJsonExtract(jsonString),
      ];

      bool parseSuccess = false;
      for (int i = 0; i < extractionAttempts.length; i++) {
        final attempt = extractionAttempts[i];
        if (attempt.isEmpty || attempt.length < 2) continue;

        debugPrint(
            '🧹 Attempt ${i + 1} (${attempt.length} chars): ${attempt.substring(0, attempt.length > 100 ? 100 : attempt.length)}');
        try {
          decoded = jsonDecode(attempt);
          debugPrint('✅ Parse succeeded on attempt ${i + 1}');
          parseSuccess = true;
          break;
        } catch (e) {
          debugPrint('❌ Attempt ${i + 1} failed: $e');
        }
      }

      if (!parseSuccess) {
        throw Exception(
          'La IA devolvió un formato inválido. Intenta de nuevo.\n\n'
          'Tip: Asegúrate de tener al menos 3-5 ingredientes en tu despensa para mejores resultados.',
        );
      }

      // Handle both List and single Map (wrap in list if single)
      List<dynamic> recipeList;
      if (decoded is List) {
        recipeList = decoded;
      } else if (decoded is Map<String, dynamic>) {
        debugPrint('⚠️ Gemini returned a single object, wrapping in list');
        recipeList = [decoded];
      } else {
        throw Exception(
          'Formato inesperado de la IA (tipo: ${decoded.runtimeType}). '
          'Intenta de nuevo.',
        );
      }

      if (recipeList.isEmpty) {
        throw Exception(
            'La IA no encontró recetas con tus ingredientes actuales.');
      }

      final suggestions = <RecipeSuggestion>[];

      for (final recipeData in recipeList) {
        if (recipeData is! Map<String, dynamic>) continue;

        final name = recipeData['nombre_receta'] as String? ?? 'Receta';
        final description = recipeData['descripcion'] as String? ?? '';
        final tiempoTotal = recipeData['tiempo_total_min'] as int? ?? 30;
        final porciones = recipeData['porciones'] as int? ?? 2;
        final ingredientesDisponibles =
            recipeData['ingredientes_disponibles'] as int? ?? 0;
        final ingredientesTotales =
            recipeData['ingredientes_totales'] as int? ?? 0;

        // Parse ingredients
        final ingredients = <RecipeIngredient>[];
        final recipeId = DateTime.now().millisecondsSinceEpoch.toString();
        final rawIngredients =
            recipeData['ingredientes'] as List<dynamic>? ?? [];

        for (int i = 0; i < rawIngredients.length; i++) {
          final item = rawIngredients[i] as Map<String, dynamic>;
          final ingName = item['nombre'] as String? ?? 'Ingrediente $i';
          final rawQty = item['cantidad'];
          final qty = rawQty is num
              ? rawQty.toDouble()
              : (rawQty is String ? double.tryParse(rawQty) ?? 1.0 : 1.0);
          final unit = item['unidad'] as String? ?? 'unidades';

          ingredients.add(RecipeIngredient(
            id: '${recipeId}_ing_$i',
            recipeId: recipeId,
            ingredientName: ingName,
            quantity: qty,
            unit: unit,
          ));
        }

        // Parse steps
        final steps = <String>[];
        final rawSteps = recipeData['pasos'] as List<dynamic>? ?? [];
        final sortedSteps = List<Map<String, dynamic>>.from(rawSteps)
          ..sort((a, b) {
            final numA = a['numero'] as int? ?? 0;
            final numB = b['numero'] as int? ?? 0;
            return numA.compareTo(numB);
          });

        for (final step in sortedSteps) {
          steps.add(step['descripcion'] as String? ?? '');
        }

        // Parse tags
        final rawTags = recipeData['tags'] as List<dynamic>? ?? [];
        final tags = rawTags.map((e) => e.toString()).toList();

        // Parse additional fields
        final utensilios = (recipeData['utensilios'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final ingredientesInferidos =
            (recipeData['ingredientes_inferidos'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
        final caloriasAproximadas = recipeData['calorias_aproximadas'] as int?;

        final recipe = Recipe(
          id: recipeId,
          name: name,
          description: description,
          durationMinutes: tiempoTotal,
          servings: porciones,
          instructions: steps,
          ingredients: ingredients,
          tags: tags,
          createdAt: DateTime.now(),
          utensilios: utensilios,
          ingredientesInferidos: ingredientesInferidos,
          caloriasAproximadas: caloriasAproximadas,
        );

        suggestions.add(RecipeSuggestion(
          recipe: recipe,
          matchPercentage: ingredientesTotales > 0
              ? ((ingredientesDisponibles / ingredientesTotales) * 100).round()
              : 0,
          missingIngredients: ingredientesTotales - ingredientesDisponibles,
        ));
      }

      return suggestions;
    } catch (e, stackTrace) {
      debugPrint('❌ Error in WhatCanICookUseCase: $e');
      debugPrint('📋 Stack trace: $stackTrace');
      throw Exception('Error al generar sugerencias con IA: $e');
    }
  }

  /// Robustly extracts JSON from a response string
  String _extractJsonFromResponse(String response, {bool expectList = false}) {
    String text = response.trim();

    if (text.contains('```')) {
      text = text.replaceAll(RegExp(r'^```json\s*', multiLine: true), '');
      text = text.replaceAll(RegExp(r'^```\s*', multiLine: true), '');
      text = text.replaceAll(RegExp(r'\s*```$', multiLine: true), '');
    }

    // If we expect a list, look for brackets first
    if (expectList) {
      final firstBracket = text.indexOf('[');
      final lastBracket = text.lastIndexOf(']');

      if (firstBracket != -1 &&
          lastBracket != -1 &&
          lastBracket > firstBracket) {
        return text.substring(firstBracket, lastBracket + 1);
      }
    }

    // Fallback to braces (object)
    final firstBrace = text.indexOf('{');
    final lastBrace = text.lastIndexOf('}');

    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      return text.substring(firstBrace, lastBrace + 1);
    }

    // Last resort: try brackets anyway
    final firstBracket = text.indexOf('[');
    final lastBracket = text.lastIndexOf(']');

    if (firstBracket != -1 && lastBracket != -1 && lastBracket > firstBracket) {
      return text.substring(firstBracket, lastBracket + 1);
    }

    return text;
  }

  /// Aggressive JSON cleaning for when normal extraction fails
  String _aggressiveJsonClean(String response) {
    String text = response.trim();

    // Remove ALL markdown code blocks completely
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    text = text.replaceAll(RegExp(r'```json\s*'), '');
    text = text.replaceAll(RegExp(r'```\s*'), '');

    // Find the first [ and last ] that could be a valid JSON array
    final firstBracket = text.indexOf('[');
    final lastBracket = text.lastIndexOf(']');

    if (firstBracket != -1 && lastBracket != -1 && lastBracket > firstBracket) {
      var candidate = text.substring(firstBracket, lastBracket + 1);
      // Remove any trailing text after ]
      final trailingNewline = candidate.indexOf('\n]');
      if (trailingNewline != -1) {
        candidate = candidate.substring(0, candidate.lastIndexOf(']') + 1);
      }
      return candidate;
    }

    // Try braces as fallback
    final firstBrace = text.indexOf('{');
    final lastBrace = text.lastIndexOf('}');

    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      return text.substring(firstBrace, lastBrace + 1);
    }

    return text;
  }

  /// Brute force: finds the outermost matching bracket/brace pair
  String _bruteForceJsonExtract(String text) {
    // Remove markdown
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    text = text.replaceAll(RegExp(r'```json\s*'), '');
    text = text.replaceAll(RegExp(r'```\s*'), '');

    // Try to find matching brackets for arrays
    for (int start = 0; start < text.length; start++) {
      if (text[start] == '[') {
        int depth = 0;
        bool inString = false;
        bool escaped = false;
        for (int end = start; end < text.length; end++) {
          final char = text[end];
          if (escaped) {
            escaped = false;
            continue;
          }
          if (char == '\\') {
            escaped = true;
            continue;
          }
          if (char == '"') {
            inString = !inString;
            continue;
          }
          if (inString) continue;
          if (char == '[') depth++;
          if (char == ']') {
            depth--;
            if (depth == 0) {
              return text.substring(start, end + 1);
            }
          }
        }
      }
    }

    // Try to find matching braces for objects
    for (int start = 0; start < text.length; start++) {
      if (text[start] == '{') {
        int depth = 0;
        bool inString = false;
        bool escaped = false;
        for (int end = start; end < text.length; end++) {
          final char = text[end];
          if (escaped) {
            escaped = false;
            continue;
          }
          if (char == '\\') {
            escaped = true;
            continue;
          }
          if (char == '"') {
            inString = !inString;
            continue;
          }
          if (inString) continue;
          if (char == '{') depth++;
          if (char == '}') {
            depth--;
            if (depth == 0) {
              return text.substring(start, end + 1);
            }
          }
        }
      }
    }

    return text;
  }
}

class RecipeSuggestion {
  final Recipe recipe;
  final int matchPercentage; // 0-100
  final int missingIngredients;

  const RecipeSuggestion({
    required this.recipe,
    required this.matchPercentage,
    required this.missingIngredients,
  });
}
