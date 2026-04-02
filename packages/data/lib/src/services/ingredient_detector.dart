import 'package:domain/src/cocina/entities/ingredient.dart';
import 'package:domain/src/cocina/entities/ingredient_units.dart';

/// Resultado de detección automática de un ingrediente.
class IngredientSuggestion {
  final String? primaryCategory;
  final String? subCategory;
  final MeasurementUnit? suggestedUnit;

  const IngredientSuggestion({this.primaryCategory, this.subCategory, this.suggestedUnit});
}

/// Motor offline de detección de ingredientes basado en diccionarios.
class IngredientDetector {
  /// Detecta categoría y unidad sugerida a partir del nombre.
  static IngredientSuggestion detect(String name) {
    final lower = name.trim().toLowerCase();

    String? primary;
    String? sub;
    MeasurementUnit? unit;

    // Buscar en diccionario exacto primero
    for (final entry in _ingredients.entries) {
      if (lower.contains(entry.key)) {
        primary = entry.value.$1;
        sub = entry.value.$2;
        unit = entry.value.$3;
        break;
      }
    }

    // Fallback: buscar por categoría general
    primary ??= _guessCategory(lower);

    return IngredientSuggestion(primaryCategory: primary, subCategory: sub, suggestedUnit: unit);
  }

  static String? _guessCategory(String lower) {
    // Reglas generales
    if (lower.endsWith('a') && _fruitSuffix.any((s) => lower.contains(s))) {
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
    'cebolla': ('Condimentos y especias', 'Aromáticos', MeasurementUnit.unidades),
    'ajo': ('Condimentos y especias', 'Aromáticos', MeasurementUnit.unidades),
    'papa': ('Tubérculos y raíces', 'Tubérculos andinos', MeasurementUnit.kg),
    'zanahoria': ('Verduras', 'Verduras de raíz', MeasurementUnit.unidades),
    'lechuga': ('Verduras', 'Verduras de hoja', MeasurementUnit.unidades),
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
    'garbanzo': ('Legumbres', 'Comunes', MeasurementUnit.g),
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

    // ── Bebidas ──
    'agua': ('Otros', 'Bebidas', MeasurementUnit.litro),
    'jugo': ('Otros', 'Bebidas', MeasurementUnit.litro),
    'cerveza': ('Otros', 'Bebidas alcohólicas', MeasurementUnit.lata),
    'vino': ('Otros', 'Bebidas alcohólicas', MeasurementUnit.botella),
    'gaseosa': ('Otros', 'Bebidas carbonatadas', MeasurementUnit.botella),
    'café': ('Otros', 'Infusiones', MeasurementUnit.g),
    'cafe': ('Otros', 'Infusiones', MeasurementUnit.g),
    'té': ('Otros', 'Infusiones', MeasurementUnit.caja),

    // ── Enlatados ──
    'conserva': ('Otros', 'Conservas', MeasurementUnit.lata),
    'sardina': ('Proteínas animales', 'Pescados enlatados', MeasurementUnit.lata),
    'leche evaporada': ('Lácteos', 'Leche procesada', MeasurementUnit.lata),
    'leche condensada': ('Lácteos', 'Leche procesada', MeasurementUnit.lata),
  };
}
