import 'package:core/core.dart';
import 'package:domain/domain.dart';
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

    test(
        'extractPendingAutoSyncBatch ignora historial inicial y solo importa registros nuevos (Plátano Seda, Armario, Utensilio)',
        () async {
      final bridge = WalletPantryBridgeService();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final futureCreatedAt = DateTime.now().add(const Duration(minutes: 2));

      // 1ra sincronización: establece punto de corte sin importar historial viejo
      final initialSummary = WalletSummary(
        version: '1.4.5',
        month: '2026-11',
        balance: 500,
        income: 1000,
        expenses: 500,
        currency: 'PEN',
        exportedAt: DateTime.now(),
        recentTransactions: [
          {
            'id': 'old-1',
            'name': 'Arroz antiguo',
            'category': 'Alimentación',
            'amount': -10.0,
            'date': yesterday.toIso8601String().split('T').first,
            'createdAt': yesterday.toIso8601String(),
          },
        ],
      );

      final firstBatch = await bridge.extractPendingAutoSyncBatch(initialSummary);
      expect(firstBatch.baselineJustInitialized, isTrue);
      expect(firstBatch.hasAny, isFalse);

      // 2da sincronización: trae registros NUEVOS posteriores al punto de corte
      final nextSummary = WalletSummary(
        version: '1.4.5',
        month: '2026-11',
        balance: 400,
        income: 1000,
        expenses: 600,
        currency: 'PEN',
        exportedAt: futureCreatedAt,
        recentTransactions: [
          ...initialSummary.recentTransactions,
          {
            'id': 'new-platano',
            'name': 'Platano Seda',
            'productName': 'Platano Seda',
            'quantity': 6,
            'unit': 'UND',
            'category': 'Alimentación',
            'amount': -5.0,
            'date': futureCreatedAt.toIso8601String().split('T').first,
            'createdAt': futureCreatedAt.toIso8601String(),
          },
          {
            'id': 'new-polo',
            'name': 'Polo negro Nike',
            'productName': 'Polo negro Nike',
            'category': 'Ropa',
            'amount': -65.0,
            'date': futureCreatedAt.toIso8601String().split('T').first,
            'createdAt': futureCreatedAt.toIso8601String(),
          },
          {
            'id': 'new-freidora',
            'name': 'Freidora de aire Oster',
            'category': 'Hogar',
            'amount': -250.0,
            'date': futureCreatedAt.toIso8601String().split('T').first,
            'createdAt': futureCreatedAt.toIso8601String(),
          },
        ],
      );

      final secondBatch = await bridge.extractPendingAutoSyncBatch(nextSummary);
      expect(secondBatch.baselineJustInitialized, isFalse);
      expect(secondBatch.groceries.length, 1);
      expect(secondBatch.groceries.single.itemName, 'Platano Seda');
      expect(secondBatch.groceries.single.quantity, 6.0);
      expect(secondBatch.groceries.single.unit, 'unidades');
      expect(secondBatch.wardrobe.length, 1);
      expect(secondBatch.wardrobe.single.itemName, 'Polo negro Nike');
      expect(secondBatch.appliances.length, 1);
      expect(secondBatch.appliances.single.name, 'Freidora de aire Oster');
    });

    test('enruta compras de pollo entero hacia poultryBreakdowns en octavos', () async {
      SharedPreferences.setMockInitialValues({});
      final bridge = WalletPantryBridgeService();
      final cutoffBase = DateTime.now();
      await bridge.extractPendingAutoSyncBatch(WalletSummary(
        version: '1.4.5',
        month: '2026-11',
        balance: 500,
        income: 1000,
        expenses: 500,
        currency: 'PEN',
        exportedAt: cutoffBase,
        recentTransactions: const [],
      ));

      final after = cutoffBase.add(const Duration(minutes: 5));
      final batch = await bridge.extractPendingAutoSyncBatch(WalletSummary(
        version: '1.4.5',
        month: '2026-11',
        balance: 478,
        income: 1000,
        expenses: 522,
        currency: 'PEN',
        exportedAt: after,
        recentTransactions: [
          {
            'id': 'tx-pollo-entero',
            'name': '1 pollo entero',
            'productName': 'Pollo entero',
            'quantity': 1,
            'unit': 'UND',
            'category': 'Alimentación',
            'amount': -22.0,
            'date': after.toIso8601String().split('T').first,
            'createdAt': after.toIso8601String(),
          },
        ],
      ));

      expect(batch.groceries, isEmpty);
      expect(batch.poultryBreakdowns.length, 1);
      expect(batch.poultryBreakdowns.single.isWholeChicken, isTrue);
      expect(batch.poultryBreakdowns.single.totalPrice, 22.0);
      final octavos = WalletPantryBridgeService.buildWholeChickenPieces(1);
      expect(octavos.fold<int>(0, (s, p) => s + p.count), 8);
      expect(octavos.any((p) => p.name == 'Entrepierna de pollo' && p.count == 2), isTrue);

      final diezPresas = WalletPantryBridgeService.buildWholeChickenPieces(1, breastInFour: true);
      expect(diezPresas.fold<int>(0, (s, p) => s + p.count), 10);
      expect(diezPresas.any((p) => p.name == 'Presa de pecho de pollo' && p.count == 4), isTrue);
    });
  });

  group('AppNotificationsService & NotificationSettings', () {
    test('serializa preferencias de horarios y construye mensajes contextuales', () {
      const settings = NotificationSettings(
        mealsEnabled: true,
        breakfastTime: DailyNotificationTime(7, 15),
        lunchTime: DailyNotificationTime(12, 0),
        dinnerTime: DailyNotificationTime(19, 0),
        expiryAlertsEnabled: false,
      );
      final roundTrip = NotificationSettings.fromJson(settings.toJson());
      expect(roundTrip.breakfastTime.format24h(), '07:15');
      expect(roundTrip.lunchTime.format24h(), '12:00');
      expect(roundTrip.dinnerTime.format24h(), '19:00');
      expect(roundTrip.expiryAlertsEnabled, isFalse);

      final loc = AppNotificationsService.resolveLocationForOffset(
        const Duration(hours: -5),
      );
      expect(loc.name, 'America/Lima');

      final dinnerCopy = AppNotificationsService.buildMealCopy(
        mealSlot: 2,
        ctx: const SmartNotificationContext(
          preparedMealsCount: 1,
          firstPreparedMealName: 'Pollo frito con lentejas',
        ),
      );
      expect(dinnerCopy.title, contains('lista en refri'));
      expect(dinnerCopy.body, contains('Pollo frito con lentejas'));
    });
  });

  group('BodyProfileNotifier', () {
    test('persiste perfil, sincroniza meta con Cocina y fusiona datos del Escáner sin perder medidas', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bodyProfileProvider.notifier);
      await notifier.saveProfile(
        const BodyCompositionProfile(
          heightCm: 175,
          weightKg: 76,
          age: 28,
          sex: BiologicalSex.male,
          activityLevel: ActivityLevel.moderate,
          goalMode: BodyGoalMode.fatLoss,
          neckCm: 38,
          waistCm: 86,
        ),
        recordCheckIn: true,
      );

      final saved = container.read(bodyProfileProvider);
      expect(saved.hasCoreMetrics, isTrue);
      expect(saved.history.length, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(BodyProfileNotifier.cocinaGoalKey),
        NutritionGoal.loseWeight.name,
      );

      // Escáner de Armario actualiza peso y rango visual sin borrar neckCm/waistCm/age
      await notifier.syncFromPhysicalScanner(
        heightCm: 175,
        weightKg: 75.2,
        visualBodyFatMin: 17,
        visualBodyFatMax: 21,
        visualBuildNote: 'Complexión media',
      );

      final merged = container.read(bodyProfileProvider);
      expect(merged.weightKg, 75.2);
      expect(merged.neckCm, 38);
      expect(merged.waistCm, 86);
      expect(merged.age, 28);
      expect(merged.visualBodyFatMin, 17);
      expect(merged.visualBodyFatMax, 21);
      // Mismo día deduplica el check-in
      expect(merged.history.length, 1);
      expect(merged.history.single.weightKg, 75.2);
    });
  });
}
