import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OfflineCacheService', () {
    test('guarda y recupera mapas JSON', () async {
      final cache = OfflineCacheService();
      await cache.saveMap('recetas:pollo', {'count': 2, 'ok': true});

      final loaded = await cache.loadMap('recetas:pollo');
      expect(loaded, {'count': 2, 'ok': true});
    });

    test('expira entradas cuando supera maxAge', () async {
      final cache = OfflineCacheService();
      await cache.saveString('prompt:test', '{"value": 1}');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final expired = await cache.loadString(
        'prompt:test',
        maxAge: Duration.zero,
      );
      expect(expired, isNull);
    });
  });

  group('WeatherService', () {
    test('seasonalFallback incluye temperatura en °C', () {
      final fallback = WeatherService.seasonalFallback();
      expect(fallback, contains('°C'));
    });

    test('persiste ciudad seleccionada y rechaza ciudades fuera de presets',
        () async {
      expect(await WeatherService.getSelectedCity(), 'Lima');
      await WeatherService.setSelectedCity('Cusco');
      expect(await WeatherService.getSelectedCity(), 'Cusco');
      await WeatherService.setSelectedCity('CiudadInexistente');
      expect(await WeatherService.getSelectedCity(), 'Cusco');
    });
  });

  group('PendingMealEvaluationNotifier', () {
    test('encola y limpia evaluación pendiente entre Cocina y FoodCoach', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(pendingMealEvaluationProvider), isNull);
      container.read(pendingMealEvaluationProvider.notifier).queue(
        recipeName: 'Lomo Saltado',
        ingredients: ['lomo', 'cebolla', 'tomate'],
      );

      final queued = container.read(pendingMealEvaluationProvider);
      expect(queued?.recipeName, 'Lomo Saltado');
      expect(queued?.ingredients, ['lomo', 'cebolla', 'tomate']);

      container.read(pendingMealEvaluationProvider.notifier).clear();
      expect(container.read(pendingMealEvaluationProvider), isNull);
    });
  });

  group('SharedIdentityService', () {
    test('setUserName tolera espacios iniciales/finales sin RangeError',
        () async {
      await SharedIdentityService.setUserName('   Joel   ');
      expect(await SharedIdentityService.getUserName(), 'Joel');

      await SharedIdentityService.setUserName('   ');
      expect(await SharedIdentityService.getUserName(), '');
    });
  });

  group('TikTokService URL helpers', () {
    test('extractFirstUrl y extractSharedCaption separan texto y enlace', () {
      const shared =
          'Arroz Chaufa estos son los secretitos: https://vt.tiktok.com/ZSmAbC123/)';
      expect(
        TikTokService.extractFirstUrl(shared),
        'https://vt.tiktok.com/ZSmAbC123/',
      );
      expect(
        TikTokService.extractSharedCaption(shared),
        'Arroz Chaufa estos son los secretitos:',
      );
      expect(
        TikTokService.extractCaptionFromInfo({
          'data': {'title': 'Arroz Chaufa Peruano por Pisu Cocina'}
        }),
        'Arroz Chaufa Peruano por Pisu Cocina',
      );
    });
  });
}
