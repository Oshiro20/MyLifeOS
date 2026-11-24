import 'dart:convert';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'body_profile_service.dart';
import 'ingredient_price_and_wallet_bridge.dart';

/// Carga de una comida desde Cocina hacia FoodCoach sin acoplar feature packages.
class PendingMealEvaluation {
  final String recipeName;
  final List<String> ingredients;
  final String? recipeContext;
  final CookingMethod? cookingMethod;
  final double servings;
  final MealMacros? baseMacros;

  const PendingMealEvaluation({
    required this.recipeName,
    required this.ingredients,
    this.recipeContext,
    this.cookingMethod,
    this.servings = 1.0,
    this.baseMacros,
  });
}

class PendingMealEvaluationNotifier extends Notifier<PendingMealEvaluation?> {
  @override
  PendingMealEvaluation? build() => null;

  void queue({
    required String recipeName,
    required List<String> ingredients,
    String? recipeContext,
    CookingMethod? cookingMethod,
    double servings = 1.0,
    MealMacros? baseMacros,
  }) {
    state = PendingMealEvaluation(
      recipeName: recipeName,
      ingredients: ingredients,
      recipeContext: recipeContext,
      cookingMethod: cookingMethod,
      servings: servings,
      baseMacros: baseMacros,
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

/// Proveedor desacoplado para consultar las estadísticas semanales/diarias de FoodCoach
/// desde Cocina o Inicio sin acoplar feature packages.
final todayMealStatsFeedProvider = Provider<Future<WeeklyStats?> Function()>(
  (ref) => () async => null,
);

/// Contador reactivo que FoodCoach incrementa al guardar o eliminar una comida
/// para refrescar automáticamente el saldo nutricional restante en Cocina.
class TodayMacrosRefreshTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final todayMacrosRefreshTickProvider =
    NotifierProvider<TodayMacrosRefreshTickNotifier, int>(
  TodayMacrosRefreshTickNotifier.new,
);

/// Saldo nutricional restante del día calculado desde el Perfil Corporal compartido
/// y lo ya consumido hoy en FoodCoach.
final dailyMacroBudgetProvider = FutureProvider<DailyMacroBudget?>((ref) async {
  ref.watch(todayMacrosRefreshTickProvider);
  final profile = ref.watch(bodyProfileProvider);
  final statsFeed = ref.watch(todayMealStatsFeedProvider);

  NutritionGoal? cocinaGoal;
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(BodyProfileNotifier.cocinaGoalKey);
    if (saved != null) {
      for (final g in NutritionGoal.values) {
        if (g.name == saved) {
          cocinaGoal = g;
          break;
        }
      }
    }
  } catch (_) {}

  final targets = BodyNutritionCalculator.calculateTargets(
    profile,
    fallbackGoal: cocinaGoal,
  );
  final stats = await statsFeed();

  // Si no hay perfil personalizado ni comidas registradas hoy, no mostrar saldo inventado.
  if (!targets.isPersonalized && (stats == null || stats.todayCalories == 0)) {
    return null;
  }

  return DailyMacroBudget(
    targets: targets,
    consumedCalories: stats?.todayCalories ?? 0,
    consumedProtein: stats?.todayProtein ?? 0,
    consumedCarbs: stats?.todayCarbs ?? 0,
    consumedFat: stats?.todayFat ?? 0,
  );
});

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
