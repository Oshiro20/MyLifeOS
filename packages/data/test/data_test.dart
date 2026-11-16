import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FoodCoachRepository offline scoring', () {
    test('distingue palabras completas y evita falsos positivos de subcadenas',
        () {
      expect(FoodCoachRepository.scoreIngredientOffline('salmón'), 3);
      expect(FoodCoachRepository.scoreIngredientOffline('ensalada fresca'), 3);
      expect(FoodCoachRepository.scoreIngredientOffline('alcohol'), -3);
      expect(FoodCoachRepository.scoreIngredientOffline('agua mineral'), isNull);
    });

    test('combina múltiples modificadores en ingredientes compuestos', () {
      // pollo (+2) + frito (-2) = 0 (neutro en lugar de quedar +2)
      expect(FoodCoachRepository.scoreIngredientOffline('pollo frito'), 0);
      expect(FoodCoachRepository.scoreIngredientOffline('papas fritas'), -3);
    });
  });
}
