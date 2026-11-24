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
