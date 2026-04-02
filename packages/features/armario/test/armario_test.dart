import 'package:flutter_test/flutter_test.dart';
import 'package:domain/domain.dart';

void main() {
  group('Garment entity', () {
    test('dos prendas con mismo id son iguales', () {
      const a = Garment(
        id: 'g1', imageUrl: 'img.jpg', type: GarmentType.shirt,
        primaryColor: '#FFF', style: GarmentStyle.casual,
      );
      const b = Garment(
        id: 'g1', imageUrl: 'img.jpg', type: GarmentType.shirt,
        primaryColor: '#FFF', style: GarmentStyle.casual,
      );
      expect(a, equals(b));
    });

    test('prenda favorita se puede crear', () {
      const g = Garment(
        id: 'g2', imageUrl: '', type: GarmentType.jeans,
        primaryColor: '#000', style: GarmentStyle.streetwear,
        isFavorite: true,
      );
      expect(g.isFavorite, isTrue);
    });
  });
}
