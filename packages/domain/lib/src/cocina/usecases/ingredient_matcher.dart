import '../entities/ingredient_units.dart';
import '../entities/inventory_ingredient.dart';
import '../entities/recipe.dart';
import 'ingredient_unit_normalizer.dart';

/// Disponibilidad real de un ingrediente de receta frente a la despensa.
enum IngredientAvailability {
  available,
  insufficient,
  incompatibleUnit,
  missing,
}

/// Resultado de evaluar un ingrediente requerido de una receta contra la despensa.
class RecipeIngredientCheck {
  final RecipeIngredient requirement;
  final InventoryIngredient? pantryMatch;
  final IngredientAvailability availability;
  final double? deductedInPantryUnit;
  final double? availableInRecipeUnit;
  final double? missingInRecipeUnit;
  final bool isApproximateConversion;

  const RecipeIngredientCheck({
    required this.requirement,
    required this.pantryMatch,
    required this.availability,
    this.deductedInPantryUnit,
    this.availableInRecipeUnit,
    this.missingInRecipeUnit,
    this.isApproximateConversion = false,
  });

  bool get canDeduct =>
      pantryMatch != null &&
      deductedInPantryUnit != null &&
      deductedInPantryUnit! > 0;

  bool get willDeplete {
    if (!canDeduct) return false;
    return (pantryMatch!.quantity - deductedInPantryUnit!) <= 0.0001;
  }

  double get remainingAfterCook {
    if (!canDeduct) return pantryMatch?.quantity ?? 0;
    final rem = pantryMatch!.quantity - deductedInPantryUnit!;
    return rem <= 0.0001 ? 0 : rem;
  }
}

/// Motor unificado para emparejar ingredientes de receta con la despensa
/// (tolerante a tildes, plurales, variantes como "ajos molidos" ↔ "ajos"
/// o "Plátano Seda" ↔ "plátano", y conversión de unidades).
class IngredientMatcher {
  static const _stopwords = <String>{
    'de',
    'del',
    'la',
    'el',
    'los',
    'las',
    'con',
    'en',
    'al',
    'a',
    'para',
    'y',
    'o',
    'un',
    'una',
    'unos',
    'unas',
  };

  static const _partMeasurePrefixes = <String>{
    'diente',
    'dientes',
    'cabeza',
    'cabezas',
    'rama',
    'ramas',
    'hoja',
    'hojas',
    'filete',
    'filetes',
    'pechuga',
    'pechugas',
    'pierna',
    'piernas',
    'lomo',
    'trozo',
    'trozos',
    'rodaja',
    'rodajas',
    'tira',
    'tiras',
    'chorrito',
    'pizca',
    'frasco',
    'frascos',
    'botella',
    'botellas',
    'lata',
    'latas',
    'paquete',
    'paquetes',
    'bolsa',
    'bolsas',
    'sobre',
    'sobres',
    'caja',
    'cajas',
    'menestra',
    'menestras',
    'presa',
    'presas',
    'cuarto',
    'cuartos',
    'mitad',
    'mitades',
    'bolsita',
    'bolsitas',
    'taper',
    'tapper',
    'tupper',
    'porcion',
    'porciones',
  };

  static const _synonymGroups = <List<String>>[
    ['sillao', 'salsa de soya', 'salsa de soja', 'soya'],
    ['pasta de ajos', 'pasta de ajo', 'ajo molido', 'ajos molidos', 'ajo', 'ajos'],
    ['entrepierna', 'entrepierna de pollo', 'encuentro', 'encuentro de pollo', 'muslo', 'muslo de pollo'],
    ['presa de pecho', 'presa de pecho de pollo', 'pechuga de pollo', 'pechuga', 'pecho'],
    ['aji especial', 'aji panca', 'panca'],
    ['palta', 'aguacate'],
    ['choclo', 'maiz'],
    ['camote', 'batata'],
    ['arveja', 'guisante', 'alberja'],
    ['vainita', 'ejote'],
    ['frejol', 'frijol', 'poroto'],
    ['chancho', 'cerdo'],
    ['rocoto', 'aji'],
    ['culantro', 'cilantro'],
    ['kion', 'jengibre'],
    ['mani', 'cacahuate'],
    ['pimiento', 'morron'],
  ];

  /// Normaliza a minúsculas sin tildes ni puntuación redundante.
  static String normalizeText(String raw) {
    var s = raw.toLowerCase().trim();
    const replacements = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
    };
    replacements.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Extrae tokens significativos eliminando preposiciones/artículos comunes.
  static List<String> tokenize(String raw) {
    final norm = normalizeText(raw);
    if (norm.isEmpty) return const [];
    return norm
        .split(' ')
        .where((t) => t.isNotEmpty && !_stopwords.contains(t))
        .toList();
  }

