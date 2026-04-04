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
