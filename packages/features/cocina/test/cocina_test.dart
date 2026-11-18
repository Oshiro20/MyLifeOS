import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocina/cocina.dart';
import 'package:domain/domain.dart';

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
  });
}
