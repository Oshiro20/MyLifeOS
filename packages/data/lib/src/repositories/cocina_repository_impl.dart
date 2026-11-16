import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:domain/domain.dart';
import 'package:data/data.dart';

class CocinaRepository implements ICocinaRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  CocinaRepository(this._db);

  // ── Mappers ──────────────────────────────────────────────────────────────────
  InventoryIngredient _toIngredient(InventoryIngredientEntry e) =>
      InventoryIngredient(
        id: e.id,
        name: e.name,
        primaryCategory: e.primaryCategory,
        subCategory: e.subCategory,
        preparation: e.preparation,
        quantity: e.quantity,
        unit: e.unit,
        expirationDate: e.expirationDate,
        imageAssetId: e.imageAssetId,
        storageArea: e.storageArea,
      );

  Recipe _toRecipe(RecipeEntry r, List<RecipeIngredientEntry> ings) => Recipe(
        id: r.id,
        name: r.name,
        description: r.description,
        durationMinutes: r.durationMinutes,
        servings: r.servings,
        instructions: _decodeStringList(r.instructionsJson),
        ingredients: ings
            .map((i) => RecipeIngredient(
                  id: i.id,
                  recipeId: i.recipeId,
                  ingredientName: i.ingredientName,
                  quantity: i.quantity,
                  unit: i.unit,
                ))
            .toList(),
        tags: r.tagsCsv.isEmpty ? [] : r.tagsCsv.split(','),
        imageAssetId: r.imageAssetId,
        goal: NutritionGoal
            .values[r.goalIndex.clamp(0, NutritionGoal.values.length - 1)],
        isFavorite: r.isFavorite,
        createdAt: r.createdAt,
        rating: r.rating > 0 ? r.rating : null,
        cuisineStyle: r.region.isNotEmpty ? r.region : null,
        fuenteUrl: r.sourceUrl,
        fuenteLabel: r.sourceIndex == 0
            ? 'Local'
            : r.sourceIndex == 1
                ? 'TheMealDB'
                : 'Chef IA',
        tipoComida: r.mealType != null && r.mealType!.isNotEmpty
            ? MealType.values.firstWhere(
                (m) => m.name == r.mealType,
                orElse: () => MealType.otro,
              )
            : null,
      );

  List<String> _decodeStringList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return const [];
  }

  ShoppingItem _toShoppingItem(ShoppingItemEntry e) => ShoppingItem(
        id: e.id,
        name: e.name,
        quantity: e.quantity,
        unit: e.unit,
        bought: e.bought,
        createdAt: e.createdAt,
      );

  // ── Inventario ───────────────────────────────────────────────────────────────
  @override
  Future<List<InventoryIngredient>> getAllIngredients() async {
    final entries = await _db.select(_db.inventoryIngredients).get();
    return entries.map(_toIngredient).toList();
  }

  @override
  Future<InventoryIngredient> addIngredient(InventoryIngredient ing) async {
    final id = ing.id.isEmpty ? _uuid.v4() : ing.id;
    await _db.into(_db.inventoryIngredients).insert(
          InventoryIngredientsCompanion(
            id: Value(id),
            name: Value(ing.name),
            primaryCategory: Value(ing.primaryCategory),
            subCategory: Value(ing.subCategory),
            preparation: Value(ing.preparation),
            quantity: Value(ing.quantity),
            unit: Value(ing.unit),
            expirationDate: Value(ing.expirationDate),
            imageAssetId: Value(ing.imageAssetId),
            storageArea: Value(ing.storageArea),
          ),
        );
    return ing.copyWith(id: id);
  }

  @override
  Future<void> updateIngredient(InventoryIngredient ing) async {
    await (_db.update(_db.inventoryIngredients)
          ..where((t) => t.id.equals(ing.id)))
        .write(InventoryIngredientsCompanion(
      name: Value(ing.name),
      primaryCategory: Value(ing.primaryCategory),
      subCategory: Value(ing.subCategory),
      preparation: Value(ing.preparation),
      quantity: Value(ing.quantity),
      unit: Value(ing.unit),
      expirationDate: Value(ing.expirationDate),
      imageAssetId: Value(ing.imageAssetId),
      storageArea: Value(ing.storageArea),
    ));
  }

  @override
  Future<void> deleteIngredient(String id) async {
    final existing = await (_db.select(_db.inventoryIngredients)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    await (_db.delete(_db.inventoryIngredients)..where((t) => t.id.equals(id)))
        .go();
    await AppDatabase.deleteLocalFileIfPresent(existing?.imageAssetId);
  }

  // ── Recetas ──────────────────────────────────────────────────────────────────
  @override
  Future<List<Recipe>> getAllRecipes() async {
    final recipes = await _db.select(_db.recipes).get();
    if (recipes.isEmpty) return const [];
    final allIngs = await _db.select(_db.recipeIngredients).get();
    final grouped = <String, List<RecipeIngredientEntry>>{};
    for (final ing in allIngs) {
      grouped.putIfAbsent(ing.recipeId, () => []).add(ing);
    }
    return recipes
        .map((r) => _toRecipe(r, grouped[r.id] ?? const []))
        .toList();
  }

  @override
  Future<Recipe?> getRecipeById(String id) async {
    final q = _db.select(_db.recipes)..where((t) => t.id.equals(id));
    final r = await q.getSingleOrNull();
    if (r == null) return null;
    final ings = await (_db.select(_db.recipeIngredients)
          ..where((t) => t.recipeId.equals(id)))
        .get();
    return _toRecipe(r, ings);
  }

  @override
  Future<Recipe> saveRecipe(Recipe recipe) async {
    final id = recipe.id.isEmpty ? _uuid.v4() : recipe.id;
    final now = recipe.createdAt;
    final sourceIndex = recipe.fuenteLabel == 'TheMealDB'
        ? 1
        : (recipe.fuenteLabel == 'Chef IA' || recipe.fuenteLabel == 'IA')
            ? 2
            : 0;

    await _db.transaction(() async {
      await _db.into(_db.recipes).insertOnConflictUpdate(RecipesCompanion(
            id: Value(id),
            name: Value(recipe.name),
            description: Value(recipe.description),
            durationMinutes: Value(recipe.durationMinutes),
            servings: Value(recipe.servings),
            instructionsJson: Value(jsonEncode(recipe.instructions)),
            tagsCsv: Value(recipe.tags.join(',')),
            imageAssetId: Value(recipe.imageAssetId),
            goalIndex: Value(recipe.goal.index),
            isFavorite: Value(recipe.isFavorite),
            createdAt: Value(now),
            sourceIndex: Value(sourceIndex),
            region: Value(recipe.cuisineStyle ?? ''),
            difficulty: Value('Media'),
            sourceUrl: Value(recipe.fuenteUrl),
            mealType: Value(recipe.tipoComida?.name),
            rating: Value(recipe.rating ?? 0),
          ));

      // Reemplazar ingredientes de la receta
      await (_db.delete(_db.recipeIngredients)
            ..where((t) => t.recipeId.equals(id)))
          .go();

      for (final ing in recipe.ingredients) {
        await _db.into(_db.recipeIngredients).insert(
              RecipeIngredientsCompanion(
                id: Value(ing.id.isEmpty ? _uuid.v4() : ing.id),
                recipeId: Value(id),
                ingredientName: Value(ing.ingredientName),
                quantity: Value(ing.quantity),
                unit: Value(ing.unit),
              ),
            );
      }
    });

    return recipe.copyWith(id: id);
  }

  @override
  Future<void> deleteRecipe(String id) async {
    final existing = await (_db.select(_db.recipes)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    await _db.transaction(() async {
      await (_db.delete(_db.weeklyMenuEntries)
            ..where((t) => t.recipeId.equals(id)))
          .go();
      await (_db.delete(_db.recipeIngredients)
            ..where((t) => t.recipeId.equals(id)))
          .go();
      await (_db.delete(_db.recipes)..where((t) => t.id.equals(id))).go();
    });
    await AppDatabase.deleteLocalFileIfPresent(existing?.imageAssetId);
  }

  @override
  Future<void> toggleFavorite(String recipeId) async {
    final r = await getRecipeById(recipeId);
    if (r == null) return;
    await (_db.update(_db.recipes)..where((t) => t.id.equals(recipeId)))
        .write(RecipesCompanion(isFavorite: Value(!r.isFavorite)));
  }

  @override
  Future<Recipe> updateRecipe(Recipe recipe) async {
    final existing = await getRecipeById(recipe.id);
    if (existing == null) throw Exception('Receta no encontrada');

    await _db.transaction(() async {
      await (_db.update(_db.recipes)..where((t) => t.id.equals(recipe.id)))
          .write(RecipesCompanion(
        name: Value(recipe.name),
        description: Value(recipe.description),
        durationMinutes: Value(recipe.durationMinutes),
        servings: Value(recipe.servings),
        instructionsJson: Value(jsonEncode(recipe.instructions)),
        tagsCsv: Value(recipe.tags.join(',')),
        imageAssetId: Value(recipe.imageAssetId),
        goalIndex: Value(recipe.goal.index),
        isFavorite: Value(recipe.isFavorite),
        region: Value(recipe.cuisineStyle ?? ''),
        sourceUrl: Value(recipe.fuenteUrl),
        mealType: Value(recipe.tipoComida?.name),
        rating: Value(recipe.rating ?? 0),
      ));

      await (_db.delete(_db.recipeIngredients)
            ..where((t) => t.recipeId.equals(recipe.id)))
          .go();

      for (final ing in recipe.ingredients) {
        await _db.into(_db.recipeIngredients).insert(
              RecipeIngredientsCompanion(
                id: Value(ing.id.isEmpty ? _uuid.v4() : ing.id),
                recipeId: Value(recipe.id),
                ingredientName: Value(ing.ingredientName),
                quantity: Value(ing.quantity),
                unit: Value(ing.unit),
              ),
            );
      }
    });

    return recipe;
  }

  // ── Sugerencias ──────────────────────────────────────────────────────────────
  @override
  Future<List<Recipe>> suggestRecipes({
    required List<InventoryIngredient> inventory,
    NutritionGoal goal = NutritionGoal.maintain,
    int limit = 10,
  }) async {
    final allRecipes = await getAllRecipes();
    final availableNames = inventory.map((i) => i.name.toLowerCase()).toSet();

    // Puntuar cada receta según cobertura de ingredientes
    final scored = allRecipes.map((recipe) {
      final required = recipe.ingredients.length;
      if (required == 0) return (recipe: recipe, score: 1.0);
      final found = recipe.ingredients
          .where((i) => availableNames.contains(i.ingredientName.toLowerCase()))
          .length;
      final score = found / required;
      return (recipe: recipe, score: score);
    }).toList();

    // Solo recetas con al menos 75% de cobertura y que coincidan con el objetivo
    final filtered = scored
        .where((s) =>
            s.score >= 0.75 &&
            (s.recipe.goal == goal || goal == NutritionGoal.maintain))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return filtered.take(limit).map((s) => s.recipe).toList();
  }

  // ── Lista de compras ─────────────────────────────────────────────────────────
  @override
  Future<List<ShoppingItem>> getShoppingList() async {
    final entries = await _db.select(_db.shoppingItems).get();
    return entries.map(_toShoppingItem).toList();
  }

  @override
  Future<ShoppingItem> addShoppingItem(ShoppingItem item) async {
    final id = item.id.isEmpty ? _uuid.v4() : item.id;
    await _db.into(_db.shoppingItems).insert(ShoppingItemsCompanion(
          id: Value(id),
          name: Value(item.name),
          quantity: Value(item.quantity),
          unit: Value(item.unit),
          bought: Value(item.bought),
          createdAt: Value(item.createdAt),
        ));
    return ShoppingItem(
      id: id,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      createdAt: item.createdAt,
    );
  }

  @override
  Future<void> toggleShoppingItem(String id) async {
    final entry = await (_db.select(_db.shoppingItems)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (entry == null) return;
    await (_db.update(_db.shoppingItems)..where((t) => t.id.equals(id)))
        .write(ShoppingItemsCompanion(bought: Value(!entry.bought)));
  }

  @override
  Future<void> deleteShoppingItem(String id) async {
    await (_db.delete(_db.shoppingItems)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<List<ShoppingItem>> generateShoppingListFromRecipes(
    List<Recipe> recipes,
    List<InventoryIngredient> inventory,
  ) async {
    // Build pantry inventory map: name -> (quantity, unit)
    final pantryMap = <String, (double, String)>{};
    for (final item in inventory) {
      final key = item.name.toLowerCase();
      if (pantryMap.containsKey(key)) {
        // Sum quantities for same item
        final existing = pantryMap[key]!;
        // Use the unit of the existing item
        pantryMap[key] = (existing.$1 + item.quantity, existing.$2);
      } else {
        pantryMap[key] = (item.quantity, item.unit);
      }
    }

    // Units that are impractical for shopping (need conversion)
    const recipeUnits = {
      'cucharadas',
      'cucharadita',
      'cucharaditas',
      'pizca',
      'pizcas',
      'al gusto',
      'porcion',
      'porciones'
    };

    // Common grocery item packaging mapping
    // Key: ingredient name pattern -> suggested shopping unit
    final packagingMap = {
      'aceite': 'botella',
      'mayonesa': 'frasco',
      'ketchup': 'botella',
      'mostaza': 'botella',
      'soya': 'botella',
      'vinagre': 'botella',
      'leche': 'cartón',
      'crema': 'envase',
      'yogur': 'envase',
      'yogurt': 'envase',
      'mantequilla': 'paquete',
      'margarina': 'paquete',
      'arroz': 'paquete',
      'fideos': 'paquete',
      'tallarín': 'paquete',
      'tallarines': 'paquete',
      'spaghetti': 'paquete',
      'harina': 'paquete',
      'azúcar': 'paquete',
      'sal': 'paquete',
      'atún': 'lata',
      'sardina': 'lata',
      'arveja': 'lata',
      'choclo': 'lata',
      'champignones': 'lata',
      'jugo': 'botella',
      'gaseosa': 'botella',
      'refresco': 'botella',
    };

    // Shopping unit mapping
    String toShoppingUnit(
        String recipeUnit, double qty, String ingredientName) {
      final lower = recipeUnit.toLowerCase();
      final ingLower = ingredientName.toLowerCase();

      // Check if it's a recipe-only unit
      if (recipeUnits.contains(lower)) {
        // Check packaging map for this ingredient
        for (final entry in packagingMap.entries) {
          if (ingLower.contains(entry.key)) {
            return entry.value; // Use packaging unit
          }
        }
        // Fallback: suggest 1 unit of something
        return 'unidades';
      }

      // Already practical units
      if ([
        'unidades',
        'paquete',
        'paquetes',
        'lata',
        'latas',
        'botella',
        'botellas',
        'frasco',
        'frascos',
        'envase',
        'envases',
        'cartón',
        'cartones'
      ].contains(lower)) {
        return lower;
      }

      // Weight/volume units - keep as is for produce
      if (['gramos', 'kilos', 'litros', 'mililitros'].contains(lower)) {
        return lower;
      }

      // Default: keep original unit
      return recipeUnit;
    }

    final needed = <String, (double, String)>{};
    for (final recipe in recipes) {
      for (final ri in recipe.ingredients) {
        final key = ri.ingredientName.toLowerCase();
        final pantryData = pantryMap[key];

        if (pantryData == null) {
          // Don't have this ingredient at all → need to buy
          final shoppingUnit =
              toShoppingUnit(ri.unit, ri.quantity, ri.ingredientName);
          if (needed.containsKey(key)) {
            final existing = needed[key]!;
            // Sum quantities, use the more practical unit
            needed[key] = (existing.$1 + ri.quantity, existing.$2);
          } else {
            // For packaging units, always suggest 1
            final isPackaging = [
              'botella',
              'frasco',
              'lata',
              'paquete',
              'envase',
              'cartón'
            ].contains(shoppingUnit);
            needed[key] = (isPackaging ? 1.0 : ri.quantity, shoppingUnit);
          }
        }
        // If we have it in pantry, skip it (already have it)
      }
    }

    final existingShopping = await getShoppingList();
    final existingPendingNames = existingShopping
        .where((i) => !i.bought)
        .map((i) => i.name.trim().toLowerCase())
        .toSet();

    final now = DateTime.now();
    final items = <ShoppingItem>[];
    for (final entry in needed.entries) {
      if (existingPendingNames.contains(entry.key)) continue;
      final item = await addShoppingItem(ShoppingItem(
        id: '',
        name: entry.key,
        quantity: entry.value.$1,
        unit: entry.value.$2,
        createdAt: now,
      ));
      items.add(item);
    }
    return items;
  }

  // ── Menú Semanal ────────────────────────────────────────────────────────────

  @override
  Future<List<WeeklyMenuEntry>> getWeeklyMenu() async {
    final rows = await (_db.select(_db.weeklyMenuEntries)
          ..orderBy([
            (t) => OrderingTerm.asc(t.dayOfWeek),
            (t) => OrderingTerm.asc(t.mealType)
          ]))
        .get();
    return rows
        .map((r) => WeeklyMenuEntry(
              id: r.id,
              dayOfWeek: r.dayOfWeek,
              mealType: r.mealType,
              recipeId: r.recipeId,
              isCustom: r.isCustom,
            ))
        .toList();
  }

  @override
  Future<void> saveWeeklyMenuEntry(WeeklyMenuEntry entry) async {
    await _db.into(_db.weeklyMenuEntries).insert(
          WeeklyMenuEntriesCompanion(
            id: Value(entry.id),
            dayOfWeek: Value(entry.dayOfWeek),
            mealType: Value(entry.mealType),
            recipeId: Value(entry.recipeId),
            isCustom: Value(entry.isCustom),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  @override
  Future<void> clearWeeklyMenu() async {
    await _db.delete(_db.weeklyMenuEntries).go();
  }
}
