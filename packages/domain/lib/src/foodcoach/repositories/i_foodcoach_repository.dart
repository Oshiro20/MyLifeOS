import '../entities/meal_evaluation.dart';

abstract interface class IFoodCoachRepository {
  /// Evalúa una comida dado un conjunto de ingredientes detectados/ingresados.
  /// Retorna una evaluación completa.
  Future<MealEvaluation> evaluateMeal({
    required List<String> ingredients,
    String? photoPath,
  });

  /// Historial de evaluaciones previas.
  Future<List<MealLog>> getHistory({int limit = 50});

  /// Guarda una evaluación en el historial.
  Future<void> saveToHistory(MealEvaluation evaluation);

  /// Elimina un registro del historial.
  Future<void> deleteFromHistory(String id);

  /// Estadísticas de la semana: promedio de healthScore y clasificaciones.
  Future<WeeklyStats> getWeeklyStats();
}

class WeeklyStats {
  final double averageHealthScore;
  final int healthyCount;
  final int balancedCount;
  final int junkCount;
  final int totalMeals;

  const WeeklyStats({
    required this.averageHealthScore,
    required this.healthyCount,
    required this.balancedCount,
    required this.junkCount,
    required this.totalMeals,
  });

  double get healthyPercent => totalMeals == 0 ? 0 : healthyCount / totalMeals;
  double get junkPercent => totalMeals == 0 ? 0 : junkCount / totalMeals;
}
