import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import 'package:domain/domain.dart';
import 'package:data/data.dart';
import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

// ── Diccionario de ingredientes ───────────────────────────────────────────────
// score > 0 = saludable, < 0 = chatarra, 0 = neutro
// Escala [-3, +3]
const Map<String, int> _ingredientScores = {
  // ── Frutas (+2)
  'manzana': 2, 'pera': 2, 'naranja': 2, 'fresa': 2, 'frambuesa': 2,
  'blueberry': 2, 'arándano': 2, 'kiwi': 2, 'mango': 2, 'papaya': 2,
  'plátano': 1, 'uva': 1, 'melón': 1, 'sandía': 1, 'piña': 1,

  // ── Verduras (+3)
  'ensalada': 3,
  'lechuga': 3, 'espinaca': 3, 'brócoli': 3, 'zanahoria': 3, 'apio': 3,
  'pepino': 3, 'tomate': 2, 'cebolla': 2, 'ajo': 3, 'pimiento': 2,
  'coliflor': 3, 'col': 2, 'remolacha': 2, 'calabacín': 2, 'acelga': 3,
  'alcachofa': 2, 'espárrago': 3, 'edamame': 3, 'kale': 3, 'rúcula': 3,

  // ── Proteínas magras (+2)
  'pollo': 2, 'pavo': 2, 'atún': 2, 'salmón': 3, 'sardina': 2,
  'pescado': 2, 'carne magra': 2, 'huevo cocido': 2,
  'huevo': 2, 'tofu': 2, 'legumbre': 2, 'lenteja': 2, 'garbanzo': 2,
  'frijol': 2, 'quinoa': 3, 'tempeh': 2, 'clara de huevo': 3,

  // ── Lácteos (+1 / 0)
  'yogur': 1, 'kéfir': 2, 'leche': 1, 'queso': 0, 'queso crema': -1,

  // ── Cereales integrales (+2)
  'avena': 3, 'arroz integral': 2, 'pan integral': 2, 'trigo entero': 2,
  'cebada': 2, 'centeno': 1, 'amaranto': 2, 'chía': 3, 'linaza': 3,

  // ── Grasas saludables (+2)
  'aguacate': 3, 'aceite de oliva': 2, 'nuez': 2, 'almendra': 2,
  'maní': 1, 'pistache': 2, 'semilla de girasol': 2, 'tahini': 1,

  // ── Neutros / moderados (0)
  'pasta': 0, 'arroz blanco': 0, 'pan blanco': -1, 'papa': 0,

  // ── Chatarra (-2 / -3)
  'azúcar': -2, 'jarabe de maíz': -3, 'gaseosa': -3, 'refresco': -3,
  'frito': -2, 'fritura': -2, 'papas fritas': -3, 'hot dog': -3,
  'salchicha': -2, 'tocino': -2, 'mantequilla': -1, 'margarina': -2,
  'mayonesa': -2, 'ketchup': -1, 'salsa de tomate industrializada': -2,
  'hamburguesa': -2, 'pizza': -1, 'donut': -3, 'galleta': -2,
  'cheto': -3, 'snack': -2, 'helado': -2, 'chocolate con leche': -1,
  'caramelo': -3, 'gelatina': -1, 'fritanga': -3, 'nugget': -2,
  'embutido': -2, 'chorizo': -2, 'alcohol': -3, 'cerveza': -2,
};

// ── Recomendaciones por clasificación ────────────────────────────────────────
const List<String> _healthyTips = [
  '¡Excelente elección! Sigue así para mantener tu energía durante el día.',
  'Una comida muy nutritiva. Complementa con agua e intenta incluir fibra en cada comida.',
  '¡Muy bien! Los nutrientes de esta comida apoyan tu sistema inmune.',
  'Sigue eligiendo alimentos frescos y naturales. Tu cuerpo te lo agradece.',
];

const List<String> _balancedTips = [
  'Comida balanceada. Para mejorar, agrega más verduras de hoja verde.',
  'Buen equilibrio. Considera reducir ligeramente los carbohidratos refinados.',
  'Casi perfecto. Añade una porción de proteína magra para completar el plato.',
  'Buena opción. Hidratate bien con agua antes y después de comer.',
];

