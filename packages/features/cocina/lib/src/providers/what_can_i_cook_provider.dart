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
    required NutritionGoal nutritionGoal,
    required List<InventoryIngredient> ingredients,
  }) {
    final compNames = components.map((c) => c.name).toList()..sort();
    final ingNames = ingredients.map((i) => i.name.toLowerCase()).toList()
      ..sort();
    return '${meal.name}|${compNames.join(',')}|$menuCount|${cuisinePreference ?? ''}|$budgetSaverMode|${nutritionGoal.name}|${ingNames.join(',')}';
  }

  static int _countMissingIngredients(
    List<RecipeIngredient> recipeIngredients,
    List<InventoryIngredient> inventory, {
    Map<String, double>? customGramsPerUnit,
  }) {
    final checks = IngredientMatcher.evaluateRecipe(
      recipeIngredients: recipeIngredients,
      inventory: inventory.where((i) => i.quantity > 0).toList(),
      customGramsPerUnit: customGramsPerUnit,
    );
    return checks
        .where((c) => c.availability != IngredientAvailability.available)
        .length;
  }

  static double _scoreRecipeForGoal(Recipe recipe, NutritionGoal goal) {
    var bonus = 0.0;
    if (recipe.goal == goal && goal != NutritionGoal.maintain) {
      bonus += 0.35;
    }

    final text = IngredientMatcher.normalizeText(
      '${recipe.name} ${recipe.description} ${recipe.tags.join(' ')}',
    );
    final kcal = recipe.caloriasAproximadas;

    switch (goal) {
      case NutritionGoal.loseWeight:
        if (kcal != null) {
          if (kcal <= 420) bonus += 0.25;
          if (kcal >= 650) bonus -= 0.25;
        }
        if (RegExp(
                r'\b(ensalada|plancha|vapor|horno|liger|light|pavo|pollo|pescado|verdur)\b')
            .hasMatch(text)) {
          bonus += 0.25;
        }
        if (RegExp(r'\b(frit|chicharron|tocino|manteca|azucar|helado|torta)\b')
            .hasMatch(text)) {
          bonus -= 0.35;
        }
        break;
      case NutritionGoal.gainMuscle:
        if (kcal != null && kcal >= 480) bonus += 0.25;
        if (RegExp(
                r'\b(pollo|carne|res|pescado|atun|huevo|quinua|avena|lentej|frijol|garbanz|batido|prote)\b')
            .hasMatch(text)) {
          bonus += 0.30;
        }
        break;
      case NutritionGoal.light:
        if (kcal != null && kcal <= 380) bonus += 0.25;
        if (RegExp(
                r'\b(sopa|crema|caldo|vapor|plancha|hervid|manzanilla|fruta|suave|liger)\b')
            .hasMatch(text)) {
          bonus += 0.30;
        }
        if (RegExp(r'\b(frit|picante|rocoto|aji|cerdo|chancho|embutid)\b')
            .hasMatch(text)) {
          bonus -= 0.30;
        }
        break;
      case NutritionGoal.maintain:
      case NutritionGoal.other:
        break;
    }
    return bonus;
  }

  Future<void> generateSuggestions({
    MealPeriod? mealPeriod,
    List<MenuComponent>? components,
    int menuCount = 3,
    String? cuisinePreference,
    bool budgetSaverMode = false,
    NutritionGoal? nutritionGoal,
    bool forceRefresh = false,
  }) async {
    final menuComponents = (components != null && components.isNotEmpty)
        ? components
        : [MenuComponent.platoFuerte];
    final meal = mealPeriod ?? _getCurrentMealPeriod();
    final goal = nutritionGoal ?? ref.read(recipesProvider).activeGoal;

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
        nutritionGoal: goal,
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
          '   Meal: ${meal.label}, Components: ${menuComponents.length}, Count: $menuCount, Ahorro: $budgetSaverMode, Meta: ${goal.label}');

      var generated = await useCase.executeWithMenu(
        inventory: inventoryState.ingredients,
        mealPeriod: meal,
        components: menuComponents,
        menuCount: menuCount,
        dislikedIngredients: prefsState.dislikedIngredients,
        cuisinePreference: cuisinePreference,
        recentlyUsedRecipeNames: recentlyUsed,
        userPreferences: chefPrefs,
        budgetSaverMode: budgetSaverMode,
        nutritionGoal: goal,
      );

      debugPrint('✅ Generated ${generated.length} recipes');

      // Recalcular localmente TANTO matchPercentage como missingIngredients reales
      final equivalences = ref.read(ingredientEquivalencesProvider);
      final viabilityCalc = CalculateRecipeViabilityUseCase();
      generated = generated.map((s) {
        final viability = viabilityCalc.execute(
          recipeIngredients: s.recipe.ingredients,
          inventory: inventoryState.ingredients,
          customGramsPerUnit: equivalences,
        );
        final realMissing = _countMissingIngredients(
          s.recipe.ingredients,
          inventoryState.ingredients,
          customGramsPerUnit: equivalences,
        );
        return RecipeSuggestion(
          recipe: s.recipe,
          matchPercentage: (viability * 100).round(),
          missingIngredients: realMissing,
          menuNumber: s.menuNumber,
        );
      }).toList();

      // Si la IA devolvió menos menús distintos de los solicitados, completar con recetario local.
      final distinctMenus =
          generated.map((s) => s.menuNumber ?? 1).toSet().length;
      if (distinctMenus < menuCount) {
        final missingMenus = menuCount - distinctMenus;
        final extraLocal = await _buildLocalMenus(
          inventory: inventoryState.ingredients,
          components: menuComponents,
          menuCount: missingMenus,
          startMenuNumber: distinctMenus + 1,
          goal: goal,
          budgetSaverMode: budgetSaverMode,
          excludeNames:
              generated.map((s) => s.recipe.name.toLowerCase()).toSet(),
        );
        if (extraLocal.isNotEmpty) {
          generated = [...generated, ...extraLocal];
          statusNotice =
              'La IA generó $distinctMenus menú(s); se completaron los faltantes desde tu recetario local.';
        }
      }

      suggestions = generated;
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
          nutritionGoal: goal,
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

  /// Construye [menuCount] menús desde el recetario local priorizando despensa, meta y ahorro.
  Future<List<RecipeSuggestion>> _buildLocalMenus({
    required List<InventoryIngredient> inventory,
    required List<MenuComponent> components,
    required int menuCount,
    int startMenuNumber = 1,
    required NutritionGoal goal,
    bool budgetSaverMode = false,
    Set<String> excludeNames = const {},
  }) async {
    final userRecipes = ref.read(recipesProvider).recipes;
    final myLifeOSRecipes = await LocalRecipeDatabaseService().loadRecipes();

    final allRecipes = <Recipe>[...myLifeOSRecipes];
    for (final userRecipe in userRecipes) {
      if (!allRecipes.any((r) =>
          r.name == userRecipe.name && r.tipoComida == userRecipe.tipoComida)) {
        allRecipes.add(userRecipe);
      }
    }

    final recipesByComponent = <MenuComponent, List<Recipe>>{};
    for (final component in components) {
      var targetType = component.mealTypeName;
      if (targetType == 'almuerzo') targetType = 'seco';
      recipesByComponent[component] = allRecipes.where((r) {
        final tipoComida = r.tipoComida?.name;
        return tipoComida == targetType;
      }).toList();
    }

    final equivalences = ref.read(ingredientEquivalencesProvider);
    final out = <RecipeSuggestion>[];
    final viabilityCalc = CalculateRecipeViabilityUseCase();
    final usedIds = <String>{};
    final usedNames = <String>{...excludeNames};

    for (int menuIdx = 0; menuIdx < menuCount; menuIdx++) {
      for (final component in components) {
        final allForComponent = recipesByComponent[component] ?? const [];
        if (allForComponent.isEmpty) continue;

        final unused = allForComponent
            .where((r) =>
                !usedIds.contains(r.id) &&
                !usedNames.contains(r.name.toLowerCase()))
            .toList();
        final pool =
            List<Recipe>.from(unused.isNotEmpty ? unused : allForComponent);
        if (pool.isEmpty) continue;

        pool.shuffle();

        Recipe? bestRecipe;
        var bestScore = -999.0;
        var bestViability = 0.0;

        for (final recipe in pool.take(15)) {
          final viability = viabilityCalc.execute(
            recipeIngredients: recipe.ingredients,
            inventory: inventory,
            customGramsPerUnit: equivalences,
          );
          final goalBonus = _scoreRecipeForGoal(recipe, goal);
          final score = viability * (budgetSaverMode ? 1.5 : 1.0) + goalBonus;
          if (score > bestScore) {
            bestScore = score;
            bestRecipe = recipe;
            bestViability = viability;
          }
        }

        bestRecipe ??= pool.first;
        usedIds.add(bestRecipe.id);
        usedNames.add(bestRecipe.name.toLowerCase());

        out.add(RecipeSuggestion(
          recipe: bestRecipe,
          matchPercentage: (bestViability * 100).round(),
          missingIngredients: _countMissingIngredients(
            bestRecipe.ingredients,
            inventory,
            customGramsPerUnit: equivalences,
          ),
          menuNumber: startMenuNumber + menuIdx,
        ));
      }
    }
    return out;
  }

  /// Generate menus from LOCAL recipes (no AI), respecting selected components and goal
  Future<void> generateRapidMenus({
    String? notice,
    NutritionGoal? nutritionGoal,
  }) async {
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

      final config = ref.read(menuConfigProvider);
      final meal = config.mealPeriod ?? _getCurrentMealPeriod();
      final components = config.components;
      final menuCount = config.menuCount;
      final goal = nutritionGoal ?? ref.read(recipesProvider).activeGoal;

      debugPrint(
          '💨 Generating rapid menus: $menuCount menus, ${components.length} components, Meta: ${goal.label}');

      final built = await _buildLocalMenus(
        inventory: inventoryState.ingredients,
        components: components,
        menuCount: menuCount,
        goal: goal,
        budgetSaverMode: config.budgetSaverMode,
      );

      if (built.isEmpty) {
        throw Exception(
            'No se encontraron recetas locales para los componentes seleccionados.\n\nAgrega más recetas con diferentes tipos de comida.');
      }

      debugPrint('✅ Generated ${built.length} rapid menu items');
      suggestions = built;
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
