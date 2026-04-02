class GenerateShoppingListUseCase {
  /// Retorna un mapa con los ingredientes que faltan y la cantidad necesaria.
  /// 
  /// Params:
  /// [recipeRequirements] - Listado de ingredientes requeridos por la receta
  /// [inventory] - Listado de ingredientes actualmente en el inventario
  Map<String, double> execute({
    required Map<String, double> recipeRequirements,
    required Map<String, double> inventory,
  }) {
    final Map<String, double> missingItems = {};

    for (final requirement in recipeRequirements.entries) {
      final reqName = requirement.key.toLowerCase().trim();
      final reqQuantity = requirement.value;

      final invQuantity = _findInInventory(inventory, reqName);

      if (invQuantity < reqQuantity) {
        missingItems[requirement.key] = reqQuantity - invQuantity;
      }
    }

    return missingItems;
  }

  double _findInInventory(Map<String, double> inventory, String name) {
    for (final inv in inventory.entries) {
      if (inv.key.toLowerCase().trim() == name) {
        return inv.value;
      }
    }
    return 0.0;
  }
}
