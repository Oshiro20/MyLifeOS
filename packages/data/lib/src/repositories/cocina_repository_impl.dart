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
        instructions: (jsonDecode(r.instructionsJson) as List)
            .map((e) => e.toString())
            .toList(),
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
        goal: NutritionGoal.values[r.goalIndex],
        isFavorite: r.isFavorite,
        createdAt: r.createdAt,
      );

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
          quantity: Value(ing.quantity),
          unit: Value(ing.unit),
          expirationDate: Value(ing.expirationDate),
          imageAssetId: Value(ing.imageAssetId),
          storageArea: Value(ing.storageArea),
        ));
  }

  @override
  Future<void> deleteIngredient(String id) async {
    await (_db.delete(_db.inventoryIngredients)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  // ── Recetas ──────────────────────────────────────────────────────────────────
  @override
  Future<List<Recipe>> getAllRecipes() async {
    final recipes = await _db.select(_db.recipes).get();
    return Future.wait(recipes.map((r) async {
      final ings = await (_db.select(_db.recipeIngredients)
            ..where((t) => t.recipeId.equals(r.id)))
          .get();
      return _toRecipe(r, ings);
    }));
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

    return recipe.copyWith(id: id);
  }

  @override
  Future<void> deleteRecipe(String id) async {
    await (_db.delete(_db.recipeIngredients)
          ..where((t) => t.recipeId.equals(id)))
        .go();
    await (_db.delete(_db.recipes)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> toggleFavorite(String recipeId) async {
    final r = await getRecipeById(recipeId);
    if (r == null) return;
    await (_db.update(_db.recipes)..where((t) => t.id.equals(recipeId)))
        .write(RecipesCompanion(isFavorite: Value(!r.isFavorite)));
  }

  // ── Sugerencias ──────────────────────────────────────────────────────────────
  @override
  Future<List<Recipe>> suggestRecipes({
    required List<InventoryIngredient> inventory,
    NutritionGoal goal = NutritionGoal.maintain,
    int limit = 10,
  }) async {
    final allRecipes = await getAllRecipes();
    final availableNames =
        inventory.map((i) => i.name.toLowerCase()).toSet();

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
    final availableMap = {
      for (final i in inventory) i.name.toLowerCase(): i.quantity
    };

    final needed = <String, (double, String)>{};
    for (final recipe in recipes) {
      for (final ri in recipe.ingredients) {
        final key = ri.ingredientName.toLowerCase();
        final have = availableMap[key] ?? 0.0;
        final deficit = ri.quantity - have;
        if (deficit > 0) {
          if (needed.containsKey(key)) {
            final existing = needed[key]!;
            needed[key] = (existing.$1 + deficit, existing.$2);
          } else {
            needed[key] = (deficit, ri.unit);
          }
        }
      }
    }

    final now = DateTime.now();
    final items = <ShoppingItem>[];
    for (final entry in needed.entries) {
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
}

// ── Extensión para copyWith ───────────────────────────────────────────────────
extension InventoryIngredientX on InventoryIngredient {
  InventoryIngredient copyWith({
    String? id,
    String? name,
    String? primaryCategory,
    String? subCategory,
    double? quantity,
    String? unit,
    DateTime? expirationDate,
    String? imageAssetId,
    String? storageArea,
  }) =>
      InventoryIngredient(
        id: id ?? this.id,
        name: name ?? this.name,
        primaryCategory: primaryCategory ?? this.primaryCategory,
        subCategory: subCategory ?? this.subCategory,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        expirationDate: expirationDate ?? this.expirationDate,
        imageAssetId: imageAssetId ?? this.imageAssetId,
        storageArea: storageArea ?? this.storageArea,
      );
}

extension RecipeX on Recipe {
  Recipe copyWith({
    String? id,
    String? name,
    String? description,
    int? durationMinutes,
    int? servings,
    List<String>? instructions,
    List<RecipeIngredient>? ingredients,
    List<String>? tags,
    String? imageAssetId,
    NutritionGoal? goal,
    bool? isFavorite,
    DateTime? createdAt,
  }) =>
      Recipe(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        servings: servings ?? this.servings,
        instructions: instructions ?? this.instructions,
        ingredients: ingredients ?? this.ingredients,
        tags: tags ?? this.tags,
        imageAssetId: imageAssetId ?? this.imageAssetId,
        goal: goal ?? this.goal,
        isFavorite: isFavorite ?? this.isFavorite,
        createdAt: createdAt ?? this.createdAt,
      );
}
