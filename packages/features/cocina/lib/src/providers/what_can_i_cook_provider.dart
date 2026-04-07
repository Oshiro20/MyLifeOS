import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';
import 'package:core/core.dart';
import '../providers/cocina_providers.dart';
import '../providers/user_food_preferences_provider.dart';

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
  DateTime? _lastRefreshTime;

  @override
  WhatCanICookState build() {
    return WhatCanICookState.initial;
  }

  /// Checks if a refresh is needed based on meal period change or manual refresh
  bool get needsRefresh {
    final currentPeriod = _getCurrentMealPeriod();
    // Refresh if it's a new meal period or if it's been more than 2 hours
    if (_lastMealPeriod == null) return true;
    if (_lastMealPeriod != currentPeriod) return true;
    if (_lastRefreshTime != null &&
        DateTime.now().difference(_lastRefreshTime!).inHours > 2) {
      return true;
    }
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

  /// Refresh suggestions with optional cuisine preference
  Future<void> generateSuggestions({String? cuisinePreference}) async {
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

      // Get recently used recipes (last 7 days) for week variety
      final recentlyUsed = _getRecentlyUsedRecipes();

      // Create the use case with Gemini adapter
      final gemini = ref.read(geminiServiceProvider);
      final useCase = WhatCanICookUseCase(_GeminiAdapter(gemini));

      suggestions = await useCase.execute(
        inventory: inventoryState.ingredients,
        maxSuggestions: 5,
        dislikedIngredients: prefsState.dislikedIngredients,
        cuisinePreference: cuisinePreference,
        recentlyUsedRecipeNames: recentlyUsed,
      );

      state = WhatCanICookState.success;
      _lastMealPeriod = _getCurrentMealPeriod();
      _lastRefreshTime = DateTime.now();
    } catch (e) {
      errorMessage = e.toString();
      state = WhatCanICookState.error;
    }
  }

  /// Get recipes used in the last 7 days (from local storage or cooking history)
  List<String> _getRecentlyUsedRecipes() {
    // TODO: Implement persistent storage of cooking history
    // For now, this returns an empty list
    // In the future, this should read from a SQLite table or SharedPreferences
    return [];
  }

  void reset() {
    state = WhatCanICookState.initial;
    suggestions = [];
    errorMessage = null;
  }

  /// Save a suggested recipe to the database
  Future<bool> saveSuggestion(RecipeSuggestion suggestion) async {
    try {
      final recipesNotifier = ref.read(recipesProvider.notifier);
      await recipesNotifier.saveRecipe(suggestion.recipe);
      return true;
    } catch (e) {
      debugPrint('❌ Error saving suggestion: $e');
      return false;
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
