import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';
import 'package:core/core.dart';
import '../providers/cocina_providers.dart';

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

      // Create the use case with Gemini adapter
      final gemini = ref.read(geminiServiceProvider);
      final useCase = WhatCanICookUseCase(_GeminiAdapter(gemini));

      suggestions = await useCase.execute(
        inventory: inventoryState.ingredients,
        maxSuggestions: 5,
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
