import 'package:domain/domain.dart';
import '../services/the_meal_db_service.dart';

/// Hybrid Use Case:
/// 1. Searches local DB for recipes matching inventory.
/// 2. If not enough, fetches from TheMealDB API.
/// 3. Sorts by match percentage.
class HybridSuggestionUseCase {
  final ICocinaRepository repository;
  final TheMealDBService apiService;

  HybridSuggestionUseCase({
    required this.repository,
    required this.apiService,
  });

  Future<List<RecipeSuggestion>> execute({
    required List<InventoryIngredient> inventory,
    int limit = 10,
    double minMatchPercentage = 0.50, // 50% match minimum
  }) async {
    final suggestions = <RecipeSuggestion>[];

    // 1. Search Local DB (Instant)
    final localSuggestions = await repository.suggestRecipes(
      inventory: inventory,
      limit: limit,
    );

    for (final recipe in localSuggestions) {
      final match = _calculateMatch(recipe, inventory);
      if (match >= minMatchPercentage) {
        suggestions.add(RecipeSuggestion(
          recipe: recipe,
          matchPercentage: (match * 100).round(),
          missingIngredients: recipe.ingredients.length - 
              recipe.ingredients.where((i) => _hasInInventory(i, inventory)).length,
        ));
      }
    }

    // 2. If not enough results, fetch from API (Fast ~1s)
    if (suggestions.length < limit) {
      final remainingSlots = limit - suggestions.length;
      
      // Pick a key ingredient to search for
      final keyIngredient = inventory.isNotEmpty 
          ? inventory.first.name 
          : 'chicken';
          
      final apiRecipes = await apiService.searchByIngredient(keyIngredient);
      
      for (final recipe in apiRecipes.take(remainingSlots)) {
        final match = _calculateMatch(recipe, inventory);
        if (match >= minMatchPercentage) {
          // Check for duplicates
          if (!suggestions.any((s) => s.recipe.name == recipe.name)) {
            suggestions.add(RecipeSuggestion(
              recipe: recipe,
              matchPercentage: (match * 100).round(),
              missingIngredients: recipe.ingredients.length - 
                  recipe.ingredients.where((i) => _hasInInventory(i, inventory)).length,
            ));
          }
        }
      }
    }

    // 3. Sort by match percentage
    suggestions.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));

    return suggestions;
  }

  double _calculateMatch(Recipe recipe, List<InventoryIngredient> inventory) {
    if (recipe.ingredients.isEmpty) return 0.0;
    int matched = recipe.ingredients.where((ing) => _hasInInventory(ing, inventory)).length;
    return matched / recipe.ingredients.length;
  }

  bool _hasInInventory(RecipeIngredient ing, List<InventoryIngredient> inventory) {
    return inventory.any((item) => 
        item.name.toLowerCase().contains(ing.ingredientName.toLowerCase()) ||
        ing.ingredientName.toLowerCase().contains(item.name.toLowerCase()));
  }
}
