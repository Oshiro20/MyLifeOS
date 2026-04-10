import 'dart:convert';
import 'dart:io';

const recetasDir = 'Recetas';
const outputFile = 'packages/core/assets/recipes/local_recipes.json';

final Map<String, String> categoriaToTipoComida = {
  'Entradas': 'entrada',
  'Sopas': 'sopa',
  'Segundos / Platos de Fondo': 'seco', // Plato fuerte = Seco
  'Postres': 'postre',
  'Postre': 'postre',
  'Bebidas': 'bebida',
};

final Map<String, String> regionToCuisineStyle = {
  'Selva': 'Peruana-selv\u00e1tica',
  'Costa': 'Peruana-coste\u00f1a',
  'Sierra': 'Peruana-serrana',
};

void main() async {
  final allRecipes = <Map<String, dynamic>>[];
  final recetasPath = Directory(recetasDir);

  if (!await recetasPath.exists()) {
    print('❌ Directorio $recetasDir no encontrado');
    return;
  }

  await for (final regionDir in recetasPath.list()) {
    if (regionDir is! Directory) continue;
    final regionName = regionDir.path.split(Platform.pathSeparator).last;
    print('\n📍 Procesando región: $regionName');

    await for (final file in regionDir.list()) {
      if (file is! File || !file.path.endsWith('.json')) continue;
      final fileName = file.path.split(Platform.pathSeparator).last;
      print('  📄 $fileName');

      final content = await file.readAsString();
      final recipes = _extractAllRecipes(content);
      print('    ✅ ${recipes.length} recetas extraídas');
      allRecipes.addAll(recipes);
    }
  }

  final outputDir = Directory(outputFile).parent;
  if (!await outputDir.exists()) await outputDir.create(recursive: true);

  final jsonString = JsonEncoder.withIndent('  ').convert(allRecipes);
  await File(outputFile).writeAsString(jsonString);

  print('\n✅ Total de recetas convertidas: ${allRecipes.length}');
  print('📁 Archivo guardado en: $outputFile');

  final stats = <String, int>{};
  for (final recipe in allRecipes) {
    final style = recipe['cuisineStyle'] as String? ?? 'Desconocido';
    stats[style] = (stats[style] ?? 0) + 1;
  }
  print('\n📊 Estadísticas por región:');
  stats.forEach((region, count) => print('  $region: $count recetas'));
}

List<Map<String, dynamic>> _extractAllRecipes(String content) {
  final allRecipes = <Map<String, dynamic>>[];
  String? categoria;
  String? region;

  var depth = 0;
  var start = 0;

  for (var i = 0; i < content.length; i++) {
    if (content[i] == '{') {
      if (depth == 0) start = i;
      depth++;
    } else if (content[i] == '}') {
      depth--;
      if (depth == 0) {
        final jsonStr = content.substring(start, i + 1);
        try {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          categoria ??= data['categoria'] as String?;
          region ??= data['region'] as String?;
          final recetas = data['recetas'] as List<dynamic>? ?? [];
          for (final receta in recetas) {
            allRecipes.add(_convertRecipe(
                receta as Map<String, dynamic>, categoria!, region!));
          }
        } catch (_) {}
      }
    }
  }
  return allRecipes;
}

Map<String, dynamic> _convertRecipe(
    Map<String, dynamic> r, String categoria, String region) {
  final tipoComida = categoriaToTipoComida[categoria] ?? 'otro';
  final cuisineStyle = regionToCuisineStyle[region];
  final rawIngredients = r['ingredientes'] as List<dynamic>? ?? [];
  final ingredients = <Map<String, dynamic>>[];
  for (final ing in rawIngredients)
    ingredients.add(_parseIngredient(ing.toString()));

  final tiempoStr = r['tiempo_preparacion'] as String? ?? '30 min';
  final durationMinutes =
      int.tryParse(RegExp(r'(\d+)').firstMatch(tiempoStr)?.group(1) ?? '30') ??
          30;

  return {
    'id': r['id'] ?? 'recipe_${DateTime.now().millisecondsSinceEpoch}',
    'name': r['nombre'] ?? 'Receta',
    'description': r['descripcion'] ?? '',
    'durationMinutes': durationMinutes,
    'servings': _parseServings(r['porciones']),
    'ingredients': ingredients,
    'instructions':
        (r['pasos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    'tags': [
      region.toLowerCase(),
      tipoComida,
      if (categoria.isNotEmpty) categoria.toLowerCase()
    ],
    'tipoComida': tipoComida,
    'cuisineStyle': cuisineStyle,
    'caloriasAproximadas': _estimateCalories(tipoComida),
  };
}

Map<String, dynamic> _parseIngredient(String ingStr) {
  final quantityMatch = RegExp(r'^([\d.,]+)\s*(.*)').firstMatch(ingStr.trim());
  if (quantityMatch != null) {
    final quantityStr = quantityMatch.group(1)!.replaceAll(',', '.');
    final quantity = double.tryParse(quantityStr) ?? 1.0;
    var rest = quantityMatch.group(2) ?? ingStr;
    final unitMatch = RegExp(
            r'^(tazas?|cucharadas?|cucharaditas?|dientes?|ramas?|unidad(?:es)?|g|kg|lb|litros?|ml|pu\u00f1ados?|lonjas?|rebanadas?|hojas?|paquetes?|latas?|pizcas?)\s+(.*)',
            caseSensitive: false)
        .firstMatch(rest.trim());
    if (unitMatch != null) {
      var unit = unitMatch.group(1)!.toLowerCase();
      if (unit.contains('cucharada'))
        unit = 'cucharadas';
      else if (unit.contains('cucharadita'))
        unit = 'cucharaditas';
      else if (unit.contains('taza'))
        unit = 'tazas';
      else if (unit.contains('diente'))
        unit = 'dientes';
      else if (unit.contains('rama'))
        unit = 'ramas';
      else if (unit.contains('unidad'))
        unit = 'unidades';
      else if (unit.contains('hoja'))
        unit = 'hojas';
      else if (unit.contains('lata')) unit = 'latas';
      return {
        'ingredientName': unitMatch.group(2)!.trim(),
        'quantity': quantity,
        'unit': unit
      };
    }
    return {
      'ingredientName': rest.trim(),
      'quantity': quantity,
      'unit': 'unidades'
    };
  }
  return {'ingredientName': ingStr.trim(), 'quantity': 1.0, 'unit': 'unidades'};
}

int _parseServings(dynamic porciones) {
  if (porciones is int) return porciones;
  if (porciones is String) {
    final match = RegExp(r'(\d+)').firstMatch(porciones);
    if (match != null) return int.parse(match.group(1)!);
  }
  return 4;
}

int _estimateCalories(String tipoComida) {
  switch (tipoComida) {
    case 'entrada':
      return 250;
    case 'sopa':
      return 300;
    case 'seco': // Plato fuerte
      return 450;
    case 'postre':
      return 250;
    case 'bebida':
      return 150;
    default:
      return 350;
  }
}
