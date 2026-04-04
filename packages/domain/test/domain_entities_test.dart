import 'package:flutter_test/flutter_test.dart';
import 'package:domain/domain.dart';

void main() {
  group('Inventory Ingredient Tests', () {
    test('should create ingredient with all fields', () {
      const ingredient = InventoryIngredient(
        id: '1',
        name: 'Arroz',
        primaryCategory: 'Cereales y granos',
        subCategory: 'Arroz blanco',
        quantity: 1.0,
        unit: 'kg',
        expirationDate: null,
        storageArea: 'Alacena',
      );

      expect(ingredient.id, '1');
      expect(ingredient.name, 'Arroz');
      expect(ingredient.primaryCategory, 'Cereales y granos');
      expect(ingredient.quantity, 1.0);
      expect(ingredient.unit, 'kg');
      expect(ingredient.storageArea, 'Alacena');
    });

    test('should detect expired ingredient', () {
      final ingredient = InventoryIngredient(
        id: '1',
        name: 'Leche',
        primaryCategory: 'Lácteos',
        quantity: 1.0,
        unit: 'L',
        expirationDate: DateTime.now().subtract(const Duration(days: 1)),
        storageArea: 'Refrigerador',
      );

      expect(ingredient.isExpired, isTrue);
    });

    test('should detect expiring soon ingredient', () {
      final ingredient = InventoryIngredient(
        id: '1',
        name: 'Yogurt',
        primaryCategory: 'Lácteos',
        quantity: 1.0,
        unit: 'unid',
        expirationDate: DateTime.now().add(const Duration(days: 2)),
        storageArea: 'Refrigerador',
      );

      expect(ingredient.isExpiringSoon, isTrue);
    });

    test('should not be expired or expiring when date is far', () {
      final ingredient = InventoryIngredient(
        id: '1',
        name: 'Arroz',
        primaryCategory: 'Cereales y granos',
        quantity: 1.0,
        unit: 'kg',
        expirationDate: DateTime.now().add(const Duration(days: 365)),
        storageArea: 'Alacena',
      );

      expect(ingredient.isExpired, isFalse);
      expect(ingredient.isExpiringSoon, isFalse);
    });
  });

  group('Recipe Tests', () {
    test('should create recipe with basic fields', () {
      final recipe = Recipe(
        id: '1',
        name: 'Arroz con Pollo',
        description: 'Receta tradicional',
        durationMinutes: 45,
        servings: 4,
        createdAt: DateTime.now(),
      );

      expect(recipe.id, '1');
      expect(recipe.name, 'Arroz con Pollo');
      expect(recipe.durationMinutes, 45);
      expect(recipe.servings, 4);
      expect(recipe.isFavorite, isFalse);
    });

    test('should toggle favorite status', () {
      var recipe = Recipe(
        id: '1',
        name: 'Arroz con Pollo',
        durationMinutes: 45,
        servings: 4,
        createdAt: DateTime.now(),
      );

      expect(recipe.isFavorite, isFalse);

      recipe = recipe.copyWith(isFavorite: true);
      expect(recipe.isFavorite, isTrue);
    });
  });

  group('Wardrobe Garment Tests', () {
    test('should create garment with all fields', () {
      final garment = WardrobeGarment(
        id: '1',
        name: 'Polo Negro',
        type: GarmentType.tshirt,
        primaryColor: '#000000',
        style: GarmentStyle.casual,
        season: Season.all,
        isClean: true,
        isFavorite: false,
        addedAt: DateTime.now(),
      );

      expect(garment.id, '1');
      expect(garment.name, 'Polo Negro');
      expect(garment.type, GarmentType.tshirt);
      expect(garment.primaryColor, '#000000');
      expect(garment.style, GarmentStyle.casual);
      expect(garment.isClean, isTrue);
      expect(garment.isFavorite, isFalse);
    });
  });

  group('Measurement Unit Tests', () {
    test('should have correct unit labels', () {
      expect(MeasurementUnit.unidades.label, 'unidades');
      expect(MeasurementUnit.g.label, 'g');
      expect(MeasurementUnit.kg.label, 'kg');
      expect(MeasurementUnit.ml.label, 'ml');
      expect(MeasurementUnit.litro.label, 'L');
      expect(MeasurementUnit.taza.label, 'taza');
      expect(MeasurementUnit.cucharada.label, 'cucharada');
      expect(MeasurementUnit.botella.label, 'botella');
      expect(MeasurementUnit.lata.label, 'lata');
    });

    test('should parse unit from string', () {
      expect(MeasurementUnit.fromString('kg'), MeasurementUnit.kg);
      expect(MeasurementUnit.fromString('unidades'), MeasurementUnit.unidades);
      expect(MeasurementUnit.fromString('taza'), MeasurementUnit.taza);
    });
  });
}
