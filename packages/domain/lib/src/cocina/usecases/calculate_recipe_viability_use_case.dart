class CalculateRecipeViabilityUseCase {
  /// Retorna un valor entre 0.0 y 1.0 (0% y 100%) indicando 
  /// cuán viable es preparar una receta dada según el inventario actual.
  /// 
  /// Params:
  /// [recipeRequirements] - Listado de ingredientes requeridos por la receta
  /// [inventory] - Listado de ingredientes actualmente en el inventario
  /// 
  /// Reglas Básicas MVP:
  /// - Match por nombre (ignorando mayúsculas/minúsculas de manera simple por ahora).
  /// - Si hay suficiente cantidad (requerido <= inventario), aporta 100% de ese ingrediente.
  /// - Si no hay, aporta 0%.
  /// (Funcionalidad normalizada de unidades queda para iteraciones futuras)
  double execute({
    required Map<String, double> recipeRequirements,
    required Map<String, double> inventory,
  }) {
    if (recipeRequirements.isEmpty) return 1.0;

    int totalRequiredItems = recipeRequirements.length;
    int metRequirements = 0;

    for (final requirement in recipeRequirements.entries) {
      final reqName = requirement.key.toLowerCase().trim();
      final reqQuantity = requirement.value;

      // Buscar en el inventario
      final invQuantity = _findInInventory(inventory, reqName);
      
      if (invQuantity >= reqQuantity) {
        metRequirements++;
      }
    }

    return metRequirements / totalRequiredItems;
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
