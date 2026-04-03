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
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      
      final name = decoded['name'] ?? 'Receta Importada';
      final description = decoded['description'] ?? '';
      final durationMinutes = decoded['durationMinutes'] as int? ?? 30;
      final servings = decoded['servings'] as int? ?? 2;
      
      final rawIngredients = decoded['ingredients'] as List<dynamic>? ?? [];
      final List<RecipeIngredient> ingredients = [];

      final recipeId = DateTime.now().millisecondsSinceEpoch.toString();

      for (int i = 0; i < rawIngredients.length; i++) {
        final item = rawIngredients[i] as Map<String, dynamic>;
        
        final ingName = item['ingredientName'] ?? 'Ingrediente \$i';
        final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
        final rawUnit = item['unit'] as String? ?? 'unidades';

        ingredients.add(RecipeIngredient(
          id: '\${recipeId}_ing_\$i',
          recipeId: recipeId,
          ingredientName: ingName,
          quantity: qty,
          unit: rawUnit, 
        ));
      }

      final rawInstructions = decoded['instructions'] as List<dynamic>? ?? [];
      final instructions = rawInstructions.map((e) => e.toString()).toList();

      final rawTags = decoded['tags'] as List<dynamic>? ?? [];
      final tags = rawTags.map((e) => e.toString()).toList();

      return Recipe(
        id: recipeId,
        name: name,
        description: description,
        durationMinutes: durationMinutes,
        servings: servings,
        instructions: instructions,
        ingredients: ingredients,
        tags: tags,
        createdAt: DateTime.now(),
      );

    } catch (e) {
      throw Exception('Error al parsear receta desde IA: \$e');
    }
  }
}
