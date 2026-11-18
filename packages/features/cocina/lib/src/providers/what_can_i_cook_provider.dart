import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';
import 'package:core/core.dart';
import '../providers/cocina_providers.dart';
import '../providers/user_food_preferences_provider.dart';
import '../providers/chef_preferences_provider.dart';
import '../utils/cooking_history_service.dart';
import '../utils/suggestions_cache_service.dart';
import '../screens/suggestions_tab.dart';

enum WhatCanICookState { initial, loading, success, error }

/// Shared menu configuration for FAB and SuggestionsTab
class MenuConfig {
  final MealPeriod? mealPeriod;
  final List<MenuComponent> components;
  final int menuCount;
  final bool budgetSaverMode;

  const MenuConfig({
    this.mealPeriod,
    this.components = const [MenuComponent.platoFuerte],
    this.menuCount = 3,
    this.budgetSaverMode = false,
  });
}

class MenuConfigNotifier extends Notifier<MenuConfig> {
  @override
  MenuConfig build() => const MenuConfig();

  void update({
    MealPeriod? mealPeriod,
    List<MenuComponent>? components,
    int? menuCount,
    bool? budgetSaverMode,
  }) {
    state = MenuConfig(
      mealPeriod: mealPeriod ?? state.mealPeriod,
      components: components ?? state.components,
      menuCount: menuCount ?? state.menuCount,
      budgetSaverMode: budgetSaverMode ?? state.budgetSaverMode,
    );
  }
}

final menuConfigProvider = NotifierProvider<MenuConfigNotifier, MenuConfig>(() {
  return MenuConfigNotifier();
});

class WhatCanICookNotifier extends Notifier<WhatCanICookState> {
  List<RecipeSuggestion> suggestions = [];
  String? errorMessage;
  String? statusNotice;
  bool usedLocalFallback = false;
  MealPeriod? _lastMealPeriod;

  final Set<String> _dismissedIds = {};
  final _cacheService = SuggestionsCacheService();

  List<RecipeSuggestion> get visibleSuggestions =>
      suggestions.where((s) => !_dismissedIds.contains(s.recipe.id)).toList();

  void dismissRecipe(String recipeId) {
    dismissMenu([recipeId]);
  }

  void dismissMenu(List<String> recipeIds) {
    _dismissedIds.addAll(recipeIds);
    suggestions =
        suggestions.where((s) => !recipeIds.contains(s.recipe.id)).toList();
    if (state == WhatCanICookState.success) {
      state = WhatCanICookState.initial;
      state = WhatCanICookState.success;
    }
  }

  @override
  WhatCanICookState build() {
    return WhatCanICookState.initial;
  }

  bool get needsRefresh {
    if (_lastMealPeriod == null) return true;
    return _lastMealPeriod != _getCurrentMealPeriod();
  }

  MealPeriod _getCurrentMealPeriod() {
    final hour = DateTime.now().hour;
    if (hour < 10) return MealPeriod.desayuno;
    if (hour < 17) return MealPeriod.almuerzo;
    return MealPeriod.cena;
  }

  String _buildCacheSignature({
    required MealPeriod meal,
    required List<MenuComponent> components,
    required int menuCount,
    required String? cuisinePreference,
    required bool budgetSaverMode,
    required List<InventoryIngredient> ingredients,
  }) {
    final compNames = components.map((c) => c.name).toList()..sort();
    final ingNames = ingredients.map((i) => i.name.toLowerCase()).toList()
      ..sort();
    return '${meal.name}|${compNames.join(',')}|$menuCount|${cuisinePreference ?? ''}|$budgetSaverMode|${ingNames.join(',')}';
  }

  static int _countMissingIngredients(
    List<RecipeIngredient> recipeIngredients,
    List<InventoryIngredient> inventory,
  ) {
    final invNames = inventory
        .where((i) => i.quantity > 0)
        .map((i) => i.name.trim().toLowerCase())
        .toList();
    var missing = 0;
    for (final ing in recipeIngredients) {
      final target = ing.ingredientName.trim().toLowerCase();
      final hasMatch = invNames.any(
        (inv) => inv == target || inv.contains(target) || target.contains(inv),
      );
      if (!hasMatch) missing++;
    }
    return missing;
  }