const List<String> _junkTips = [
  'Considera reemplazar este tipo de comidas por opciones ricas en fibra y proteína.',
  'Intenta aplicar la regla 80/20: el 80% del tiempo come saludable.',
  'Tip: preparar comida en casa reduce el consumo de grasas trans y azúcares ocultos.',
  'Tomar mucha agua después de este tipo de comidas ayuda a tu digestión.',
];

// ── Repositorio concreto ──────────────────────────────────────────────────────
class FoodCoachRepository implements IFoodCoachRepository {
  final AppDatabase _db;
  final GeminiService? _ai;
  final _uuid = const Uuid();
  var _tipIndex = 0;

  FoodCoachRepository(this._db, [this._ai]);

  // ── Clasificación IA + fallback offline con macros ───────────────────────────
  @override
  Future<MealEvaluation> evaluateMeal({
    required List<String> ingredients,
    String? photoPath,
    String? mealName,
    MealSlot? mealSlot,
    CookingMethod? cookingMethod,
    double servings = 1.0,
    String? recipeContext,
    MealMacros? recipeBaseMacros,
  }) async {
    final lowerIngredients =
        ingredients.map((i) => i.trim().toLowerCase()).where((i) => i.isNotEmpty).toList();
    final effectiveSlot = mealSlot ?? MealSlot.forHour(DateTime.now().hour);
    var effectiveMethod = cookingMethod ??
        CookingMethod.inferFromText(
          '${mealName ?? ''} ${lowerIngredients.join(' ')} ${recipeContext ?? ''}',
        );
    final effectiveServings = servings.clamp(0.25, 10.0).toDouble();

    // ── INFERENCIA CON IA ──────────────────────────────────────────────────────
    bool aiSuccess = false;
    FoodClassification classification = FoodClassification.balanced;
    double healthScore = 0.5;
    List<String> pos = [];
    List<String> neg = [];
    String feedback = '';
    String rec = '';
    MealMacros? macros;

    if (_ai != null) {
      try {
        final description = lowerIngredients.isNotEmpty
            ? lowerIngredients.join(', ')
            : 'Analiza los alimentos visibles en la fotografía.';
        final jsonStr = await _ai.evaluateMealStructured(
          description: description,
          photoPath: photoPath,
          mealName: mealName,
          mealSlotLabel: effectiveSlot.label,
          cookingMethodLabel: effectiveMethod?.label,
          servings: effectiveServings,
          recipeContext: recipeContext,
        );
        if (jsonStr != null) {
          final decoded = AiJsonParser.decodeMap(jsonStr);
          if (decoded != null) {
            final clsStr =
                decoded['classification']?.toString().toLowerCase() ??
                    'balanced';
            classification = FoodClassification.values.firstWhere(
              (e) => e.name == clsStr,
              orElse: () => FoodClassification.balanced,
            );
            healthScore =
                ((decoded['healthScore'] as num?)?.toDouble() ?? 0.5)
                    .clamp(0.0, 1.0);
            pos = List<String>.from(decoded['positiveFactors'] ?? []);
            neg = List<String>.from(decoded['negativeFactors'] ?? []);
            feedback = decoded['feedback'] as String? ?? '';
            rec = decoded['recommendation'] as String? ?? '';
            macros = MealMacros.fromJson(decoded);
            effectiveMethod ??= CookingMethod.fromName(
              decoded['detectedCookingMethod']?.toString(),
            );
            aiSuccess = true;
          }
        }
      } catch (e) {
        debugPrint('Error IA FoodCoach: $e'); // Log silencioso
      }
    }

    if (!aiSuccess && lowerIngredients.isEmpty && photoPath != null) {
      throw Exception(
          'No se pudo analizar la fotografía sin conexión. Añade ingredientes manualmente o verifica tu internet.');
    } else if (!aiSuccess) {
      // ── LOGICA OFFLINE (FALLBACK) ──────────────────────────────────────────────
      int totalScore = 0;
      int scoredCount = 0;

      for (final ingredient in lowerIngredients) {
        final score = scoreIngredientOffline(ingredient);
        if (score != null) {
          scoredCount++;
          totalScore += score;
          if (score >= 2) {
            pos.add(ingredient);
          } else if (score <= -2) {
            neg.add(ingredient);
          }
        }
      }

      if (effectiveMethod == CookingMethod.fried) {
        totalScore -= 2;
        scoredCount++;
        if (!neg.contains('preparación frita')) {
          neg.add('preparación frita');
        }
      } else if (effectiveMethod == CookingMethod.boiled ||
          effectiveMethod == CookingMethod.grilled ||
          effectiveMethod == CookingMethod.raw) {
        totalScore += 1;
        scoredCount++;
      }

      final maxPossible = scoredCount * 3;
      final minPossible = scoredCount * -3;
      final range = maxPossible - minPossible;
      healthScore = range == 0
          ? 0.5
          : ((totalScore - minPossible) / range).clamp(0.0, 1.0);

      if (healthScore >= 0.68) {
        classification = FoodClassification.healthy;
        feedback =
            '¡Esta comida es muy saludable! 💚 ${pos.isNotEmpty ? "Destacan: ${pos.take(3).join(", ")}." : ""}';
        rec = _healthyTips[_tipIndex % _healthyTips.length];
      } else if (healthScore >= 0.40) {
        classification = FoodClassification.balanced;
        feedback =
            'Comida balanceada. 💛 ${neg.isNotEmpty ? "Cuidado con: ${neg.take(2).join(", ")}." : ""}';
        rec = _balancedTips[_tipIndex % _balancedTips.length];
      } else {
        classification = FoodClassification.junk;
        feedback =
            'Alto en calorías vacías. 🔴 ${neg.isNotEmpty ? "Modera: ${neg.take(3).join(", ")}." : ""}';
        rec = _junkTips[_tipIndex % _junkTips.length];
      }
      _tipIndex++;
    }

    macros ??= estimateMacrosOffline(
      ingredients: lowerIngredients,
      cookingMethod: effectiveMethod,
      servings: effectiveServings,
      recipeBaseMacros: recipeBaseMacros,
    );

    final evaluation = MealEvaluation(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      photoPath: photoPath,
      classification: classification,
      healthScore: healthScore,
      detectedIngredients: lowerIngredients,
      positiveFactors: pos,
      negativeFactors: neg,
      feedback: feedback,
      recommendation: rec,
      mealName: (mealName != null && mealName.trim().isNotEmpty)
          ? mealName.trim()
          : null,
      mealSlot: effectiveSlot,
      cookingMethod: effectiveMethod,
      servings: effectiveServings,
      macros: macros,
    );

    await saveToHistory(evaluation);
    return evaluation;
  }

