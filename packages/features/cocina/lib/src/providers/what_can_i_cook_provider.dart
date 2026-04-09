import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';
import 'package:core/core.dart';
import '../providers/cocina_providers.dart';
import '../providers/user_food_preferences_provider.dart';
import '../providers/chef_preferences_provider.dart';
import '../utils/cooking_history_service.dart';
import '../utils/suggestions_cache_service.dart';

enum WhatCanICookState { initial, loading, success, error }

/// Determines current meal period based on time of day
String _getCurrentMealPeriod() {
  final hour = DateTime.now().hour;
  if (hour < 10) return 'desayuno';
  if (hour < 17) return 'almuerzo';
  return 'cena';
}

class WhatCanICookNotifier extends Notifier<WhatCanICookState> {
  List<RecipeSuggestion> suggestions = [];
  String? errorMessage;
  String? _lastMealPeriod;
  SuggestionMode _currentMode = SuggestionMode.now;

  // Dismissed recipe IDs (user doesn't want to see these)
  final Set<String> _dismissedIds = {};

  // Cooked recipe IDs (history)
  final Set<String> _cookedIds = {};

  // Cache service
  final _cacheService = SuggestionsCacheService();

  /// Get currently visible suggestions (excluding dismissed)
  List<RecipeSuggestion> get visibleSuggestions =>
      suggestions.where((s) => !_dismissedIds.contains(s.recipe.id)).toList();

  /// Dismiss a recipe (user doesn't want to see it)
  void dismissRecipe(String recipeId) {
    _dismissedIds.add(recipeId);
    // Trigger UI update
    state = state;
  }

  /// Mark a recipe as cooked
  void markAsCooked(String recipeId) {
    _cookedIds.add(recipeId);
  }

  /// Get current suggestion mode

  @override
  WhatCanICookState build() {
    return WhatCanICookState.initial;
  }

  /// Checks if a refresh is needed based on meal period change
  /// Auto-refresh only 3 times a day at meal transitions:
  /// - Before 10:00 (breakfast)
  /// - 10:00-17:00 (lunch)
  /// - After 17:00 (dinner)
  bool get needsRefresh {
    final currentPeriod = _getCurrentMealPeriod();
    // First time ever - load
    if (_lastMealPeriod == null) return true;
    // Only refresh when meal period changes (3 times a day max)
    if (_lastMealPeriod != currentPeriod) return true;
    // Don't auto-refresh otherwise - user can manually refresh
    return false;
  }

  /// Returns current meal period label with emoji
  String get currentMealLabel {
    final period = _getCurrentMealPeriod();
    switch (period) {
      case 'desayuno':
        return '🌅 Desayuno';
      case 'almuerzo':
        return '🍛 Almuerzo';
      case 'cena':
        return '🌙 Cena';
      default:
        return '🍽️ Recetas';
    }
  }

  /// Current suggestion mode
  SuggestionMode get currentMode => _currentMode;

  /// Refresh suggestions with optional cuisine preference
  Future<void> generateSuggestions({
    String? cuisinePreference,
    SuggestionMode? mode,
    bool forceRefresh = false,
  }) async {
    if (mode != null) _currentMode = mode;

    // Try to load from cache first (unless force refresh)
    if (!forceRefresh) {
      final cachedSuggestions = await _cacheService.getCachedSuggestions();
      if (cachedSuggestions != null && cachedSuggestions.isNotEmpty) {
        suggestions = cachedSuggestions;
        state = WhatCanICookState.success;
        _lastMealPeriod = _getCurrentMealPeriod();
        debugPrint('✅ Suggestions loaded from cache');
        return;
      }
    }

    state = WhatCanICookState.loading;
    errorMessage = null;

    try {
      // Get inventory from cocina provider
      final inventoryNotifier = ref.read(inventoryProvider.notifier);
      await inventoryNotifier.load();
      final inventoryState = ref.read(inventoryProvider);

      if (inventoryState.ingredients.isEmpty) {
        throw Exception(
          'No tienes ingredientes en tu inventario. '
          'Agrega algunos en la pestaña de Inventario primero.',
        );
      }

      // Get disliked ingredients
      final prefsState = ref.read(userFoodPreferencesProvider);

      // Get chef preferences (optional user profile)
      final chefPrefs = ref.read(chefPreferencesProvider);

      // Get recently used recipes (last 7 days) for week variety
      final recentlyUsed = await _getRecentlyUsedRecipes();

      // Create the use case with Gemini adapter
      final gemini = ref.read(geminiProvider);
      final useCase = WhatCanICookUseCase(_GeminiAdapter(gemini));

      suggestions = await useCase.execute(
        inventory: inventoryState.ingredients,
        maxSuggestions: _currentMode == SuggestionMode.menu ? 4 : 5,
        dislikedIngredients: prefsState.dislikedIngredients,
        cuisinePreference: cuisinePreference,
        recentlyUsedRecipeNames: recentlyUsed,
        mode: _currentMode,
        userPreferences: chefPrefs,
      );

      // Recalculate match percentages using local viability calculator
      // instead of relying on AI-estimated numbers
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

      // Cache the suggestions
      await _cacheService.saveSuggestions(suggestions);

      state = WhatCanICookState.success;
      _lastMealPeriod = _getCurrentMealPeriod();
    } catch (e) {
      errorMessage = e.toString();
      state = WhatCanICookState.error;
    }
  }

  /// Get recipes used in the last 7 days (from persistent storage)
  Future<List<String>> _getRecentlyUsedRecipes() async {
    final historyService = CookingHistoryService();
    return await historyService.getRecentRecipeNames(days: 7);
  }

  void reset() {
    state = WhatCanICookState.initial;
    suggestions = [];
    errorMessage = null;
    _cacheService.clearCache();
  }

  /// Clear suggestions cache (user can call this manually)
  Future<void> clearCache() async {
    await _cacheService.clearCache();
  }

  /// Check if we have valid cached suggestions
  Future<bool> hasCachedSuggestions() async {
    return await _cacheService.hasValidCache();
  }

  /// Save a suggested recipe to the database with duplicate check.
  /// Returns [SaveRecipeResult] indicating success or duplicates found.
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

  /// Cook a suggested recipe (deduct ingredients from pantry)
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

      // Record in cooking history
      final historyService = CookingHistoryService();
      await historyService.recordCooked(suggestion.recipe.name);
      _cookedIds.add(suggestion.recipe.id);

      return CookResult(
        success: true,
        message:
            '🍳 ¡Cocinando ${suggestion.recipe.name}! Ingredientes descontados.',
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

/// Result of cooking a recipe
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

// Adapter to use GeminiService with IAIRecipeExtractor interface
class _GeminiAdapter implements IAIRecipeExtractor {
  final GeminiService gemini;
  _GeminiAdapter(this.gemini);

  @override
  Future<String?> extractRecipeJson({String? textContext, String? mediaPath}) {
    return gemini.extractRecipe(textContext: textContext, mediaPath: mediaPath);
  }
}
