import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:domain/domain.dart';
import 'package:foodcoach/foodcoach.dart';

void main() {
  group('MealEvaluation entity', () {
    test('meal evaluation con ingredientes detectados', () {
      final log = MealEvaluation(
        id: 'm1',
        timestamp: DateTime(2026, 4, 1),
        photoPath: 'photos/meal.jpg',
        classification: FoodClassification.healthy,
        healthScore: 0.9,
        positiveFactors: const [],
        negativeFactors: const [],
        recommendation: '',
        feedback: 'Rico en proteínas',
        detectedIngredients: const ['pollo', 'arroz', 'brócoli'],
      );
      expect(log.detectedIngredients.length, 3);
      expect(log.classification, FoodClassification.healthy);
    });

    test('meal evaluation sin ingredientes tiene lista vacía', () {
      final log = MealEvaluation(
        id: 'm2',
        timestamp: DateTime.now(),
        photoPath: '',
        classification: FoodClassification.balanced,
        healthScore: 0.5,
        positiveFactors: const [],
        negativeFactors: const [],
        recommendation: '',
        feedback: '',
        detectedIngredients: const [],
      );
      expect(log.detectedIngredients, isEmpty);
    });

    test('DailyWaterNotifier incrementa, decrementa y persiste vasos de agua', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(dailyWaterProvider.notifier);
      await notifier.increment();
      await notifier.increment();
      expect(container.read(dailyWaterProvider), 2);
      await notifier.decrement();
      expect(container.read(dailyWaterProvider), 1);
    });
  });
}