  /// Compara dos tokens tolerando pluralización en español (-s, -es, -z/-ces).
  static bool tokensMatch(String a, String b) {
    if (a == b) return true;
    if (a.isEmpty || b.isEmpty) return false;
    if ('${a}s' == b || '${b}s' == a) return true;
    if ('${a}es' == b || '${b}es' == a) return true;
    if (a.endsWith('z') && '${a.substring(0, a.length - 1)}ces' == b) {
      return true;
    }
    if (b.endsWith('z') && '${b.substring(0, b.length - 1)}ces' == a) {
      return true;
    }
    return false;
  }

  static bool _allTokensPresent(List<String> needle, List<String> haystack) {
    for (final n in needle) {
      if (!haystack.any((h) => tokensMatch(n, h))) {
        return false;
      }
    }
    return true;
  }

  static int _scoreCandidate(String recipeName, String pantryName) {
    final rNorm = normalizeText(recipeName);
    final pNorm = normalizeText(pantryName);
    if (rNorm.isEmpty || pNorm.isEmpty) return 0;

    if (rNorm == pNorm) return 1000;

    final rTokens = tokenize(rNorm);
    final pTokens = tokenize(pNorm);
    if (rTokens.isEmpty || pTokens.isEmpty) return 0;

    if (rTokens.length == pTokens.length) {
      var allMatch = true;
      for (int i = 0; i < rTokens.length; i++) {
        if (!tokensMatch(rTokens[i], pTokens[i])) {
          allMatch = false;
          break;
        }
      }
      if (allMatch) return 900;
    }

    // Mismo sustantivo principal (ej. "ajos molidos" <-> "ajos", "plátano seda" <-> "plátano").
    // Evita falsos positivos como "salsa de tomate" <-> "tomate" o "caldo de pollo" <-> "pollo".
    if (tokensMatch(rTokens.first, pTokens.first)) {
      if (_allTokensPresent(rTokens, pTokens) ||
          _allTokensPresent(pTokens, rTokens)) {
        final diff = (rTokens.length - pTokens.length).abs();
        return (800 - diff * 15).clamp(700, 899);
      }
    }

    // Aliases / sinónimos culinarios exactos (ej. "sillao" <-> "salsa de soya",
    // "pasta de ajos" <-> "ajos molidos", "entrepierna" <-> "encuentro").
    for (final group in _synonymGroups) {
      final hasR = group.any((alias) =>
          rNorm == alias ||
          rNorm.contains(alias) ||
          (rTokens.length == 1 && tokensMatch(rTokens.first, alias)));
      final hasP = group.any((alias) =>
          pNorm == alias ||
          pNorm.contains(alias) ||
          (pTokens.length == 1 && tokensMatch(pTokens.first, alias)));
      if (hasR && hasP) return 720;
    }

    // Prefijo de corte/categoría ("dientes de ajo" -> "ajo", "menestra lentejas baby" -> "lentejas baby").
    List<String> stripPrefixes(List<String> tokens) {
      var cur = tokens;
      while (cur.length >= 2 && _partMeasurePrefixes.contains(cur.first)) {
        cur = cur.sublist(1);
      }
      return cur;
    }

    final rCore = stripPrefixes(rTokens);
    final pCore = stripPrefixes(pTokens);

    if (rCore.isNotEmpty &&
        pCore.isNotEmpty &&
        tokensMatch(rCore.first, pCore.first) &&
        (_allTokensPresent(rCore, pCore) || _allTokensPresent(pCore, rCore))) {
      final diff = (rCore.length - pCore.length).abs();
      return (660 - diff * 15).clamp(580, 699);
    }

    return 0;
  }

  /// Encuentra el mejor ingrediente coincidente en la despensa.
  static InventoryIngredient? findBestMatch(
    List<InventoryIngredient> inventory,
    String recipeIngredientName, {
    String? preferredUnit,
    Map<String, String>? learnedAliases,
  }) {
    InventoryIngredient? best;
    var bestScore = 0;
    var bestConvertible = false;

    final targetUnit =
        preferredUnit != null ? MeasurementUnit.fromString(preferredUnit) : null;
    final normRecipeName = normalizeText(recipeIngredientName);
    final learnedPantryTarget = learnedAliases?[normRecipeName];

    for (final item in inventory) {
      var score = 0;
      if (learnedPantryTarget != null &&
          normalizeText(item.name) == normalizeText(learnedPantryTarget)) {
        score = 950;
      } else {
        score = _scoreCandidate(recipeIngredientName, item.name);
      }
      if (score <= 0) continue;

      final isConvertible = targetUnit != null &&
          IngredientUnitNormalizer.convertForIngredient(
                1,
                targetUnit,
                MeasurementUnit.fromString(item.unit),
                item.name,
                pantryPreparation: item.preparation,
              ) !=
              null;

      final isBetter = score > bestScore ||
          (score == bestScore && isConvertible && !bestConvertible) ||
          (score == bestScore &&
              isConvertible == bestConvertible &&
              item.quantity > (best?.quantity ?? -1));

      if (isBetter) {
        best = item;
        bestScore = score;
        bestConvertible = isConvertible;
      }
    }

    return best;
  }

