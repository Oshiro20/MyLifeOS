import '../entities/meal_evaluation.dart';

abstract interface class IFoodCoachRepository {
  /// Evalúa una comida dado un conjunto de ingredientes, nombre, horario,
  /// método de cocción y contexto opcional de receta.
  Future<MealEvaluation> evaluateMeal({
    required List<String> ingredients,
    String? photoPath,
    String? mealName,
    MealSlot? mealSlot,
    CookingMethod? cookingMethod,
    double servings = 1.0,
    String? recipeContext,
    MealMacros? recipeBaseMacros,
  });

  /// Historial de evaluaciones previas.
  Future<List<MealLog>> getHistory({int limit = 100});

  /// Guarda una evaluación en el historial.
  Future<void> saveToHistory(MealEvaluation evaluation);

  /// Elimina un registro del historial.
  Future<void> deleteFromHistory(String id);

  /// Estadísticas de la semana: score, clasificaciones y macros diarios/semanales.
  Future<WeeklyStats> getWeeklyStats();
}

class WeeklyStats {
  final double averageHealthScore;
  final int healthyCount;
  final int balancedCount;
  final int junkCount;
  final int totalMeals;
  final int todayCalories;
  final double todayProtein;
  final double todayCarbs;
  final double todayFat;
  final double todayFiber;
  final int avgDailyCalories;
  final double avgDailyProtein;
  final int friedCount;

  const WeeklyStats({
    required this.averageHealthScore,
    required this.healthyCount,
    required this.balancedCount,
    required this.junkCount,
    required this.totalMeals,
    this.todayCalories = 0,
    this.todayProtein = 0,
    this.todayCarbs = 0,
    this.todayFat = 0,
    this.todayFiber = 0,
    this.avgDailyCalories = 0,
    this.avgDailyProtein = 0,
    this.friedCount = 0,
  });

  double get healthyPercent => totalMeals == 0 ? 0 : healthyCount / totalMeals;
  double get junkPercent => totalMeals == 0 ? 0 : junkCount / totalMeals;
  double get friedPercent => totalMeals == 0 ? 0 : friedCount / totalMeals;
}
