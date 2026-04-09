import 'package:uuid/uuid.dart';
import 'package:data/data.dart';
import '../entities/inventory_ingredient.dart';
import '../entities/recipe.dart';
import 'calculate_recipe_viability_use_case.dart';
import '../repositories/i_cocina_repository.dart';

/// Use Case to generate a weekly menu plan based on available inventory
class GenerateWeeklyMenuUseCase {
  final ICocinaRepository repository;

  GenerateWeeklyMenuUseCase({required this.repository});

  /// Generates or regenerates the weekly menu
  /// If inventory is provided, prioritizes recipes with higher ingredient match
  Future<void> execute({List<InventoryIngredient>? inventory}) async {
    // Clear existing menu
    await repository.clearWeeklyMenu();

    // Fetch available recipes
    final recipes = await repository.getAllRecipes();
    if (recipes.isEmpty) {
      throw Exception(
          'No tienes recetas guardadas para armar el menú semanal.');
    }

    final uuid = const Uuid();
    final days = [1, 2, 3, 4, 5, 6, 7]; // Mon-Sun
    final meals = [0, 1, 2]; // Breakfast, Lunch, Dinner

    List<Recipe> sortedRecipes;

    // If inventory is available, sort recipes by viability
    if (inventory != null && inventory.isNotEmpty) {
      final viabilityCalc = CalculateRecipeViabilityUseCase();

      // Calculate viability for each recipe
      final recipeViability = <Recipe, double>{};
      for (final recipe in recipes) {
        final viability = viabilityCalc.execute(
          recipeIngredients: recipe.ingredients,
          inventory: inventory,
        );
        recipeViability[recipe] = viability;
      }

      // Sort recipes by viability (highest first), then by name for stability
      sortedRecipes = List.from(recipes);
      sortedRecipes.sort((a, b) {
        final viabilityA = recipeViability[a] ?? 0.0;
        final viabilityB = recipeViability[b] ?? 0.0;
        if (viabilityB != viabilityA) {
          return viabilityB.compareTo(viabilityA);
        }
        return a.name.compareTo(b.name);
      });

      // Filter out recipes with 0% viability if we have enough viable ones
      final viableRecipes = sortedRecipes.where((r) {
        final viability = recipeViability[r] ?? 0.0;
        return viability > 0.0;
      }).toList();

      // Use viable recipes if we have enough, otherwise use all sorted recipes
      if (viableRecipes.length >= days.length * meals.length) {
        sortedRecipes = viableRecipes;
      }
    } else {
      // No inventory available - fallback to random
      sortedRecipes = List.from(recipes);
      sortedRecipes.shuffle();
    }

    int recipeIndex = 0;

    for (final day in days) {
      for (final mealType in meals) {
        if (recipeIndex >= sortedRecipes.length) {
          recipeIndex = 0; // Loop back if not enough recipes
        }

        final recipe = sortedRecipes[recipeIndex];

        await repository.saveWeeklyMenuEntry(WeeklyMenuEntry(
          id: uuid.v4(),
          dayOfWeek: day,
          mealType: mealType,
          recipeId: recipe.id,
          isCustom: false,
        ));

        recipeIndex++;
      }
    }
  }
}