  /// Busca override personalizado de gramos/unidad por nombre de despensa o receta.
  static double? resolveCustomGramsPerUnit(
    Map<String, double>? customGramsPerUnit,
    String ingredientName,
    String? pantryName,
  ) {
    if (customGramsPerUnit == null || customGramsPerUnit.isEmpty) return null;
    if (pantryName != null) {
      final pNorm = normalizeText(pantryName);
      if (customGramsPerUnit.containsKey(pNorm)) {
        return customGramsPerUnit[pNorm];
      }
    }
    final rNorm = normalizeText(ingredientName);
    if (customGramsPerUnit.containsKey(rNorm)) {
      return customGramsPerUnit[rNorm];
    }
    return null;
  }

  /// Evalúa todos los ingredientes de una receta contra el inventario actual.
  static List<RecipeIngredientCheck> evaluateRecipe({
    required List<RecipeIngredient> recipeIngredients,
    required List<InventoryIngredient> inventory,
    Map<String, double>? customGramsPerUnit,
    Map<String, String>? learnedAliases,
  }) {
    final checks = <RecipeIngredientCheck>[];
    // Copia local de cantidades restantes por si la receta repite el mismo ingrediente.
    final simulatedQtyById = <String, double>{
      for (final ing in inventory) ing.id: ing.quantity,
    };

    for (final req in recipeIngredients) {
      final match = findBestMatch(
        inventory,
        req.ingredientName,
        preferredUnit: req.unit,
        learnedAliases: learnedAliases,
      );

      if (match == null) {
        checks.add(RecipeIngredientCheck(
          requirement: req,
          pantryMatch: null,
          availability: IngredientAvailability.missing,
          missingInRecipeUnit: req.quantity,
        ));
        continue;
      }

      final currentQty = simulatedQtyById[match.id] ?? match.quantity;
      final effectiveMatch = match.copyWith(quantity: currentQty);

      final reqUnit = MeasurementUnit.fromString(req.unit);
      final invUnit = MeasurementUnit.fromString(match.unit);
      final customGrams = resolveCustomGramsPerUnit(
        customGramsPerUnit,
        req.ingredientName,
        match.name,
      );

      final deductedConv = IngredientUnitNormalizer.convertForIngredient(
        req.quantity,
        reqUnit,
        invUnit,
        req.ingredientName,
        gramsPerUnitOverride: customGrams,
        pantryPreparation: match.preparation,
      ) ??
          IngredientUnitNormalizer.convertForIngredient(
            req.quantity,
            reqUnit,
            invUnit,
            match.name,
            gramsPerUnitOverride: customGrams,
            pantryPreparation: match.preparation,
          );

      if (deductedConv == null) {
        checks.add(RecipeIngredientCheck(
          requirement: req,
          pantryMatch: effectiveMatch,
          availability: IngredientAvailability.incompatibleUnit,
        ));
        continue;
      }

      final deductedInPantryUnit = deductedConv.value;
      final availableConv = IngredientUnitNormalizer.convertForIngredient(
        currentQty,
        invUnit,
        reqUnit,
        req.ingredientName,
        gramsPerUnitOverride: customGrams,
        pantryPreparation: match.preparation,
      ) ??
          IngredientUnitNormalizer.convertForIngredient(
            currentQty,
            invUnit,
            reqUnit,
            match.name,
            gramsPerUnitOverride: customGrams,
            pantryPreparation: match.preparation,
          );
      final availableInRecipeUnit = availableConv?.value;

      if (currentQty + 0.0001 >= deductedInPantryUnit) {
        simulatedQtyById[match.id] =
            (currentQty - deductedInPantryUnit).clamp(0, double.infinity);
        checks.add(RecipeIngredientCheck(
          requirement: req,
          pantryMatch: effectiveMatch,
          availability: IngredientAvailability.available,
          deductedInPantryUnit: deductedInPantryUnit,
          availableInRecipeUnit: availableInRecipeUnit,
          isApproximateConversion: deductedConv.isApproximate,
        ));
      } else {
        simulatedQtyById[match.id] = 0;
        final missingInRecipe = (availableInRecipeUnit != null &&
                req.quantity > availableInRecipeUnit)
            ? req.quantity - availableInRecipeUnit
            : req.quantity;
        checks.add(RecipeIngredientCheck(
          requirement: req,
          pantryMatch: effectiveMatch,
          availability: IngredientAvailability.insufficient,
          deductedInPantryUnit: currentQty > 0 ? currentQty : 0,
          availableInRecipeUnit: availableInRecipeUnit,
          missingInRecipeUnit: missingInRecipe,
          isApproximateConversion: deductedConv.isApproximate,
        ));
      }
    }

    return checks;
  }
}
