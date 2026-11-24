import '../../cocina/usecases/ingredient_matcher.dart';
import '../entities/meal_evaluation.dart';

enum FoodGroup {
  fruit,
  vegetable,
  protein,
  carbLegume,
  dairy,
  healthyFat,
  processed;

  String get label => switch (this) {
        FoodGroup.fruit => 'Frutas',
        FoodGroup.vegetable => 'Verduras',
        FoodGroup.protein => 'Proteínas',
        FoodGroup.carbLegume => 'Carbos / Menestras',
        FoodGroup.dairy => 'Lácteos',
        FoodGroup.healthyFat => 'Grasas saludables',
        FoodGroup.processed => 'Ultraprocesados / Frituras',
      };

  String get emoji => switch (this) {
        FoodGroup.fruit => '🍎',
        FoodGroup.vegetable => '🥦',
        FoodGroup.protein => '🍗',
        FoodGroup.carbLegume => '🌾',
        FoodGroup.dairy => '🥛',
        FoodGroup.healthyFat => '🥑',
        FoodGroup.processed => '🍟',
      };
}

class ConsumptionItemCount {
  final String name;
  final int count;
  final FoodGroup group;

  const ConsumptionItemCount({
    required this.name,
    required this.count,
    required this.group,
  });
}

class ConsumptionAnalytics {
  final List<({String name, int count})> topMeals;
  final List<ConsumptionItemCount> topFruits;
  final List<ConsumptionItemCount> topVegetables;
  final List<ConsumptionItemCount> topProteins;
  final Map<FoodGroup, int> groupCounts;
  final Map<CookingMethod, int> cookingMethodCounts;
  final int daysWithFruit;
  final int daysWithVegetable;
  final int friedMealsCount;
  final int totalMealsAnalyzed;
  final List<String> balanceAlerts;

  const ConsumptionAnalytics({
    this.topMeals = const [],
    this.topFruits = const [],
    this.topVegetables = const [],
    this.topProteins = const [],
    this.groupCounts = const {},
    this.cookingMethodCounts = const {},
    this.daysWithFruit = 0,
    this.daysWithVegetable = 0,
    this.friedMealsCount = 0,
    this.totalMealsAnalyzed = 0,
    this.balanceAlerts = const [],
  });
}

/// Analiza el historial de `MealLog` para responder qué platos, frutas,
/// verduras y proteínas se consumen más y detectar brechas nutricionales.
class ConsumptionAnalyticsUseCase {
  const ConsumptionAnalyticsUseCase();

