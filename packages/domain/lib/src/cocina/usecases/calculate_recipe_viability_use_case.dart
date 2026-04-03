import '../entities/ingredient_units.dart';
import '../entities/inventory_ingredient.dart';
import '../entities/recipe.dart';
import 'ingredient_unit_normalizer.dart';

class CalculateRecipeViabilityUseCase {
  /// Retorna un valor entre 0.0 y 1.0 (0% y 100%) indicando 
  /// cuán viable es preparar una receta dada según el inventario actual.
  /// 
  /// Utiliza el [IngredientUnitNormalizer] para validar cantidades precisas
  /// basándose en las unidades de medida reales.
  double execute({
    required List<RecipeIngredient> recipeIngredients,
    required List<InventoryIngredient> inventory,
  }) {
    if (recipeIngredients.isEmpty) return 1.0;

    double totalViabilitySum = 0.0;
    int totalRequiredItems = recipeIngredients.length;

    for (final requirement in recipeIngredients) {
      final reqName = requirement.ingredientName.toLowerCase().trim();
      final reqQuantity = requirement.quantity;
      final reqUnit = MeasurementUnit.fromString(requirement.unit);

      // Buscar en el inventario
      final match = _findInInventory(inventory, reqName);
      
      if (match != null) {
        final invQuantity = match.quantity;
        final invUnit = MeasurementUnit.fromString(match.unit);

        // Convertiremos la cantidad del inventario a la unidad de la receta
        final convertedInvQuantity = IngredientUnitNormalizer.convert(
          invQuantity, 
          invUnit, 
          reqUnit,
        );

        if (convertedInvQuantity != null) {
          if (convertedInvQuantity >= reqQuantity) {
            totalViabilitySum += 1.0; // 100% de este ingrediente
          } else {
            totalViabilitySum += (convertedInvQuantity / reqQuantity); // Fracción
          }
        } else {
          // Si no es convertible (ej. gramos vs unidades), fallback a macheo simple si es exacto
          if (invUnit == reqUnit && invQuantity >= reqQuantity) {
             totalViabilitySum += 1.0;
          }
        }
      }
    }

    return totalViabilitySum / totalRequiredItems;
  }

  InventoryIngredient? _findInInventory(List<InventoryIngredient> inventory, String name) {
    for (final inv in inventory) {
      if (inv.name.toLowerCase().trim() == name) {
        return inv;
      }
    }
    return null;
  }
}
