import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:core/core.dart';
import 'package:cocina/cocina.dart';
import 'package:cocina/src/providers/cooking_session_provider.dart';
import 'package:cocina/src/providers/prepared_meals_provider.dart';
import 'package:cocina/src/screens/inventory_tab.dart';
import 'package:cocina/src/screens/widgets/recipe_cook_helper.dart';
import 'package:domain/domain.dart';

class _FakeGeminiRescueService extends GeminiService {
  _FakeGeminiRescueService()
      : super(
          connectivity: ConnectivityService(),
          cache: OfflineCacheService(),
          apiKey: '',
        );

  @override
  Future<String?> suggestRescueRecipesGemini({
    required List<String> priorityIngredients,
    required List<String> allPantryNames,
    required String goalLabel,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return '1. Tacu tacu express (10 min)\nUsa tu Menestra lentejas baby.';
  }
}

class _FakeCocinaRepo implements ICocinaRepository {
  final List<InventoryIngredient> items;
  final List<ShoppingItem> shopping = [];

  _FakeCocinaRepo(this.items);

  @override
  Future<List<InventoryIngredient>> getAllIngredients() async =>
      List<InventoryIngredient>.from(items);

  @override
  Future<InventoryIngredient> addIngredient(InventoryIngredient ing) async {
    items.add(ing);
    return ing;
  }

  @override
  Future<void> updateIngredient(InventoryIngredient ing) async {
    final idx = items.indexWhere((i) => i.id == ing.id);
    if (idx != -1) items[idx] = ing;
  }

  @override
  Future<void> deleteIngredient(String id) async {
    items.removeWhere((i) => i.id == id);
  }

  @override
  Future<List<Recipe>> getAllRecipes() async => const [];

  @override
  Future<List<ShoppingItem>> getShoppingList() async =>
      List<ShoppingItem>.from(shopping);

