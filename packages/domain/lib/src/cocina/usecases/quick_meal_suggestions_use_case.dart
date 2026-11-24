import '../entities/inventory_ingredient.dart';
import '../entities/recipe.dart';
import '../../foodcoach/entities/body_composition_profile.dart';
import 'ingredient_matcher.dart';

/// Periodos principales del día para la lista rápida de comidas.
enum QuickMealPeriod {
  breakfast,
  lunch,
  dinner;

  static QuickMealPeriod forHour(int hour) {
    if (hour < 11) return QuickMealPeriod.breakfast;
    if (hour < 17) return QuickMealPeriod.lunch;
    return QuickMealPeriod.dinner;
  }

  /// Índice compatible con `WeeklyMenuEntry.mealType` (0=Desayuno, 1=Almuerzo, 2=Cena).
  int get weeklyMealType => switch (this) {
        QuickMealPeriod.breakfast => 0,
        QuickMealPeriod.lunch => 1,
        QuickMealPeriod.dinner => 2,
      };

  String get label => switch (this) {
        QuickMealPeriod.breakfast => 'Desayuno',
        QuickMealPeriod.lunch => 'Almuerzo',
        QuickMealPeriod.dinner => 'Cena',
      };

  String get emoji => switch (this) {
        QuickMealPeriod.breakfast => '🌅',
        QuickMealPeriod.lunch => '🍛',
        QuickMealPeriod.dinner => '🌙',
      };

  String get menuPeriodKey => switch (this) {
        QuickMealPeriod.breakfast => 'desayuno',
        QuickMealPeriod.lunch => 'almuerzo',
        QuickMealPeriod.dinner => 'cena',
      };
}

class QuickMealRecommendation {
  final Recipe recipe;
  final double availabilityRatio;
  final int availableCount;
  final int totalIngredients;
  final List<String> rescuedExpiringNames;
  final bool matchesGoal;
  final bool matchesPeriod;
  final double score;
  final String? nutritionFitBadge;

  const QuickMealRecommendation({
    required this.recipe,
    required this.availabilityRatio,
    required this.availableCount,
    required this.totalIngredients,
    this.rescuedExpiringNames = const [],
    this.matchesGoal = false,
    this.matchesPeriod = false,
    required this.score,
    this.nutritionFitBadge,
  });

  int get availabilityPercent => (availabilityRatio * 100).round().clamp(0, 100);
}

/// Motor instantáneo (0s, 100% local) que ordena las recetas guardadas para
/// Desayuno, Almuerzo o Cena usando disponibilidad real en Despensa,
/// rescate de ingredientes por vencer y meta nutricional activa.
class QuickMealSuggestionsUseCase {
  const QuickMealSuggestionsUseCase();

  static bool matchesMealPeriod(Recipe recipe, QuickMealPeriod period) {
    final type = recipe.tipoComida;
    if (type != null) {
      return switch (period) {
        QuickMealPeriod.breakfast => type == MealType.desayuno ||
            type == MealType.jugo ||
            type == MealType.bebida ||
            type == MealType.snack,
        QuickMealPeriod.lunch => type == MealType.seco ||
            type == MealType.sopa ||
            type == MealType.entrada,
        QuickMealPeriod.dinner => type == MealType.sopa ||
            type == MealType.entrada ||
            type == MealType.seco ||
            type == MealType.snack ||
            type == MealType.bebida,
      };
    }

    final text = IngredientMatcher.normalizeText(
      '${recipe.name} ${recipe.tags.join(' ')}',
    );
    return switch (period) {
      QuickMealPeriod.breakfast => _containsAny(text, const [
          'desayuno',
          'avena',
          'panqueque',
          'pancake',
          'tostada',
          'batido',
          'jugo',
          'smoothie',
          'yogurt',
          'omelette',
          'tortilla',
          'huevo',
          'sandwich',
          'quinoa',
        ]),
      QuickMealPeriod.lunch => !_containsAny(text, const [
          'desayuno',
          'postre',
          'mazamorra',
          'torta',
          'queque',
          'galleta',
          'batido',
          'jugo',
        ]),
      QuickMealPeriod.dinner => !_containsAny(text, const [
          'desayuno',
          'mazamorra',
          'postre',
        ]),
    };
  }

  static bool _containsAny(String text, List<String> keywords) =>
      keywords.any(text.contains);

