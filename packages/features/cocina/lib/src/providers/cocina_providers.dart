import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:domain/domain.dart';
import 'package:data/data.dart';
import 'package:core/core.dart';
import '../utils/cooking_history_service.dart';

const _cocinaUuid = Uuid();
const _activeGoalPrefKey = 'cocina_active_nutrition_goal_v1';

/// Helper to navigate/switch Cocina tabs (0=Despensa, 1=Recetas, ..., 4=Lista)
class CocinaTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setTab(int index) => state = index;
}

final cocinaTabProvider =
    NotifierProvider<CocinaTabNotifier, int>(CocinaTabNotifier.new);

/// Result of attempting to save a recipe with duplicate check
class SaveRecipeResult {
  final bool success;
  final bool hasDuplicates;
  final List<DuplicateMatch> duplicates;
  final Recipe? savedRecipe;
  final String? error;

  const SaveRecipeResult.success({
    required this.savedRecipe,
    this.hasDuplicates = false,
    this.duplicates = const [],
  })  : success = true,
        error = null;

  const SaveRecipeResult.duplicatesFound({
    required this.duplicates,
    this.savedRecipe,
  })  : success = false,
        hasDuplicates = true,
        error = null;

  const SaveRecipeResult.error(this.error)
      : success = false,
        hasDuplicates = false,
        duplicates = const [],
        savedRecipe = null;
}

// ── Estados ───────────────────────────────────────────────────────────────────
class InventoryState {
  final List<InventoryIngredient> ingredients;
  final bool isLoading;
  final String? error;

  const InventoryState({
    this.ingredients = const [],
    this.isLoading = false,
    this.error,
  });

