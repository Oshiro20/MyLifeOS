import '../entities/ingredient_units.dart';

class IngredientUnitNormalizer {
  /// Intenta convertir la cantidad [fromQuantity] que está en [fromUnit] hacia [toUnit].
  /// Retorna un valor nulo si la conversión es matemáticamente imposible
  /// (ej. tratar de convertir 'litros' a 'unidades' o 'docenas' a 'kg').
  static double? convert(
      double fromQuantity, MeasurementUnit fromUnit, MeasurementUnit toUnit) {
    if (fromUnit == toUnit) return fromQuantity;

    // Normalizar a una base de volumen (base en ml)
    if (_isVolume(fromUnit) && _isVolume(toUnit)) {
      final ml = _toMl(fromQuantity, fromUnit);
      return _fromMl(ml, toUnit);
    }

    // Normalizar a base de masa (base en gramos)
    if (_isMass(fromUnit) && _isMass(toUnit)) {
      final grams = _toGrams(fromQuantity, fromUnit);
      return _fromGrams(grams, toUnit);
    }

    // Normalizar discretos (docenas vs unidades)
    if (_isDiscrete(fromUnit) && _isDiscrete(toUnit)) {
      final units = _toUnits(fromQuantity, fromUnit);
      return _fromUnits(units, toUnit);
    }

    // Incompatible (Masa a Volumen o Discreto a Masa)
    return null;
  }

  /// Pesos promedio culinarios (gramos por 1 unidad) para ingredientes comunes.
  static const Map<String, double> _culinaryGramsPerUnit = {
    'papa amarilla': 150.0,
    'papa blanca': 180.0,
    'papa huayro': 170.0,
    'papa': 170.0,
    'camote': 200.0,
    'yuca': 300.0,
    'cebolla': 150.0,
    'tomate': 120.0,
    'limon': 40.0,
    'platano': 120.0,
    'manzana': 160.0,
    'naranja': 180.0,
    'mandarina': 90.0,
    'palta': 200.0,
    'aguacate': 200.0,
    'zanahoria': 100.0,
    'pimiento': 140.0,
    'rocoto': 70.0,
    'aji': 25.0,
    'choclo': 250.0,
    'huevo': 60.0,
    'ajo': 5.0,
    'pechuga': 250.0,
    'pierna': 150.0,
    'encuentro': 140.0,
    'ala': 85.0,
    'presa': 150.0,
    'pollo': 1800.0,
  };

  /// Palabras clave de líquidos o pastas donde 1 ml ≈ 1 g de forma segura.
  static const List<String> _densityOneToOneKeywords = [
    'ajo molido',
    'ajos molidos',
    'sillao',
    'soya',
    'leche',
    'agua',
    'caldo',
    'vinagre',
    'salsa',
    'yogurt',
    'yogur',
    'crema',
    'aceite',
    'miel',
  ];

