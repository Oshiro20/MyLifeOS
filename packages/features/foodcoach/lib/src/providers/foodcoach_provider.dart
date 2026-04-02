import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/src/foodcoach/entities/meal_evaluation.dart';
import 'package:domain/src/foodcoach/repositories/i_foodcoach_repository.dart';

// ── Estado ────────────────────────────────────────────────────────────────────
class FoodCoachState {
  final MealEvaluation? currentEvaluation;
  final List<MealLog> history;
  final WeeklyStats? weeklyStats;
  final List<String> currentIngredients;
  final bool isEvaluating;
  final String? error;

  const FoodCoachState({
    this.currentEvaluation,
    this.history = const [],
    this.weeklyStats,
    this.currentIngredients = const [],
    this.isEvaluating = false,
    this.error,
  });

  FoodCoachState copyWith({
    MealEvaluation? currentEvaluation,
    List<MealLog>? history,
    WeeklyStats? weeklyStats,
    List<String>? currentIngredients,
    bool? isEvaluating,
    String? error,
  }) =>
      FoodCoachState(
        currentEvaluation: currentEvaluation ?? this.currentEvaluation,
        history: history ?? this.history,
        weeklyStats: weeklyStats ?? this.weeklyStats,
        currentIngredients: currentIngredients ?? this.currentIngredients,
        isEvaluating: isEvaluating ?? this.isEvaluating,
        error: error,
      );
}

// ── Notifier (Riverpod v3) ────────────────────────────────────────────────────
class FoodCoachNotifier extends Notifier<FoodCoachState> {
  IFoodCoachRepository get _repo => ref.read(foodCoachRepositoryProvider);

  @override
  FoodCoachState build() {
    Future.microtask(() => _load());
    return const FoodCoachState();
  }

  Future<void> _load() async {
    try {
      final history = await _repo.getHistory();
      final stats = await _repo.getWeeklyStats();
      state = state.copyWith(history: history, weeklyStats: stats);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void addIngredient(String ingredient) {
    if (ingredient.trim().isEmpty) return;
    final trimmed = ingredient.trim().toLowerCase();
    if (!state.currentIngredients.contains(trimmed)) {
      state = state.copyWith(
          currentIngredients: [...state.currentIngredients, trimmed]);
    }
  }

  void removeIngredient(String ingredient) {
    state = state.copyWith(
        currentIngredients:
            state.currentIngredients.where((i) => i != ingredient).toList());
  }

  void clearIngredients() => state = state.copyWith(currentIngredients: []);

  Future<void> evaluate({String? photoPath}) async {
    if (state.currentIngredients.isEmpty) return;
    state = state.copyWith(isEvaluating: true, error: null);
    try {
      final eval = await _repo.evaluateMeal(
        ingredients: state.currentIngredients,
        photoPath: photoPath,
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
    } catch (e) {
      state = state.copyWith(isEvaluating: false, error: e.toString());
    }
  }

  Future<void> deleteFromHistory(String id) async {
    await _repo.deleteFromHistory(id);
    final history = await _repo.getHistory();
    final stats = await _repo.getWeeklyStats();
    state = state.copyWith(history: history, weeklyStats: stats);
  }

  void clearResult() => state = state.copyWith(currentEvaluation: null);
  void clearError() => state = state.copyWith(error: null);
}

// ── Providers ─────────────────────────────────────────────────────────────────
final foodCoachRepositoryProvider = Provider<IFoodCoachRepository>((ref) {
  throw UnimplementedError(
      'Provide IFoodCoachRepository via ProviderScope.overrides');
});

final foodCoachProvider =
    NotifierProvider<FoodCoachNotifier, FoodCoachState>(FoodCoachNotifier.new);
