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

  group('Garment', () {
    test('equality por props', () {
      const a = Garment(
        id: 'g1', imageUrl: 'path/img.jpg',
        type: GarmentType.shirt, primaryColor: '#FFFFFF',
        style: GarmentStyle.casual,
      );
      const b = Garment(
        id: 'g1', imageUrl: 'path/img.jpg',
        type: GarmentType.shirt, primaryColor: '#FFFFFF',
        style: GarmentStyle.casual,
      );
      expect(a, equals(b));
    });

    test('isFavorite por defecto es false', () {
      const g = Garment(
        id: 'g1', imageUrl: '', type: GarmentType.pants,
        primaryColor: '#000', style: GarmentStyle.formal,
      );
      expect(g.isFavorite, isFalse);
    });

    test('secondaryColor por defecto es vacío', () {
      const g = Garment(
        id: 'g1', imageUrl: '', type: GarmentType.shoes,
        primaryColor: '#FFF', style: GarmentStyle.sport,
      );
      expect(g.secondaryColor, isEmpty);
    });
  });

  group('MealLog', () {
    test('equality por props', () {
      final ts = DateTime(2026, 4, 1, 12);
      final a = MealLog(
        id: 'm1', timestamp: ts, photoPath: 'path/photo.jpg',
        classification: MealClassification.healthy,
        feedback: 'Muy nutritivo',
      );
      final b = MealLog(
        id: 'm1', timestamp: ts, photoPath: 'path/photo.jpg',
        classification: MealClassification.healthy,
        feedback: 'Muy nutritivo',
      );
      expect(a, equals(b));
    });

    test('detectedIngredients por defecto es lista vacía', () {
      final log = MealLog(
        id: 'm1', timestamp: DateTime.now(), photoPath: '',
        classification: MealClassification.unknown, feedback: '',
      );
      expect(log.detectedIngredients, isEmpty);
    });

    test('clasificaciones disponibles', () {
      expect(MealClassification.values.length, 4);
      expect(MealClassification.values, containsAll([
        MealClassification.healthy,
        MealClassification.junk,
        MealClassification.balanced,
        MealClassification.unknown,
      ]));
    });
  });
}
