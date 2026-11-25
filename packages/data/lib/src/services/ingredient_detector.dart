import 'package:domain/domain.dart';

/// Resultado de detección automática de un ingrediente.
class IngredientSuggestion {
  final String? primaryCategory;
  final String? subCategory;
  final MeasurementUnit? suggestedUnit;
  final String? suggestedPreparation;

  const IngredientSuggestion({
    this.primaryCategory,
    this.subCategory,
    this.suggestedUnit,
    this.suggestedPreparation,
  });
}

/// Motor offline de detección de ingredientes basado en diccionarios.
class IngredientDetector {
  static String _normalize(String raw) => raw
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u');

  /// Coincidencia por palabra completa (permite plurales simples s/es), evitando
  /// falsos positivos como "ensALAda" -> "ala", "PASaje" -> "pasa", "enSALada" -> "sal".
  static bool matchesWholeWord(String rawText, String keyword) {
    final text = _normalize(rawText);
    final k = _normalize(keyword);
    if (text.isEmpty || k.isEmpty) return false;
    final pattern = RegExp(
      '(^|[^a-z0-9ñ])${RegExp.escape(k)}(?:s|es)?(?=\$|[^a-z0-9ñ])',
    );
    return pattern.hasMatch(text);
  }

  static final List<MapEntry<String, (String, String, MeasurementUnit)>>
      _sortedEntries = _ingredients.entries.toList()
        ..sort((a, b) => b.key.length.compareTo(a.key.length));

  /// Detecta categoría, unidad sugerida y preparación (ej. "cocido / listo") a partir del nombre.
  static IngredientSuggestion detect(String name) {
    final lower = name.trim().toLowerCase();

    String? primary;
    String? sub;
    MeasurementUnit? unit;
    String? preparation;

    if (RegExp(
            r'\b(cocid[ao]s?|cocinad[ao]s?|pre-?cocid[ao]s?|list[ao]s?\s*(para|al))\b')
        .hasMatch(lower)) {
      preparation = 'cocido / listo';
    }

    // Buscar en diccionario por palabra completa (frases más largas primero)
    for (final entry in _sortedEntries) {
      if (matchesWholeWord(lower, entry.key)) {
        primary = entry.value.$1;
        sub = entry.value.$2;
        unit = entry.value.$3;
        break;
      }
    }

    if (preparation == 'cocido / listo' && primary == 'Legumbres') {
      sub = 'Menestra cocida / lista';
    }

    // Fallback: buscar por categoría general
    primary ??= _guessCategory(lower);

    return IngredientSuggestion(
      primaryCategory: primary,
      subCategory: sub,
      suggestedUnit: unit,
      suggestedPreparation: preparation,
    );
  }

  static String? _guessCategory(String lower) {
    // Reglas generales
    if (_fruitSuffix.any((s) => matchesWholeWord(lower, s))) {
      return 'Frutas';
    }
    return null;
  }

  static const _fruitSuffix = ['manzana', 'naranja', 'fresa', 'cereza', 'pera'];

