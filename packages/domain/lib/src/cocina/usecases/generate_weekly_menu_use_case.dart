import 'package:uuid/uuid.dart';
import '../entities/inventory_ingredient.dart';
import '../entities/recipe.dart';
import '../entities/weekly_menu_entry.dart';
import 'calculate_recipe_viability_use_case.dart';
import '../repositories/i_cocina_repository.dart';

/// Use Case to generate a weekly menu plan based on available inventory
class GenerateWeeklyMenuUseCase {
  final ICocinaRepository repository;

  GenerateWeeklyMenuUseCase({required this.repository});

  /// Generates or regenerates the weekly menu
  /// If inventory is provided, prioritizes recipes with higher ingredient match
  Future<void> execute({List<InventoryIngredient>? inventory}) async {
    // Validate available recipes BEFORE clearing existing weekly plan
    final recipes = await repository.getAllRecipes();
    if (recipes.isEmpty) {
      throw Exception(
          'No tienes recetas guardadas para armar el menú semanal.');
    }

    await repository.clearWeeklyMenu();

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

    final slotCursors = <int, int>{0: 0, 1: 0, 2: 0};

    for (final day in days) {
      for (final mealType in meals) {
        final candidates = _recipesForSlot(sortedRecipes, mealType);
        final idx = (slotCursors[mealType] ?? 0) % candidates.length;
        final recipe = candidates[idx];
        slotCursors[mealType] = idx + 1;

        await repository.saveWeeklyMenuEntry(WeeklyMenuEntry(
          id: uuid.v4(),
          dayOfWeek: day,
          mealType: mealType,
          recipeId: recipe.id,
          isCustom: false,
        ));
      }
    }
  }

  static List<Recipe> _recipesForSlot(List<Recipe> pool, int mealType) {
    final preferred = switch (mealType) {
      0 => const {MealType.desayuno, MealType.jugo, MealType.bebida},
      1 => const {
          MealType.almuerzo,
          MealType.seco,
          MealType.sopa,
          MealType.entrada,
        },
      2 => const {
          MealType.cena,
          MealType.entrada,
          MealType.sopa,
          MealType.seco,
        },
      _ => MealType.values.toSet(),
    };
    final exact = pool
        .where(
            (r) => r.tipoComida != null && preferred.contains(r.tipoComida))
        .toList();
    final untyped = pool.where((r) => r.tipoComida == null).toList();
    if (exact.isNotEmpty || untyped.isNotEmpty) {
      return [...exact, ...untyped];
    }
    return pool;
  }
}
