import 'package:flutter_test/flutter_test.dart';
import 'package:domain/domain.dart';

void main() {
  group('InventoryIngredient y WeeklyMenuEntry', () {
    test('InventoryIngredient equality por id', () {
      const a = InventoryIngredient(
        id: '1',
        name: 'Tomate',
        primaryCategory: 'Verduras',
        quantity: 2,
        unit: 'kg',
      );
      const b = InventoryIngredient(
        id: '1',
        name: 'Tomate',
        primaryCategory: 'Verduras',
        quantity: 2,
        unit: 'kg',
      );
      expect(a, equals(b));
    });

    test('InventoryIngredient distintos no son iguales', () {
      const a = InventoryIngredient(
        id: '1',
        name: 'Tomate',
        primaryCategory: 'Verduras',
        quantity: 2,
        unit: 'kg',
      );
      const b = InventoryIngredient(
        id: '2',
        name: 'Cebolla',
        primaryCategory: 'Verduras',
        quantity: 1,
        unit: 'unidades',
      );
      expect(a, isNot(equals(b)));
    });

    test('WeeklyMenuEntry equality y copyWith', () {
      const entry = WeeklyMenuEntry(
        id: 'w1',
        dayOfWeek: 1,
        mealType: 1,
        recipeId: 'r1',
      );
      expect(entry.isCustom, isFalse);
      expect(entry.copyWith(isCustom: true).isCustom, isTrue);
    });

    test('expirationDate puede ser null', () {
      const i = InventoryIngredient(
        id: '1',
        name: 'Sal',
        primaryCategory: 'Condimentos y especias',
        quantity: 500,
        unit: 'g',
      );
      expect(i.expirationDate, isNull);
    });
  });

  group('WardrobeGarment', () {
    test('equality por props', () {
      final ts = DateTime(2026, 4, 1, 12);
      final a = WardrobeGarment(
        id: 'g1',
        name: 'Shirt 1',
        type: GarmentType.shirt,
        primaryColor: '#FFFFFF',
        style: GarmentStyle.casual,
        addedAt: ts,
      );
      final b = WardrobeGarment(
        id: 'g1',
        name: 'Shirt 1',
        type: GarmentType.shirt,
        primaryColor: '#FFFFFF',
        style: GarmentStyle.casual,
        addedAt: ts,
      );
      expect(a, equals(b));
    });

    test('isFavorite por defecto es false', () {
      final ts = DateTime(2026, 4, 1, 12);
      final g = WardrobeGarment(
        id: 'g1',
        name: 'Pants',
        type: GarmentType.pants,
        primaryColor: '#000',
        style: GarmentStyle.formal,
        addedAt: ts,
      );
      expect(g.isFavorite, isFalse);
    });

    test('secondaryColor por defecto es vacío', () {
      final ts = DateTime(2026, 4, 1, 12);
      final g = WardrobeGarment(
        id: 'g1',
        name: 'Shoes',
        type: GarmentType.shoes,
        primaryColor: '#FFF',
        style: GarmentStyle.sport,
        addedAt: ts,
      );
      expect(g.secondaryColor, isEmpty);
    });
  });

  group('MealLog', () {
    test('equality por props', () {
      final ts = DateTime(2026, 4, 1, 12);
      final a = MealLog(
        id: 'm1',
        timestamp: ts,
        photoPath: 'path/photo.jpg',
        classification: FoodClassification.healthy,
        healthScore: 0.9,
        feedback: 'Muy nutritivo',
      );
      final b = MealLog(
        id: 'm1',
        timestamp: ts,
        photoPath: 'path/photo.jpg',
        classification: FoodClassification.healthy,
        healthScore: 0.9,
        feedback: 'Muy nutritivo',
      );
      expect(a, equals(b));
    });

    test('clasificaciones disponibles', () {
      expect(FoodClassification.values.length, 3);
      expect(
          FoodClassification.values,
          containsAll([
            FoodClassification.healthy,
            FoodClassification.junk,
            FoodClassification.balanced,
          ]));
    });

    test('ConsumptionAnalyticsUseCase agrupa platos, frutas, verduras y alertas de balance', () {
      const useCase = ConsumptionAnalyticsUseCase();
      final now = DateTime.now();
      final logs = [
        MealLog(
          id: '1',
          timestamp: now.subtract(const Duration(days: 1)),
          classification: FoodClassification.healthy,
          healthScore: 0.85,
          feedback: 'Ok',
          mealName: 'Pollo frito con lentejas',
          cookingMethod: CookingMethod.fried,
          detectedIngredients: const ['pollo', 'lentejas', 'tomate', 'cebolla'],
        ),
        MealLog(
          id: '2',
          timestamp: now.subtract(const Duration(hours: 10)),
          classification: FoodClassification.balanced,
          healthScore: 0.65,
          feedback: 'Ok',
          mealName: 'Pollo frito con lentejas',
          cookingMethod: CookingMethod.fried,
          detectedIngredients: const ['pollo', 'lentejas', 'tomate'],
        ),
        MealLog(
          id: '3',
          timestamp: now.subtract(const Duration(hours: 3)),
          classification: FoodClassification.healthy,
          healthScore: 0.9,
          feedback: 'Ok',
          mealName: 'Avena con plátano',
          cookingMethod: CookingMethod.boiled,
          detectedIngredients: const ['avena', 'plátano', 'fresas'],
        ),
      ];

      final analytics = useCase(logs, lastDays: 30);
      expect(analytics.topMeals.first.name, 'Pollo frito con lentejas');
      expect(analytics.topMeals.first.count, 2);
      expect(analytics.topFruits.map((f) => f.name), containsAll(['Plátano', 'Fresa']));
      expect(analytics.topVegetables.first.name, 'Tomate');
      expect(analytics.topVegetables.first.count, 2);
      expect(analytics.topProteins.first.name, 'Pollo');
      expect(analytics.friedMealsCount, 2);
      expect(analytics.balanceAlerts.any((a) => a.contains('fritas')), isTrue);
      expect(CookingMethod.inferFromText('Pollo a la plancha'), CookingMethod.grilled);
      expect(CookingMethod.inferFromText('Huevo sancochado'), CookingMethod.boiled);
    });

    test('BodyNutritionCalculator calcula US Navy, prioridad de fuentes y metas reales', () {
      final navyMale = BodyNutritionCalculator.calculateUsNavyBodyFat(
        sex: BiologicalSex.male,
        heightCm: 175,
        neckCm: 38,
        waistCm: 84,
      );
      expect(navyMale, isNotNull);
      expect(navyMale!, inInclusiveRange(12.0, 22.0));

      final navyFemale = BodyNutritionCalculator.calculateUsNavyBodyFat(
        sex: BiologicalSex.female,
        heightCm: 164,
        neckCm: 33,
        waistCm: 72,
        hipCm: 96,
      );
      expect(navyFemale, isNotNull);
      expect(navyFemale!, inInclusiveRange(18.0, 32.0));

      const visualOnly = BodyCompositionProfile(
        heightCm: 175,
        weightKg: 74,
        age: 28,
        sex: BiologicalSex.male,
        activityLevel: ActivityLevel.moderate,
        goalMode: BodyGoalMode.recomposition,
        visualBodyFatMin: 17,
        visualBodyFatMax: 21,
      );
      final targetsVisual = BodyNutritionCalculator.calculateTargets(visualOnly);
      expect(targetsVisual.isPersonalized, isTrue);
      expect(targetsVisual.bodyFatSource, BodyFatSource.visualEstimate);
      expect(targetsVisual.estimatedBodyFatPercent, 19.0);
      expect(targetsVisual.caloriesKcal, inInclusiveRange(2100, 2800));
      expect(targetsVisual.proteinGrams, greaterThanOrEqualTo(120));

      final withNavy = visualOnly.copyWith(neckCm: 38, waistCm: 84);
      final targetsNavy = BodyNutritionCalculator.calculateTargets(withNavy);
      expect(targetsNavy.bodyFatSource, BodyFatSource.usNavy);
      expect(targetsNavy.leanMassKg, isNotNull);

      final withManual = withNavy.copyWith(manualBodyFatPercent: 15.5);
      final targetsManual = BodyNutritionCalculator.calculateTargets(withManual);
      expect(targetsManual.bodyFatSource, BodyFatSource.manual);
      expect(targetsManual.estimatedBodyFatPercent, 15.5);

      final budget = DailyMacroBudget(
        targets: targetsManual,
        consumedCalories: 1600,
        consumedProtein: 90,
        consumedCarbs: 180,
        consumedFat: 45,
      );
      expect(budget.remainingCalories, targetsManual.caloriesKcal - 1600);
      expect(budget.toChefPromptContext(withManual), contains('PERFIL CORPORAL'));
    });

    test('QuickMealSuggestionsUseCase prioriza recetas acordes al saldo restante del día', () {
      const useCase = QuickMealSuggestionsUseCase();
      const inv = [
        InventoryIngredient(
          id: '1',
          name: 'Pechuga de pollo',
          primaryCategory: 'Proteínas Animales',
          quantity: 500,
          unit: 'gramos',
        ),
      ];
      final lightHighProt = Recipe(
        id: 'r1',
        name: 'Pechuga de pollo a la plancha',
        durationMinutes: 15,
        ingredients: const [
          RecipeIngredient(
            id: 'ri1',
            recipeId: 'r1',
            ingredientName: 'Pechuga de pollo',
            quantity: 200,
            unit: 'gramos',
          ),
        ],
        caloriasAproximadas: 320,
        nutrition: const NutritionInfo(proteinasG: 42),
        tipoComida: MealType.seco,
        createdAt: DateTime(2026),
      );
      final heavyFried = Recipe(
        id: 'r2',
        name: 'Pollo frito con papas fritas',
        durationMinutes: 25,
        ingredients: const [
          RecipeIngredient(
            id: 'ri2',
            recipeId: 'r2',
            ingredientName: 'Pechuga de pollo',
            quantity: 200,
            unit: 'gramos',
          ),
        ],
        caloriasAproximadas: 820,
        nutrition: const NutritionInfo(proteinasG: 28),
        tipoComida: MealType.seco,
        createdAt: DateTime(2026),
      );
      const targets = DailyNutritionTargets(
        caloriesKcal: 2000,
        proteinGrams: 140,
        carbsGrams: 200,
        fatGrams: 60,
        fiberGrams: 28,
        waterLiters: 2.5,
        bmrKcal: 1650,
        tdeeKcal: 2200,
        isPersonalized: true,
        effectiveGoal: BodyGoalMode.fatLoss,
      );
      const budget = DailyMacroBudget(
        targets: targets,
        consumedCalories: 1650,
        consumedProtein: 95,
        consumedCarbs: 170,
        consumedFat: 52,
      );

      final recs = useCase(
        period: QuickMealPeriod.dinner,
        recipes: [heavyFried, lightHighProt],
        inventory: inv,
        remainingMacros: budget,
      );
      expect(recs.first.recipe.id, 'r1');
      expect(recs.first.nutritionFitBadge, isNotNull);
    });
  });

  group('AiJsonParser', () {
    test('limpia cercos markdown y decodifica objeto JSON', () {
      const raw = 'Aquí tienes:\n```json\n{"name": "Ceviche", "mins": 20}\n```';
      expect(
        AiJsonParser.decodeMap(raw),
        {'name': 'Ceviche', 'mins': 20},
      );
    });

    test('extrae y decodifica lista JSON envuelta en texto', () {
      const raw = 'Sugerencias: [{"name": "Ensalada"}, {"name": "Sopa"}] fin.';
      final list = AiJsonParser.decodeList(raw);
      expect(list, hasLength(2));
      expect((list!.first as Map<String, dynamic>)['name'], 'Ensalada');
    });

    test('retorna null ante JSON inválido', () {
      expect(AiJsonParser.decodeMap('texto sin json'), isNull);
      expect(AiJsonParser.decodeList('texto sin lista'), isNull);
    });
  });
}
