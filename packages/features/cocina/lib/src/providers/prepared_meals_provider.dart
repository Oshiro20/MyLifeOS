import 'dart:convert';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _preparedMealsPrefsKey = 'cocina_prepared_meals_v1';
const _uuid = Uuid();

/// Extra cocido/preparado que acompaña a un plato sobrante (ej. huevos sancochados).
class PreparedMealExtra {
  final String name;
  final double remainingQty;
  final String unit;

  const PreparedMealExtra({
    required this.name,
    required this.remainingQty,
    required this.unit,
  });

  PreparedMealExtra copyWith({double? remainingQty}) => PreparedMealExtra(
        name: name,
        remainingQty: remainingQty ?? this.remainingQty,
        unit: unit,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'remainingQty': remainingQty,
        'unit': unit,
      };

  factory PreparedMealExtra.fromJson(Map<String, dynamic> json) =>
      PreparedMealExtra(
        name: json['name']?.toString() ?? '',
        remainingQty: (json['remainingQty'] as num?)?.toDouble() ?? 0.0,
        unit: json['unit']?.toString() ?? 'unidades',
      );
}

/// Plato preparado con porciones restantes guardado para recalentar y comer luego,
/// separado de la Despensa de insumos crudos para evitar confusión.
class PreparedMeal {
  final String id;
  final String recipeName;
  final String? recipeId;
  final double remainingServings;
  final List<PreparedMealExtra> extras;
  final DateTime savedAt;
  final DateTime expiresAt;
  final String storageArea;