  static const Map<String, ({String canonical, FoodGroup group})> _foodCatalog =
      {
    // Frutas
    'platano': (canonical: 'Plátano', group: FoodGroup.fruit),
    'banana': (canonical: 'Plátano', group: FoodGroup.fruit),
    'manzana': (canonical: 'Manzana', group: FoodGroup.fruit),
    'fresa': (canonical: 'Fresa', group: FoodGroup.fruit),
    'papaya': (canonical: 'Papaya', group: FoodGroup.fruit),
    'mango': (canonical: 'Mango', group: FoodGroup.fruit),
    'naranja': (canonical: 'Naranja', group: FoodGroup.fruit),
    'mandarina': (canonical: 'Mandarina', group: FoodGroup.fruit),
    'pera': (canonical: 'Pera', group: FoodGroup.fruit),
    'uva': (canonical: 'Uva', group: FoodGroup.fruit),
    'pina': (canonical: 'Piña', group: FoodGroup.fruit),
    'sandia': (canonical: 'Sandía', group: FoodGroup.fruit),
    'melon': (canonical: 'Melón', group: FoodGroup.fruit),
    'kiwi': (canonical: 'Kiwi', group: FoodGroup.fruit),
    'arandano': (canonical: 'Arándano', group: FoodGroup.fruit),
    'blueberry': (canonical: 'Arándano', group: FoodGroup.fruit),
    'durazno': (canonical: 'Durazno', group: FoodGroup.fruit),
    'maracuya': (canonical: 'Maracuyá', group: FoodGroup.fruit),
    'lucuma': (canonical: 'Lúcuma', group: FoodGroup.fruit),
    // Verduras
    'tomate': (canonical: 'Tomate', group: FoodGroup.vegetable),
    'cebolla': (canonical: 'Cebolla', group: FoodGroup.vegetable),
    'lechuga': (canonical: 'Lechuga', group: FoodGroup.vegetable),
    'espinaca': (canonical: 'Espinaca', group: FoodGroup.vegetable),
    'brocoli': (canonical: 'Brócoli', group: FoodGroup.vegetable),
    'zanahoria': (canonical: 'Zanahoria', group: FoodGroup.vegetable),
    'pepino': (canonical: 'Pepino', group: FoodGroup.vegetable),
    'pimiento': (canonical: 'Pimiento', group: FoodGroup.vegetable),
    'ensalada': (canonical: 'Ensalada', group: FoodGroup.vegetable),
    'coliflor': (canonical: 'Coliflor', group: FoodGroup.vegetable),
    'apio': (canonical: 'Apio', group: FoodGroup.vegetable),
    'zapallo': (canonical: 'Zapallo', group: FoodGroup.vegetable),
    'vainita': (canonical: 'Vainita', group: FoodGroup.vegetable),
    'arveja': (canonical: 'Arveja', group: FoodGroup.vegetable),
    'alverja': (canonical: 'Arveja', group: FoodGroup.vegetable),
    'choclo': (canonical: 'Choclo', group: FoodGroup.vegetable),
    'acelga': (canonical: 'Acelga', group: FoodGroup.vegetable),
    'beterraga': (canonical: 'Beterraga', group: FoodGroup.vegetable),
    'esparrago': (canonical: 'Espárrago', group: FoodGroup.vegetable),
    'limon': (canonical: 'Limón', group: FoodGroup.vegetable),
    // Proteínas
    'pollo': (canonical: 'Pollo', group: FoodGroup.protein),
    'huevo': (canonical: 'Huevo', group: FoodGroup.protein),
    'atun': (canonical: 'Atún', group: FoodGroup.protein),
    'pescado': (canonical: 'Pescado', group: FoodGroup.protein),
    'salmon': (canonical: 'Salmón', group: FoodGroup.protein),
    'carne': (canonical: 'Carne', group: FoodGroup.protein),
    'res': (canonical: 'Carne de res', group: FoodGroup.protein),
    'lomo': (canonical: 'Carne de res', group: FoodGroup.protein),
    'pavo': (canonical: 'Pavo', group: FoodGroup.protein),
    'cerdo': (canonical: 'Cerdo', group: FoodGroup.protein),
    'tofu': (canonical: 'Tofu', group: FoodGroup.protein),
    // Carbohidratos / menestras
    'lenteja': (canonical: 'Lentejas', group: FoodGroup.carbLegume),
    'menestra': (canonical: 'Menestra', group: FoodGroup.carbLegume),
    'frijol': (canonical: 'Frijol', group: FoodGroup.carbLegume),
    'frejol': (canonical: 'Frijol', group: FoodGroup.carbLegume),
    'garbanzo': (canonical: 'Garbanzo', group: FoodGroup.carbLegume),
    'arroz': (canonical: 'Arroz', group: FoodGroup.carbLegume),
    'papa': (canonical: 'Papa', group: FoodGroup.carbLegume),
    'camote': (canonical: 'Camote', group: FoodGroup.carbLegume),
    'yuca': (canonical: 'Yuca', group: FoodGroup.carbLegume),
    'avena': (canonical: 'Avena', group: FoodGroup.carbLegume),
    'quinua': (canonical: 'Quinua', group: FoodGroup.carbLegume),
    'quinoa': (canonical: 'Quinua', group: FoodGroup.carbLegume),
    'pasta': (canonical: 'Pasta / Fideos', group: FoodGroup.carbLegume),
    'fideo': (canonical: 'Pasta / Fideos', group: FoodGroup.carbLegume),
    'pan': (canonical: 'Pan', group: FoodGroup.carbLegume),
    // Lácteos
    'yogurt': (canonical: 'Yogurt', group: FoodGroup.dairy),
    'yogur': (canonical: 'Yogurt', group: FoodGroup.dairy),
    'leche': (canonical: 'Leche', group: FoodGroup.dairy),
    'queso': (canonical: 'Queso', group: FoodGroup.dairy),
    // Grasas saludables
    'palta': (canonical: 'Palta', group: FoodGroup.healthyFat),
    'aguacate': (canonical: 'Palta', group: FoodGroup.healthyFat),
    'mani': (canonical: 'Maní', group: FoodGroup.healthyFat),
    'almendra': (canonical: 'Almendra', group: FoodGroup.healthyFat),
    'nuez': (canonical: 'Nuez', group: FoodGroup.healthyFat),
    'chia': (canonical: 'Chía', group: FoodGroup.healthyFat),
    // Procesados / frituras
    'gaseosa': (canonical: 'Gaseosa', group: FoodGroup.processed),
    'hamburguesa': (canonical: 'Hamburguesa', group: FoodGroup.processed),
    'pizza': (canonical: 'Pizza', group: FoodGroup.processed),
    'salchicha': (canonical: 'Embutidos', group: FoodGroup.processed),
    'hot dog': (canonical: 'Hot dog', group: FoodGroup.processed),
    'embutido': (canonical: 'Embutidos', group: FoodGroup.processed),
    'galleta': (canonical: 'Galletas', group: FoodGroup.processed),
    'helado': (canonical: 'Helado', group: FoodGroup.processed),
    'papas fritas': (canonical: 'Papas fritas', group: FoodGroup.processed),
    'frito': (canonical: 'Frituras', group: FoodGroup.processed),
  };

  static ({String canonical, FoodGroup group})? classifyFoodItem(String raw) {
    final norm = IngredientMatcher.normalizeText(raw);
    if (norm.isEmpty) return null;
    for (final entry in _foodCatalog.entries) {
      final pattern = RegExp('(?:^|\\s)${RegExp.escape(entry.key)}(?:s|es)?(?:\\s|\$)');
      if (pattern.hasMatch(norm)) {
        return entry.value;
      }
    }
    return null;
  }

