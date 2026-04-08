import 'package:domain/domain.dart';
import '../services/the_meal_db_service.dart';
import '../services/local_recipe_database_service.dart';

class HybridSuggestionUseCase {
  final ICocinaRepository repository;
  final TheMealDBService apiService;
  final LocalRecipeDatabaseService localDbService;

  HybridSuggestionUseCase({
    required this.repository,
    required this.apiService,
    LocalRecipeDatabaseService? localDbService,
  }) : localDbService = localDbService ?? LocalRecipeDatabaseService();

  Future<List<RecipeSuggestion>> execute({
    required List<InventoryIngredient> inventory,
    int limit = 15,
    double minMatchPercentage = 0.30,
    bool useApi = false,
  }) async {
    final suggestions = <RecipeSuggestion>[];
    final seenNames = <String>{};
    final inventoryNames = inventory.map((i) => i.name.toLowerCase()).toList();

    // 1. Search user's saved recipes
    final savedRecipes =
        await repository.suggestRecipes(inventory: inventory, limit: limit);
    for (final recipe in savedRecipes) {
      final match = _calculateMatch(recipe, inventory);
      if (match >= minMatchPercentage) {
        suggestions.add(_createSuggestion(recipe, match, inventory));
        seenNames.add(recipe.name.toLowerCase());
      }
    }

    // 2. Search local recipe database
    if (suggestions.length < limit) {
      final localRecipes = await localDbService
          .searchByIngredients(inventoryNames, limit: limit * 2);
      for (final recipe in localRecipes) {
        if (seenNames.contains(recipe.name.toLowerCase())) continue;
        final match = _calculateMatch(recipe, inventory);
        if (match >= minMatchPercentage * 0.7) {
          suggestions.add(_createSuggestion(recipe, match, inventory));
          seenNames.add(recipe.name.toLowerCase());
          if (suggestions.length >= limit) break;
        }
      }
    }

    // 3. Only use API if explicitly requested
    if (useApi && suggestions.length < limit) {
      final remainingSlots = limit - suggestions.length;
      final keyIngredient =
          inventory.isNotEmpty ? inventory.first.name : 'chicken';
      final apiRecipes = await apiService.searchByIngredient(keyIngredient);
      for (final recipe in apiRecipes.take(remainingSlots)) {
        if (seenNames.contains(recipe.name.toLowerCase())) continue;
        final match = _calculateMatch(recipe, inventory);
        if (match >= minMatchPercentage) {
          suggestions.add(_createSuggestion(recipe, match, inventory));
          seenNames.add(recipe.name.toLowerCase());
        }
      }
    }

    suggestions.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));
    return suggestions.take(limit).toList();
  }

  RecipeSuggestion _createSuggestion(
      Recipe recipe, double match, List<InventoryIngredient> inventory) {
    return RecipeSuggestion(
      recipe: recipe,
      matchPercentage: (match * 100).round(),
      missingIngredients: recipe.ingredients.length -
          recipe.ingredients.where((i) => _hasInInventory(i, inventory)).length,
    );
  }

  double _calculateMatch(Recipe recipe, List<InventoryIngredient> inventory) {
    if (recipe.ingredients.isEmpty) return 0.0;
    int matched = recipe.ingredients
        .where((ing) => _hasInInventory(ing, inventory))
        .length;
    return matched / recipe.ingredients.length;
  }

  bool _hasInInventory(
      RecipeIngredient ing, List<InventoryIngredient> inventory) {
    return inventory.any((item) =>
        item.name.toLowerCase().contains(ing.ingredientName.toLowerCase()) ||
        ing.ingredientName.toLowerCase().contains(item.name.toLowerCase()));
  }
}