  Future<void> generateSuggestions({
    MealPeriod? mealPeriod,
    List<MenuComponent>? components,
    int menuCount = 3,
    String? cuisinePreference,
    bool budgetSaverMode = false,
    bool forceRefresh = false,
  }) async {
    final menuComponents =
        (components != null && components.isNotEmpty) ? components : [MenuComponent.platoFuerte];
    final meal = mealPeriod ?? _getCurrentMealPeriod();

    state = WhatCanICookState.loading;
    errorMessage = null;
    statusNotice = null;
    usedLocalFallback = false;
    _dismissedIds.clear();

    try {
      final inventoryNotifier = ref.read(inventoryProvider.notifier);
      await inventoryNotifier.load();
      final inventoryState = ref.read(inventoryProvider);

      if (inventoryState.ingredients.isEmpty) {
        throw Exception(
          'No tienes ingredientes en tu inventario. '
          'Agrega algunos en la pestaña de Despensa primero.',
        );
      }

      final signature = _buildCacheSignature(
        meal: meal,
        components: menuComponents,
        menuCount: menuCount,
        cuisinePreference: cuisinePreference,
        budgetSaverMode: budgetSaverMode,
        ingredients: inventoryState.ingredients,
      );

      final cached = forceRefresh
          ? null
          : await _cacheService.getCachedSuggestions(
              expectedSignature: signature,
            );
      if (cached != null && cached.isNotEmpty) {
        suggestions = cached;
        state = WhatCanICookState.success;
        _lastMealPeriod = meal;
        return;
      }

      final prefsState = ref.read(userFoodPreferencesProvider);
      final chefPrefs = ref.read(chefPreferencesProvider);
      final recentlyUsed = await _getRecentlyUsedRecipes();
      final gemini = ref.read(geminiProvider);
      final useCase = WhatCanICookUseCase(_GeminiAdapter(gemini));

      debugPrint('🔄 Generating new menu suggestions...');
      debugPrint(
          '   Meal: ${meal.label}, Components: ${menuComponents.length}, Count: $menuCount, Ahorro: $budgetSaverMode');

      suggestions = await useCase.executeWithMenu(
        inventory: inventoryState.ingredients,
        mealPeriod: meal,
        components: menuComponents,
        menuCount: menuCount,
        dislikedIngredients: prefsState.dislikedIngredients,
        cuisinePreference: cuisinePreference,
        recentlyUsedRecipeNames: recentlyUsed,
        userPreferences: chefPrefs,
        budgetSaverMode: budgetSaverMode,
      );

      debugPrint('✅ Generated ${suggestions.length} recipes');

      // Recalcular localmente TANTO matchPercentage como missingIngredients reales
      final viabilityCalc = CalculateRecipeViabilityUseCase();
      suggestions = suggestions.map((s) {
        final viability = viabilityCalc.execute(
          recipeIngredients: s.recipe.ingredients,
          inventory: inventoryState.ingredients,
        );
        final realMissing = _countMissingIngredients(
          s.recipe.ingredients,
          inventoryState.ingredients,
        );
        return RecipeSuggestion(
          recipe: s.recipe,
          matchPercentage: (viability * 100).round(),
          missingIngredients: realMissing,
          menuNumber: s.menuNumber,
        );
      }).toList();

      await _cacheService.saveSuggestions(suggestions, signature: signature);

      state = WhatCanICookState.success;
      _lastMealPeriod = meal;
    } catch (e) {
      debugPrint('❌ WhatCanICook AI error: $e — intentando fallback local...');
      final invState = ref.read(inventoryProvider);
      if (invState.ingredients.isNotEmpty) {
        ref.read(menuConfigProvider.notifier).update(
              mealPeriod: meal,
              components: menuComponents,
              menuCount: menuCount,
              budgetSaverMode: budgetSaverMode,
            );
        await generateRapidMenus(
          notice:
              'Chef IA remoto no disponible; mostrando sugerencias de tu recetario local.',
        );
        if (state == WhatCanICookState.success) {
          usedLocalFallback = true;
          return;
        }
      }
      errorMessage = e.toString();
      state = WhatCanICookState.error;
    }
  }

