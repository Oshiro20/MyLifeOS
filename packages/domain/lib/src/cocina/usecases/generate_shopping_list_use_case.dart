import '../entities/inventory_ingredient.dart';
import '../entities/recipe.dart';
import 'ingredient_matcher.dart';

class GenerateShoppingListUseCase {
  /// Retorna una lista con los ingredientes que faltan y la cantidad necesaria.
  List<ShoppingItem> execute({
    required List<RecipeIngredient> recipeIngredients,
    required List<InventoryIngredient> inventory,
    Map<String, double>? customGramsPerUnit,
  }) {
    final checks = IngredientMatcher.evaluateRecipe(
      recipeIngredients: recipeIngredients,
      inventory: inventory,
      customGramsPerUnit: customGramsPerUnit,
    );

    final List<ShoppingItem> missingItems = [];
    for (final c in checks) {
      final req = c.requirement;
      switch (c.availability) {
        case IngredientAvailability.available:
          break;
        case IngredientAvailability.insufficient:
          missingItems.add(
            ShoppingItem(
              id: '',
              name: req.ingredientName,
              quantity: c.missingInRecipeUnit ?? req.quantity,
              unit: req.unit,
              createdAt: DateTime.now(),
            ),
          );
          break;
        case IngredientAvailability.incompatibleUnit:
        case IngredientAvailability.missing:
          missingItems.add(
            ShoppingItem(
              id: '',
              name: req.ingredientName,
              quantity: req.quantity,
              unit: req.unit,
              createdAt: DateTime.now(),
            ),
          );
          break;
      }
    }

    return missingItems;
  }
}
