/// Resultado de una validación con mensaje de error opcional.
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult.ok() : isValid = true, errorMessage = null;
  const ValidationResult.fail(this.errorMessage) : isValid = false;
}

/// Conjunto de validaciones de negocio reutilizables.
class Validator {
  const Validator._();

  // ── Generales ────────────────────────────────────────────────────────────────
  static ValidationResult notEmpty(String? value, {String field = 'campo'}) {
    if (value == null || value.trim().isEmpty) {
      return ValidationResult.fail('El $field no puede estar vacío.');
    }
    return const ValidationResult.ok();
  }

  static ValidationResult maxLength(String? value, int max, {String field = 'campo'}) {
    if (value != null && value.trim().length > max) {
      return ValidationResult.fail('El $field no puede superar $max caracteres.');
    }
    return const ValidationResult.ok();
  }

  static ValidationResult positiveNumber(num? value, {String field = 'valor'}) {
    if (value == null || value <= 0) {
      return ValidationResult.fail('El $field debe ser mayor que cero.');
    }
    return const ValidationResult.ok();
  }

  // ── Cocina ───────────────────────────────────────────────────────────────────
  static ValidationResult ingredientName(String? name) {
    final notEmptyResult = notEmpty(name, field: 'nombre');
    if (!notEmptyResult.isValid) return notEmptyResult;
    return maxLength(name, 80, field: 'nombre del ingrediente');
  }

  static ValidationResult ingredientQuantity(double? qty) =>
      positiveNumber(qty, field: 'cantidad');

  static ValidationResult recipeName(String? name) {
    final notEmptyResult = notEmpty(name, field: 'nombre de la receta');
    if (!notEmptyResult.isValid) return notEmptyResult;
    return maxLength(name, 100, field: 'nombre de la receta');
  }

  static ValidationResult recipeDuration(int? minutes) {
    if (minutes == null || minutes <= 0) {
      return const ValidationResult.fail('La duración debe ser mayor que 0 minutos.');
    }
    if (minutes > 1440) {
      return const ValidationResult.fail('La duración no puede superar 24 horas (1440 min).');
    }
    return const ValidationResult.ok();
  }

  // ── Armario ──────────────────────────────────────────────────────────────────
  static ValidationResult garmentName(String? name) {
    final notEmptyResult = notEmpty(name, field: 'nombre de la prenda');
    if (!notEmptyResult.isValid) return notEmptyResult;
    return maxLength(name, 60, field: 'nombre de la prenda');
  }

  static ValidationResult hexColor(String? color) {
    if (color == null || color.trim().isEmpty) {
      return const ValidationResult.fail('El color no puede estar vacío.');
    }
    final hex = color.trim().replaceAll('#', '');
    if (hex.length != 6) {
      return const ValidationResult.fail('El color debe ser un hex válido (ej: #3A86FF).');
    }
    final isHex = RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex);
    if (!isHex) {
      return const ValidationResult.fail('El color debe contener solo caracteres hexadecimales.');
    }
    return const ValidationResult.ok();
  }

  static ValidationResult outfitName(String? name) {
    final notEmptyResult = notEmpty(name, field: 'nombre del outfit');
    if (!notEmptyResult.isValid) return notEmptyResult;
    return maxLength(name, 60, field: 'nombre del outfit');
  }

  /// Combina varias validaciones — devuelve el primer error encontrado.
  static ValidationResult combine(List<ValidationResult> results) {
    for (final r in results) {
      if (!r.isValid) return r;
    }
    return const ValidationResult.ok();
  }
}