  Future<List<String>> _getRecentlyUsedRecipes() async {
    final historyService = CookingHistoryService();
    return await historyService.getRecentRecipeNames(days: 7);
  }

  /// Generate menus from LOCAL recipes (no AI), respecting selected components
  Future<void> generateRapidMenus({String? notice}) async {
    state = WhatCanICookState.loading;
    errorMessage = null;
    statusNotice = notice;
    usedLocalFallback = notice != null;
    _dismissedIds.clear();

    try {
      final inventoryNotifier = ref.read(inventoryProvider.notifier);
      await inventoryNotifier.load();
      final inventoryState = ref.read(inventoryProvider);

      if (inventoryState.ingredients.isEmpty) {
        throw Exception(
          'No tienes ingredientes en tu inventario. '
          'Agrega algunos en la pestaña de Inventario primero.',
        );
      }

      // Get menu config
      final config = ref.read(menuConfigProvider);
      final meal = config.mealPeriod ?? _getCurrentMealPeriod();
      final components = config.components;
      final menuCount = config.menuCount;

      debugPrint(
          '💨 Generating rapid menus: $menuCount menus, ${components.length} components');

      // Get user-saved recipes from provider
      final recipesState = ref.read(recipesProvider);
      final userRecipes = recipesState.recipes;

      // Get 315 MyLifeOS local recipes from asset
      final localDb = LocalRecipeDatabaseService();
      final myLifeOSRecipes = await localDb.loadRecipes();

      // Combine both sources (MyLifeOS + user recipes)
      final allRecipes = <Recipe>[];
      allRecipes.addAll(myLifeOSRecipes);
      // Add user recipes that aren't duplicates
      for (final userRecipe in userRecipes) {
        if (!allRecipes.any((r) =>
            r.name == userRecipe.name &&
            r.tipoComida == userRecipe.tipoComida)) {
          allRecipes.add(userRecipe);
        }
      }

      debugPrint(
          '   📚 Total recipes: ${allRecipes.length} (${myLifeOSRecipes.length} MyLifeOS + ${userRecipes.length} usuario)');

      // Filter by component type (match tipoComida)
      final recipesByComponent = <MenuComponent, List<Recipe>>{};
      for (final component in components) {
        // Map component's mealTypeName to actual recipe tipoComida values
        // 'almuerzo' component → 'seco' recipes (plato fuerte)
        String targetType = component.mealTypeName;
        if (targetType == 'almuerzo') targetType = 'seco';

        debugPrint(
            '   🔍 Component ${component.label} → targetType: $targetType');

        final matching = allRecipes.where((r) {
          final tipoComida = r.tipoComida?.name;
          if (tipoComida == null) return false;
          return tipoComida == targetType;
        }).toList();

        debugPrint('      Found ${matching.length} recipes');
        recipesByComponent[component] = matching;
      }

      // Organize into menus - pick different recipes when possible, allow repeats if needed
      final suggestions = <RecipeSuggestion>[];
      final viabilityCalc = CalculateRecipeViabilityUseCase();
      final usedRecipeIds = <String>{};

      for (int menuIdx = 0; menuIdx < menuCount; menuIdx++) {
        for (final component in components) {
          // Get all recipes for this component
          final allForComponent = recipesByComponent[component] ?? [];
          if (allForComponent.isEmpty) continue;

          // Prefer unused recipes, but allow repeats
          final available = allForComponent
              .where((r) => !usedRecipeIds.contains(r.id))
              .toList();

          final pool = available.isNotEmpty ? available : allForComponent;
          if (pool.isEmpty) continue;

          // Shuffle for variety
          pool.shuffle();

          // Pick best match from shuffled batch
          Recipe? bestRecipe;
          double bestMatch = -1;

          for (final recipe in pool.take(5)) {
            final viability = viabilityCalc.execute(
              recipeIngredients: recipe.ingredients,
              inventory: inventoryState.ingredients,
            );
            if (viability > bestMatch) {
              bestMatch = viability;
              bestRecipe = recipe;
            }
          }

          bestRecipe ??= pool.first;
          usedRecipeIds.add(bestRecipe.id);

          final viability = viabilityCalc.execute(
            recipeIngredients: bestRecipe.ingredients,
            inventory: inventoryState.ingredients,
          );

          suggestions.add(RecipeSuggestion(
            recipe: bestRecipe,
            matchPercentage: (viability * 100).round(),
            missingIngredients: _countMissingIngredients(
              bestRecipe.ingredients,
              inventoryState.ingredients,
            ),
            menuNumber: menuIdx + 1,
          ));
        }
      }

      if (suggestions.isEmpty) {
        throw Exception(
            'No se encontraron recetas locales para los componentes seleccionados.\n\nAgrega más recetas con diferentes tipos de comida.');
      }

      debugPrint('✅ Generated ${suggestions.length} rapid menu items');
      this.suggestions = suggestions;
      state = WhatCanICookState.success;
      _lastMealPeriod = meal;
    } catch (e) {
      errorMessage = e.toString();
      state = WhatCanICookState.error;
      debugPrint('❌ Rapid menus error: $e');
    }
  }