  List<QuickMealRecommendation> call({
    required QuickMealPeriod period,
    required List<Recipe> recipes,
    required List<InventoryIngredient> inventory,
    NutritionGoal activeGoal = NutritionGoal.maintain,
    DailyMacroBudget? remainingMacros,
    Set<String> recentlyCookedNames = const {},
    Map<String, double>? customGramsPerUnit,
    Map<String, String>? learnedAliases,
    int limit = 4,
  }) {
    if (recipes.isEmpty || limit <= 0) return const [];

    final rawPantry = inventory
        .where((i) =>
            i.subCategory != 'Porción guardada' &&
            i.subCategory != 'Extra listo')
        .toList();

    final recentNorm = recentlyCookedNames
        .map(IngredientMatcher.normalizeText)
        .toSet();

    final scored = <QuickMealRecommendation>[];

    for (final recipe in recipes) {
      final isPeriodMatch = matchesMealPeriod(recipe, period);
      final checks = IngredientMatcher.evaluateRecipe(
        recipeIngredients: recipe.ingredients,
        inventory: rawPantry,
        customGramsPerUnit: customGramsPerUnit,
        learnedAliases: learnedAliases,
      );

      final total = checks.length;
      final available = checks
          .where((c) => c.availability == IngredientAvailability.available)
          .length;
      final partial = checks
          .where((c) => c.availability == IngredientAvailability.insufficient)
          .length;

      final ratio = total == 0 ? 1.0 : (available + partial * 0.5) / total;

      final rescued = <String>[];
      for (final c in checks) {
        final match = c.pantryMatch;
        if (match == null) continue;
        final prep = match.preparation.toLowerCase();
        final isUrgent = match.isExpiringSoon ||
            prep.contains('cocido') ||
            prep.contains('listo');
        if (isUrgent && !rescued.contains(match.name)) {
          rescued.add(match.name);
        }
      }

      final matchesGoal =
          activeGoal != NutritionGoal.maintain && recipe.goal == activeGoal;
      final wasCookedRecently =
          recentNorm.contains(IngredientMatcher.normalizeText(recipe.name));

      var score = ratio * 45.0;
      if (isPeriodMatch) score += 35.0;
      score += (rescued.length.clamp(0, 2)) * 12.0;
      if (matchesGoal) score += 12.0;
      if (recipe.isFavorite) score += 4.0;
      if (wasCookedRecently) score -= 14.0;
      if ((period == QuickMealPeriod.breakfast ||
              period == QuickMealPeriod.dinner) &&
          recipe.durationMinutes > 0 &&
          recipe.durationMinutes <= 20) {
        score += 6.0;
      }

      // Ajuste según saldo real restante del día (FoodCoach + Perfil Corporal)
      String? fitBadge;
      if (remainingMacros != null) {
        final kcal = recipe.caloriasAproximadas;
        final prot = recipe.nutrition?.proteinasG;
        final remKcal = remainingMacros.remainingCalories;
        final remProt = remainingMacros.remainingProtein;
        final normText = IngredientMatcher.normalizeText(
          '${recipe.name} ${recipe.ingredients.map((i) => i.ingredientName).join(' ')}',
        );
        final looksHighProtein = (prot != null && prot >= 24) ||
            _containsAny(normText, const [
              'pollo',
              'pechuga',
              'pavo',
              'pescado',
              'atun',
              'salmon',
              'huevo',
              'lentej',
              'quinua',
              'carne',
              'res',
            ]);
        final looksFried = _containsAny(normText, const [
          'frito',
          'frita',
          'chicharron',
          'milanesa',
          'apanado',
          'bistec a lo pobre',
        ]);

        if (remainingMacros.isOverCalories || remKcal <= 450) {
          if (kcal != null && kcal <= 450) {
            score += 12.0;
            fitBadge = '✅ Ligero (~$kcal kcal)';
          } else if (kcal != null && kcal >= 650) {
            score -= 14.0;
            final suggestedPortion =
                ((remKcal.clamp(250, 500)) / kcal).clamp(0.5, 0.8);
            fitBadge =
                '📏 Sugerido: ${suggestedPortion.toStringAsFixed(1)} porc.';
          }
          if (looksFried) score -= 10.0;
        } else if (kcal != null && kcal <= remKcal + 80) {
          score += 8.0;
          fitBadge = '✅ Encaja hoy (~$kcal kcal)';
        }

        if (remProt >= 30 && looksHighProtein) {
          score += 11.0;
          if (prot != null && prot > 0) {
            fitBadge = '⚡ ~${prot.round()}g prot · ideal para tu meta';
          } else {
            fitBadge ??= '⚡ Alta en proteína para tu meta';
          }
        }
      }

      scored.add(
        QuickMealRecommendation(
          recipe: recipe,
          availabilityRatio: ratio,
          availableCount: available,
          totalIngredients: total,
          rescuedExpiringNames: List.unmodifiable(rescued),
          matchesGoal: matchesGoal,
          matchesPeriod: isPeriodMatch,
          score: score,
          nutritionFitBadge: fitBadge,
        ),
      );
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.availabilityRatio.compareTo(a.availabilityRatio);
    });

    final matching = scored.where((r) => r.matchesPeriod).toList();
    if (matching.length >= limit) {
      return matching.take(limit).toList();
    }
    final fallback = scored.where((r) => !r.matchesPeriod).toList();
    return [...matching, ...fallback].take(limit).toList();
  }
}