  static String _normKey(String raw) {
    var s = raw.toLowerCase().trim();
    const acc = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    acc.forEach((k, v) => s = s.replaceAll(k, v));
    return s.replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Devuelve gramos promedio por unidad si se conoce para [ingredientName].
  static double? defaultGramsPerUnit(String ingredientName) {
    final norm = _normKey(ingredientName);
    if (norm.isEmpty) return null;
    for (final entry in _culinaryGramsPerUnit.entries) {
      if (norm == entry.key ||
          norm.contains('${entry.key} ') ||
          norm.endsWith(' ${entry.key}') ||
          norm.contains('${entry.key}s')) {
        return entry.value;
      }
    }
    return null;
  }

  /// Convierte teniendo en cuenta equivalencias peso ↔ unidades (ej. 1 kg papa ↔ ~6 u)
  /// y densidad 1:1 para pastas/líquidos conocidos cuando es necesario.
  static ({double value, bool isApproximate})? convertForIngredient(
    double fromQuantity,
    MeasurementUnit fromUnit,
    MeasurementUnit toUnit,
    String ingredientName, {
    double? gramsPerUnitOverride,
  }) {
    final exact = convert(fromQuantity, fromUnit, toUnit);
    if (exact != null) {
      return (value: exact, isApproximate: false);
    }

    final gPerUnit = (gramsPerUnitOverride != null && gramsPerUnitOverride > 0)
        ? gramsPerUnitOverride
        : defaultGramsPerUnit(ingredientName);

    // Masa <-> Unidades / Docenas
    if (gPerUnit != null) {
      if (_isMass(fromUnit) && _isDiscrete(toUnit)) {
        final grams = _toGrams(fromQuantity, fromUnit);
        final units = grams / gPerUnit;
        return (value: _fromUnits(units, toUnit), isApproximate: true);
      }
      if (_isDiscrete(fromUnit) && _isMass(toUnit)) {
        final units = _toUnits(fromQuantity, fromUnit);
        final grams = units * gPerUnit;
        return (value: _fromGrams(grams, toUnit), isApproximate: true);
      }
    }

    // Volumen <-> Masa para líquidos/pastas húmedas (1 ml ≈ 1 g)
    final norm = _normKey(ingredientName);
    final allowLiquidDensity =
        _densityOneToOneKeywords.any((kw) => norm.contains(kw));
    if (allowLiquidDensity) {
      if (_isVolume(fromUnit) && _isMass(toUnit)) {
        final ml = _toMl(fromQuantity, fromUnit);
        return (value: _fromGrams(ml, toUnit), isApproximate: true);
      }
      if (_isMass(fromUnit) && _isVolume(toUnit)) {
        final grams = _toGrams(fromQuantity, fromUnit);
        return (value: _fromMl(grams, toUnit), isApproximate: true);
      }
    }

    return null;
  }

  static bool _isVolume(MeasurementUnit u) => const [
        MeasurementUnit.litro,
        MeasurementUnit.ml,
        MeasurementUnit.taza,
        MeasurementUnit.cucharada,
        MeasurementUnit.cucharadita,
      ].contains(u);

  static bool _isMass(MeasurementUnit u) => const [
        MeasurementUnit.kg,
        MeasurementUnit.g,
        MeasurementUnit.libra,
        MeasurementUnit.onza,
      ].contains(u);

  static bool _isDiscrete(MeasurementUnit u) => const [
        MeasurementUnit.unidades,
        MeasurementUnit.docena,
      ].contains(u);

  static double _toMl(double q, MeasurementUnit u) {
    switch (u) {
      case MeasurementUnit.litro:
        return q * 1000.0;
      case MeasurementUnit.ml:
        return q;
      case MeasurementUnit.taza:
        return q * 250.0; // asumiendo 1 taza = 250ml
      case MeasurementUnit.cucharada:
        return q * 15.0; // 1 cda = 15ml
      case MeasurementUnit.cucharadita:
        return q * 5.0; // 1 cdta = 5ml
      default:
        throw ArgumentError("No es unidad de volumen volumétrica estricta");
    }
  }

  static double _fromMl(double ml, MeasurementUnit u) {
    switch (u) {
      case MeasurementUnit.litro:
        return ml / 1000.0;
      case MeasurementUnit.ml:
        return ml;
      case MeasurementUnit.taza:
        return ml / 250.0;
      case MeasurementUnit.cucharada:
        return ml / 15.0;
      case MeasurementUnit.cucharadita:
        return ml / 5.0;
      default:
        throw ArgumentError("No es unidad volumétrica");
    }
  }

  static double _toGrams(double q, MeasurementUnit u) {
    switch (u) {
      case MeasurementUnit.kg:
        return q * 1000.0;
      case MeasurementUnit.g:
        return q;
      case MeasurementUnit.libra:
        return q * 453.592;
      case MeasurementUnit.onza:
        return q * 28.3495;
      default:
        throw ArgumentError("No es unidad de masa");
    }
  }

  static double _fromGrams(double g, MeasurementUnit u) {
    switch (u) {
      case MeasurementUnit.kg:
        return g / 1000.0;
      case MeasurementUnit.g:
        return g;
      case MeasurementUnit.libra:
        return g / 453.592;
      case MeasurementUnit.onza:
        return g / 28.3495;
      default:
        throw ArgumentError("No es unidad de masa");
    }
  }

  static double _toUnits(double q, MeasurementUnit u) {
    if (u == MeasurementUnit.docena) return q * 12.0;
    return q; // unidades
  }

  static double _fromUnits(double units, MeasurementUnit u) {
    if (u == MeasurementUnit.docena) return units / 12.0;
    return units;
  }
}
