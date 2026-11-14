import 'package:flutter_test/flutter_test.dart';
import 'package:domain/domain.dart';

void main() {
  group('WardrobeGarment entity', () {
    test('dos prendas con mismo id son iguales', () {
      final ts = DateTime(2026, 4, 1, 12);
      final a = WardrobeGarment(
        id: 'g1',
        name: 'Shirt 1',
        type: GarmentType.shirt,
        primaryColor: '#FFF',
        style: GarmentStyle.casual,
        addedAt: ts,
      );
      final b = WardrobeGarment(
        id: 'g1',
        name: 'Shirt 1',
        type: GarmentType.shirt,
        primaryColor: '#FFF',
        style: GarmentStyle.casual,
        addedAt: ts,
      );
      expect(a, equals(b));
    });

    test('prenda favorita se puede crear', () {
      final ts = DateTime(2026, 4, 1, 12);
      final g = WardrobeGarment(
        id: 'g2',
        name: 'Jeans',
        type: GarmentType.jeans,
        primaryColor: '#000',
        style: GarmentStyle.streetwear,
        isFavorite: true,
        addedAt: ts,
      );
      expect(g.isFavorite, isTrue);
    });

    test('incremento de timesWorn mantiene datos base de la prenda', () {
      final ts = DateTime(2026, 4, 1, 12);
      final g = WardrobeGarment(
        id: 'g3',
        name: 'Casaca Denim',
        type: GarmentType.jacket,
        primaryColor: '#1E3A8A',
        style: GarmentStyle.casual,
        price: 120.0,
        timesWorn: 2,
        addedAt: ts,
      );
      final updated = g.copyWith(timesWorn: g.timesWorn + 1);
      expect(updated.timesWorn, 3);
      expect(updated.price, 120.0);
      expect(updated.price! / updated.timesWorn, 40.0);
    });
  });
}
