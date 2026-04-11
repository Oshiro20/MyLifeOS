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

class WhatCanICookNotifier extends Notifier<WhatCanICookState> {
  List<RecipeSuggestion> suggestions = [];
  String? errorMessage;
  MealPeriod? _lastMealPeriod;

  final Set<String> _dismissedIds = {};
  final _cacheService = SuggestionsCacheService();

  List<RecipeSuggestion> get visibleSuggestions =>
      suggestions.where((s) => !_dismissedIds.contains(s.recipe.id)).toList();

  void dismissRecipe(String recipeId) {
    _dismissedIds.add(recipeId);
    state = state;
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

  Future<void> generateSuggestions({
    MealPeriod? mealPeriod,
    List<MenuComponent>? components,
    int menuCount = 3,
    String? cuisinePreference,
    bool forceRefresh = false,
  }) async {
    // ALWAYS force refresh when user explicitly generates
    // The cache was causing stale results when parameters changed
    final cached =
        forceRefresh ? null : await _cacheService.getCachedSuggestions();
    if (cached != null && cached.isNotEmpty) {
      suggestions = cached;
      state = WhatCanICookState.success;
      return;
    }

    state = WhatCanICookState.loading;
    errorMessage = null;

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

      final prefsState = ref.read(userFoodPreferencesProvider);
      final chefPrefs = ref.read(chefPreferencesProvider);
      final recentlyUsed = await _getRecentlyUsedRecipes();
      final gemini = ref.read(geminiProvider);
      final useCase = WhatCanICookUseCase(_GeminiAdapter(gemini));

      // Build the menu context from components
      final menuComponents = components ?? [MenuComponent.platoFuerte];
      final meal = mealPeriod ?? _getCurrentMealPeriod();

      debugPrint('🔄 Generating new menu suggestions...');
      debugPrint(
          '   Meal: ${meal.label}, Components: ${menuComponents.length}, Count: $menuCount');

      suggestions = await useCase.executeWithMenu(
        inventory: inventoryState.ingredients,
        mealPeriod: meal,
        components: menuComponents,
        menuCount: menuCount,
        dislikedIngredients: prefsState.dislikedIngredients,
        cuisinePreference: cuisinePreference,
        recentlyUsedRecipeNames: recentlyUsed,
        userPreferences: chefPrefs,
      );

      debugPrint('✅ Generated ${suggestions.length} recipes');

      // Recalculate match percentages
      final viabilityCalc = CalculateRecipeViabilityUseCase();
      suggestions = suggestions.map((s) {
        final viability = viabilityCalc.execute(
          recipeIngredients: s.recipe.ingredients,
          inventory: inventoryState.ingredients,
        );
        return RecipeSuggestion(
          recipe: s.recipe,
          matchPercentage: (viability * 100).round(),
          missingIngredients: s.missingIngredients,
        );
      }).toList();

      await _cacheService.saveSuggestions(suggestions);

      state = WhatCanICookState.success;
      _lastMealPeriod = meal;
    } catch (e) {
      errorMessage = e.toString();
      state = WhatCanICookState.error;
      debugPrint('❌ WhatCanICook error: $e');
    }
  }

  Future<List<String>> _getRecentlyUsedRecipes() async {
    final historyService = CookingHistoryService();
    return await historyService.getRecentRecipeNames(days: 7);
  }

  void reset() {
    state = WhatCanICookState.initial;
    suggestions = [];
    errorMessage = null;
  }

  Future<SaveRecipeResult> saveSuggestion(RecipeSuggestion suggestion) async {
    try {
      final recipesNotifier = ref.read(recipesProvider.notifier);
      return await recipesNotifier
          .saveRecipeWithDuplicateCheck(suggestion.recipe);
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

      if (deducted.isEmpty) {
        return const CookResult(
          success: false,
          message: 'No tienes ingredientes coincidentes en tu despensa.',
          deducted: [],
        );
      }

      final historyService = CookingHistoryService();
      await historyService.recordCooked(suggestion.recipe.name);

      return CookResult(
        success: true,
        message: '🍳 ¡Cocinando ${suggestion.recipe.name}!',
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
    return gemini.extractRecipe(textContext: textContext, mediaPath: mediaPath);
  }
}
