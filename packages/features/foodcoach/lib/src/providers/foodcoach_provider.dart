import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        currentEvaluation:
            clearEvaluation ? null : (currentEvaluation ?? this.currentEvaluation),
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

  Future<void> evaluate({String? photoPath}) async {
    final hasPhoto = photoPath != null && photoPath.isNotEmpty;
    if (state.currentIngredients.isEmpty && !hasPhoto) return;
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
    try {
      await _repo.deleteFromHistory(id);
      final history = await _repo.getHistory();
      final stats = await _repo.getWeeklyStats();
      state = state.copyWith(history: history, weeklyStats: stats, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clearResult() => state = state.copyWith(clearEvaluation: true);
  void clearError() => state = state.copyWith(error: null);
}

// ── Providers ─────────────────────────────────────────────────────────────────
final foodCoachRepositoryProvider = Provider<IFoodCoachRepository>((ref) {
  throw UnimplementedError(
      'Provide IFoodCoachRepository via ProviderScope.overrides');
});

final foodCoachProvider =
    NotifierProvider<FoodCoachNotifier, FoodCoachState>(FoodCoachNotifier.new);