  ConsumptionAnalytics call(
    List<MealLog> logs, {
    int? lastDays,
    int topLimit = 6,
  }) {
    final cutoff = lastDays == null
        ? null
        : DateTime.now().subtract(Duration(days: lastDays));
    final filtered = cutoff == null
        ? logs
        : logs.where((l) => l.timestamp.isAfter(cutoff)).toList();

    if (filtered.isEmpty) return const ConsumptionAnalytics();

    final mealCounts = <String, int>{};
    final mealDisplay = <String, String>{};
    final itemCounts = <String, ({int count, FoodGroup group})>{};
    final groupCounts = <FoodGroup, int>{};
    final methodCounts = <CookingMethod, int>{};
    final fruitDays = <String>{};
    final vegDays = <String>{};
    var friedMeals = 0;

    for (final log in filtered) {
      final dayKey =
          '${log.timestamp.year}-${log.timestamp.month}-${log.timestamp.day}';

      final rawName = log.mealName?.trim();
      if (rawName != null && rawName.isNotEmpty) {
        final normName = IngredientMatcher.normalizeText(rawName);
        if (normName.isNotEmpty) {
          mealCounts[normName] = (mealCounts[normName] ?? 0) + 1;
          mealDisplay.putIfAbsent(normName, () => rawName);
        }
      }

      final method = log.cookingMethod ??
          CookingMethod.inferFromText(
            '${log.mealName ?? ''} ${log.detectedIngredients.join(' ')}',
          );
      if (method != null) {
        methodCounts[method] = (methodCounts[method] ?? 0) + 1;
        if (method == CookingMethod.fried) friedMeals++;
      }

      final seenCanonicalInMeal = <String>{};
      final sources = [
        ...log.detectedIngredients,
        if (rawName != null && rawName.isNotEmpty) rawName,
      ];
      for (final src in sources) {
        final norm = IngredientMatcher.normalizeText(src);
        if (norm.isEmpty) continue;
        for (final entry in _foodCatalog.entries) {
          final pattern = RegExp(
            '(?:^|\\s)${RegExp.escape(entry.key)}(?:s|es)?(?:\\s|\$)',
          );
          if (!pattern.hasMatch(norm)) continue;
          final hit = entry.value;
          if (!seenCanonicalInMeal.add(hit.canonical)) continue;
          final prev = itemCounts[hit.canonical];
          itemCounts[hit.canonical] = (
            count: (prev?.count ?? 0) + 1,
            group: hit.group,
          );
          groupCounts[hit.group] = (groupCounts[hit.group] ?? 0) + 1;
          if (hit.group == FoodGroup.fruit) fruitDays.add(dayKey);
          if (hit.group == FoodGroup.vegetable) vegDays.add(dayKey);
        }
      }
    }

    final topMeals = mealCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    List<ConsumptionItemCount> topFor(FoodGroup g) {
      final list = itemCounts.entries
          .where((e) => e.value.group == g)
          .map((e) => ConsumptionItemCount(
                name: e.key,
                count: e.value.count,
                group: g,
              ))
          .toList()
        ..sort((a, b) => b.count.compareTo(a.count));
      return list.take(topLimit).toList();
    }

    final topFruits = topFor(FoodGroup.fruit);
    final topVegetables = topFor(FoodGroup.vegetable);
    final topProteins = topFor(FoodGroup.protein);

    final alerts = <String>[];
    final total = filtered.length;
    if (total >= 3 && fruitDays.isEmpty) {
      alerts.add('🍎 Aún no registras frutas en este periodo — suma 1 fruta al desayuno o media tarde.');
    } else if (total >= 5 && fruitDays.length <= 1) {
      alerts.add('🍎 Bajo consumo de frutas (${fruitDays.length} día) — intenta variar con plátano, papaya o mandarina.');
    }
    if (total >= 3 && vegDays.isEmpty) {
      alerts.add('🥦 Faltan verduras en tus registros — acompaña tus segundos con ensalada fresca o brócoli.');
    }
    if (total >= 3 && friedMeals / total >= 0.35) {
      final pct = ((friedMeals / total) * 100).round();
      alerts.add('🍳 $pct% de tus comidas fueron fritas — alterna con plancha, sancochado o airfryer.');
    }
    if (alerts.isEmpty && total >= 3) {
      alerts.add('💚 Buen equilibrio entre grupos alimenticios y métodos de preparación.');
    }

    return ConsumptionAnalytics(
      topMeals: topMeals
          .take(topLimit)
          .map((e) => (name: mealDisplay[e.key] ?? e.key, count: e.value))
          .toList(),
      topFruits: topFruits,
      topVegetables: topVegetables,
      topProteins: topProteins,
      groupCounts: Map.unmodifiable(groupCounts),
      cookingMethodCounts: Map.unmodifiable(methodCounts),
      daysWithFruit: fruitDays.length,
      daysWithVegetable: vegDays.length,
      friedMealsCount: friedMeals,
      totalMealsAnalyzed: total,
      balanceAlerts: List.unmodifiable(alerts),
    );
  }
}