  const PreparedMeal({
    required this.id,
    required this.recipeName,
    this.recipeId,
    required this.remainingServings,
    this.extras = const [],
    required this.savedAt,
    required this.expiresAt,
    this.storageArea = 'Refrigerador',
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isExpiringSoon {
    final diff = expiresAt.difference(DateTime.now()).inHours;
    return !isExpired && diff <= 24;
  }

  PreparedMeal copyWith({
    double? remainingServings,
    List<PreparedMealExtra>? extras,
  }) =>
      PreparedMeal(
        id: id,
        recipeName: recipeName,
        recipeId: recipeId,
        remainingServings: remainingServings ?? this.remainingServings,
        extras: extras ?? this.extras,
        savedAt: savedAt,
        expiresAt: expiresAt,
        storageArea: storageArea,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipeName': recipeName,
        if (recipeId != null) 'recipeId': recipeId,
        'remainingServings': remainingServings,
        'extras': extras.map((e) => e.toJson()).toList(),
        'savedAt': savedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'storageArea': storageArea,
      };

  factory PreparedMeal.fromJson(Map<String, dynamic> json) => PreparedMeal(
        id: json['id']?.toString() ?? _uuid.v4(),
        recipeName: json['recipeName']?.toString() ?? 'Comida preparada',
        recipeId: json['recipeId']?.toString(),
        remainingServings:
            (json['remainingServings'] as num?)?.toDouble() ?? 1.0,
        extras: (json['extras'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    PreparedMealExtra.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
        savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
            DateTime.now(),
        expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
            DateTime.now().add(const Duration(days: 3)),
        storageArea: json['storageArea']?.toString() ?? 'Refrigerador',
      );
}

class PreparedMealsNotifier extends Notifier<List<PreparedMeal>> {
  bool _loaded = false;
  Future<void>? _loadFuture;

  @override
  List<PreparedMeal> build() {
    Future.microtask(load);
    return const [];
  }

  Future<void> load() => _loadFuture ??= _readFromPrefs();

  Future<void> _readFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_preparedMealsPrefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final parsed = decoded
              .whereType<Map>()
              .map((m) => PreparedMeal.fromJson(Map<String, dynamic>.from(m)))
              .where((m) => m.remainingServings > 0.001 || m.extras.isNotEmpty)
              .toList()
            ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
          state = parsed;
        }
      }
      _loaded = true;
    } catch (_) {
      _loaded = true;
    }
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _preparedMealsPrefsKey,
        jsonEncode(state.map((m) => m.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> addMeal(PreparedMeal meal) async {
    await _ensureLoaded();
    final next = [meal, ...state]
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    state = next;
    await _persist();
  }

  /// Registra el consumo de porciones del plato preparado y/o sus extras.
  /// Si tanto el plato como los extras llegan a 0, lo retira automáticamente.
  Future<void> consumeServings(
    String mealId, {
    required double servings,
    Map<String, double> extraQuantities = const {},
  }) async {
    await _ensureLoaded();
    final idx = state.indexWhere((m) => m.id == mealId);
    if (idx == -1) return;

    final current = state[idx];
    final nextServings = (current.remainingServings - servings)
        .clamp(0.0, current.remainingServings);
    final nextExtras = <PreparedMealExtra>[];
    for (final ex in current.extras) {
      final eaten = extraQuantities[ex.name] ?? 0.0;
      final rem = (ex.remainingQty - eaten).clamp(0.0, ex.remainingQty);
      if (rem > 0.001) {
        nextExtras.add(ex.copyWith(remainingQty: double.parse(rem.toStringAsFixed(2))));
      }
    }

    final updated = List<PreparedMeal>.from(state);
    if (nextServings <= 0.001 && nextExtras.isEmpty) {
      updated.removeAt(idx);
    } else {
      updated[idx] = current.copyWith(
        remainingServings: double.parse(nextServings.toStringAsFixed(2)),
        extras: nextExtras,
      );
    }
    state = updated;
    await _persist();
  }

  Future<void> removeMeal(String mealId) async {
    await _ensureLoaded();
    state = state.where((m) => m.id != mealId).toList();
    await _persist();
  }

  /// Migra sobras antiguas guardadas en Despensa (`Porción guardada` / `Extra listo`)
  /// hacia `PreparedMealsNotifier` y las elimina de Despensa.
  Future<int> migrateLegacyFromPantry(
    List<InventoryIngredient> inventory,
    Future<void> Function(String id) deleteFromPantry,
  ) async {
    await _ensureLoaded();
    final legacyMains = inventory
        .where((i) => i.subCategory == 'Porción guardada')
        .toList();
    final legacyExtras =
        inventory.where((i) => i.subCategory == 'Extra listo').toList();
    if (legacyMains.isEmpty && legacyExtras.isEmpty) return 0;

    final extraModels = legacyExtras
        .map(
          (e) => PreparedMealExtra(
            name: e.name.replaceFirst(RegExp(r'\s*\(cocido\)$', caseSensitive: false), '').trim(),
            remainingQty: e.quantity,
            unit: e.unit,
          ),
        )
        .toList();

    final now = DateTime.now();
    if (legacyMains.isNotEmpty) {
      for (var i = 0; i < legacyMains.length; i++) {
        final main = legacyMains[i];
        final cleanName = main.name
            .replaceFirst(RegExp(r'\s*\(preparado\)$', caseSensitive: false), '')
            .trim();
        await addMeal(
          PreparedMeal(
            id: _uuid.v4(),
            recipeName: cleanName.isEmpty ? main.name : cleanName,
            remainingServings: main.quantity,
            extras: i == 0 ? extraModels : const [],
            savedAt: now,
            expiresAt: main.expirationDate ?? now.add(const Duration(days: 3)),
            storageArea: main.storageArea ?? 'Refrigerador',
          ),
        );
      }
    } else if (extraModels.isNotEmpty) {
      final first = legacyExtras.first;
      await addMeal(
        PreparedMeal(
          id: _uuid.v4(),
          recipeName: 'Acompañamientos listos',
          remainingServings: 0,
          extras: extraModels,
          savedAt: now,
          expiresAt: first.expirationDate ?? now.add(const Duration(days: 3)),
          storageArea: first.storageArea ?? 'Refrigerador',
        ),
      );
    }

    for (final legacy in [...legacyMains, ...legacyExtras]) {
      await deleteFromPantry(legacy.id);
    }
    return legacyMains.length + legacyExtras.length;
  }
}

final preparedMealsProvider =
    NotifierProvider<PreparedMealsNotifier, List<PreparedMeal>>(
  PreparedMealsNotifier.new,
);
