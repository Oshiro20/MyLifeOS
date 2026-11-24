import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:core/core.dart';
import 'package:domain/domain.dart';

// ── Estado ────────────────────────────────────────────────────────────────────
class FoodCoachState {
  final MealEvaluation? currentEvaluation;
  final List<MealLog> history;
  final WeeklyStats? weeklyStats;
  final List<String> currentIngredients;
  final bool isLoading;
  final bool isEvaluating;
  final String? error;

  const FoodCoachState({
    this.currentEvaluation,
    this.history = const [],
    this.weeklyStats,
    this.currentIngredients = const [],
    this.isLoading = false,
    this.isEvaluating = false,
    this.error,
  });

  FoodCoachState copyWith({
    MealEvaluation? currentEvaluation,
    bool clearEvaluation = false,
    List<MealLog>? history,
    WeeklyStats? weeklyStats,
    List<String>? currentIngredients,
    bool? isLoading,
    bool? isEvaluating,
    String? error,
  }) =>
      FoodCoachState(
        currentEvaluation: clearEvaluation
            ? null
            : (currentEvaluation ?? this.currentEvaluation),
        history: history ?? this.history,
        weeklyStats: weeklyStats ?? this.weeklyStats,
        currentIngredients: currentIngredients ?? this.currentIngredients,
        isLoading: isLoading ?? this.isLoading,
        isEvaluating: isEvaluating ?? this.isEvaluating,
        error: error,
      );
}

// ── Notifier (Riverpod v3) ────────────────────────────────────────────────────
class FoodCoachNotifier extends Notifier<FoodCoachState> {
  IFoodCoachRepository get _repo => ref.read(foodCoachRepositoryProvider);

  @override
  FoodCoachState build() {
    Future.microtask(() => load());
    return const FoodCoachState();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final history = await _repo.getHistory();
      final stats = await _repo.getWeeklyStats();
      state = state.copyWith(
        history: history,
        weeklyStats: stats,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void addIngredient(String ingredient) {
    if (ingredient.trim().isEmpty) return;
    final trimmed = ingredient.trim().toLowerCase();
    if (!state.currentIngredients.contains(trimmed)) {
      state = state
          .copyWith(currentIngredients: [...state.currentIngredients, trimmed]);
    }
  }

  void removeIngredient(String ingredient) {
    state = state.copyWith(
        currentIngredients:
            state.currentIngredients.where((i) => i != ingredient).toList());
  }

  void clearIngredients() => state = state.copyWith(currentIngredients: []);

  Future<void> evaluate({
    String? photoPath,
    String? mealName,
    MealSlot? mealSlot,
    CookingMethod? cookingMethod,
    double servings = 1.0,
    String? recipeContext,
    MealMacros? recipeBaseMacros,
  }) async {
    final hasPhoto = photoPath != null && photoPath.isNotEmpty;
    if (state.currentIngredients.isEmpty && !hasPhoto) return;
    state = state.copyWith(isEvaluating: true, error: null);
    try {
      final eval = await _repo.evaluateMeal(
        ingredients: state.currentIngredients,
        photoPath: photoPath,
        mealName: mealName,
        mealSlot: mealSlot,
        cookingMethod: cookingMethod,
        servings: servings,
        recipeContext: recipeContext,
        recipeBaseMacros: recipeBaseMacros,
      );
      final history = await _repo.getHistory();
      final stats = await _repo.getWeeklyStats();
      state = state.copyWith(
        currentEvaluation: eval,
        history: history,
        weeklyStats: stats,
        isEvaluating: false,
        currentIngredients: [],
      );
      ref.read(todayMacrosRefreshTickProvider.notifier).bump();
    } catch (e) {
      state = state.copyWith(isEvaluating: false, error: e.toString());
    }
  }

  Future<void> deleteFromHistory(String id) async {
    try {
      await _repo.deleteFromHistory(id);
      final history = await _repo.getHistory();
      final stats = await _repo.getWeeklyStats();
      state = state.copyWith(history: history, weeklyStats: stats, error: null);
      ref.read(todayMacrosRefreshTickProvider.notifier).bump();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clearResult() => state = state.copyWith(clearEvaluation: true);
  void clearError() => state = state.copyWith(error: null);
}

/// Contador diario de vasos de agua (persistido por fecha en SharedPreferences).
class DailyWaterNotifier extends Notifier<int> {
  bool _loaded = false;
  Future<void>? _loadFuture;

  static String _todayKey() {
    final now = DateTime.now();
    return 'foodcoach_water_${now.year}_${now.month}_${now.day}';
  }

  @override
  int build() {
    _loaded = false;
    _loadFuture = null;
    Future.microtask(load);
    return 0;
  }

  Future<void> load() => _loadFuture ??= _readFromPrefs();

  Future<void> _readFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_todayKey()) ?? 0;
      if (!_loaded) {
        _loaded = true;
        state = saved;
      }
    } catch (_) {
      _loaded = true;
    }
  }

  Future<void> setGlasses(int next) async {
    if (!_loaded) await load();
    final clamped = next.clamp(0, 20);
    state = clamped;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_todayKey(), clamped);
    } catch (_) {}
  }

  Future<void> increment() async {
    if (!_loaded) await load();
    await setGlasses(state + 1);
  }

  Future<void> decrement() async {
    if (!_loaded) await load();
    await setGlasses(state - 1);
  }
}

/// Meta nutricional activa sincronizada desde Cocina (`cocina_active_nutrition_goal_v1`).
final foodCoachNutritionGoalProvider =
    FutureProvider<NutritionGoal>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('cocina_active_nutrition_goal_v1');
    if (saved != null) {
      for (final g in NutritionGoal.values) {
        if (g.name == saved) return g;
      }
    }
  } catch (_) {}
  return NutritionGoal.maintain;
});

// ── Providers ─────────────────────────────────────────────────────────────────
final foodCoachRepositoryProvider = Provider<IFoodCoachRepository>((ref) {
  throw UnimplementedError(
      'Provide IFoodCoachRepository via ProviderScope.overrides');
});

final foodCoachProvider =
    NotifierProvider<FoodCoachNotifier, FoodCoachState>(FoodCoachNotifier.new);

final dailyWaterProvider =
    NotifierProvider<DailyWaterNotifier, int>(DailyWaterNotifier.new);
