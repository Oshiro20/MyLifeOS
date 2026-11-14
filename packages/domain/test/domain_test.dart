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
  });
}
