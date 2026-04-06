import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';

// ── Estados ───────────────────────────────────────────────────────────────────
class InventoryState {
  final List<InventoryIngredient> ingredients;
  final bool isLoading;
  final String? error;

  const InventoryState({
    this.ingredients = const [],
    this.isLoading = false,
    this.error,
  });

  InventoryState copyWith({
    List<InventoryIngredient>? ingredients,
    bool? isLoading,
    String? error,
  }) =>
      InventoryState(
        ingredients: ingredients ?? this.ingredients,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class RecipesState {
  final List<Recipe> recipes;
  final List<Recipe> suggestions;
  final List<ShoppingItem> shoppingList;
  final NutritionGoal activeGoal;
  final bool isLoading;
  final String? error;

  const RecipesState({
    this.recipes = const [],
    this.suggestions = const [],
    this.shoppingList = const [],
    this.activeGoal = NutritionGoal.maintain,
    this.isLoading = false,
    this.error,
  });

  RecipesState copyWith({
    List<Recipe>? recipes,
    List<Recipe>? suggestions,
    List<ShoppingItem>? shoppingList,
    NutritionGoal? activeGoal,
    bool? isLoading,
    String? error,
  }) =>
      RecipesState(
        recipes: recipes ?? this.recipes,
        suggestions: suggestions ?? this.suggestions,
        shoppingList: shoppingList ?? this.shoppingList,
        activeGoal: activeGoal ?? this.activeGoal,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ── Notifiers (Riverpod v3) ───────────────────────────────────────────────────
class InventoryNotifier extends Notifier<InventoryState> {
  ICocinaRepository get _repo => ref.read(cocinaRepositoryProvider);

  @override
  InventoryState build() {
    Future.microtask(() => load());
    return const InventoryState();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final items = await _repo.getAllIngredients();
      state = state.copyWith(ingredients: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> add(InventoryIngredient ing) async {
    try {
      final saved = await _repo.addIngredient(ing);
      state = state.copyWith(ingredients: [saved, ...state.ingredients]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> update(InventoryIngredient ing) async {
    try {
      await _repo.updateIngredient(ing);
      state = state.copyWith(ingredients: [
        for (final i in state.ingredients)
          if (i.id == ing.id) ing else i
      ]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> delete(String id) async {
    try {
      await _repo.deleteIngredient(id);
      state = state.copyWith(
          ingredients: state.ingredients.where((i) => i.id != id).toList());
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Deduct recipe ingredients from pantry
  /// Returns list of ingredients that were deducted (for feedback)
  Future<List<String>> deductRecipeIngredients(
      List<RecipeIngredient> recipeIngredients) async {
    final deducted = <String>[];
    final updatedIngredients =
        List<InventoryIngredient>.from(state.ingredients);

    for (final recipeIng in recipeIngredients) {
      // Find matching pantry item (case-insensitive name match)
      final matchIndex = updatedIngredients.indexWhere((pantryItem) =>
          pantryItem.name.toLowerCase() ==
          recipeIng.ingredientName.toLowerCase());

      if (matchIndex != -1) {
        final pantryItem = updatedIngredients[matchIndex];
        // Convert recipe quantity to same unit if possible (simplified: assume same unit)
        final newQty = pantryItem.quantity - recipeIng.quantity;

        if (newQty <= 0) {
          // Remove from pantry
          updatedIngredients.removeAt(matchIndex);
          deducted.add(recipeIng.ingredientName);
        } else {
          // Update quantity - create new instance since InventoryIngredient is immutable
          updatedIngredients[matchIndex] = InventoryIngredient(
            id: pantryItem.id,
            name: pantryItem.name,
            primaryCategory: pantryItem.primaryCategory,
            subCategory: pantryItem.subCategory,
            preparation: pantryItem.preparation,
            quantity: newQty,
            unit: pantryItem.unit,
            expirationDate: pantryItem.expirationDate,
            imageAssetId: pantryItem.imageAssetId,
            storageArea: pantryItem.storageArea,
          );
          deducted.add(recipeIng.ingredientName);
        }
      }
    }

    if (deducted.isNotEmpty) {
      state = state.copyWith(ingredients: updatedIngredients);
    }

    return deducted;
  }

  void clearError() => state = state.copyWith(error: null);
}

class RecipesNotifier extends Notifier<RecipesState> {
  ICocinaRepository get _repo => ref.read(cocinaRepositoryProvider);

  @override
  RecipesState build() {
    Future.microtask(() => load());
    return const RecipesState();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final recipes = await _repo.getAllRecipes();
      final shopping = await _repo.getShoppingList();
      state = state.copyWith(
        recipes: recipes,
        shoppingList: shopping,
        isLoading: false,
      );
      await refreshSuggestions();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> refreshSuggestions() async {
    final inventory = await _repo.getAllIngredients();
    final suggestions = await _repo.suggestRecipes(
        inventory: inventory, goal: state.activeGoal);
    state = state.copyWith(suggestions: suggestions);
  }

  Future<void> saveRecipe(Recipe recipe) async {
    try {
      final saved = await _repo.saveRecipe(recipe);
      final existing = state.recipes.any((r) => r.id == saved.id);
      state = state.copyWith(
        recipes: existing
            ? [
                for (final r in state.recipes)
                  if (r.id == saved.id) saved else r
              ]
            : [saved, ...state.recipes],
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteRecipe(String id) async {
    await _repo.deleteRecipe(id);
    state = state.copyWith(
        recipes: state.recipes.where((r) => r.id != id).toList());
  }

  Future<void> toggleFavorite(String id) async {
    await _repo.toggleFavorite(id);
    state = state.copyWith(
      recipes: [
        for (final r in state.recipes)
          if (r.id == id) r.copyWith(isFavorite: !r.isFavorite) else r
      ],
    );
  }

  void setGoal(NutritionGoal goal) {
    state = state.copyWith(activeGoal: goal);
    refreshSuggestions();
  }

  Future<void> toggleShoppingItem(String id) async {
    await _repo.toggleShoppingItem(id);
    await load();
  }

  Future<void> deleteShoppingItem(String id) async {
    await _repo.deleteShoppingItem(id);
    await load();
  }

  Future<void> clearBoughtShoppingItems() async {
    final bought = state.shoppingList.where((i) => i.bought).toList();
    for (final item in bought) {
      await _repo.deleteShoppingItem(item.id);
    }
    await load();
  }

  Future<void> clearAllShoppingList() async {
    for (final item in state.shoppingList) {
      await _repo.deleteShoppingItem(item.id);
    }
    state = state.copyWith(shoppingList: []);
  }

  Future<void> generateShoppingList(List<Recipe> selected) async {
    final items = await _repo.generateShoppingListFromRecipes(
        selected, await _repo.getAllIngredients());
    state = state.copyWith(shoppingList: [...state.shoppingList, ...items]);
  }

  void clearError() => state = state.copyWith(error: null);
}

// ── Providers ─────────────────────────────────────────────────────────────────
final cocinaRepositoryProvider = Provider<ICocinaRepository>((ref) {
  throw UnimplementedError(
      'Provide ICocinaRepository via ProviderScope.overrides');
});

final inventoryProvider =
    NotifierProvider<InventoryNotifier, InventoryState>(InventoryNotifier.new);

final recipesProvider =
    NotifierProvider<RecipesNotifier, RecipesState>(RecipesNotifier.new);
