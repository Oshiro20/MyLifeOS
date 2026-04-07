import 'package:uuid/uuid.dart';
import 'package:data/data.dart';
import '../repositories/i_cocina_repository.dart';

/// Use Case to generate a weekly menu plan
class GenerateWeeklyMenuUseCase {
  final ICocinaRepository repository;

  GenerateWeeklyMenuUseCase({required this.repository});

  /// Generates or regenerates the weekly menu
  Future<void> execute() async {
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

    // Create a copy to shuffle
    final availableRecipes = List.from(recipes);
    availableRecipes.shuffle();

    int recipeIndex = 0;

    for (final day in days) {
      for (final mealType in meals) {
        if (recipeIndex >= availableRecipes.length) {
          recipeIndex = 0; // Loop back if not enough recipes
        }

        final recipe = availableRecipes[recipeIndex];

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
