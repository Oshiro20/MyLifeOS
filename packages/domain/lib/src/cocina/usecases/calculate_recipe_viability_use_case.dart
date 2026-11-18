import '../entities/ingredient_units.dart';
import '../entities/inventory_ingredient.dart';
import '../entities/recipe.dart';
import 'ingredient_matcher.dart';

class CalculateRecipeViabilityUseCase {
  /// Retorna un valor entre 0.0 y 1.0 (0% y 100%) indicando
  /// cuán viable es preparar una receta dada según el inventario actual.
  ///
  /// Utiliza el [IngredientUnitNormalizer] para validar cantidades precisas
  /// basándose en las unidades de medida reales.
  double execute({
    required List<RecipeIngredient> recipeIngredients,
    required List<InventoryIngredient> inventory,
    Map<String, double>? customGramsPerUnit,
  }) {
    if (recipeIngredients.isEmpty) return 1.0;

    final checks = IngredientMatcher.evaluateRecipe(
      recipeIngredients: recipeIngredients,
      inventory: inventory,
      customGramsPerUnit: customGramsPerUnit,
    );

    double totalViabilitySum = 0.0;
    for (final c in checks) {
      switch (c.availability) {
        case IngredientAvailability.available:
          totalViabilitySum += 1.0;
          break;
        case IngredientAvailability.insufficient:
          final avail = c.availableInRecipeUnit ?? 0;
          if (c.requirement.quantity > 0 && avail > 0) {
            totalViabilitySum +=
                (avail / c.requirement.quantity).clamp(0.0, 1.0);
          }
          break;
        case IngredientAvailability.incompatibleUnit:
          final pantry = c.pantryMatch;
          if (pantry != null &&
              MeasurementUnit.fromString(pantry.unit) ==
                  MeasurementUnit.fromString(c.requirement.unit) &&
              pantry.quantity >= c.requirement.quantity) {
            totalViabilitySum += 1.0;
          }
          break;
        case IngredientAvailability.missing:
          break;
      }
    }

    return totalViabilitySum / checks.length;
  }
}
