import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';
import 'package:core/core.dart';
import '../providers/cocina_providers.dart';
import '../providers/user_food_preferences_provider.dart';

enum WhatCanICookState { initial, loading, success, error }

class WhatCanICookNotifier extends Notifier<WhatCanICookState> {
  List<RecipeSuggestion> suggestions = [];
  String? errorMessage;

  @override
  WhatCanICookState build() {
    return WhatCanICookState.initial;
  }

  Future<void> generateSuggestions() async {
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

      // Create the use case with Gemini adapter
      final gemini = ref.read(geminiServiceProvider);
      final useCase = WhatCanICookUseCase(_GeminiAdapter(gemini));

      suggestions = await useCase.execute(
        inventory: inventoryState.ingredients,
        maxSuggestions: 5,
        dislikedIngredients: prefsState.dislikedIngredients,
      );

      state = WhatCanICookState.success;
    } catch (e) {
      errorMessage = e.toString();
      state = WhatCanICookState.error;
    }
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