  // (primaryCategory, subCategory, unidad sugerida)
  static const _ingredients = <String, (String, String, MeasurementUnit)>{
    // ── Frutas ──
    'manzana': ('Frutas', 'Frutas dulces', MeasurementUnit.unidades),
    'plátano': ('Frutas', 'Frutas dulces', MeasurementUnit.unidades),
    'platano': ('Frutas', 'Frutas dulces', MeasurementUnit.unidades),
    'naranja': ('Frutas', 'Cítricos', MeasurementUnit.unidades),
    'limón': ('Frutas', 'Cítricos', MeasurementUnit.unidades),
    'limon': ('Frutas', 'Cítricos', MeasurementUnit.unidades),
    'fresa': ('Frutas', 'Frutas dulces', MeasurementUnit.g),
    'uva': ('Frutas', 'Frutas dulces', MeasurementUnit.g),
    'piña': ('Frutas', 'Frutas tropicales', MeasurementUnit.unidades),
    'palta': ('Frutas', 'Otros', MeasurementUnit.unidades),
    'aguacate': ('Frutas', 'Otros', MeasurementUnit.unidades),
    'mango': ('Frutas', 'Frutas tropicales', MeasurementUnit.unidades),
    'sandía': ('Frutas', 'Frutas de agua', MeasurementUnit.unidades),
    'papaya': ('Frutas', 'Frutas tropicales', MeasurementUnit.unidades),
    'durazno': ('Frutas', 'Frutas de hueso', MeasurementUnit.unidades),
    'mandarina': ('Frutas', 'Cítricos', MeasurementUnit.unidades),

    // ── Verduras ──
    'tomate': ('Verduras', 'Verduras de fruto', MeasurementUnit.unidades),
    'cebolla': (
      'Condimentos y especias',
      'Aromáticos',
      MeasurementUnit.unidades
    ),
    'ajo': ('Condimentos y especias', 'Aromáticos', MeasurementUnit.unidades),
    'papa': ('Tubérculos y raíces', 'Tubérculos andinos', MeasurementUnit.kg),
    'zanahoria': ('Verduras', 'Verduras de raíz', MeasurementUnit.unidades),
    'lechuga': ('Verduras', 'Verduras de hoja', MeasurementUnit.unidades),
    'ensalada': ('Verduras', 'Ensaladas y mezclas', MeasurementUnit.unidades),
    'brócoli': ('Verduras', 'Verduras de flor', MeasurementUnit.unidades),
    'brocoli': ('Verduras', 'Verduras de flor', MeasurementUnit.unidades),
    'espinaca': ('Verduras', 'Verduras de hoja', MeasurementUnit.g),
    'pimiento': ('Verduras', 'Verduras de fruto', MeasurementUnit.unidades),
    'ají': ('Verduras', 'Verduras picantes', MeasurementUnit.unidades),
    'aji': ('Verduras', 'Verduras picantes', MeasurementUnit.unidades),
    'choclo': ('Cereales y granos', 'Granos andinos', MeasurementUnit.unidades),
    'zapallo': ('Verduras', 'Verduras de fruto', MeasurementUnit.kg),
    'pepino': ('Verduras', 'Verduras de fruto', MeasurementUnit.unidades),
    'apio': ('Verduras', 'Verduras de tallo', MeasurementUnit.unidades),
    'perejil': ('Condimentos y especias', 'Hierbas', MeasurementUnit.sobre),
    'culantro': ('Condimentos y especias', 'Hierbas', MeasurementUnit.sobre),
    'cilantro': ('Condimentos y especias', 'Hierbas', MeasurementUnit.sobre),
    'kion': ('Condimentos y especias', 'Aromáticos', MeasurementUnit.g),
    'jengibre': ('Condimentos y especias', 'Aromáticos', MeasurementUnit.g),

    // ── Proteínas animales ──
    'pollo': ('Proteínas animales', 'Aves', MeasurementUnit.kg),
    'carne': ('Proteínas animales', 'Carnes rojas', MeasurementUnit.kg),
    'res': ('Proteínas animales', 'Carnes rojas', MeasurementUnit.kg),
    'cerdo': ('Proteínas animales', 'Carnes rojas', MeasurementUnit.kg),
    'pescado': ('Proteínas animales', 'Pescados', MeasurementUnit.kg),
    'atún': ('Proteínas animales', 'Pescados', MeasurementUnit.lata),
    'atun': ('Proteínas animales', 'Pescados', MeasurementUnit.lata),
    'huevo': ('Proteínas animales', 'Huevos', MeasurementUnit.unidades),
    'camarón': ('Proteínas animales', 'Mariscos', MeasurementUnit.kg),
    'camaron': ('Proteínas animales', 'Mariscos', MeasurementUnit.kg),
    'lenteja': ('Legumbres', 'Comunes', MeasurementUnit.g),
    'frijol': ('Legumbres', 'Frejoles', MeasurementUnit.g),
    'frejol': ('Legumbres', 'Frejoles', MeasurementUnit.g),
    'menestra': ('Legumbres', 'Menestras', MeasurementUnit.g),
    'pallar': ('Legumbres', 'Pallares', MeasurementUnit.g),
    'arveja': ('Legumbres', 'Comunes', MeasurementUnit.g),
    'alverja': ('Legumbres', 'Comunes', MeasurementUnit.g),
    'habas': ('Legumbres', 'Comunes', MeasurementUnit.g),
    'garbanzo': ('Legumbres', 'Comunes', MeasurementUnit.g),
    'tarwi': ('Legumbres', 'Andinas', MeasurementUnit.g),
    'pechuga': ('Proteínas animales', 'Aves', MeasurementUnit.unidades),
    'pierna': ('Proteínas animales', 'Aves', MeasurementUnit.unidades),
    'encuentro': ('Proteínas animales', 'Aves', MeasurementUnit.unidades),
    'ala': ('Proteínas animales', 'Aves', MeasurementUnit.unidades),
    'camote': ('Tubérculos y raíces', 'Tubérculos andinos', MeasurementUnit.kg),
    'yuca': ('Tubérculos y raíces', 'Raíces', MeasurementUnit.kg),
    'chorizo': ('Proteínas animales', 'Embutidos', MeasurementUnit.unidades),
    'jamón': ('Proteínas animales', 'Embutidos', MeasurementUnit.g),
    'jamon': ('Proteínas animales', 'Embutidos', MeasurementUnit.g),
    'tocino': ('Proteínas animales', 'Embutidos', MeasurementUnit.g),
    'salchicha': ('Proteínas animales', 'Embutidos', MeasurementUnit.paquete),

    // ── Lácteos ──
    'leche': ('Lácteos', 'Leche', MeasurementUnit.litro),
    'queso': ('Lácteos', 'Quesos', MeasurementUnit.g),
    'yogur': ('Lácteos', 'Fermentados', MeasurementUnit.unidades),
    'yogurt': ('Lácteos', 'Fermentados', MeasurementUnit.unidades),
    'crema': ('Lácteos', 'Grasas lácteas', MeasurementUnit.ml),
    'mantequilla': ('Lácteos', 'Grasas lácteas', MeasurementUnit.g),
    'nata': ('Lácteos', 'Grasas lácteas', MeasurementUnit.ml),

    // ── Cereales/Granos ──
    'arroz': ('Cereales y granos', 'Tradicionales', MeasurementUnit.kg),
    'fideo': ('Harinas y derivados', 'Pastas', MeasurementUnit.paquete),
    'pasta': ('Harinas y derivados', 'Pastas', MeasurementUnit.paquete),
    'pan': ('Harinas y derivados', 'Panadería', MeasurementUnit.unidades),
    'avena': ('Cereales y granos', 'Granos procesados', MeasurementUnit.g),
    'harina': ('Harinas y derivados', 'Harinas', MeasurementUnit.kg),
    'quinua': ('Cereales y granos', 'Granos andinos', MeasurementUnit.g),
    'trigo': ('Cereales y granos', 'Tradicionales', MeasurementUnit.kg),
    'maíz': ('Cereales y granos', 'Tradicionales', MeasurementUnit.kg),
    'maiz': ('Cereales y granos', 'Tradicionales', MeasurementUnit.kg),

    // ── Condimentos ──
    'sal': ('Condimentos y especias', 'Especias', MeasurementUnit.g),
    'azúcar': ('Endulzantes', 'Refinados', MeasurementUnit.kg),
    'azucar': ('Endulzantes', 'Refinados', MeasurementUnit.kg),
    'pimienta': ('Condimentos y especias', 'Especias', MeasurementUnit.sobre),
    'comino': ('Condimentos y especias', 'Especias', MeasurementUnit.sobre),
    'orégano': ('Condimentos y especias', 'Hierbas', MeasurementUnit.sobre),
    'oregano': ('Condimentos y especias', 'Hierbas', MeasurementUnit.sobre),
    'canela': ('Condimentos y especias', 'Especias', MeasurementUnit.sobre),
    'sillao': ('Salsas', 'Fermentadas', MeasurementUnit.botella),
    'soya': ('Salsas', 'Fermentadas', MeasurementUnit.botella),
    'vinagre': ('Condimentos y especias', 'Líquidos', MeasurementUnit.botella),
    'mostaza': ('Salsas', 'Frías', MeasurementUnit.botella),
    'ketchup': ('Salsas', 'Frías', MeasurementUnit.botella),
    'mayonesa': ('Salsas', 'Frías', MeasurementUnit.botella),
    'sazonador': ('Condimentos y especias', 'Mezclas', MeasurementUnit.sobre),
    'ajinomoto': ('Condimentos y especias', 'Sales', MeasurementUnit.sobre),

    // ── Aceites ──
    'aceite': ('Aceites y grasas', 'Vegetales', MeasurementUnit.botella),
    'oliva': ('Aceites y grasas', 'Vegetales', MeasurementUnit.botella),
    'manteca': ('Aceites y grasas', 'Sólidas', MeasurementUnit.g),
    'margarina': ('Aceites y grasas', 'Sólidas', MeasurementUnit.g),

    // ── Snacks y dulces (para seguimiento nutricional en FoodCoach) ──
    'galleta': ('Snacks y dulces', 'Galletas', MeasurementUnit.paquete),
    'chocolate': ('Snacks y dulces', 'Chocolates', MeasurementUnit.unidades),
    'helado': ('Snacks y dulces', 'Helados', MeasurementUnit.unidades),
    'barrita': ('Snacks y dulces', 'Snacks', MeasurementUnit.unidades),
    'cereal': ('Snacks y dulces', 'Cereales', MeasurementUnit.paquete),
    'wafer': ('Snacks y dulces', 'Galletas', MeasurementUnit.paquete),
    'brownie': ('Snacks y dulces', 'Postres', MeasurementUnit.unidades),
    'queque': ('Snacks y dulces', 'Postres', MeasurementUnit.unidades),
    'turron': ('Snacks y dulces', 'Dulces', MeasurementUnit.unidades),
    'caramelo': ('Snacks y dulces', 'Dulces', MeasurementUnit.paquete),
    'gomita': ('Snacks y dulces', 'Dulces', MeasurementUnit.paquete),
    'piqueo': ('Snacks y dulces', 'Snacks salados', MeasurementUnit.paquete),
    'chifle': ('Snacks y dulces', 'Snacks salados', MeasurementUnit.paquete),
    'canchita': ('Snacks y dulces', 'Snacks salados', MeasurementUnit.paquete),
    'papas fritas': (
      'Snacks y dulces',
      'Snacks salados',
      MeasurementUnit.paquete
    ),
    'mani': ('Snacks y dulces', 'Frutos secos', MeasurementUnit.paquete),
    'almendra': ('Snacks y dulces', 'Frutos secos', MeasurementUnit.g),
    'nuez': ('Snacks y dulces', 'Frutos secos', MeasurementUnit.g),
    'pasas': ('Frutas', 'Frutos secos', MeasurementUnit.g),

    // ── Bebidas ──
    'agua': ('Otros', 'Bebidas', MeasurementUnit.litro),
    'jugo': ('Otros', 'Bebidas', MeasurementUnit.litro),
    'manzanilla': ('Otros', 'Infusiones', MeasurementUnit.sobre),
    'cerveza': ('Otros', 'Bebidas alcohólicas', MeasurementUnit.lata),
    'vino': ('Otros', 'Bebidas alcohólicas', MeasurementUnit.botella),
    'gaseosa': ('Otros', 'Bebidas carbonatadas', MeasurementUnit.botella),
    'café': ('Otros', 'Infusiones', MeasurementUnit.sobre),
    'cafe': ('Otros', 'Infusiones', MeasurementUnit.sobre),
    'té': ('Otros', 'Infusiones', MeasurementUnit.sobre),
    'te': ('Otros', 'Infusiones', MeasurementUnit.sobre),

    // ── Enlatados ──
    'conserva': ('Otros', 'Conservas', MeasurementUnit.lata),
    'sardina': (
      'Proteínas animales',
      'Pescados enlatados',
      MeasurementUnit.lata
    ),
    'leche evaporada': ('Lácteos', 'Leche procesada', MeasurementUnit.lata),
    'leche condensada': ('Lácteos', 'Leche procesada', MeasurementUnit.lata),
  };
}