  /// Estima macros aproximados en modo offline usando macros base de receta
  /// o aportes por grupo alimenticio + ajuste del método de cocción.
  static MealMacros estimateMacrosOffline({
    required List<String> ingredients,
    CookingMethod? cookingMethod,
    double servings = 1.0,
    MealMacros? recipeBaseMacros,
  }) {
    if (recipeBaseMacros != null && recipeBaseMacros.caloriesKcal > 0) {
      return recipeBaseMacros.scale(servings);
    }

    var kcal = 0.0;
    var protein = 0.0;
    var carbs = 0.0;
    var fat = 0.0;
    var fiber = 0.0;

    for (final raw in ingredients) {
      final hit = ConsumptionAnalyticsUseCase.classifyFoodItem(raw);
      if (hit == null) {
        kcal += 55;
        carbs += 8;
        protein += 2;
        fat += 1.5;
        continue;
      }
      switch (hit.group) {
        case FoodGroup.protein:
          kcal += 165;
          protein += 24;
          fat += 6;
        case FoodGroup.carbLegume:
          kcal += 170;
          carbs += 32;
          protein += 6;
          fat += 1.5;
          fiber += 4;
        case FoodGroup.vegetable:
          kcal += 35;
          carbs += 6;
          protein += 1.5;
          fiber += 2.5;
        case FoodGroup.fruit:
          kcal += 80;
          carbs += 19;
          protein += 1;
          fiber += 3;
        case FoodGroup.dairy:
          kcal += 110;
          protein += 7;
          carbs += 9;
          fat += 4.5;
        case FoodGroup.healthyFat:
          kcal += 140;
          fat += 13;
          protein += 2;
          carbs += 4;
          fiber += 3;
        case FoodGroup.processed:
          kcal += 240;
          carbs += 26;
          protein += 6;
          fat += 12;
      }
    }

    if (kcal == 0) {
      kcal = 350;
      protein = 18;
      carbs = 40;
      fat = 12;
      fiber = 4;
    }

    // Ajuste calórico/grasa según método de cocción
    switch (cookingMethod) {
      case CookingMethod.fried:
        kcal += 130;
        fat += 14;
      case CookingMethod.stewed:
        kcal += 45;
        fat += 4.5;
      case CookingMethod.baked:
        kcal += 20;
        fat += 2;
      case CookingMethod.grilled:
      case CookingMethod.boiled:
      case CookingMethod.raw:
      case null:
        break;
    }

    return MealMacros(
      caloriesKcal: (kcal * servings).round().clamp(30, 3500),
      proteinGrams:
          double.parse((protein * servings).toStringAsFixed(1)),
      carbsGrams: double.parse((carbs * servings).toStringAsFixed(1)),
      fatGrams: double.parse((fat * servings).toStringAsFixed(1)),
      fiberGrams: double.parse((fiber * servings).toStringAsFixed(1)),
    );
  }

