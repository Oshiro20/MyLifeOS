import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:domain/domain.dart';
import 'package:data/data.dart';
import 'package:core/core.dart';
import '../utils/cooking_history_service.dart';

const _cocinaUuid = Uuid();

/// Helper to navigate/switch Cocina tabs (0=Despensa, 1=Recetas, ..., 4=Lista)
class CocinaTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setTab(int index) => state = index;
}

final cocinaTabProvider =
    NotifierProvider<CocinaTabNotifier, int>(CocinaTabNotifier.new);

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
    this.savedRecipe,
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
      final matchIndex = updatedIngredients.indexWhere((pantryItem) =>
          pantryItem.name.toLowerCase() ==
          recipeIng.ingredientName.toLowerCase());

      if (matchIndex != -1) {
        final pantryItem = updatedIngredients[matchIndex];
        final converted = IngredientUnitNormalizer.convert(
          recipeIng.quantity,
          MeasurementUnit.fromString(recipeIng.unit),
          MeasurementUnit.fromString(pantryItem.unit),
        );
        if (converted == null) continue;
        final newQty = pantryItem.quantity - converted;

        if (newQty <= 0) {
          updatedIngredients.removeAt(matchIndex);
          deducted.add(recipeIng.ingredientName);
          await _repo.deleteIngredient(pantryItem.id);
        } else {
          final updated = pantryItem.copyWith(quantity: newQty);
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
    final revertedIngredients =
        List<InventoryIngredient>.from(state.ingredients);

    for (final recipeIng in recipeIngredients) {
      final matchIndex = revertedIngredients.indexWhere((pantryItem) =>
          pantryItem.name.toLowerCase() ==
          recipeIng.ingredientName.toLowerCase());

      if (matchIndex != -1) {
        final pantryItem = revertedIngredients[matchIndex];
        final converted = IngredientUnitNormalizer.convert(
          recipeIng.quantity,
          MeasurementUnit.fromString(recipeIng.unit),
          MeasurementUnit.fromString(pantryItem.unit),
        );
        if (converted == null) continue;
        final updated =
            pantryItem.copyWith(quantity: pantryItem.quantity + converted);
        revertedIngredients[matchIndex] = updated;
        await _repo.updateIngredient(updated);
      } else {
        final detected = IngredientDetector.detect(recipeIng.ingredientName);
        final restored = InventoryIngredient(
          id: _cocinaUuid.v4(),
          name: recipeIng.ingredientName,
          primaryCategory: detected.primaryCategory ?? 'Otros',
          subCategory: detected.subCategory ?? '',
          preparation: '',
          quantity: recipeIng.quantity,
          unit: recipeIng.unit,
          expirationDate: null,
          imageAssetId: null,
          storageArea: 'Alacena',
        );
        revertedIngredients.add(restored);
        await _repo.addIngredient(restored);
      }
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
        final converted = IngredientUnitNormalizer.convert(
          item.quantity,
          MeasurementUnit.fromString(item.unit),
          MeasurementUnit.fromString(existing.unit),
        );
        if (converted != null) {
          final updated =
              existing.copyWith(quantity: existing.quantity + converted);
          await _repo.updateIngredient(updated);
          state = state.copyWith(ingredients: [
            for (int i = 0; i < state.ingredients.length; i++)
              if (i == existingIndex) updated else state.ingredients[i]
          ]);
          continue;
        }
      }
      {
        final detected = IngredientDetector.detect(item.name);
        final newIng = InventoryIngredient(
          id: _cocinaUuid.v4(),
          name: item.name,
          primaryCategory: detected.primaryCategory ?? 'Otros',
          subCategory: detected.subCategory ?? '',
          preparation: '',
          quantity: item.quantity,
          unit: item.unit,
          expirationDate: null,
          imageAssetId: null,
          storageArea: 'Alacena',
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
    bool forceSave = false,
  }) async {
    try {
      if (!forceSave) {
        final duplicates = RecipeDuplicateChecker.findDuplicates(
          recipe,
          state.recipes,
          threshold: duplicateThreshold,
        );

        if (duplicates.isNotEmpty) {
          return SaveRecipeResult.duplicatesFound(
            duplicates: duplicates,
          );
        }
      }

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
    state = state.copyWith(shoppingList: [
      for (final item in state.shoppingList)
        if (item.id == id) item.copyWith(bought: !item.bought) else item,
    ]);
  }

  Future<void> deleteShoppingItem(String id) async {
    await _repo.deleteShoppingItem(id);
    state = state.copyWith(
      shoppingList: state.shoppingList.where((i) => i.id != id).toList(),
    );
  }

  Future<void> clearBoughtShoppingItems() async {
    final boughtIds =
        state.shoppingList.where((i) => i.bought).map((i) => i.id).toSet();
    if (boughtIds.isEmpty) return;
    await Future.wait(boughtIds.map(_repo.deleteShoppingItem));
    state = state.copyWith(
      shoppingList:
          state.shoppingList.where((i) => !boughtIds.contains(i.id)).toList(),
    );
  }

  Future<void> addShoppingItem(ShoppingItem item) async {
    try {
      final saved = await _repo.addShoppingItem(item);
      state = state.copyWith(shoppingList: [saved, ...state.shoppingList]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> clearAllShoppingList() async {
    final ids = state.shoppingList.map((i) => i.id).toList();
    if (ids.isEmpty) return;
    await Future.wait(ids.map(_repo.deleteShoppingItem));
    state = state.copyWith(shoppingList: []);
  }

  Future<void> generateShoppingList(List<Recipe> selected) async {
    final items = await _repo.generateShoppingListFromRecipes(
        selected, await _repo.getAllIngredients());
    if (items.isEmpty) return;
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
  final List<WeeklyMenuEntry> entries;
  WeeklyMenuLoaded(this.entries);
}

class WeeklyMenuError extends WeeklyMenuState {
  final String message;
  WeeklyMenuError(this.message);
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
      state = WeeklyMenuError(e.toString());
    }
  }

  Future<void> clearSlot(WeeklyMenuEntry entry) async {
    await _repo.saveWeeklyMenuEntry(WeeklyMenuEntry(
      id: entry.id,
      dayOfWeek: entry.dayOfWeek,
      mealType: entry.mealType,
      recipeId: '',
      isCustom: true,
    ));
    await load();
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
      final entries = await _repo.getWeeklyMenu().catchError((_) => <WeeklyMenuEntry>[]);
      state = entries.isNotEmpty ? WeeklyMenuLoaded(entries) : WeeklyMenuInitial();
      rethrow;
    }
  }
}

final weeklyMenuProvider =
    NotifierProvider<WeeklyMenuNotifier, WeeklyMenuState>(
        WeeklyMenuNotifier.new);