  @override
  Future<ShoppingItem> addShoppingItem(ShoppingItem item) async {
    shopping.add(item);
    return item;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('InventoryIngredient entity', () {
    test('ingrediente con fecha de vencimiento', () {
      final expiry = DateTime(2026, 12, 31);
      final i = InventoryIngredient(
        id: '1',
        name: 'Leche',
        primaryCategory: 'Lácteos',
        quantity: 1,
        unit: 'L',
        expirationDate: expiry,
      );
      expect(i.expirationDate, expiry);
    });

    test('AiJsonParser limpia bloques markdown y extrae JSON', () {
      const raw = '```json\n{"ok": true}\n```';
      expect(AiJsonParser.decodeMap(raw), {'ok': true});
    });
  });

  group('InventoryNotifier & ShoppingList smart cook flow', () {
    test(
        'deductRecipeIngredients descuenta 2 cucharadas (30 ml) de Ajos molidos (300 ml) y restoreCookedIngredients lo revierte',
        () async {
      const ajos = InventoryIngredient(
        id: 'inv_ajos',
        name: 'Ajos molidos',
        primaryCategory: 'Condimentos',
        quantity: 300.0,
        unit: 'ml',
      );
      final repo = _FakeCocinaRepo([ajos]);
      final container = ProviderContainer(
        overrides: [cocinaRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(inventoryProvider.notifier);
      await notifier.load();

      final deducted = await notifier.deductRecipeIngredients(const [
        RecipeIngredient(
          id: 'r1',
          recipeId: 'rec1',
          ingredientName: 'ajos',
          quantity: 2.0,
          unit: 'cucharadas',
        ),
        RecipeIngredient(
          id: 'r2',
          recipeId: 'rec1',
          ingredientName: 'sal',
          quantity: 1.0,
          unit: 'cdta',
        ),
      ]);

      expect(deducted, ['Ajos molidos']);
      expect(container.read(inventoryProvider).ingredients.single.quantity,
          closeTo(270.0, 0.001));

      await notifier.restoreCookedIngredients([ajos]);
      expect(container.read(inventoryProvider).ingredients.single.quantity,
          closeTo(300.0, 0.001));
    });

    test('addMissingToShoppingList agrega faltantes evitando duplicados pendientes',
        () async {
      final repo = _FakeCocinaRepo([]);
      final container = ProviderContainer(
        overrides: [cocinaRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final recipesNotifier = container.read(recipesProvider.notifier);
      await recipesNotifier.load();

      final added1 = await recipesNotifier.addMissingToShoppingList([
        (name: 'Sal', quantity: 1.0, unit: 'cdta'),
        (name: 'sal', quantity: 2.0, unit: 'cdta'),
      ]);
      expect(added1, 1);
      expect(container.read(recipesProvider).shoppingList.length, 1);
    });

    test('deductRecipeIngredients convierte unidades de papa contra stock en kg', () async {
      const papa = InventoryIngredient(
        id: 'inv_papa',
        name: 'Papa blanca',
        primaryCategory: 'Tubérculos y raíces',
        quantity: 1.0,
        unit: 'kg',
      );
      final repo = _FakeCocinaRepo([papa]);
      final container = ProviderContainer(
        overrides: [cocinaRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(inventoryProvider.notifier);
      await notifier.load();

      final deducted = await notifier.deductRecipeIngredients(const [
        RecipeIngredient(
          id: 'r_papa',
          recipeId: 'rec1',
          ingredientName: 'papa',
          quantity: 3.0,
          unit: 'unidades',
        ),
      ]);

      expect(deducted, ['Papa blanca']);
      // 3 papas * 170 g = 0.51 kg descontados → quedan ~0.49 kg
      expect(container.read(inventoryProvider).ingredients.single.quantity,
          closeTo(0.49, 0.05));
    });

    test(
        'applyIngredientQuantityOverrides reduce 2 papas a 1 papa solo para esta cocción y descuenta solo 1',
        () async {
      const papa = InventoryIngredient(
        id: 'inv_papa',
        name: 'Papa blanca',
        primaryCategory: 'Tubérculos y raíces',
        quantity: 4.0,
        unit: 'unidades',
      );
      final repo = _FakeCocinaRepo([papa]);
      final container = ProviderContainer(
        overrides: [cocinaRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(inventoryProvider.notifier);
      await notifier.load();

      const scaled = [
        RecipeIngredient(
          id: 'r_papa',
          recipeId: 'rec_menestra',
          ingredientName: 'papa blanca picada en cuadritos',
          quantity: 2.0,
          unit: 'unidades',
        ),
        RecipeIngredient(
          id: 'r_sal',
          recipeId: 'rec_menestra',
          ingredientName: 'sal',
          quantity: 1.0,
          unit: 'cdta',
        ),
      ];

      final adjusted = applyIngredientQuantityOverrides(scaled, {0: 1.0, 1: 0.0})
          .where((i) => i.quantity > 0)
          .toList();

      expect(adjusted.length, 1);
      expect(adjusted.single.quantity, 1.0);

      await notifier.deductRecipeIngredients(adjusted);
      expect(container.read(inventoryProvider).ingredients.single.quantity,
          closeTo(3.0, 0.001));
    });

    test('CookingSessionNotifier.addExtra acumula extras añadidos durante la cocción',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sessionNotifier = container.read(cookingSessionProvider.notifier);
      sessionNotifier.startSession(
        recipeName: 'Menestra de lentejas baby',
        recipeId: 'rec_menestra',
        originalServings: 4,
        scaledServings: 4,
        estimatedDurationMinutes: 45,
      );

      sessionNotifier.addExtra(
        pantryId: 'inv_huevo',
        name: 'Huevo de gallina',
        quantity: 4.0,
        unit: 'unidades',
      );
      sessionNotifier.addExtra(
        pantryId: 'inv_huevo',
        name: 'Huevo de gallina',
        quantity: 2.0,
        unit: 'unidades',
      );

      final session = container.read(cookingSessionProvider);
      expect(session, isNotNull);
      expect(session!.extras.length, 1);
      expect(session.extras.single.quantity, closeTo(6.0, 0.001));
      expect(session.extras.single.name, 'Huevo de gallina');

      sessionNotifier.endSession();
      expect(container.read(cookingSessionProvider), isNull);
    });

    test(
        'buildCookConfirmationData mueve sustitutos IA a deducibles y los quita de faltantes',
        () {
      const pollo = InventoryIngredient(
        id: 'inv_pollo',
        name: 'Pierna de pollo',
        primaryCategory: 'Carnes y Aves',
        quantity: 6.0,
        unit: 'unidades',
      );
      const tomate = InventoryIngredient(
        id: 'inv_tomate',
        name: 'Tomate',
        primaryCategory: 'Verduras',
        quantity: 3.0,
        unit: 'unidades',
      );
      const pantry = [pollo, tomate];

      const recipeReqs = [
        RecipeIngredient(
          id: 'r1',
          recipeId: 'rec_lentejas',
          ingredientName: 'Pollo en presas',
          quantity: 2.0,
          unit: 'unidades',
        ),
        RecipeIngredient(
          id: 'r2',
          recipeId: 'rec_lentejas',
          ingredientName: 'Ají especial (panca) en pasta',
          quantity: 2.0,
          unit: 'cucharadas',
        ),
        RecipeIngredient(
          id: 'r3',
          recipeId: 'rec_lentejas',
          ingredientName: 'Sal',
          quantity: 1.0,
          unit: 'al gusto',
        ),
      ];

      final checks = IngredientMatcher.evaluateRecipe(
        recipeIngredients: recipeReqs,
        inventory: pantry,
      );
      final ajiKey =
          IngredientMatcher.normalizeText('Ají especial (panca) en pasta');

      final confirmData = buildCookConfirmationData(
        checks: checks,
        adaptedSubstitutes: {
          ajiKey: (
            pantryId: tomate.id,
            pantryName: tomate.name,
            pantryUnit: tomate.unit,
            quantity: 1.0,
            reason: 'Cuerpo y color al aderezo',
          ),
        },
        pantry: pantry,
      );

      expect(
        confirmData.deductibleRows.map((r) => r.pantry.name).toList(),
        ['Pierna de pollo', 'Tomate'],
      );
      final tomateRow = confirmData.deductibleRows.last;
      expect(tomateRow.defaultDeduct, closeTo(1.0, 0.001));
      expect(tomateRow.replacesNames, ['Ají especial (panca) en pasta']);
      expect(tomateRow.willDeplete, isFalse);

      expect(
        confirmData.alertChecks.map((c) => c.requirement.ingredientName).toList(),
        ['Sal'],
      );
    });

    test(
        'PreparedMealsNotifier guarda sobras, descuenta porciones y extras y migra registros antiguos de Despensa',
        () async {
      SharedPreferences.setMockInitialValues({});
      const legacyMain = InventoryIngredient(
        id: 'leg_main',
        name: 'Pollo frito con lentejas (preparado)',
        primaryCategory: 'Preparados / Listos',
        subCategory: 'Porción guardada',
        preparation: 'cocido / listo',
        quantity: 2.0,
        unit: 'unidades',
      );
      const legacyExtra = InventoryIngredient(
        id: 'leg_extra',
        name: 'Huevos (cocido)',
        primaryCategory: 'Preparados / Listos',
        subCategory: 'Extra listo',
        preparation: 'cocido / listo',
        quantity: 3.0,
        unit: 'unidades',
      );

      final repo = _FakeCocinaRepo([legacyMain, legacyExtra]);
      final container = ProviderContainer(
        overrides: [cocinaRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final invNotifier = container.read(inventoryProvider.notifier);
      await invNotifier.load();

      final mealsNotifier = container.read(preparedMealsProvider.notifier);
      final migrated = await mealsNotifier.migrateLegacyFromPantry(
        container.read(inventoryProvider).ingredients,
        invNotifier.delete,
      );

      expect(migrated, 2);
      expect(container.read(inventoryProvider).ingredients, isEmpty);

      final list1 = container.read(preparedMealsProvider);
      expect(list1.length, 1);
      expect(list1.single.recipeName, 'Pollo frito con lentejas');
      expect(list1.single.remainingServings, closeTo(2.0, 0.001));
      expect(list1.single.extras.single.name, 'Huevos');
      expect(list1.single.extras.single.remainingQty, closeTo(3.0, 0.001));

      await mealsNotifier.consumeServings(
        list1.single.id,
        servings: 1.0,
        extraQuantities: {'Huevos': 2.0},
      );
      final list2 = container.read(preparedMealsProvider);
      expect(list2.single.remainingServings, closeTo(1.0, 0.001));
      expect(list2.single.extras.single.remainingQty, closeTo(1.0, 0.001));

      await mealsNotifier.consumeServings(
        list1.single.id,
        servings: 1.0,
        extraQuantities: {'Huevos': 1.0},
      );
      expect(container.read(preparedMealsProvider), isEmpty);
    });

    testWidgets(
        'InventoryTab botón "¿Qué preparo hoy?" abre ideas con Gemini dentro de StatefulShellRoute sin pantalla negra',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      const menestra = InventoryIngredient(
        id: 'inv_menestra',
        name: 'Menestra lentejas baby',
        primaryCategory: 'Legumbres',
        preparation: 'cocido / listo',
        quantity: 1.0,
        unit: 'unidades',
      );
      final repo = _FakeCocinaRepo([menestra]);
      final router = GoRouter(
        initialLocation: '/cocina',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, __, shell) => Scaffold(body: shell),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/cocina',
                    builder: (_, __) => const InventoryTab(),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cocinaRepositoryProvider.overrideWithValue(repo),
            geminiProvider.overrideWithValue(_FakeGeminiRescueService()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final rescueBtn = find.textContaining('¿Qué preparo hoy?');
      expect(rescueBtn, findsOneWidget);
      await tester.tap(rescueBtn);
      await tester.pump();
      expect(find.text('Ideas de rescate con Gemini'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.textContaining('Tacu tacu express'), findsOneWidget);

      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('Ideas de rescate con Gemini'), findsNothing);
      expect(find.textContaining('¿Qué preparo hoy?'), findsOneWidget);
    });
  });
}