  /// Codifica la metadata enriquecida en `detectedIngredientsCsv` manteniendo
  /// compatibilidad total con filas antiguas en formato CSV plano.
  static String encodeMealMetadata(MealEvaluation eval) {
    return jsonEncode({
      'v': 2,
      if (eval.mealName != null) 'mealName': eval.mealName,
      'mealSlot': eval.mealSlot.name,
      if (eval.cookingMethod != null) 'cookingMethod': eval.cookingMethod!.name,
      'servings': eval.servings,
      'ingredients': eval.detectedIngredients,
      if (eval.macros != null) 'macros': eval.macros!.toJson(),
    });
  }

  static ({
    String? mealName,
    MealSlot mealSlot,
    CookingMethod? cookingMethod,
    double servings,
    List<String> ingredients,
    MealMacros? macros,
  }) decodeMealMetadata(String raw, DateTime fallbackTime) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          return (
            mealName: map['mealName']?.toString(),
            mealSlot: MealSlot.fromName(map['mealSlot']?.toString()),
            cookingMethod:
                CookingMethod.fromName(map['cookingMethod']?.toString()),
            servings: (map['servings'] as num?)?.toDouble() ?? 1.0,
            ingredients: (map['ingredients'] as List?)
                    ?.map((e) => e.toString())
                    .where((e) => e.trim().isNotEmpty)
                    .toList() ??
                const [],
            macros: MealMacros.fromJson(
              map['macros'] is Map
                  ? Map<String, dynamic>.from(map['macros'] as Map)
                  : null,
            ),
          );
        }
      } catch (_) {}
    }
    final legacyList = trimmed.isEmpty
        ? const <String>[]
        : trimmed
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    return (
      mealName: null,
      mealSlot: MealSlot.forHour(fallbackTime.hour),
      cookingMethod: CookingMethod.inferFromText(legacyList.join(' ')),
      servings: 1.0,
      ingredients: legacyList,
      macros: null,
    );
  }

  /// Puntúa un ingrediente en modo offline usando coincidencia por palabra
  /// completa y sumando modificadores compuestos (ej: "pollo frito" -> +2 - 2 = 0).
  static final List<MapEntry<String, int>> _sortedIngredientEntries =
      _ingredientScores.entries.toList()
        ..sort((a, b) => b.key.length.compareTo(a.key.length));

  static int? scoreIngredientOffline(String rawIngredient) {
    final ingredient = rawIngredient.trim().toLowerCase();
    if (ingredient.isEmpty) return null;

    final exact = _ingredientScores[ingredient];
    if (exact != null) return exact;

    var remaining = ingredient;
    var sum = 0;
    var hits = 0;

    for (final entry in _sortedIngredientEntries) {
      final pattern = RegExp(
        '(?:^|[^a-záéíóúüñ])${RegExp.escape(entry.key)}(?:s|es)?(?=\$|[^a-záéíóúüñ])',
      );
      if (pattern.hasMatch(remaining)) {
        sum += entry.value;
        hits++;
        remaining = remaining.replaceAll(pattern, ' ');
      }
    }

    return hits == 0 ? null : sum.clamp(-3, 3);
  }

  // ── Historial ────────────────────────────────────────────────────────────────
  @override
  Future<List<MealLog>> getHistory({int limit = 100}) async {
    final q = _db.select(_db.mealLogs)
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
      ..limit(limit);
    final rows = await q.get();
    return rows.map((r) {
      final meta = decodeMealMetadata(r.detectedIngredientsCsv, r.timestamp);
      return MealLog(
        id: r.id,
        timestamp: r.timestamp,
        photoPath: r.photoPath.isEmpty ? null : r.photoPath,
        classification:
            FoodClassification.values[r.classificationIndex.clamp(0, 2)],
        healthScore: r.healthScore.clamp(0.0, 1.0),
        feedback: r.feedback,
        mealName: meta.mealName,
        mealSlot: meta.mealSlot,
        cookingMethod: meta.cookingMethod,
        servings: meta.servings,
        detectedIngredients: meta.ingredients,
        macros: meta.macros,
      );
    }).toList();
  }

  @override
  Future<void> saveToHistory(MealEvaluation eval) async {
    await _db.into(_db.mealLogs).insert(MealLogsCompanion(
          id: Value(eval.id),
          timestamp: Value(eval.timestamp),
          photoPath: Value(eval.photoPath ?? ''),
          classificationIndex: Value(eval.classification.index),
          healthScore: Value(eval.healthScore.clamp(0.0, 1.0)),
          feedback: Value(eval.feedback),
          detectedIngredientsCsv: Value(encodeMealMetadata(eval)),
        ));
  }

  @override
  Future<void> deleteFromHistory(String id) async {
    final existing = await (_db.select(_db.mealLogs)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    await (_db.delete(_db.mealLogs)..where((t) => t.id.equals(id))).go();
    await AppDatabase.deleteLocalFileIfPresent(existing?.photoPath);
  }

  // ── Estadísticas semanales ────────────────────────────────────────────────
  @override
  Future<WeeklyStats> getWeeklyStats() async {
    final now = DateTime.now();
    final since = now.subtract(const Duration(days: 7));
    final q = _db.select(_db.mealLogs)
      ..where((t) => t.timestamp.isBiggerThanValue(since));
    final rows = await q.get();

    if (rows.isEmpty) {
      return const WeeklyStats(
        averageHealthScore: 0,
        healthyCount: 0,
        balancedCount: 0,
        junkCount: 0,
        totalMeals: 0,
      );
    }

    int healthy = 0, balanced = 0, junk = 0, fried = 0;
    double totalScore = 0;
    int todayKcal = 0;
    double todayP = 0, todayC = 0, todayF = 0, todayFib = 0;
    int weekKcal = 0;
    double weekP = 0;
    final activeDays = <String>{};

    for (final r in rows) {
      final c = FoodClassification.values[r.classificationIndex.clamp(0, 2)];
      totalScore += r.healthScore.clamp(0.0, 1.0);
      switch (c) {
        case FoodClassification.healthy:
          healthy++;
        case FoodClassification.balanced:
          balanced++;
        case FoodClassification.junk:
          junk++;
      }

      final meta = decodeMealMetadata(r.detectedIngredientsCsv, r.timestamp);
      if (meta.cookingMethod == CookingMethod.fried) fried++;

      final dayKey =
          '${r.timestamp.year}-${r.timestamp.month}-${r.timestamp.day}';
      final isToday = r.timestamp.year == now.year &&
          r.timestamp.month == now.month &&
          r.timestamp.day == now.day;

      final macros = meta.macros;
      if (macros != null) {
        activeDays.add(dayKey);
        weekKcal += macros.caloriesKcal;
        weekP += macros.proteinGrams;
        if (isToday) {
          todayKcal += macros.caloriesKcal;
          todayP += macros.proteinGrams;
          todayC += macros.carbsGrams;
          todayF += macros.fatGrams;
          todayFib += macros.fiberGrams;
        }
      }
    }

    final daysCount = activeDays.isEmpty ? 1 : activeDays.length;
    return WeeklyStats(
      averageHealthScore: totalScore / rows.length,
      healthyCount: healthy,
      balancedCount: balanced,
      junkCount: junk,
      totalMeals: rows.length,
      todayCalories: todayKcal,
      todayProtein: double.parse(todayP.toStringAsFixed(1)),
      todayCarbs: double.parse(todayC.toStringAsFixed(1)),
      todayFat: double.parse(todayF.toStringAsFixed(1)),
      todayFiber: double.parse(todayFib.toStringAsFixed(1)),
      avgDailyCalories: activeDays.isEmpty ? 0 : (weekKcal / daysCount).round(),
      avgDailyProtein: activeDays.isEmpty
          ? 0
          : double.parse((weekP / daysCount).toStringAsFixed(1)),
      friedCount: fried,
    );
  }
}
