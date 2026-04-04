import 'package:flutter_test/flutter_test.dart';
import 'package:domain/domain.dart';

void main() {
  group('Ingredient', () {
    test('equality por id', () {
      const a = Ingredient(
        id: '1', name: 'Tomate', category: IngredientCategory.vegetable,
        quantity: 2, unit: 'kg',
      );
      const b = Ingredient(
        id: '1', name: 'Tomate', category: IngredientCategory.vegetable,
        quantity: 2, unit: 'kg',
      );
      expect(a, equals(b));
    });

    test('ingredientes distintos no son iguales', () {
      const a = Ingredient(
        id: '1', name: 'Tomate', category: IngredientCategory.vegetable,
        quantity: 2, unit: 'kg',
      );
      const b = Ingredient(
        id: '2', name: 'Cebolla', category: IngredientCategory.vegetable,
        quantity: 1, unit: 'unidad',
      );
      expect(a, isNot(equals(b)));
    });

    test('label de categoría en español', () {
      expect(IngredientCategory.fruit.label, 'Fruta');
      expect(IngredientCategory.protein.label, 'Proteína');
      expect(IngredientCategory.dairy.label, 'Lácteo');
    });

    test('expirationDate puede ser null', () {
      const i = Ingredient(
        id: '1', name: 'Sal', category: IngredientCategory.spice,
        quantity: 500, unit: 'g',
      );
      expect(i.expirationDate, isNull);
    });
  });

  group('WardrobeGarment', () {
    test('equality por props', () {
      final ts = DateTime(2026, 4, 1, 12);
      final a = WardrobeGarment(
        id: 'g1', name: 'Shirt 1',
        type: GarmentType.shirt, primaryColor: '#FFFFFF',
        style: GarmentStyle.casual, addedAt: ts,
      );
      final b = WardrobeGarment(
        id: 'g1', name: 'Shirt 1',
        type: GarmentType.shirt, primaryColor: '#FFFFFF',
        style: GarmentStyle.casual, addedAt: ts,
      );
      expect(a, equals(b));
    });

    test('isFavorite por defecto es false', () {
      final ts = DateTime(2026, 4, 1, 12);
      final g = WardrobeGarment(
        id: 'g1', name: 'Pants', type: GarmentType.pants,
        primaryColor: '#000', style: GarmentStyle.formal, addedAt: ts,
      );
      expect(g.isFavorite, isFalse);
    });

    test('secondaryColor por defecto es vacío', () {
      final ts = DateTime(2026, 4, 1, 12);
      final g = WardrobeGarment(
        id: 'g1', name: 'Shoes', type: GarmentType.shoes,
        primaryColor: '#FFF', style: GarmentStyle.sport, addedAt: ts,
      );
      expect(g.secondaryColor, isEmpty);
    });
  });

  group('MealLog', () {
    test('equality por props', () {
      final ts = DateTime(2026, 4, 1, 12);
      final a = MealLog(
        id: 'm1', timestamp: ts, photoPath: 'path/photo.jpg',
        classification: FoodClassification.healthy,
        healthScore: 0.9,
        feedback: 'Muy nutritivo',
      );
      final b = MealLog(
        id: 'm1', timestamp: ts, photoPath: 'path/photo.jpg',
        classification: FoodClassification.healthy,
        healthScore: 0.9,
        feedback: 'Muy nutritivo',
      );
      expect(a, equals(b));
    });

    test('clasificaciones disponibles', () {
      expect(FoodClassification.values.length, 3);
      expect(FoodClassification.values, containsAll([
        FoodClassification.healthy,
        FoodClassification.junk,
        FoodClassification.balanced,
      ]));
    });
  });
}
