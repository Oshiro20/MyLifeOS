import 'package:flutter_test/flutter_test.dart';
import 'package:domain/domain.dart';

void main() {
  group('Ingredient entity', () {
    test('ingrediente con fecha de vencimiento', () {
      final expiry = DateTime(2026, 12, 31);
      final i = Ingredient(
        id: '1', name: 'Leche', category: IngredientCategory.dairy,
        quantity: 1, unit: 'L', expirationDate: expiry,
      );
      expect(i.expirationDate, expiry);
    });

    test('todas las categorías tienen label en español', () {
      for (final cat in IngredientCategory.values) {
        expect(cat.label, isNotEmpty);
      }
    });
  });
}
