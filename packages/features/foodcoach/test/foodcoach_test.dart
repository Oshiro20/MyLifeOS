import 'package:flutter_test/flutter_test.dart';
import 'package:domain/domain.dart';

void main() {
  group('MealLog entity', () {
    test('meal log con ingredientes detectados', () {
      final log = MealLog(
        id: 'm1',
        timestamp: DateTime(2026, 4, 1),
        photoPath: 'photos/meal.jpg',
        classification: MealClassification.healthy,
        feedback: 'Rico en proteínas',
        detectedIngredients: ['pollo', 'arroz', 'brócoli'],
      );
      expect(log.detectedIngredients.length, 3);
      expect(log.classification, MealClassification.healthy);
    });

    test('meal log sin ingredientes tiene lista vacía', () {
      final log = MealLog(
        id: 'm2', timestamp: DateTime.now(), photoPath: '',
        classification: MealClassification.unknown, feedback: '',
      );
      expect(log.detectedIngredients, isEmpty);
    });
  });
}
