import '../entities/ingredient_units.dart';
import '../entities/inventory_ingredient.dart';
import '../entities/recipe.dart';
import 'ingredient_unit_normalizer.dart';

class GenerateShoppingListUseCase {
  /// Retorna una lista con los ingredientes que faltan y la cantidad necesaria.
  List<ShoppingItem> execute({
    required List<RecipeIngredient> recipeIngredients,
    required List<InventoryIngredient> inventory,
  }) {
    final List<ShoppingItem> missingItems = [];

    for (final requirement in recipeIngredients) {
      final reqName = requirement.ingredientName.toLowerCase().trim();
      final reqQuantity = requirement.quantity;
      final reqUnit = MeasurementUnit.fromString(requirement.unit);

      final match = _findInInventory(inventory, reqName);

      if (match != null) {
        final invQuantity = match.quantity;
        final invUnit = MeasurementUnit.fromString(match.unit);

        final convertedInvQuantity = IngredientUnitNormalizer.convert(
          invQuantity,
          invUnit,
          reqUnit,
        );

        if (convertedInvQuantity != null) {
          if (convertedInvQuantity < reqQuantity) {
            missingItems.add(
              ShoppingItem(
                id: '', // Empty ID, to be assigned when persisted
                name: requirement.ingredientName,
                quantity: reqQuantity - convertedInvQuantity,
                unit: requirement.unit,
                createdAt: DateTime.now(),
              ),
            );
          }
        } else {
          // If not convertible, just add the full requirement as missing?
          // Fallback to strict match
          if (invUnit == reqUnit) {
            if (invQuantity < reqQuantity) {
              missingItems.add(
                ShoppingItem(
                  id: '',
                  name: requirement.ingredientName,
                  quantity: reqQuantity - invQuantity,
                  unit: requirement.unit,
                  createdAt: DateTime.now(),
                ),
              );
            }
          } else {
             // Treat as missing entirely
             missingItems.add(
                ShoppingItem(
                  id: '',
                  name: requirement.ingredientName,
                  quantity: reqQuantity,
                  unit: requirement.unit,
                  createdAt: DateTime.now(),
                ),
              );
          }
        }
      } else {
        // Not in inventory at all
        missingItems.add(
          ShoppingItem(
            id: '',
            name: requirement.ingredientName,
            quantity: reqQuantity,
            unit: requirement.unit,
            createdAt: DateTime.now(),
          ),
        );
      }
    }

    return missingItems;
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
