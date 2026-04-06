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
  }) async {
    if (inventory.isEmpty) {
      throw Exception('No tienes ingredientes en tu inventario. Agrega algunos primero.');
    }

    // Build inventory description for AI
    final inventoryDescription = inventory.map((item) {
      return '- ${item.name}: ${item.quantity} ${item.unit}${item.preparation.isNotEmpty ? ' (${item.preparation})' : ''}';
    }).join('\n');

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

🍳 AHORA SUGIERE LAS RECETAS BASADO EN EL INVENTARIO DEL USUARIO.''';

    try {
      final jsonString = await aiExtractor.extractRecipeJson(
        textContext: prompt,
        mediaPath: null,
      );

      if (jsonString == null || jsonString.isEmpty) {
        throw Exception('La IA no pudo generar sugerencias');
      }

      // Clean markdown if present
      String cleanJson = jsonString.trim();
      if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
      }

      final decoded = jsonDecode(cleanJson) as List<dynamic>;
      final suggestions = <RecipeSuggestion>[];

      for (final recipeData in decoded) {
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
        final rawIngredients = recipeData['ingredientes'] as List<dynamic>? ?? [];

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
}

/// Represents a recipe suggestion with match information
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