  void reset() {
    state = WhatCanICookState.initial;
    suggestions = [];
    errorMessage = null;
  }

  Future<SaveRecipeResult> saveSuggestion(
    RecipeSuggestion suggestion, {
    bool forceSave = false,
  }) async {
    try {
      final recipesNotifier = ref.read(recipesProvider.notifier);
      return await recipesNotifier.saveRecipeWithDuplicateCheck(
        suggestion.recipe,
        forceSave: forceSave,
      );
    } catch (e) {
      debugPrint('❌ Error saving suggestion: $e');
      return SaveRecipeResult.error(e.toString());
    }
  }

  Future<CookResult> cookSuggestion(RecipeSuggestion suggestion) async {
    try {
      final inventoryNotifier = ref.read(inventoryProvider.notifier);
      final deducted = await inventoryNotifier
          .deductRecipeIngredients(suggestion.recipe.ingredients);

      final historyService = CookingHistoryService();
      await historyService.recordCooked(suggestion.recipe.name);

      return CookResult(
        success: true,
        message: deducted.isEmpty
            ? '🍳 ¡Cocinando ${suggestion.recipe.name} (sin descuentos en despensa)!'
            : '🍳 ¡Cocinando ${suggestion.recipe.name}!',
        deducted: deducted,
      );
    } catch (e) {
      return CookResult(
        success: false,
        message: 'Error al descontar ingredientes: $e',
        deducted: [],
      );
    }
  }
}

class CookResult {
  final bool success;
  final String message;
  final List<String> deducted;

  const CookResult({
    required this.success,
    required this.message,
    required this.deducted,
  });
}

final whatCanICookProvider =
    NotifierProvider<WhatCanICookNotifier, WhatCanICookState>(() {
  return WhatCanICookNotifier();
});

class _GeminiAdapter implements IAIRecipeExtractor {
  final GeminiService gemini;
  _GeminiAdapter(this.gemini);

  @override
  Future<String?> extractRecipeJson({String? textContext, String? mediaPath}) {
    if (textContext != null && textContext.isNotEmpty) {
      return gemini.generateJsonText(
        prompt: textContext,
        mediaPaths: mediaPath != null ? [mediaPath] : const [],
      );
    }
    return gemini.extractRecipe(textContext: textContext, mediaPath: mediaPath);
  }
}
