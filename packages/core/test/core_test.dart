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

  group('WalletPantryBridgeService & IngredientPriceService', () {
    test('parseGroceryDescription extrae cantidad, unidad y producto', () {
      final tomates = WalletPantryBridgeService.parseGroceryDescription(
        'Compra de tomates 10 unidades',
      );
      expect(tomates, isNotNull);
      expect(tomates!.name, 'Tomates');
      expect(tomates.quantity, 10.0);
      expect(tomates.unit, 'unidades');

      final pollo = WalletPantryBridgeService.parseGroceryDescription(
        '2.5 kg de pollo',
      );
      expect(pollo, isNotNull);
      expect(pollo!.name, 'Pollo');
      expect(pollo.quantity, 2.5);
      expect(pollo.unit, 'kg');

      final ruido = WalletPantryBridgeService.parseGroceryDescription(
        'Almuerzo en chifa 2 platos',
      );
      expect(ruido, isNull);
    });

    test('classifyRelevantModule filtra transacciones relevantes para MyLifeOS',
        () {
      expect(
        WalletPantryBridgeService.classifyRelevantModule({
          'description': 'Compra de tomates 10 unidades',
          'category': 'Alimentación',
          'amount': -15.0,
        }),
        'cocina',
      );
      expect(
        WalletPantryBridgeService.classifyRelevantModule({
          'description': 'Zapatillas deportivas',
          'category': 'Ropa',
          'amount': -180.0,
        }),
        'armario',
      );
      expect(
        WalletPantryBridgeService.classifyRelevantModule({
          'description': 'Pago tarjeta Visa',
          'category': 'Finanzas',
          'amount': -500.0,
        }),
        isNull,
      );
      expect(
        WalletPantryBridgeService.classifyRelevantModule({
          'description': 'Sueldo mensual',
          'category': 'Ingresos',
          'amount': 3200.0,
        }),
        isNull,
      );
    });

    test('extractPendingGroceryCandidates lee items estructurados y texto libre y deduplica',
        () async {
      final bridge = WalletPantryBridgeService();
      final summary = WalletSummary(
        version: '3.0',
        month: '2026-11',
        balance: 500,
        income: 1000,
        expenses: 500,
        currency: 'PEN',
        exportedAt: DateTime(2026, 11, 16),
        recentTransactions: [
          {
            'id': 'tx-1',
            'description': 'Compra de tomates 10 unidades',
            'category': 'Mercado',
            'amount': -12.0,
            'date': '2026-11-16',
          },
          {
            'id': 'tx-2',
            'description': 'Mercado semanal',
            'category': 'Supermercado',
            'amount': -25.0,
            'date': '2026-11-16',
            'items': [
              {'name': 'Arroz', 'quantity': 2, 'unit': 'kg', 'price': 9.0},
            ],
          },
        ],
      );

      final first = await bridge.extractPendingGroceryCandidates(summary);
      expect(first.length, 2);
      expect(first.first.itemName, 'Tomates');
      expect(first.last.itemName, 'Arroz');

      await bridge.markTxProcessed('tx-1');
      final second = await bridge.extractPendingGroceryCandidates(summary);
      expect(second.length, 1);
      expect(second.single.transactionKey, 'tx-2');
    });

    test('IngredientPriceService guarda precio y estima lista con conversión de unidades',
        () async {
      final service = IngredientPriceService();
      await service.recordPurchase(
        name: 'Tomates',
        quantity: 1,
        unit: 'kilogramos',
        totalPrice: 10.0,
      );

      final catalog = await service.loadCatalog();
      final est = IngredientPriceService.estimateList(
        catalog: catalog,
        items: const [
          (name: 'Tomate', quantity: 500, unit: 'gramos'),
          (name: 'Azafrán', quantity: 5, unit: 'gramos'),
        ],
      );

      expect(est.totalCount, 2);
      expect(est.pricedCount, 1);
      expect(est.totalEstimated, closeTo(5.0, 0.01));
    });
  });
}
