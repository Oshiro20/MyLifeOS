import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:core/src/services/ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('GeminiService Tests', () {
    test('generateFoodEvaluation returns null if API key is not set', () async {
      // Usar storage real o mockeado, aquí probamos el comportamiento base
      // Asumimos un secure storage vacío para esta instancia in-memory
      const storage = FlutterSecureStorage();
      final service = GeminiService(storage);

      // Borramos por si acaso
      await service.removeApiKey();

      final result = await service.generateFoodEvaluation(ingredients: ['manzana']);
      expect(result, isNull);
    });

    test('analyzeGarment returns null if API key is not set', () async {
      const storage = FlutterSecureStorage();
      final service = GeminiService(storage);

      // Borramos por si acaso
      await service.removeApiKey();

      final result = await service.analyzeGarment(name: 'Camisa azul', photoPath: 'dummy.jpg');
      expect(result, isNull);
    });
  });
}
