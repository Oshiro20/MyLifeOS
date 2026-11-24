import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FoodCoachRepository offline scoring', () {
    test('distingue palabras completas y evita falsos positivos de subcadenas',
        () {
      expect(FoodCoachRepository.scoreIngredientOffline('salmón'), 3);
      expect(FoodCoachRepository.scoreIngredientOffline('ensalada fresca'), 3);
      expect(FoodCoachRepository.scoreIngredientOffline('alcohol'), -3);
      expect(FoodCoachRepository.scoreIngredientOffline('agua mineral'), isNull);
    });

    test('combina múltiples modificadores en ingredientes compuestos', () {
      // pollo (+2) + frito (-2) = 0 (neutro en lugar de quedar +2)
      expect(FoodCoachRepository.scoreIngredientOffline('pollo frito'), 0);
      expect(FoodCoachRepository.scoreIngredientOffline('papas fritas'), -3);
    });

    test('estimateMacrosOffline ajusta calorías y grasas según método de cocción y receta', () {
      final boiled = FoodCoachRepository.estimateMacrosOffline(
        ingredients: const ['pollo', 'papa', 'brócoli'],
        cookingMethod: CookingMethod.boiled,
      );
      final fried = FoodCoachRepository.estimateMacrosOffline(
        ingredients: const ['pollo', 'papa', 'brócoli'],
        cookingMethod: CookingMethod.fried,
      );
      expect(fried.caloriesKcal, greaterThan(boiled.caloriesKcal));
      expect(fried.fatGrams, greaterThan(boiled.fatGrams));

      final fromRecipe = FoodCoachRepository.estimateMacrosOffline(
        ingredients: const ['lentejas'],
        servings: 1.5,
        recipeBaseMacros: const MealMacros(
          caloriesKcal: 400,
          proteinGrams: 30,
          carbsGrams: 40,
          fatGrams: 10,
          fiberGrams: 8,
        ),
      );
      expect(fromRecipe.caloriesKcal, 600);
      expect(fromRecipe.proteinGrams, closeTo(45.0, 0.01));
    });

    test('encodeMealMetadata y decodeMealMetadata soportan v2 JSON y CSV antiguo', () {
      final now = DateTime(2026, 11, 24, 13, 0);
      final eval = MealEvaluation(
        id: 'e1',
        timestamp: now,
        classification: FoodClassification.healthy,
        healthScore: 0.85,
        detectedIngredients: const ['pollo', 'lentejas', 'ensalada'],
        positiveFactors: const ['Alta proteína'],
        negativeFactors: const [],
        feedback: 'Muy balanceado',
        recommendation: 'Sigue así',
        mealName: 'Pollo con lentejas',
        mealSlot: MealSlot.lunch,
        cookingMethod: CookingMethod.stewed,
        servings: 1.5,
        macros: const MealMacros(
          caloriesKcal: 580,
          proteinGrams: 42,
          carbsGrams: 52,
          fatGrams: 16,
          fiberGrams: 9,
        ),
      );

      final encoded = FoodCoachRepository.encodeMealMetadata(eval);
      final decoded = FoodCoachRepository.decodeMealMetadata(encoded, now);
      expect(decoded.mealName, 'Pollo con lentejas');
      expect(decoded.mealSlot, MealSlot.lunch);
      expect(decoded.cookingMethod, CookingMethod.stewed);
      expect(decoded.servings, 1.5);
      expect(decoded.ingredients, ['pollo', 'lentejas', 'ensalada']);
      expect(decoded.macros?.caloriesKcal, 580);
      expect(decoded.macros?.proteinGrams, 42);

      final legacy = FoodCoachRepository.decodeMealMetadata('pollo frito,arroz', now);
      expect(legacy.ingredients, ['pollo frito', 'arroz']);
      expect(legacy.cookingMethod, CookingMethod.fried);
      expect(legacy.mealSlot, MealSlot.lunch);
    });

    test('CocinaRepository codifica y decodifica calorías, macros y vitaminas en tagsCsv', () {
      final recipe = Recipe(
        id: 'r-nutri',
        name: 'Ceviche de pescado',
        tags: const ['peruano', 'fresco'],
        caloriasAproximadas: 340,
        nutrition: const NutritionInfo(
          proteinasG: 32,
          carbohidratosG: 24,
          grasasG: 8,
          fibraG: 3,
          micronutrientes: ['Vitamina C', 'Omega 3', 'Potasio'],
        ),
        createdAt: DateTime(2026),
      );
      final encoded = CocinaRepository.encodeRecipeTagsWithNutrition(recipe);
      final decoded = CocinaRepository.decodeRecipeTagsWithNutrition(encoded);
      expect(decoded.tags, ['peruano', 'fresco']);
      expect(decoded.calories, 340);
      expect(decoded.nutrition?.proteinasG, 32);
      expect(decoded.nutrition?.carbohidratosG, 24);
      expect(decoded.nutrition?.grasasG, 8);
      expect(decoded.nutrition?.fibraG, 3);
      expect(decoded.nutrition?.micronutrientes, ['Vitamina C', 'Omega 3', 'Potasio']);
    });
  });
}