  InventoryState copyWith({
    List<InventoryIngredient>? ingredients,
    bool? isLoading,
    String? error,
  }) =>
      InventoryState(
        ingredients: ingredients ?? this.ingredients,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class RecipesState {
  final List<Recipe> recipes;
  final List<Recipe> suggestions;
  final List<ShoppingItem> shoppingList;
  final NutritionGoal activeGoal;
  final bool isLoading;
  final String? error;

  const RecipesState({
    this.recipes = const [],
    this.suggestions = const [],
    this.shoppingList = const [],
    this.activeGoal = NutritionGoal.maintain,
    this.isLoading = false,
    this.error,
  });

  RecipesState copyWith({
    List<Recipe>? recipes,
    List<Recipe>? suggestions,
    List<ShoppingItem>? shoppingList,
    NutritionGoal? activeGoal,
    bool? isLoading,
    String? error,
  }) =>
      RecipesState(
        recipes: recipes ?? this.recipes,
        suggestions: suggestions ?? this.suggestions,
        shoppingList: shoppingList ?? this.shoppingList,
        activeGoal: activeGoal ?? this.activeGoal,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ── Notifiers (Riverpod v3) ───────────────────────────────────────────────────
class InventoryNotifier extends Notifier<InventoryState> {
  ICocinaRepository get _repo => ref.read(cocinaRepositoryProvider);
  bool _hasLoaded = false;

  @override
  InventoryState build() {
    Future.microtask(() => load());
    return const InventoryState();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final items = await _repo.getAllIngredients();
      _hasLoaded = true;
      state = state.copyWith(ingredients: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> add(InventoryIngredient ing) async {
    try {
      final saved = await _repo.addIngredient(ing);
      state = state.copyWith(ingredients: [saved, ...state.ingredients]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> update(InventoryIngredient ing) async {
    try {
      await _repo.updateIngredient(ing);
      state = state.copyWith(ingredients: [
        for (final i in state.ingredients)
          if (i.id == ing.id) ing else i
      ]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> delete(String id) async {
    try {
      await _repo.deleteIngredient(id);
      state = state.copyWith(
          ingredients: state.ingredients.where((i) => i.id != id).toList());
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  double? _convertQtyForDeduction(
    RecipeIngredient recipeIng,
    InventoryIngredient pantryItem,
    Map<String, double> equivalences,
  ) {
    final override = IngredientMatcher.resolveCustomGramsPerUnit(
      equivalences,
      recipeIng.ingredientName,
      pantryItem.name,
    );
    final reqUnit = MeasurementUnit.fromString(recipeIng.unit);
    final invUnit = MeasurementUnit.fromString(pantryItem.unit);
    return (IngredientUnitNormalizer.convertForIngredient(
              recipeIng.quantity,
              reqUnit,
              invUnit,
              recipeIng.ingredientName,
              gramsPerUnitOverride: override,
              pantryPreparation: pantryItem.preparation,
            ) ??
            IngredientUnitNormalizer.convertForIngredient(
              recipeIng.quantity,
              reqUnit,
              invUnit,
              pantryItem.name,
              gramsPerUnitOverride: override,
              pantryPreparation: pantryItem.preparation,
            ))
        ?.value;
  }

  /// Deduct recipe ingredients from pantry
  /// Returns list of ingredient names that were deducted (for feedback)
  Future<List<String>> deductRecipeIngredients(
    List<RecipeIngredient> recipeIngredients, {
    Set<String> skipPantryIds = const {},
    List<({String pantryId, double quantity})> extraDeductions = const [],
  }) async {
    if (!_hasLoaded) {
      await load();
    }
    final equivalences = ref.read(ingredientEquivalencesProvider);
    final aliases = ref.read(learnedIngredientAliasesProvider);
    final deducted = <String>[];
    final updatedIngredients =
        List<InventoryIngredient>.from(state.ingredients);

    Future<void> applyDeductionByIndex(int matchIndex, double amount) async {
      final pantryItem = updatedIngredients[matchIndex];
      final newQty = pantryItem.quantity - amount;
      if (newQty <= 0.0001) {
        updatedIngredients.removeAt(matchIndex);
        deducted.add(pantryItem.name);
        await _repo.deleteIngredient(pantryItem.id);
      } else {
        final updated = pantryItem.copyWith(quantity: newQty);
        updatedIngredients[matchIndex] = updated;
        deducted.add(pantryItem.name);
        await _repo.updateIngredient(updated);
      }
    }

    for (final recipeIng in recipeIngredients) {
      final match = IngredientMatcher.findBestMatch(
        updatedIngredients,
        recipeIng.ingredientName,
        preferredUnit: recipeIng.unit,
        learnedAliases: aliases,
      );
      if (match == null || skipPantryIds.contains(match.id)) continue;

      final matchIndex =
          updatedIngredients.indexWhere((item) => item.id == match.id);
      if (matchIndex == -1) continue;

      final pantryItem = updatedIngredients[matchIndex];
      final converted =
          _convertQtyForDeduction(recipeIng, pantryItem, equivalences);
      if (converted == null || converted <= 0) continue;
      await applyDeductionByIndex(matchIndex, converted);
    }

    for (final extra in extraDeductions) {
      if (extra.quantity <= 0 || skipPantryIds.contains(extra.pantryId)) {
        continue;
      }
      final idx =
          updatedIngredients.indexWhere((i) => i.id == extra.pantryId);
      if (idx == -1) continue;
      await applyDeductionByIndex(idx, extra.quantity);
    }

    if (deducted.isNotEmpty) {
      state = state.copyWith(ingredients: updatedIngredients);
    }

    return deducted;
  }

  /// Restaura exactamente los ítems afectados al deshacer una cocción.
  Future<void> restoreCookedIngredients(
      List<InventoryIngredient> previousPantryItems) async {
    final restoredList = List<InventoryIngredient>.from(state.ingredients);
    for (final orig in previousPantryItems) {
      final idx = restoredList.indexWhere((i) => i.id == orig.id);
      if (idx != -1) {
        restoredList[idx] = orig;
        await _repo.updateIngredient(orig);
      } else {
        restoredList.add(orig);
        await _repo.addIngredient(orig);
      }
    }
    state = state.copyWith(ingredients: restoredList);
  }

  /// Revert a deduction (undo last cook action)
  Future<void> revertDeduction(List<RecipeIngredient> recipeIngredients) async {
    final equivalences = ref.read(ingredientEquivalencesProvider);
    final aliases = ref.read(learnedIngredientAliasesProvider);
    final revertedIngredients =
        List<InventoryIngredient>.from(state.ingredients);

    for (final recipeIng in recipeIngredients) {
      final match = IngredientMatcher.findBestMatch(
        revertedIngredients,
        recipeIng.ingredientName,
        preferredUnit: recipeIng.unit,
        learnedAliases: aliases,
      );
      final matchIndex = match == null
          ? -1
          : revertedIngredients.indexWhere((i) => i.id == match.id);

      if (matchIndex != -1) {
        final pantryItem = revertedIngredients[matchIndex];
        final converted =
            _convertQtyForDeduction(recipeIng, pantryItem, equivalences);
        if (converted == null) continue;
        final updated =
            pantryItem.copyWith(quantity: pantryItem.quantity + converted);
        revertedIngredients[matchIndex] = updated;
        await _repo.updateIngredient(updated);
      } else {
        final detected = IngredientDetector.detect(recipeIng.ingredientName);
        final restored = InventoryIngredient(
          id: _cocinaUuid.v4(),
          name: recipeIng.ingredientName,
          primaryCategory: detected.primaryCategory ?? 'Otros',
          subCategory: detected.subCategory ?? '',
          preparation: detected.suggestedPreparation ?? '',
          quantity: recipeIng.quantity,
          unit: recipeIng.unit,
          expirationDate: null,
          imageAssetId: null,
          storageArea: 'Alacena',
        );
        revertedIngredients.add(restored);
        await _repo.addIngredient(restored);
      }
    }

    state = state.copyWith(ingredients: revertedIngredients);
  }

  /// Inserta o fusiona ingredientes (por nombre y unidad compatible) en despensa.
  Future<int> _upsertToPantry(
    Iterable<
        ({
          String name,
          double quantity,
          String unit,
          String? suggestedCategory,
          String? suggestedSubCategory,
        })> entries, {
    String? storageAreaOverride,
    DateTime? expirationDateOverride,
    String? preparationOverride,
  }) async {
    if (!_hasLoaded) {
      await load();
    }
    int count = 0;
    for (final entry in entries) {
      final rawCleanName = entry.name.trim();
      if (rawCleanName.isEmpty || entry.quantity <= 0) continue;

      // Expandir multipacks de supermercado (ej. "LECHE IDEAL 6 PACK 390G" -> 6 latas + equivalencia 390g)
      final expanded = WalletPantryBridgeService.expandMultipack(
        rawCleanName,
        quantity: entry.quantity,
        unit: entry.unit,
      );
      final cleanName = expanded.cleanName;
      final effectiveQty = expanded.expandedQuantity;
      final effectiveUnit = expanded.unit;

      if (expanded.gramsPerUnit != null && expanded.gramsPerUnit! > 0) {
        await ref
            .read(ingredientEquivalencesProvider.notifier)
            .setGramsPerUnit(cleanName, expanded.gramsPerUnit!);
      }

      final existingIndex = state.ingredients.indexWhere(
        (ing) =>
            IngredientPriceService.normalizeKey(ing.name) ==
            IngredientPriceService.normalizeKey(cleanName),
      );
      if (existingIndex != -1) {
        final existing = state.ingredients[existingIndex];
        final converted = IngredientUnitNormalizer.convert(
          effectiveQty,
          MeasurementUnit.fromString(effectiveUnit),
          MeasurementUnit.fromString(existing.unit),
        );
        if (converted != null) {
          final updated = existing.copyWith(
            quantity: existing.quantity + converted,
            storageArea: storageAreaOverride ?? existing.storageArea,
            expirationDate: expirationDateOverride ?? existing.expirationDate,
          );
          await _repo.updateIngredient(updated);
          state = state.copyWith(ingredients: [
            for (int i = 0; i < state.ingredients.length; i++)
              if (i == existingIndex) updated else state.ingredients[i]
          ]);
          count++;
          continue;
        }
      }

      final detected = IngredientDetector.detect(cleanName);
      final chosenCategory =
          (entry.suggestedCategory != null && entry.suggestedCategory!.isNotEmpty)
              ? entry.suggestedCategory!
              : (detected.primaryCategory ?? 'Otros');
      final chosenSub = (entry.suggestedSubCategory != null &&
              entry.suggestedSubCategory!.isNotEmpty)
          ? entry.suggestedSubCategory!
          : (detected.subCategory ?? '');
      final newIng = InventoryIngredient(
        id: _cocinaUuid.v4(),
        name: cleanName,
        primaryCategory: chosenCategory,
        subCategory: chosenSub,
        preparation: preparationOverride ?? detected.suggestedPreparation ?? '',
        quantity: effectiveQty,
        unit: effectiveUnit,
        expirationDate: expirationDateOverride,
        imageAssetId: null,
        storageArea: storageAreaOverride ?? 'Alacena',
      );
      await _repo.addIngredient(newIng);
      state = state.copyWith(ingredients: [newIng, ...state.ingredients]);
      count++;
    }
    return count;
  }

  /// Inserta o fusiona presas/porciones desglosadas (ej. pollo en octavos).
  Future<int> upsertPoultryPieces(
    Iterable<({String name, double quantity, String unit})> entries, {
    required String storageArea,
    DateTime? expirationDate,
  }) =>
      _upsertToPantry(
        entries.map(
          (e) => (
            name: e.name,
            quantity: e.quantity,
            unit: e.unit,
            suggestedCategory: null,
            suggestedSubCategory: null,
          ),
        ),
        storageAreaOverride: storageArea,
        expirationDateOverride: expirationDate,
      );

  /// Move bought shopping items to pantry inventory
  Future<void> bulkAddBoughtToPantry(List<ShoppingItem> boughtItems) async {
    if (boughtItems.isEmpty) return;
    await _upsertToPantry(
      boughtItems.map(
        (item) => (
          name: item.name,
          quantity: item.quantity,
          unit: item.unit,
          suggestedCategory: null,
          suggestedSubCategory: null,
        ),
      ),
    );
  }

  /// Importa compras detectadas desde WalletAI a despensa, registra precios y deduplica.
  Future<int> importGroceryCandidates(
    List<WalletGroceryCandidate> candidates,
  ) async {
    if (candidates.isEmpty) return 0;

    final added = await _upsertToPantry(
      candidates.map(
        (c) => (
          name: c.itemName,
          quantity: c.quantity,
          unit: c.unit,
          suggestedCategory: c.suggestedCategory,
          suggestedSubCategory: c.suggestedSubCategory,
        ),
      ),
    );

    final priceNotifier = ref.read(ingredientPriceCatalogProvider.notifier);
    final bridge = ref.read(walletGroceryBridgeProvider);
    final seenTxKeys = <String>{};

    for (final c in candidates) {
      if (c.totalPrice != null && c.totalPrice! > 0) {
        await priceNotifier.recordPurchase(
          name: c.itemName,
          quantity: c.quantity,
          unit: c.unit,
          totalPrice: c.totalPrice!,
          currency: c.currency,
          source: 'walletai',
        );
      }
      if (seenTxKeys.add(c.transactionKey)) {
        await bridge.markTxProcessed(c.transactionKey);
      }
    }

    await ref
        .read(recipesProvider.notifier)
        .markMatchingShoppingItemsBought(candidates.map((c) => c.itemName));

    ref.read(walletPendingGroceryRefreshProvider.notifier).bump();
    return added;
  }

  /// Elimina de Despensa los artículos no comestibles / comidas servidas que se
  /// colaron antes (ej. pasaje, bolsa, desodorante, condón, almuerzo, salchichaufa),
  /// expande multipacks sin separar (ej. "LECHE IDEAL 6 PACK 390G" -> 6 latas) y
  /// reclasifica insumos mal categorizados.
  Future<({int removedCount, int recategorizedCount, int expandedCount})>
      cleanupMisclassifiedAndNoiseItems() async {
    int removed = 0;
    int recategorized = 0;
    int expandedCount = 0;
    final current = List<InventoryIngredient>.from(state.ingredients);

    for (final ing in current) {
      if (ing.subCategory == 'Porción guardada' ||
          ing.subCategory == 'Extra listo') {
        continue;
      }

      if (WalletPantryBridgeService.isNonPantryNoiseName(ing.name)) {
        await _repo.deleteIngredient(ing.id);
        removed++;
        continue;
      }

      var working = ing;
      bool changed = false;

      // 1. Expandir multipacks pendientes (ej. "LECHE IDEAL 6 PACK 390G", 1.0 -> 6.0 latas)
      final exp = WalletPantryBridgeService.expandMultipack(
        working.name,
        quantity: working.quantity,
        unit: working.unit,
      );
      if (exp.wasExpanded) {
        working = working.copyWith(
          name: exp.cleanName,
          quantity: exp.expandedQuantity,
          unit: exp.unit,
        );
        if (exp.gramsPerUnit != null && exp.gramsPerUnit! > 0) {
          await ref
              .read(ingredientEquivalencesProvider.notifier)
              .setGramsPerUnit(exp.cleanName, exp.gramsPerUnit!);
        }
        expandedCount++;
        changed = true;
      }

      // 2. Reclasificar insumos mal categorizados
      final detected = IngredientDetector.detect(working.name);
      final needsFix = detected.primaryCategory != null &&
          detected.primaryCategory != working.primaryCategory &&
          (working.primaryCategory == 'Otros' ||
              (IngredientDetector.matchesWholeWord(working.name, 'ensalada') &&
                  working.primaryCategory == 'Proteínas animales'));
      if (needsFix) {
        working = working.copyWith(
          primaryCategory: detected.primaryCategory!,
          subCategory: detected.subCategory ?? working.subCategory,
        );
        recategorized++;
        changed = true;
      }

      if (changed) {
        await _repo.updateIngredient(working);
      }
    }

    if (removed > 0 || recategorized > 0 || expandedCount > 0) {
      await load();
    }
    return (
      removedCount: removed,
      recategorizedCount: recategorized,
      expandedCount: expandedCount,
    );
  }

  /// Audita toda la Despensa actual usando IA en 1 sola llamada rápida para detectar
  /// platos servidos fuera (ej. Salchichaufa, Mostrito), no-alimentos o multipacks sin expandir.
  Future<
      ({
        List<({InventoryIngredient item, String reason})> toRemove,
        List<
            ({
              InventoryIngredient item,
              String newName,
              double newQuantity,
              String newUnit,
              String newCategory,
              String reason,
            })> toFix,
      })?> auditPantryWithAi() async {
    final items = state.ingredients
        .where((i) =>
            i.subCategory != 'Porción guardada' &&
            i.subCategory != 'Extra listo')
        .toList();
    if (items.isEmpty) {
      return (toRemove: const <({InventoryIngredient item, String reason})>[], toFix: const <({InventoryIngredient item, String newName, double newQuantity, String newUnit, String newCategory, String reason})>[]);
    }

    final payload = items
        .map((i) => {
              'id': i.id,
              'nombre': i.name,
              'categoria': i.primaryCategory,
              'cantidad': i.quantity,
              'unidad': i.unit,
            })
        .toList();

    final prompt = '''
Eres el auditor inteligente de Despensa de MyLifeOS (Perú).
Revisa esta lista actual de Despensa y detecta ÚNICAMENTE los ítems con problemas:
1. "quitar": platos preparados/comida rápida servida fuera (ej. Salchichaufa, Mostrito, Aeropuerto, Almuerzo, Ceviche, Pollo a la brasa, Menú) o artículos NO comestibles (bolsas, pasajes, aseo, farmacia).
   IMPORTANTE: SÍ conserva snacks/dulces empaquetados (galletas, chocolates, helados, barritas, cereales) porque el usuario hace seguimiento nutricional.
2. "corregir": multipacks sin expandir (ej. "LECHE IDEAL 6 PACK 390G" con cantidad 1 -> nombre "Leche Ideal 390g", cantidad 6, unidad "lata", categoria "Lácteos") o ítems en categoría claramente incorrecta.

Categorías válidas:
["Proteínas animales", "Lácteos", "Verduras", "Frutas", "Tubérculos y raíces", "Legumbres", "Cereales y granos", "Harinas y derivados", "Aceites y grasas", "Condimentos y especias", "Salsas", "Endulzantes", "Snacks y dulces", "Otros"]

Despensa actual:
${jsonEncode(payload)}

Devuelve SOLO JSON válido (sin markdown):
{"quitar": [{"id": "...", "razon": "Plato de comida rápida"}], "corregir": [{"id": "...", "nombre": "Leche Ideal 390g", "cantidad": 6, "unidad": "lata", "categoria": "Lácteos", "razon": "Multipack de 6 latas"}]}
''';

    final raw =
        await ref.read(geminiProvider).classifyWalletTransactionsJson(prompt);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final cleaned = raw
          .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
          .replaceAll('```', '')
          .trim();
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start == -1 || end <= start) return null;
      final decoded = jsonDecode(cleaned.substring(start, end + 1));
      if (decoded is! Map) return null;

      final byId = {for (final i in items) i.id: i};
      final toRemove = <({InventoryIngredient item, String reason})>[];
      final toFix = <({
        InventoryIngredient item,
        String newName,
        double newQuantity,
        String newUnit,
        String newCategory,
        String reason,
      })>[];

      if (decoded['quitar'] is List) {
        for (final row in decoded['quitar'] as List) {
          if (row is! Map) continue;
          final ing = byId[row['id']?.toString()];
          if (ing != null) {
            toRemove.add((
              item: ing,
              reason: row['razon']?.toString().trim().isNotEmpty == true
                  ? row['razon'].toString().trim()
                  : 'Ajeno a despensa',
            ));
          }
        }
      }

      if (decoded['corregir'] is List) {
        for (final row in decoded['corregir'] as List) {
          if (row is! Map) continue;
          final ing = byId[row['id']?.toString()];
          if (ing == null) continue;
          final newName = (row['nombre']?.toString().trim().isNotEmpty == true)
              ? row['nombre'].toString().trim()
              : ing.name;
          final newQty = (row['cantidad'] as num?)?.toDouble() ?? ing.quantity;
          final newUnit = (row['unidad']?.toString().trim().isNotEmpty == true)
              ? MeasurementUnit.fromString(row['unidad'].toString()).label
              : ing.unit;
          final newCat =
              (row['categoria']?.toString().trim().isNotEmpty == true)
                  ? row['categoria'].toString().trim()
                  : ing.primaryCategory;
          toFix.add((
            item: ing,
            newName: newName,
            newQuantity: newQty > 0 ? newQty : ing.quantity,
            newUnit: newUnit,
            newCategory: newCat,
            reason: row['razon']?.toString().trim().isNotEmpty == true
                ? row['razon'].toString().trim()
                : 'Ajuste sugerido por IA',
          ));
        }
      }

      return (toRemove: toRemove, toFix: toFix);
    } catch (_) {
      return null;
    }
  }

  /// Aplica los cambios confirmados de `auditPantryWithAi`.
  Future<void> applyPantryAudit({
    required List<String> idsToRemove,
    required List<
        ({
          InventoryIngredient item,
          String newName,
          double newQuantity,
          String newUnit,
          String newCategory,
        })> fixes,
  }) async {
    for (final id in idsToRemove) {
      await _repo.deleteIngredient(id);
    }
    for (final f in fixes) {
      await _repo.updateIngredient(
        f.item.copyWith(
          name: f.newName,
          quantity: f.newQuantity,
          unit: f.newUnit,
          primaryCategory: f.newCategory,
        ),
      );
      final exp = WalletPantryBridgeService.expandMultipack(
        f.item.name,
        quantity: f.item.quantity,
        unit: f.item.unit,
      );
      if (exp.gramsPerUnit != null && exp.gramsPerUnit! > 0) {
        await ref
            .read(ingredientEquivalencesProvider.notifier)
            .setGramsPerUnit(f.newName, exp.gramsPerUnit!);
      }
    }
    await load();
  }

  void clearError() => state = state.copyWith(error: null);
}

class RecipesNotifier extends Notifier<RecipesState> {
  ICocinaRepository get _repo => ref.read(cocinaRepositoryProvider);

  @override
  RecipesState build() {
    Future.microtask(() => load());
    return const RecipesState();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      var persistedGoal = state.activeGoal;
      try {
        final prefs = await SharedPreferences.getInstance();
        final goalName = prefs.getString(_activeGoalPrefKey);
        if (goalName != null) {
          persistedGoal = NutritionGoal.values.firstWhere(
            (g) => g.name == goalName,
            orElse: () => state.activeGoal,
          );
        }
      } catch (_) {}

      final recipes = await _repo.getAllRecipes();
      final shopping = await _repo.getShoppingList();
      state = state.copyWith(
        recipes: recipes,
        shoppingList: shopping,
        activeGoal: persistedGoal,
        isLoading: false,
      );
      await refreshSuggestions();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> refreshSuggestions() async {
    final inventory = await _repo.getAllIngredients();
    final suggestions = await _repo.suggestRecipes(
        inventory: inventory, goal: state.activeGoal);
    state = state.copyWith(suggestions: suggestions);
  }

  Future<void> saveRecipe(Recipe recipe) async {
    try {
      final saved = await _repo.saveRecipe(recipe);
      final existing = state.recipes.any((r) => r.id == saved.id);
      state = state.copyWith(
        recipes: existing
            ? [
                for (final r in state.recipes)
                  if (r.id == saved.id) saved else r
              ]
            : [saved, ...state.recipes],
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Save a recipe with automatic duplicate validation.
  /// Returns [SaveRecipeResult] indicating success, duplicates found, or error.
  Future<SaveRecipeResult> saveRecipeWithDuplicateCheck(
    Recipe recipe, {
    double duplicateThreshold = 0.70,
    bool forceSave = false,
  }) async {
    try {
      if (!forceSave) {
        final duplicates = RecipeDuplicateChecker.findDuplicates(
          recipe,
          state.recipes,
          threshold: duplicateThreshold,
        );

        if (duplicates.isNotEmpty) {
          return SaveRecipeResult.duplicatesFound(
            duplicates: duplicates,
          );
        }
      }

      final saved = await _repo.saveRecipe(recipe);
      final existing = state.recipes.any((r) => r.id == saved.id);
      state = state.copyWith(
        recipes: existing
            ? [
                for (final r in state.recipes)
                  if (r.id == saved.id) saved else r
              ]
            : [saved, ...state.recipes],
      );
      return SaveRecipeResult.success(savedRecipe: saved);
    } catch (e) {
      return SaveRecipeResult.error(e.toString());
    }
  }

  Future<void> deleteRecipe(String id) async {
    await _repo.deleteRecipe(id);
    state = state.copyWith(
        recipes: state.recipes.where((r) => r.id != id).toList());
  }

  Future<void> toggleFavorite(String id) async {
    await _repo.toggleFavorite(id);
    state = state.copyWith(
      recipes: [
        for (final r in state.recipes)
          if (r.id == id) r.copyWith(isFavorite: !r.isFavorite) else r
      ],
    );
  }

  Future<void> updateRecipeRating(String id, int rating) async {
    final recipe = state.recipes.firstWhere((r) => r.id == id);
    final updated = recipe.copyWith(rating: rating);
    await _repo.updateRecipe(updated);
    state = state.copyWith(
      recipes: [
        for (final r in state.recipes)
          if (r.id == id) updated else r
      ],
    );
  }

  Future<void> setGoal(NutritionGoal goal) async {
    state = state.copyWith(activeGoal: goal);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeGoalPrefKey, goal.name);
    } catch (_) {}
    await refreshSuggestions();
  }

  Future<void> toggleShoppingItem(String id) async {
    await _repo.toggleShoppingItem(id);
    state = state.copyWith(shoppingList: [
      for (final item in state.shoppingList)
        if (item.id == id) item.copyWith(bought: !item.bought) else item,
    ]);
  }

  /// Marca como comprados los ítems pendientes en Lista que coincidan con lo recién ingresado.
  Future<int> markMatchingShoppingItemsBought(Iterable<String> names) async {
    final targetKeys = names
        .map(IngredientPriceService.normalizeKey)
        .where((k) => k.isNotEmpty)
        .toSet();
    if (targetKeys.isEmpty) return 0;
    int marked = 0;
    for (final item in state.shoppingList) {
      if (item.bought) continue;
      final itemKey = IngredientPriceService.normalizeKey(item.name);
      if (targetKeys.contains(itemKey)) {
        await toggleShoppingItem(item.id);
        marked++;
      }
    }
    return marked;
  }

  Future<void> deleteShoppingItem(String id) async {
    await _repo.deleteShoppingItem(id);
    state = state.copyWith(
      shoppingList: state.shoppingList.where((i) => i.id != id).toList(),
    );
  }

  Future<void> clearBoughtShoppingItems() async {
    final boughtIds =
        state.shoppingList.where((i) => i.bought).map((i) => i.id).toSet();
    if (boughtIds.isEmpty) return;
    await Future.wait(boughtIds.map(_repo.deleteShoppingItem));
    state = state.copyWith(
      shoppingList:
          state.shoppingList.where((i) => !boughtIds.contains(i.id)).toList(),
    );
  }

  Future<void> addShoppingItem(ShoppingItem item) async {
    try {
      final saved = await _repo.addShoppingItem(item);
      state = state.copyWith(shoppingList: [saved, ...state.shoppingList]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Agrega ingredientes faltantes o agotados a Lista de compras evitando duplicados pendientes.
  Future<int> addMissingToShoppingList(
    Iterable<({String name, double quantity, String unit})> entries,
  ) async {
    var added = 0;
    final pendingKeys = state.shoppingList
        .where((item) => !item.bought)
        .map((item) => IngredientMatcher.normalizeText(item.name))
        .toSet();

    for (final entry in entries) {
      final cleanName = entry.name.trim();
      final key = IngredientMatcher.normalizeText(cleanName);
      if (cleanName.isEmpty || key.isEmpty || pendingKeys.contains(key)) {
        continue;
      }
      final saved = await _repo.addShoppingItem(
        ShoppingItem(
          id: _cocinaUuid.v4(),
          name: cleanName,
          quantity: entry.quantity > 0 ? entry.quantity : 1,
          unit: entry.unit.trim().isNotEmpty ? entry.unit.trim() : 'unidades',
          createdAt: DateTime.now(),
        ),
      );
      state = state.copyWith(shoppingList: [saved, ...state.shoppingList]);
      pendingKeys.add(key);
      added++;
    }
    return added;
  }

  Future<void> clearAllShoppingList() async {
    final ids = state.shoppingList.map((i) => i.id).toList();
    if (ids.isEmpty) return;
    await Future.wait(ids.map(_repo.deleteShoppingItem));
    state = state.copyWith(shoppingList: []);
  }

  Future<void> generateShoppingList(List<Recipe> selected) async {
    final items = await _repo.generateShoppingListFromRecipes(
        selected, await _repo.getAllIngredients());
    if (items.isEmpty) return;
    state = state.copyWith(shoppingList: [...state.shoppingList, ...items]);
  }

  void clearError() => state = state.copyWith(error: null);
}

// ── Providers ─────────────────────────────────────────────────────────────────
final cocinaRepositoryProvider = Provider<ICocinaRepository>((ref) {
  throw UnimplementedError(
      'Provide ICocinaRepository via ProviderScope.overrides');
});

// Shared service provider — single source of truth for cooking history
final cookingHistoryServiceProvider = Provider<CookingHistoryService>((_) {
  return CookingHistoryService();
});

final inventoryProvider =
    NotifierProvider<InventoryNotifier, InventoryState>(InventoryNotifier.new);

final recipesProvider =
    NotifierProvider<RecipesNotifier, RecipesState>(RecipesNotifier.new);

// ── Hybrid Suggestion Provider (Fast Local + API) ───────────────────────────
final hybridSuggestionsProvider =
    FutureProvider<List<RecipeSuggestion>>((ref) async {
  final invState = ref.watch(inventoryProvider);
  final repo = ref.watch(cocinaRepositoryProvider);

  if (invState.ingredients.isEmpty) return [];

  final useCase = HybridSuggestionUseCase(
    repository: repo,
    apiService: TheMealDBService(),
  );

  return useCase.execute(
    inventory: invState.ingredients,
    limit: 15,
    minMatchPercentage: 0.30,
    useApi: false,
  );
});

// ── Weekly Menu Provider ──────────────────────────────────────────────────────
class WeeklyMenuState {}

class WeeklyMenuInitial extends WeeklyMenuState {}

class WeeklyMenuLoading extends WeeklyMenuState {}

class WeeklyMenuLoaded extends WeeklyMenuState {
  final List<WeeklyMenuEntry> entries;
  WeeklyMenuLoaded(this.entries);
}

class WeeklyMenuError extends WeeklyMenuState {
  final String message;
  WeeklyMenuError(this.message);
}

class WeeklyMenuNotifier extends Notifier<WeeklyMenuState> {
  ICocinaRepository get _repo => ref.read(cocinaRepositoryProvider);

  @override
  WeeklyMenuState build() => WeeklyMenuInitial();

  Future<void> load() async {
    state = WeeklyMenuLoading();
    try {
      final entries = await _repo.getWeeklyMenu();
      state = WeeklyMenuLoaded(entries);
    } catch (e) {
      state = WeeklyMenuError(e.toString());
    }
  }

  Future<void> clearSlot(WeeklyMenuEntry entry) async {
    await _repo.saveWeeklyMenuEntry(WeeklyMenuEntry(
      id: entry.id,
      dayOfWeek: entry.dayOfWeek,
      mealType: entry.mealType,
      recipeId: '',
      isCustom: true,
    ));
    await load();
  }

  Future<void> generate({bool useAI = false}) async {
    state = WeeklyMenuLoading();
    try {
      final inventoryNotifier = ref.read(inventoryProvider.notifier);
      await inventoryNotifier.load();
      final inventoryState = ref.read(inventoryProvider);
      final activeGoal = ref.read(recipesProvider).activeGoal;

      if (!useAI) {
        final useCase = GenerateWeeklyMenuUseCase(repository: _repo);
        await useCase.execute(
          inventory: inventoryState.ingredients,
          goal: activeGoal,
        );
        await load();
        return;
      }

      final recipes = await _repo.getAllRecipes();
      if (recipes.isEmpty) {
        throw Exception(
            'No tienes recetas guardadas para armar el menú semanal.');
      }

      final gemini = ref.read(geminiProvider);
      final expiring = inventoryState.ingredients
          .where((i) => i.isExpiringSoon)
          .map((i) => i.name)
          .toList();
      final pantrySummary = inventoryState.ingredients
          .take(35)
          .map((i) =>
              '${i.name} (${i.quantity} ${i.unit}${i.preparation.isNotEmpty ? ', ${i.preparation}' : ''})')
          .join(', ');
      final recipeCatalog = recipes
          .take(60)
          .map((r) =>
              '{"id":"${r.id}","nombre":"${r.name}","tipo":"${r.tipoComida?.label ?? 'Otro'}","meta":"${r.goal.label}"}')
          .join('\n');

      final prompt = '''
Planifica un menú semanal variado de Lunes (day=1) a Domingo (day=7) con Desayuno (mealType=0), Almuerzo (mealType=1) y Cena (mealType=2).
Meta nutricional: ${activeGoal.label} (${activeGoal.hint}).
Ingredientes por vencer pronto (priorizar al inicio de la semana): ${expiring.isEmpty ? 'ninguno' : expiring.join(', ')}.
Despensa actual: $pantrySummary.

Recetas disponibles (USA ÚNICAMENTE estos id exactos):
$recipeCatalog

Devuelve ÚNICAMENTE una lista JSON de 21 objetos:
[{"day": 1, "mealType": 0, "recipeId": "..."}]''';

      final raw = await gemini
          .generateText(prompt: prompt)
          .timeout(const Duration(seconds: 30));
      final parsed = raw != null ? AiJsonParser.decodeList(raw) : null;
      final validIds = {for (final r in recipes) r.id};

      if (parsed == null || parsed.isEmpty) {
        final fallback = GenerateWeeklyMenuUseCase(repository: _repo);
        await fallback.execute(
          inventory: inventoryState.ingredients,
          goal: activeGoal,
        );
        await load();
        return;
      }

      // Primero llenar todo con heurística de respaldo para asegurar 21 slots completos
      final base = GenerateWeeklyMenuUseCase(repository: _repo);
      await base.execute(
        inventory: inventoryState.ingredients,
        goal: activeGoal,
      );
      final baseEntries = await _repo.getWeeklyMenu();
      final slotMap = <String, WeeklyMenuEntry>{
        for (final e in baseEntries) '${e.dayOfWeek}_${e.mealType}': e,
      };

      for (final item in parsed) {
        if (item is! Map) continue;
        final day = (item['day'] as num?)?.toInt();
        final mealType = (item['mealType'] as num?)?.toInt();
        final recipeId = item['recipeId']?.toString();
        if (day == null ||
            day < 1 ||
            day > 7 ||
            mealType == null ||
            mealType < 0 ||
            mealType > 2 ||
            recipeId == null ||
            !validIds.contains(recipeId)) {
          continue;
        }
        final key = '${day}_$mealType';
        final existing = slotMap[key];
        await _repo.saveWeeklyMenuEntry(WeeklyMenuEntry(
          id: existing?.id ?? _cocinaUuid.v4(),
          dayOfWeek: day,
          mealType: mealType,
          recipeId: recipeId,
          isCustom: false,
        ));
      }
      await load();
    } catch (e) {
      final entries =
          await _repo.getWeeklyMenu().catchError((_) => <WeeklyMenuEntry>[]);
      state =
          entries.isNotEmpty ? WeeklyMenuLoaded(entries) : WeeklyMenuInitial();
      rethrow;
    }
  }
}

final weeklyMenuProvider =
    NotifierProvider<WeeklyMenuNotifier, WeeklyMenuState>(
        WeeklyMenuNotifier.new);
