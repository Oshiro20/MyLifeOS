import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import 'package:domain/domain.dart';
import 'package:data/data.dart';
import 'dart:convert';
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
  'lechuga': 3, 'espinaca': 3, 'brócoli': 3, 'zanahoria': 3, 'apio': 3,
  'pepino': 3, 'tomate': 2, 'cebolla': 2, 'ajo': 3, 'pimiento': 2,
  'coliflor': 3, 'col': 2, 'remolacha': 2, 'calabacín': 2, 'acelga': 3,
  'alcachofa': 2, 'espárrago': 3, 'edamame': 3, 'kale': 3, 'rúcula': 3,

  // ── Proteínas magras (+2)
  'pollo': 2, 'pavo': 2, 'atún': 2, 'salmón': 3, 'sardina': 2,
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

  // ── Clasificación offline ────────────────────────────────────────────────────
  @override
  Future<MealEvaluation> evaluateMeal({
    required List<String> ingredients,
    String? photoPath,
  }) async {
    final lowerIngredients =
        ingredients.map((i) => i.trim().toLowerCase()).toList();

    // ── INFERENCIA CON IA ──────────────────────────────────────────────────────
    bool aiSuccess = false;
    FoodClassification classification = FoodClassification.balanced;
    double healthScore = 0.5;
    List<String> pos = [];
    List<String> neg = [];
    String feedback = '';
    String rec = '';

    if (_ai != null) {
      try {
        final jsonStr = await _ai.generateFoodEvaluation(
          ingredients: lowerIngredients,
          photoPath: photoPath,
        );
        if (jsonStr != null) {
          final cleanJson =
              jsonStr.replaceAll(RegExp(r'```json\n|```'), '').trim();
          final decoded = json.decode(cleanJson) as Map<String, dynamic>;
          final clsStr = decoded['classification'] as String? ?? 'balanced';
          classification = FoodClassification.values.firstWhere(
            (e) => e.name == clsStr,
            orElse: () => FoodClassification.balanced,
          );
          healthScore = (decoded['healthScore'] as num?)?.toDouble() ?? 0.5;
          pos = List<String>.from(decoded['positiveFactors'] ?? []);
          neg = List<String>.from(decoded['negativeFactors'] ?? []);
          feedback = decoded['feedback'] as String? ?? '';
          rec = decoded['recommendation'] as String? ?? '';
          aiSuccess = true;
        }
      } catch (e) {
        debugPrint('Error IA FoodCoach: $e'); // Log silencioso
      }
    }

    if (!aiSuccess) {
      // ── LOGICA OFFLINE (FALLBACK) ──────────────────────────────────────────────
      int totalScore = 0;
      final matched = <String>{};

      for (final ingredient in lowerIngredients) {
        int? score = _ingredientScores[ingredient];
        if (score == null) {
          for (final key in _ingredientScores.keys) {
            if (ingredient.contains(key) || key.contains(ingredient)) {
              score = _ingredientScores[key];
              break;
            }
          }
        }

        if (score != null) {
          matched.add(ingredient);
          totalScore += score;
          if (score >= 2) {
            pos.add(ingredient);
          } else if (score <= -2) {
            neg.add(ingredient);
          }
        }
      }

      final maxPossible = lowerIngredients.length * 3;
      final minPossible = lowerIngredients.length * -3;
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
    );

    await saveToHistory(evaluation);
    return evaluation;
  }

  // ── Historial ────────────────────────────────────────────────────────────────
  @override
  Future<List<MealLog>> getHistory({int limit = 50}) async {
    final q = _db.select(_db.mealLogs)
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
      ..limit(limit);
    final rows = await q.get();
    return rows
        .map((r) => MealLog(
              id: r.id,
              timestamp: r.timestamp,
              photoPath: r.photoPath.isEmpty ? null : r.photoPath,
              classification:
                  FoodClassification.values[r.classificationIndex.clamp(0, 2)],
              healthScore: r.classificationIndex / 2.0,
              feedback: r.feedback,
            ))
        .toList();
  }

  @override
  Future<void> saveToHistory(MealEvaluation eval) async {
    await _db.into(_db.mealLogs).insert(MealLogsCompanion(
          id: Value(eval.id),
          timestamp: Value(eval.timestamp),
          photoPath: Value(eval.photoPath ?? ''),
          classificationIndex: Value(eval.classification.index),
          feedback: Value(eval.feedback),
          detectedIngredientsCsv: Value(eval.detectedIngredients.join(',')),
        ));
  }

  @override
  Future<void> deleteFromHistory(String id) async {
    await (_db.delete(_db.mealLogs)..where((t) => t.id.equals(id))).go();
  }

  // ── Estadísticas semanales ────────────────────────────────────────────────
  @override
  Future<WeeklyStats> getWeeklyStats() async {
    final since = DateTime.now().subtract(const Duration(days: 7));
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

    int healthy = 0, balanced = 0, junk = 0;
    double totalScore = 0;

    for (final r in rows) {
      final c = FoodClassification.values[r.classificationIndex.clamp(0, 2)];
      switch (c) {
        case FoodClassification.healthy:
          healthy++;
          totalScore += 0.85;
        case FoodClassification.balanced:
          balanced++;
          totalScore += 0.55;
        case FoodClassification.junk:
          junk++;
          totalScore += 0.20;
      }
    }

    return WeeklyStats(
      averageHealthScore: totalScore / rows.length,
      healthyCount: healthy,
      balancedCount: balanced,
      junkCount: junk,
      totalMeals: rows.length,
    );
  }
}
