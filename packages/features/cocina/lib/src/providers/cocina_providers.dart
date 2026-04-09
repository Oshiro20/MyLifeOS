import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';
import 'package:core/core.dart';
import '../utils/cooking_history_service.dart';

/// Result of attempting to save a recipe with duplicate check
class SaveRecipeResult {
  final bool success;
  final bool hasDuplicates;
  final List<DuplicateMatch> duplicates;
  final Recipe? savedRecipe;
  final String? error;

  const SaveRecipeResult.success({
    required this.savedRecipe,
    this.hasDuplicates = false,
    this.duplicates = const [],
  })  : success = true,
        error = null;

  const SaveRecipeResult.duplicatesFound({
    required this.duplicates,
    required this.savedRecipe,
  })  : success = false,
        hasDuplicates = true,
        error = null;

  const SaveRecipeResult.error(this.error)
      : success = false,
        hasDuplicates = false,
        duplicates = const [],
        savedRecipe = null;
}

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
  /// Returns list of ingredient names that were deducted (for feedback)
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
          await _repo.deleteIngredient(pantryItem.id);
        } else {
          // Update quantity - create new instance since InventoryIngredient is immutable
          final updated = InventoryIngredient(
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
          updatedIngredients[matchIndex] = updated;
          deducted.add(recipeIng.ingredientName);
          await _repo.updateIngredient(updated);
        }
      }
    }

    if (deducted.isNotEmpty) {
      state = state.copyWith(ingredients: updatedIngredients);
    }

    return deducted;
  }

  /// Revert a deduction (undo last cook action)
  Future<void> revertDeduction(List<RecipeIngredient> recipeIngredients) async {
    final currentIngredients = state.ingredients;
    final revertedIngredients =
        List<InventoryIngredient>.from(currentIngredients);

    for (final recipeIng in recipeIngredients) {
      final matchIndex = revertedIngredients.indexWhere((pantryItem) =>
          pantryItem.name.toLowerCase() ==
          recipeIng.ingredientName.toLowerCase());

      if (matchIndex != -1) {
        final pantryItem = revertedIngredients[matchIndex];
        final newQty = pantryItem.quantity + recipeIng.quantity;
        revertedIngredients[matchIndex] = InventoryIngredient(
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
      } else {
        // Ingredient was deleted, re-add it (approximate)
        revertedIngredients.add(InventoryIngredient(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: recipeIng.ingredientName,
          primaryCategory: 'Otros',
          subCategory: '',
          preparation: '',
          quantity: recipeIng.quantity,
          unit: recipeIng.unit,
          expirationDate: null,
          imageAssetId: '',
          storageArea: 'pantry',
        ));
      }
    }

    // Persist to DB
    for (final ing in revertedIngredients) {
      await _repo.updateIngredient(ing);
    }

    state = state.copyWith(ingredients: revertedIngredients);
  }

  /// Move bought shopping items to pantry inventory
  Future<void> bulkAddBoughtToPantry(List<ShoppingItem> boughtItems) async {
    if (boughtItems.isEmpty) return;

    for (final item in boughtItems) {
      final existingIndex = state.ingredients.indexWhere(
          (ing) => ing.name.toLowerCase() == item.name.toLowerCase());

      if (existingIndex != -1) {
        final existing = state.ingredients[existingIndex];
        final updated = InventoryIngredient(
          id: existing.id,
          name: existing.name,
          primaryCategory: existing.primaryCategory,
          subCategory: existing.subCategory,
          preparation: existing.preparation,
          quantity: existing.quantity + item.quantity,
          unit: existing.unit,
          expirationDate: existing.expirationDate,
          imageAssetId: existing.imageAssetId,
          storageArea: existing.storageArea,
        );
        await _repo.updateIngredient(updated);
        state = state.copyWith(ingredients: [
          for (int i = 0; i < state.ingredients.length; i++)
            if (i == existingIndex) updated else state.ingredients[i]
        ]);
      } else {
        final newIng = InventoryIngredient(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: item.name,
          primaryCategory: 'Otros',
          subCategory: '',
          preparation: '',
          quantity: item.quantity,
          unit: item.unit,
          expirationDate: null,
          imageAssetId: '',
          storageArea: 'pantry',
        );
        await _repo.addIngredient(newIng);
        state = state.copyWith(ingredients: [newIng, ...state.ingredients]);
      }
    }
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

  /// Save a recipe with automatic duplicate validation.
  /// Returns [SaveRecipeResult] indicating success, duplicates found, or error.
  Future<SaveRecipeResult> saveRecipeWithDuplicateCheck(
    Recipe recipe, {
    double duplicateThreshold = 0.70,
  }) async {
    try {
      // Check for duplicates against existing recipes
      final duplicates = RecipeDuplicateChecker.findDuplicates(
        recipe,
        state.recipes,
        threshold: duplicateThreshold,
      );

      if (duplicates.isNotEmpty) {
        // Save the recipe anyway but warn the user
        final saved = await _repo.saveRecipe(recipe);
        state = state.copyWith(
          recipes: [saved, ...state.recipes],
        );
        return SaveRecipeResult.duplicatesFound(
          duplicates: duplicates,
          savedRecipe: saved,
        );
      }

      // No duplicates, save normally
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
      return SaveRecipeResult.success(savedRecipe: saved);
    } catch (e) {
      return SaveRecipeResult.error(e.toString());
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

  Future<void> updateRecipeRating(String id, int rating) async {
    final recipe = state.recipes.firstWhere((r) => r.id == id);
    final updated = recipe.copyWith(rating: rating);
    await _repo.updateRecipe(updated);
    state = state.copyWith(
      recipes: [
        for (final r in state.recipes)
          if (r.id == id) updated else r
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

  Future<void> addShoppingItem(ShoppingItem item) async {
    try {
      await _repo.addShoppingItem(item);
      state = state.copyWith(shoppingList: [item, ...state.shoppingList]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
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

// Shared service provider — single source of truth for cooking history
final cookingHistoryServiceProvider = Provider<CookingHistoryService>((_) {
  return CookingHistoryService();
});

final inventoryProvider =
    NotifierProvider<InventoryNotifier, InventoryState>(InventoryNotifier.new);

final recipesProvider =
    NotifierProvider<RecipesNotifier, RecipesState>(RecipesNotifier.new);

// ── Hybrid Suggestion Provider (Fast Local + API) ───────────────────────────
final hybridSuggestionsProvider =
    FutureProvider<List<RecipeSuggestion>>((ref) async {
  final invState = ref.watch(inventoryProvider);
  final repo = ref.watch(cocinaRepositoryProvider);

  if (invState.ingredients.isEmpty) return [];

  final useCase = HybridSuggestionUseCase(
    repository: repo,
    apiService: TheMealDBService(),
  );

  return useCase.execute(
    inventory: invState.ingredients,
    limit: 15,
    minMatchPercentage: 0.30,
    useApi: false,
  );
});

// ── Weekly Menu Provider ──────────────────────────────────────────────────────
class WeeklyMenuState {}

class WeeklyMenuInitial extends WeeklyMenuState {}

class WeeklyMenuLoading extends WeeklyMenuState {}

class WeeklyMenuLoaded extends WeeklyMenuState {
  final List<dynamic> entries; // Use dynamic
  WeeklyMenuLoaded(this.entries);
}

class WeeklyMenuNotifier extends Notifier<WeeklyMenuState> {
  ICocinaRepository get _repo => ref.read(cocinaRepositoryProvider);

  @override
  WeeklyMenuState build() => WeeklyMenuInitial();

  Future<void> load() async {
    state = WeeklyMenuLoading();
    try {
      final entries = await _repo.getWeeklyMenu();
      state = WeeklyMenuLoaded(entries);
    } catch (e) {
      state = WeeklyMenuInitial();
    }
  }

  Future<void> generate() async {
    state = WeeklyMenuLoading();
    try {
      final useCase = GenerateWeeklyMenuUseCase(repository: _repo);

      // Get current inventory to prioritize recipes with available ingredients
      final inventoryNotifier = ref.read(inventoryProvider.notifier);
      await inventoryNotifier.load();
      final inventoryState = ref.read(inventoryProvider);

      await useCase.execute(inventory: inventoryState.ingredients);
      await load();
    } catch (e) {
      state = WeeklyMenuInitial();
      rethrow;
    }
  }
}

final weeklyMenuProvider =
    NotifierProvider<WeeklyMenuNotifier, WeeklyMenuState>(
        WeeklyMenuNotifier.new);
