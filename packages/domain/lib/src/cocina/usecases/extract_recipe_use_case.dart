import 'dart:convert';
import '../entities/recipe.dart';
import '../repositories/i_ai_recipe_extractor.dart';

class ExtractRecipeUseCase {
  final IAIRecipeExtractor aiExtractor;

  ExtractRecipeUseCase(this.aiExtractor);

  Future<Recipe?> execute({String? textContext, String? mediaPath}) async {
    final jsonString = await aiExtractor.extractRecipeJson(
      textContext: textContext,
      mediaPath: mediaPath,
    );

    if (jsonString == null || jsonString.isEmpty) return null;

    try {
      // Clean markdown if present
      String cleanJson = jsonString.trim();
      if (cleanJson.startsWith('```')) {
        cleanJson =
            cleanJson.replaceAll('```json', '').replaceAll('```', '').trim();
      }

      final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;

      // Support BOTH old and new JSON formats
      final name =
          decoded['name'] ?? decoded['nombre_receta'] ?? 'Receta Importada';
      final description =
          decoded['description'] ?? decoded['descripcion'] ?? '';

      // Support both formats for time
      int durationMinutes;
      if (decoded['durationMinutes'] != null) {
        durationMinutes = decoded['durationMinutes'] as int;
      } else if (decoded['tiempo_total_min'] != null) {
        durationMinutes = decoded['tiempo_total_min'] as int;
      } else {
        durationMinutes = 30;
      }

      // Support both formats for servings
      final servings = decoded['servings'] ?? decoded['porciones'];
      final servingsInt =
          servings is int ? servings : (servings is num ? servings.toInt() : 2);

      // Support both ingredient formats
      List<dynamic> rawIngredients = [];
      if (decoded['ingredients'] != null) {
        rawIngredients = decoded['ingredients'] as List<dynamic>;
      } else if (decoded['ingredientes'] != null) {
        rawIngredients = decoded['ingredientes'] as List<dynamic>;
      }

      final List<RecipeIngredient> ingredients = [];
      final recipeId = DateTime.now().millisecondsSinceEpoch.toString();

      for (int i = 0; i < rawIngredients.length; i++) {
        final item = rawIngredients[i] as Map<String, dynamic>;

        // Support both ingredient field names
        final ingName =
            item['ingredientName'] ?? item['nombre'] ?? 'Ingrediente $i';

        // Support both quantity formats (number or string)
        double qty;
        final rawQty = item['quantity'] ?? item['cantidad'];
        if (rawQty is num) {
          qty = rawQty.toDouble();
        } else if (rawQty is String) {
          qty = double.tryParse(rawQty) ?? 1.0;
        } else {
          qty = 1.0;
        }

        final rawUnit = item['unit'] ?? item['unidad'] ?? 'unidades';

        ingredients.add(RecipeIngredient(
          id: '${recipeId}_ing_$i',
          recipeId: recipeId,
          ingredientName: ingName,
          quantity: qty,
          unit: rawUnit,
        ));
      }

      // Support both instruction formats
      List<dynamic> rawInstructions = [];
      if (decoded['instructions'] != null) {
        rawInstructions = decoded['instructions'] as List<dynamic>;
      } else if (decoded['pasos'] != null) {
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

      // VALIDATION AUTOMÁTICA: Verificar que la receta tenga contenido mínimo
      if (rawIngredients.length < 2) {
        print('⚠️ Validation: Less than 2 ingredients detected');
      }
      if (rawInstructions.length < 3) {
        print('⚠️ Validation: Less than 3 steps detected');
      }

      final instructions = rawInstructions.map((e) => e.toString()).toList();

      // Support both tag formats
      final rawTags = decoded['tags'] as List<dynamic>? ?? [];
      final tags = rawTags.map((e) => e.toString()).toList();

      return Recipe(
        id: recipeId,
        name: name,
        description: description,
        durationMinutes: durationMinutes,
        servings: servingsInt,
        instructions: instructions,
        ingredients: ingredients,
        tags: tags,
        createdAt: DateTime.now(),
      );
    } catch (e, stackTrace) {
      print('❌ Error parsing recipe JSON: $e');
      print(
          '📄 Raw JSON was: ${jsonString.substring(0, jsonString.length > 500 ? 500 : jsonString.length)}...');
      print('📋 Stack trace: $stackTrace');
      throw Exception('Error al parsear receta desde IA: $e');
    }
  }
}
