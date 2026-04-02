import '../entities/inventory_ingredient.dart';
import '../entities/recipe.dart';
import '../repositories/i_cocina_repository.dart';

/// Dado el inventario actual, devuelve recetas que se pueden cocinar
/// con ≥ 75% de los ingredientes disponibles.
class SuggestRecipesUseCase {
  final ICocinaRepository _repo;
  const SuggestRecipesUseCase(this._repo);

  Future<List<Recipe>> call({
    NutritionGoal goal = NutritionGoal.maintain,
    int limit = 10,
  }) async {
    final inventory = await _repo.getAllIngredients();
    return _repo.suggestRecipes(
      inventory: inventory,
      goal: goal,
      limit: limit,
    );
  }
}

/// Genera lista de compras desde recetas seleccionadas,
/// descontando lo que ya hay en inventario.
class GenerateShoppingListUseCase {
  final ICocinaRepository _repo;
  const GenerateShoppingListUseCase(this._repo);

  Future<List<ShoppingItem>> call(List<Recipe> recipes) async {
    final inventory = await _repo.getAllIngredients();
    return _repo.generateShoppingListFromRecipes(recipes, inventory);
  }
}
