import 'package:flutter_test/flutter_test.dart';
import 'package:domain/domain.dart';

void main() {
  group('WardrobeGarment entity', () {
    test('dos prendas con mismo id son iguales', () {
      final ts = DateTime(2026, 4, 1, 12);
      final a = WardrobeGarment(
        id: 'g1', name: 'Shirt 1', type: GarmentType.shirt,
        primaryColor: '#FFF', style: GarmentStyle.casual, addedAt: ts,
      );
      final b = WardrobeGarment(
        id: 'g1', name: 'Shirt 1', type: GarmentType.shirt,
        primaryColor: '#FFF', style: GarmentStyle.casual, addedAt: ts,
      );
      expect(a, equals(b));
    });

    test('prenda favorita se puede crear', () {
      final ts = DateTime(2026, 4, 1, 12);
      final g = WardrobeGarment(
        id: 'g2', name: 'Jeans', type: GarmentType.jeans,
        primaryColor: '#000', style: GarmentStyle.streetwear,
        isFavorite: true, addedAt: ts,
      );
      expect(g.isFavorite, isTrue);
    });
  });
}
