import '../entities/inventory_ingredient.dart';
import '../entities/recipe.dart';

/// Interfaz del repositorio de Cocina (puerto hexagonal)
abstract interface class ICocinaRepository {
  // ── Inventario ──────────────────────────────────────────────────────────────
  Future<List<InventoryIngredient>> getAllIngredients();
  Future<InventoryIngredient> addIngredient(InventoryIngredient ingredient);
  Future<void> updateIngredient(InventoryIngredient ingredient);
  Future<void> deleteIngredient(String id);

  // ── Recetas ─────────────────────────────────────────────────────────────────
  Future<List<Recipe>> getAllRecipes();
  Future<Recipe?> getRecipeById(String id);
  Future<Recipe> saveRecipe(Recipe recipe);
  Future<void> deleteRecipe(String id);
  Future<void> toggleFavorite(String recipeId);

  // ── Sugerencias ─────────────────────────────────────────────────────────────
  Future<List<Recipe>> suggestRecipes({
    required List<InventoryIngredient> inventory,
    NutritionGoal goal = NutritionGoal.maintain,
    int limit = 10,
  });

  // ── Lista de compras ────────────────────────────────────────────────────────
  Future<List<ShoppingItem>> getShoppingList();
  Future<ShoppingItem> addShoppingItem(ShoppingItem item);
  Future<void> toggleShoppingItem(String id);
  Future<void> deleteShoppingItem(String id);
  Future<List<ShoppingItem>> generateShoppingListFromRecipes(
    List<Recipe> recipes,
    List<InventoryIngredient> inventory,
  );
}
