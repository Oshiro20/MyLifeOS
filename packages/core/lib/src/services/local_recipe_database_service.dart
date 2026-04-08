import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:domain/domain.dart';
import 'package:uuid/uuid.dart';

/// Service to load local recipes from bundled JSON database.
/// Provides instant access to ~100+ Peruvian and international recipes.
class LocalRecipeDatabaseService {
  static const String _recipesPath =
      'packages/core/assets/recipes/local_recipes.json';
  static const _uuid = Uuid();

  List<Recipe>? _cachedRecipes;

  /// Loads all local recipes from JSON asset file.
  /// Results are cached for subsequent calls.
  Future<List<Recipe>> loadRecipes() async {
    if (_cachedRecipes != null) return _cachedRecipes!;

    try {
      final jsonString = await rootBundle.loadString(_recipesPath);
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;

      _cachedRecipes = jsonList.map((item) => _parseRecipe(item)).toList();
      return _cachedRecipes!;
    } catch (e) {
      return [];
    }
  }

  /// Searches local recipes by ingredient names.
  /// Returns recipes that contain any of the given ingredients.
  Future<List<Recipe>> searchByIngredients(
    List<String> ingredients, {
    int limit = 15,
  }) async {
    final allRecipes = await loadRecipes();
    if (ingredients.isEmpty) return allRecipes.take(limit).toList();

    final scored = <_RecipeScore>[];

    for (final recipe in allRecipes) {
      final recipeIngs =
          recipe.ingredients.map((i) => i.ingredientName.toLowerCase()).toSet();

      int matches = 0;
      for (final searchIng in ingredients) {
        final searchLower = searchIng.toLowerCase();
        if (recipeIngs.any((r) => r.contains(searchLower) || searchLower.contains(r))) {
          matches++;
        }
      }

      if (matches > 0) {
        scored.add(_RecipeScore(recipe: recipe, score: matches));
      }
    }

    // Sort by score (more matches first) and limit
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((s) => s.recipe).toList();
  }

  /// Searches local recipes by category/meal type.
  Future<List<Recipe>> searchByType(MealType type, {int limit = 15}) async {
    final allRecipes = await loadRecipes();
    return allRecipes
        .where((r) => r.tipoComida == type)
        .take(limit)
        .toList();
  }

  /// Searches local recipes by cuisine style.
  Future<List<Recipe>> searchByCuisine(String cuisine, {int limit = 15}) async {
    final allRecipes = await loadRecipes();
    return allRecipes
        .where((r) =>
            r.cuisineStyle?.toLowerCase().contains(cuisine.toLowerCase()) ??
            false)
        .take(limit)
        .toList();
  }

  /// Returns random recipes from local database.
  Future<List<Recipe>> getRandomRecipes({int limit = 10}) async {
    final allRecipes = await loadRecipes();
    final shuffled = List<Recipe>.from(allRecipes)..shuffle();
    return shuffled.take(limit).toList();
  }

  Recipe _parseRecipe(Map<String, dynamic> json) {
    final ingredients = <RecipeIngredient>[];
    final rawIngredients = json['ingredients'] as List<dynamic>? ?? [];

    for (int i = 0; i < rawIngredients.length; i++) {
      final item = rawIngredients[i] as Map<String, dynamic>;
      ingredients.add(RecipeIngredient(
        id: _uuid.v4(),
        recipeId: json['id'] as String,
        ingredientName: item['ingredientName'] as String? ?? 'Ingrediente',
        quantity: (item['quantity'] as num?)?.toDouble() ?? 1.0,
        unit: item['unit'] as String? ?? 'unidades',
      ));
    }

    MealType? mealType;
    final tipoComidaStr = json['tipoComida'] as String?;
    if (tipoComidaStr != null) {
      mealType = MealType.values.cast<MealType?>().firstWhere(
            (m) => m!.name == tipoComidaStr,
            orElse: () => null,
          );
    }

    return Recipe(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Receta',
      description: json['description'] as String? ?? '',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 30,
      servings: (json['servings'] as num?)?.toInt() ?? 4,
      ingredients: ingredients,
      instructions: (json['instructions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      tipoComida: mealType,
      cuisineStyle: json['cuisineStyle'] as String?,
      caloriasAproximadas: json['caloriasAproximadas'] as int?,
      createdAt: DateTime.now(),
      fuenteLabel: 'Base Local',
    );
  }
}

class _RecipeScore {
  final Recipe recipe;
  final int score;
  _RecipeScore({required this.recipe, required this.score});
}
