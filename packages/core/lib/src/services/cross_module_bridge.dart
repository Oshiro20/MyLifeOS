import 'dart:convert';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ingredient_price_and_wallet_bridge.dart';

/// Carga de una comida desde Cocina hacia FoodCoach sin acoplar feature packages.
class PendingMealEvaluation {
  final String recipeName;
  final List<String> ingredients;

  const PendingMealEvaluation({
    required this.recipeName,
    required this.ingredients,
  });
}

class PendingMealEvaluationNotifier extends Notifier<PendingMealEvaluation?> {
  @override
  PendingMealEvaluation? build() => null;

  void queue({required String recipeName, required List<String> ingredients}) {
    state = PendingMealEvaluation(
      recipeName: recipeName,
      ingredients: ingredients,
    );
  }

  void clear() => state = null;
}

final pendingMealEvaluationProvider =
    NotifierProvider<PendingMealEvaluationNotifier, PendingMealEvaluation?>(
  PendingMealEvaluationNotifier.new,
);

/// Proveedores desacoplados para leer despensa y recetas desde otros módulos (ej. FoodCoach).
final pantryIngredientsFeedProvider =
    Provider<Future<List<InventoryIngredient>> Function()>(
  (ref) => () async => const [],
);

final recipesFeedProvider = Provider<Future<List<Recipe>> Function()>(
  (ref) => () async => const [],
);

/// Callback desacoplado para importar compras detectadas de WalletAI a Despensa.
final walletPantryDirectImportProvider = Provider<
    Future<int> Function(List<WalletGroceryCandidate> candidates)?>(
  (ref) => null,
);

/// Devuelve nombres de recetas cocinadas recientemente (últimos 7 días) desde SharedPreferences.
final recentCookedNamesProvider = FutureProvider<List<String>>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cooking_history');
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return decoded
        .whereType<Map<String, dynamic>>()
        .where((e) {
          final iso = e['cookedAt']?.toString();
          if (iso == null) return false;
          final dt = DateTime.tryParse(iso);
          return dt != null && dt.isAfter(cutoff);
        })
        .map((e) => e['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
  } catch (_) {
    return const [];
  }
});
