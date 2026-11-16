import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../entities/inventory_ingredient.dart';
import '../entities/recipe.dart';
import '../entities/chef_preferences.dart';
import '../repositories/i_ai_recipe_extractor.dart';
import '../../utils/ai_json_parser.dart';
import 'extract_recipe_use_case.dart';

/// Suggestion mode: what type of recipes to suggest
enum SuggestionMode {
  /// Quick suggestions - mix of everything based on inventory
  now('¿Qué como ahora?'),

  /// Full menu - suggests multiple courses
  menu('Armar Menú'),

  /// Just cravings - snacks, desserts, drinks (time-independent)
  cravings('Antojos');

  final String label;
  const SuggestionMode(this.label);
}

/// Use case that uses Gemini AI to suggest recipes based on available inventory
/// Returns a list of recipe suggestions with full details
class WhatCanICookUseCase {
  final IAIRecipeExtractor aiExtractor;

  WhatCanICookUseCase(this.aiExtractor);

  Future<List<RecipeSuggestion>> execute({
    required List<InventoryIngredient> inventory,
    int maxSuggestions = 5,
    List<String>? dislikedIngredients,
    List<String>? preferredCuisines,
    String? cuisinePreference,
    List<String>? recentlyUsedRecipeNames, // Recipes used in last 7 days
    SuggestionMode mode = SuggestionMode.now,
    ChefPreferences? userPreferences,
  }) async {
    if (inventory.isEmpty) {
      throw Exception(
          'No tienes ingredientes en tu inventario. Agrega algunos primero.');
    }

    // Build inventory description for AI
    final inventoryDescription = inventory.map((item) {
      return '- ${item.name}: ${item.quantity} ${item.unit}${item.preparation.isNotEmpty ? ' (${item.preparation})' : ''}';
    }).join('\n');

    // Build disliked ingredients warning
    String dislikedWarning = '';
    if (dislikedIngredients != null && dislikedIngredients.isNotEmpty) {
      dislikedWarning = '''
⛔ INGREDIENTES QUE EL USUARIO NO LE GUSTAN (NO USAR EN LAS RECETAS):
${dislikedIngredients.map((e) => '- $e').join('\n')}

Si una receta normalmente usa estos ingredientes, SUSTITUYELOS por algo similar que el usuario sí quiera.
Ejemplo: si no le gusta la cebolla, usa cebollín o ajo en su lugar.
''';
    }

    // Build cuisine preference
    String cuisineContext = '';
    if (cuisinePreference != null && cuisinePreference.isNotEmpty) {
      cuisineContext = '''
🌍 PREFERENCIA CULINARIA DEL USUARIO: "$cuisinePreference"
El usuario quiere probar comida de este estilo. Prioriza recetas de esta cocina.
Ejemplos: Peruana-sierra, Peruana-selva, Peruana-costa, Italiana, Mexicana, Asiática, etc.
''';
    } else if (preferredCuisines != null && preferredCuisines.isNotEmpty) {
      cuisineContext = '''
🌍 ESTILOS DE COCINA PREFERIDOS DEL USUARIO:
${preferredCuisines.map((e) => '- $e').join('\n')}
Prioriza estos estilos culinarios en las sugerencias.
''';
    }

    // Build recently used recipes warning (week variety)
    String recentlyUsedWarning = '';
    if (recentlyUsedRecipeNames != null && recentlyUsedRecipeNames.isNotEmpty) {
      recentlyUsedWarning = '''
📅 RECETAS USADAS RECIENTEMENTE (últimos 7 días) - NO REPETIR:
${recentlyUsedRecipeNames.map((e) => '- $e').join('\n')}

⚠️ IMPORTANTE: NO sugieras estas recetas nuevamente esta semana. El usuario quiere variedad.
Sugiere recetas DIFERENTES y CREÁTIVAS que no estén en esta lista.
''';
    }

    // Build mode-specific instructions
    String modeContext = '';
    switch (mode) {
      case SuggestionMode.now:
        modeContext = '''
🎯 MODO: "¿Qué como ahora?"
Sugiere $maxSuggestions recetas VARIADAS mezclando diferentes tipos de plato.
Incluye: platos fuertes, sopas, entradas, postres, bebidas, snacks.
El usuario quiere ver opciones diversas para decidir qué cocinar AHORA.
''';
      case SuggestionMode.menu:
        modeContext = '''
📋 MODO: "Armar Menú Completo"
Sugiere $maxSuggestions MENÚS COMPLETOS. Cada menú debe tener TODOS estos platos:

MENÚ TIPO (ejemplo para $maxSuggestions menús):
Menú 1:
  • Entrada: [nombre de la entrada]
  • Sopa: [nombre de la sopa]
  • Plato fuerte (Segundo): [nombre del plato principal]
  • Bebida/Refresco: [nombre de la bebida]

Menú 2:
  • Entrada: [otra entrada diferente]
  • Sopa: [otra sopa diferente]
  • Plato fuerte: [otro plato principal]
  • Bebida: [otra bebida]

REGLAS IMPORTANTES:
1. Cada menú debe ser diferente (NO repetir recetas entre menús)
2. Todos los platos deben usar los ingredientes disponibles
3. Sé creativo con las combinaciones
4. Para CADA plato del menú, incluye TODOS los campos obligatorios
5. El "tipo_comida" de cada plato debe ser: "Entrada", "Sopa", "Almuerzo" (para el segundo), "Bebida"

DEVUELVE un array con TODOS los platos de los $maxSuggestions menús completos.
Ejemplo: si $maxSuggestions=4, devolverás 16 recetas (4 menús x 4 platos cada uno).
''';
      case SuggestionMode.cravings:
        modeContext = '''
🍫 MODO: "Antojos"
Sugiere $maxSuggestions recetas SOLO de estos tipos:
- Postres (🍰): tortas, flanes, mazamorras, gelatinas
- Snacks/Botanas (🍿): canchas, papas rellenas, tequeños, empanadas
- Bebidas (🥤): jugos, chicha, limonadas, emoliente, smoothies
- Acompañamientos: sarsa criolla, guacamole, etc.
NO sugieras platos fuertes, sopas ni entradas en este modo.
Estos antojos son INDEPENDIENTES de la hora del día.
''';
    }

    // Build user preferences context (optional)
    final userPrefsContext = _buildUserPrefsContext(userPreferences);

    final prompt = '''
👨‍🍳 ERES UN CHEF PROFESIONAL ESPECIALIZADO EN COCINA DE APROVECHAMIENTO.

📋 TU MISIÓN:
El usuario tiene estos ingredientes disponibles en su cocina/inventario:

$inventoryDescription

Basándote en estos ingredientes, sugiere $maxSuggestions recetas REALISTAS y ATRACTIVAS que pueda cocinar AHORA MISMO.

🔍 REGLAS IMPORTANTES:
1. Usa SOLAMENTE los ingredientes disponibles (o la mayoría de ellos)
2. Puedes sugerir ingredientes adicionales mínimos que todo mundo tiene (aceite, sal, pimienta, agua)
3. Cada receta debe ser diferente y creativa
4. Prioriza recetas que usen ingredientes que están por vencer
5. Sé específico con cantidades y pasos
6. CADA receta DEBE tener AL MENOS 3 ingredientes reales y 3 pasos.
7. Para CADA receta incluye "cuisine_style" (ej: "Peruana-sierra", "Peruana-costa", "Italiana").

📝 FORMATO DE SALIDA (JSON PURO - SIN MARKDOWN):
Devuelve un único objeto JSON con clave "recetas":
{
  "recetas": [
    {
      "nombre_receta": "Arroz chaufa sencillo",
      "descripcion": "Arroz chaufa peruano con huevo y cebollita china",
      "porciones": 4,
      "tiempo_preparacion_min": 10,
      "tiempo_coccion_min": 20,
      "tiempo_total_min": 30,
      "dificultad": "Fácil",
      "tipo_comida": "seco",
      "cocina": "Peruana",
      "cuisine_style": "Peruana-costa",
      "ingredientes": [
        {"nombre": "Arroz", "cantidad": 2, "unidad": "tazas"},
        {"nombre": "Huevo", "cantidad": 3, "unidad": "unidades"},
        {"nombre": "Cebolla china", "cantidad": 2, "unidad": "unidades"}
      ],
      "ingredientes_inferidos": ["aceite", "sal", "salsa de soya"],
      "pasos": [
        {"numero": 1, "descripcion": "Calentar el wok a fuego alto con un poco de aceite"},
        {"numero": 2, "descripcion": "Agregar los huevos batidos y revolver"},
        {"numero": 3, "descripcion": "Añadir el arroz salteado y mezclar todo"}
      ],
      "utensilios": ["wok", "cuchara de madera"],
      "calorias_aproximadas": 350,
      "tags": ["fácil", "peruano", "rápido"]
    }
  ]
}

${cuisineContext.isNotEmpty ? cuisineContext : ''}
${dislikedWarning.isNotEmpty ? dislikedWarning : ''}
${recentlyUsedWarning.isNotEmpty ? recentlyUsedWarning : ''}
${modeContext.isNotEmpty ? modeContext : ''}
${userPrefsContext.isNotEmpty ? userPrefsContext : ''}

🍳 AHORA DEVUELVE SOLAMENTE EL OBJETO JSON:{"recetas": [...]}''';

    try {
      final jsonString = await aiExtractor.extractRecipeJson(
        textContext: prompt,
        mediaPath: null,
      );

      if (jsonString == null || jsonString.isEmpty) {
        throw Exception('La IA no pudo generar sugerencias');
      }

      final parsedEntries = _decodeSuggestionPayload(jsonString);
      final suggestions = <RecipeSuggestion>[];
      for (final entry in parsedEntries) {
        final parsed = _parseSuggestionEntry(
          entry.recipeMap,
          suggestions.length,
          menuNumber: entry.menuNumber,
        );
        if (parsed != null) suggestions.add(parsed);
      }

      if (suggestions.isEmpty) {
        throw Exception(
            'La IA no devolvió recetas válidas con tus ingredientes actuales.');
      }

      return suggestions;
    } catch (e, stackTrace) {
      debugPrint('❌ Error in WhatCanICookUseCase: $e');
      debugPrint('📋 Stack trace: $stackTrace');
      throw Exception('Error al generar sugerencias con IA: $e');
    }
  }

  /// Decodifica respuestas tanto en formato `{"menus": [...]}` como `{"recetas": [...]}` o `[...]`.
  List<({Map<String, dynamic> recipeMap, int? menuNumber})>
      _decodeSuggestionPayload(String jsonString) {
    dynamic decoded;
    final candidates = [
      _extractJsonFromResponse(jsonString, expectList: false),
      _extractJsonFromResponse(jsonString, expectList: true),
      _aggressiveJsonClean(jsonString),
      _bruteForceJsonExtract(jsonString),
    ];

    bool parseSuccess = false;
    for (final attempt in candidates) {
      if (attempt.trim().length < 2) continue;
      try {
        decoded = jsonDecode(attempt);
        parseSuccess = true;
        break;
      } catch (_) {}
    }

    if (!parseSuccess) {
      throw Exception(
        'La IA devolvió un formato inválido.\n\n'
        'Consejos para mejores resultados:\n'
        '• Ten al menos 5-7 ingredientes en tu despensa\n'
        '• Incluye ingredientes variados\n'
        '• Toca "Regenerar" para probar de nuevo',
      );
    }

    final results = <({Map<String, dynamic> recipeMap, int? menuNumber})>[];

    if (decoded is Map) {
      final root = Map<String, dynamic>.from(decoded);
      if (root['menus'] is List) {
        final menus = root['menus'] as List;
        for (int mIdx = 0; mIdx < menus.length; mIdx++) {
          final menuItem = menus[mIdx];
          if (menuItem is! Map) continue;
          final menuMap = Map<String, dynamic>.from(menuItem);
          final menuNum =
              (menuMap['menu_numero'] as num?)?.toInt() ?? (mIdx + 1);
          final platos = menuMap['platos'] ?? menuMap['recetas'];
          if (platos is List) {
            for (final plato in platos) {
              if (plato is Map) {
                results.add((
                  recipeMap: Map<String, dynamic>.from(plato),
                  menuNumber: menuNum,
                ));
              }
            }
          } else if (menuMap.containsKey('nombre_receta')) {
            results.add((recipeMap: menuMap, menuNumber: menuNum));
          }
        }
        return results;
      }

      final listField =
          root['recetas'] ?? root['recipes'] ?? root['suggestions'];
      if (listField is List) {
        for (final item in listField) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            results.add((
              recipeMap: map,
              menuNumber: (map['menu_numero'] as num?)?.toInt(),
            ));
          }
        }
        return results;
      }

      results.add((
        recipeMap: root,
        menuNumber: (root['menu_numero'] as num?)?.toInt(),
      ));
      return results;
    }

    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          results.add((
            recipeMap: map,
            menuNumber: (map['menu_numero'] as num?)?.toInt(),
          ));
        }
      }
      return results;
    }

    throw Exception('Formato inesperado de la IA (${decoded.runtimeType}).');
  }

  RecipeSuggestion? _parseSuggestionEntry(
    Map<String, dynamic> recipeData,
    int index, {
    int? menuNumber,
  }) {
    final name = recipeData['nombre_receta']?.toString().trim();
    if (name == null || name.isEmpty) return null;

    final description = recipeData['descripcion']?.toString() ?? '';
    final rawTiempo = recipeData['tiempo_total_min'];
    final tiempoTotal = rawTiempo is num
        ? rawTiempo.round()
        : (rawTiempo is String ? int.tryParse(rawTiempo) ?? 30 : 30);
    final rawPorciones = recipeData['porciones'];
    final porciones = rawPorciones is num
        ? rawPorciones.round()
        : (rawPorciones is String ? int.tryParse(rawPorciones) ?? 2 : 2);
    final ingredientesDisponibles =
        (recipeData['ingredientes_disponibles'] as num?)?.toInt() ?? 0;
    final ingredientesTotales =
        (recipeData['ingredientes_totales'] as num?)?.toInt() ?? 0;

    final ingredients = <RecipeIngredient>[];
    final recipeId = 'ai_${DateTime.now().microsecondsSinceEpoch}_$index';
    final rawIngField = recipeData['ingredientes'];
    final rawIngredients = rawIngField is List ? rawIngField : const [];

    for (int i = 0; i < rawIngredients.length; i++) {
      final rawItem = rawIngredients[i];
      if (rawItem is String && rawItem.trim().isNotEmpty) {
        ingredients.add(RecipeIngredient(
          id: '${recipeId}_ing_$i',
          recipeId: recipeId,
          ingredientName: rawItem.trim(),
          quantity: 1.0,
          unit: 'unidades',
        ));
        continue;
      }
      if (rawItem is! Map) continue;
      final item = Map<String, dynamic>.from(rawItem);
      final ingName = item['nombre']?.toString().trim() ?? 'Ingrediente $i';
      final rawQty = item['cantidad'];
      final qty = rawQty is num
          ? rawQty.toDouble()
          : (rawQty is String
              ? double.tryParse(rawQty.replaceAll(',', '.')) ?? 1.0
              : 1.0);
      final unit = item['unidad']?.toString() ?? 'unidades';

      ingredients.add(RecipeIngredient(
        id: '${recipeId}_ing_$i',
        recipeId: recipeId,
        ingredientName: ingName,
        quantity: qty,
        unit: unit,
      ));
    }

    if (ingredients.length < 2) {
      debugPrint('⚠️ Skipping empty recipe: $name');
      return null;
    }

    final steps = <String>[];
    final rawStepsField = recipeData['pasos'];
    final rawSteps = rawStepsField is List ? rawStepsField : const [];
    final mapSteps = <Map<String, dynamic>>[];
    final stringSteps = <String>[];

    for (final s in rawSteps) {
      if (s is Map) {
        mapSteps.add(Map<String, dynamic>.from(s));
      } else if (s != null && s.toString().trim().isNotEmpty) {
        stringSteps.add(s.toString().trim());
      }
    }

    if (mapSteps.isNotEmpty) {
      mapSteps.sort((a, b) {
        final numA = (a['numero'] as num?)?.toInt() ?? 0;
        final numB = (b['numero'] as num?)?.toInt() ?? 0;
        return numA.compareTo(numB);
      });
      for (final step in mapSteps) {
        final desc = step['descripcion']?.toString().trim() ?? '';
        if (desc.isNotEmpty) steps.add(desc);
      }
    } else {
      steps.addAll(stringSteps);
    }

    final rawTags = recipeData['tags'];
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString()).toList()
        : const <String>[];

    final rawUtensilios = recipeData['utensilios'];
    final utensilios = rawUtensilios is List
        ? rawUtensilios.map((e) => e.toString()).toList()
        : const <String>[];

    final rawInferidos = recipeData['ingredientes_inferidos'];
    final ingredientesInferidos = rawInferidos is List
        ? rawInferidos.map((e) => e.toString()).toList()
        : const <String>[];

    final rawCal = recipeData['calorias_aproximadas'];
    final caloriasAproximadas = rawCal is num
        ? rawCal.round()
        : (rawCal is String ? int.tryParse(rawCal) : null);

    final tipoComidaStr = recipeData['tipo_comida']?.toString();
    final mealType = tipoComidaStr != null
        ? ExtractRecipeUseCase.parseMealType(tipoComidaStr)
        : null;

    final recipe = Recipe(
      id: recipeId,
      name: name,
      description: description,
      durationMinutes: tiempoTotal,
      servings: porciones,
      instructions: steps,
      ingredients: ingredients,
      tags: tags,
      createdAt: DateTime.now(),
      utensilios: utensilios,
      ingredientesInferidos: ingredientesInferidos,
      caloriasAproximadas: caloriasAproximadas,
      tipoComida: mealType,
    );

    return RecipeSuggestion(
      recipe: recipe,
      matchPercentage: ingredientesTotales > 0
          ? ((ingredientesDisponibles / ingredientesTotales) * 100).round()
          : 0,
      missingIngredients:
          (ingredientesTotales - ingredientesDisponibles).clamp(0, 999),
      menuNumber: menuNumber,
    );
  }

  /// Robustly extracts JSON from a response string
  String _extractJsonFromResponse(String response, {bool expectList = false}) =>
      AiJsonParser.extractJson(response, expectList: expectList);

  /// Aggressive JSON cleaning for when normal extraction fails
  String _aggressiveJsonClean(String response) {
    final text = AiJsonParser.stripMarkdownFences(response);
    final candidate = AiJsonParser.extractJson(text, expectList: true);
    final trailingNewline = candidate.indexOf('\n]');
    if (trailingNewline != -1) {
      return candidate.substring(0, candidate.lastIndexOf(']') + 1);
    }
    return candidate;
  }

  /// Brute force: finds the outermost matching bracket/brace pair
  String _bruteForceJsonExtract(String text) {
    // Strip fence markers without deleting JSON content inside
    text = text.replaceAll(RegExp(r'```(?:json)?', caseSensitive: false), '');
    text = text.replaceAll('```', '');

    // Try to find matching brackets for arrays
    for (int start = 0; start < text.length; start++) {
      if (text[start] == '[') {
        int depth = 0;
        bool inString = false;
        bool escaped = false;
        for (int end = start; end < text.length; end++) {
          final char = text[end];
          if (escaped) {
            escaped = false;
            continue;
          }
          if (char == '\\') {
            escaped = true;
            continue;
          }
          if (char == '"') {
            inString = !inString;
            continue;
          }
          if (inString) continue;
          if (char == '[') depth++;
          if (char == ']') {
            depth--;
            if (depth == 0) {
              return text.substring(start, end + 1);
            }
          }
        }
      }
    }

    // Try to find matching braces for objects
    for (int start = 0; start < text.length; start++) {
      if (text[start] == '{') {
        int depth = 0;
        bool inString = false;
        bool escaped = false;
        for (int end = start; end < text.length; end++) {
          final char = text[end];
          if (escaped) {
            escaped = false;
            continue;
          }
          if (char == '\\') {
            escaped = true;
            continue;
          }
          if (char == '"') {
            inString = !inString;
            continue;
          }
          if (inString) continue;
          if (char == '{') depth++;
          if (char == '}') {
            depth--;
            if (depth == 0) {
              return text.substring(start, end + 1);
            }
          }
        }
      }
    }

    return text;
  }

  /// NEW: Execute with personalized menu components (loteado automático y objeto JSON).
  Future<List<RecipeSuggestion>> executeWithMenu({
    required List<InventoryIngredient> inventory,
    required dynamic mealPeriod, // MealPeriod enum
    required List<dynamic> components, // List<MenuComponent>
    required int menuCount,
    List<String>? dislikedIngredients,
    String? cuisinePreference,
    List<String>? recentlyUsedRecipeNames,
    ChefPreferences? userPreferences,
    bool budgetSaverMode = false,
  }) async {
    if (inventory.isEmpty) {
      throw Exception(
          'No tienes ingredientes en tu inventario. Agrega algunos primero.');
    }

    final safeComponents =
        components.isNotEmpty ? components : const ['platoFuerte'];
    final safeMenuCount = menuCount.clamp(1, 5);
    final totalRecipes = safeMenuCount * safeComponents.length;

    // Si supera 6 recetas en una sola llamada, dividir en lotes de máximo 2 menús
    // para no truncar tokens ni superar timeouts.
    if (totalRecipes > 6 && safeMenuCount > 2) {
      final results = <RecipeSuggestion>[];
      final usedNames = <String>[...?recentlyUsedRecipeNames];
      int nextMenuIndex = 1;
      int remaining = safeMenuCount;

      while (remaining > 0) {
        final batchMenus = remaining >= 2 ? 2 : 1;
        final batch = await _executeMenuBatch(
          inventory: inventory,
          mealPeriod: mealPeriod,
          components: safeComponents,
          batchMenuCount: batchMenus,
          startMenuNumber: nextMenuIndex,
          dislikedIngredients: dislikedIngredients,
          cuisinePreference: cuisinePreference,
          recentlyUsedRecipeNames: usedNames,
          userPreferences: userPreferences,
          budgetSaverMode: budgetSaverMode,
        );
        for (final s in batch) {
          results.add(s);
          usedNames.add(s.recipe.name);
        }
        nextMenuIndex += batchMenus;
        remaining -= batchMenus;
      }
      return results;
    }

    return _executeMenuBatch(
      inventory: inventory,
      mealPeriod: mealPeriod,
      components: safeComponents,
      batchMenuCount: safeMenuCount,
      startMenuNumber: 1,
      dislikedIngredients: dislikedIngredients,
      cuisinePreference: cuisinePreference,
      recentlyUsedRecipeNames: recentlyUsedRecipeNames,
      userPreferences: userPreferences,
      budgetSaverMode: budgetSaverMode,
    );
  }

  Future<List<RecipeSuggestion>> _executeMenuBatch({
    required List<InventoryIngredient> inventory,
    required dynamic mealPeriod,
    required List<dynamic> components,
    required int batchMenuCount,
    required int startMenuNumber,
    List<String>? dislikedIngredients,
    String? cuisinePreference,
    List<String>? recentlyUsedRecipeNames,
    ChefPreferences? userPreferences,
    bool budgetSaverMode = false,
  }) async {
    final inventoryDescription = inventory.map((item) {
      return '- ${item.name}: ${item.quantity} ${item.unit}${item.preparation.isNotEmpty ? ' (${item.preparation})' : ''}';
    }).join('\n');

    final componentNames = components.map((c) {
      final label = c.toString().split('.').last;
      const componentMap = {
        'entrada': '🥗 Entrada',
        'sopa': '🍲 Sopa',
        'platoFuerte': '🥘 Plato Fuerte (seco/segundo)',
        'refresco': '🥤 Refresco/Bebida',
        'postre': '🍰 Postre',
      };
      return componentMap[label] ?? label;
    }).join(', ');

    final mealTypeNames = components.map((c) {
      final label = c.toString().split('.').last;
      const typeMap = {
        'entrada': 'entrada',
        'sopa': 'sopa',
        'platoFuerte': 'seco',
        'refresco': 'bebida',
        'postre': 'postre',
      };
      return typeMap[label] ?? 'seco';
    }).toSet();

    final mealTypeList = mealTypeNames.join(', ');
    final mealPeriodName = mealPeriod.toString().split('.').last;
    const mealPeriodEmoji = {
      'desayuno': '🌅',
      'almuerzo': '🍛',
      'cena': '🌙',
    };
    final emoji = mealPeriodEmoji[mealPeriodName] ?? '🍽️';

    String dinnerNote = '';
    if (mealPeriodName == 'cena') {
      dinnerNote = '''
🌙 IMPORTANTE: Es para la CENA. Sugiere platos LIGEROS y fáciles de digerir (sopas livianas, ensaladas, sandwiches, tortillas). Evita frituras o guisos muy pesados.
''';
    }

    String dislikedWarning = '';
    if (dislikedIngredients != null && dislikedIngredients.isNotEmpty) {
      dislikedWarning = '''
⛔ INGREDIENTES QUE NO LE GUSTAN AL USUARIO (NO USAR):
${dislikedIngredients.map((e) => '- $e').join('\n')}
''';
    }

    String cuisineContext = '';
    if (cuisinePreference != null && cuisinePreference.isNotEmpty) {
      cuisineContext = '''
🌍 PREFERENCIA CULINARIA: "$cuisinePreference". Prioriza recetas de esta cocina.
''';
    }

    String recentlyUsedWarning = '';
    if (recentlyUsedRecipeNames != null && recentlyUsedRecipeNames.isNotEmpty) {
      recentlyUsedWarning = '''
📅 RECETAS YA USADAS (NO REPETIR):
${recentlyUsedRecipeNames.take(12).map((e) => '- $e').join('\n')}
''';
    }

    final budgetNote = budgetSaverMode
        ? '💰 MODO AHORRO ACTIVO: Prioriza recetas económicas usando al máximo lo que ya existe en la despensa y minimizando ingredientes por comprar.\n'
        : '';

    final userPrefsContext = _buildUserPrefsContext(userPreferences);
    final endMenuNumber = startMenuNumber + batchMenuCount - 1;

    final prompt = '''
$emoji Chef peruano. Genera EXACTAMENTE $batchMenuCount menú(s) completo(s) numerado(s) del $startMenuNumber al $endMenuNumber para $mealPeriodName.
Cada menú DEBE incluir estos componentes en su lista "platos": $componentNames (tipos válidos: $mealTypeList).

INGREDIENTES DISPONIBLES EN DESPENSA:
$inventoryDescription

$dinnerNote$budgetNote$cuisineContext$dislikedWarning$recentlyUsedWarning$userPrefsContext
REGLAS:
- Recetas peruanas reales priorizando los ingredientes disponibles, SIN repetir platos.
- Cada plato DEBE tener mínimo 2 ingredientes reales y 3 pasos concisos.
- "tipo_comida" debe coincidir con: entrada, sopa, seco, postre, bebida, mazamorra, desayuno, almuerzo o cena.
- Devuelve ÚNICAMENTE un objeto JSON válido con clave "menus" (sin texto extra ni markdown).

FORMATO JSON EXACTO:
{
  "menus": [
    {
      "menu_numero": $startMenuNumber,
      "platos": [
        {
          "nombre_receta": "Nombre",
          "descripcion": "Descripción corta",
          "porciones": 4,
          "tiempo_preparacion_min": 10,
          "tiempo_coccion_min": 20,
          "tiempo_total_min": 30,
          "dificultad": "Fácil",
          "tipo_comida": "seco",
          "cocina": "Peruana",
          "cuisine_style": "Peruana",
          "ingredientes": [{"nombre": "Ingrediente", "cantidad": 1, "unidad": "unidades"}],
          "ingredientes_inferidos": ["sal", "aceite"],
          "pasos": [{"numero": 1, "descripcion": "Paso conciso"}],
          "utensilios": ["olla"],
          "calorias_aproximadas": 350,
          "tags": ["peruana"]
        }
      ]
    }
  ]
}''';

    try {
      final jsonString = await aiExtractor.extractRecipeJson(
        textContext: prompt,
        mediaPath: null,
      );

      if (jsonString == null || jsonString.isEmpty) {
        throw Exception('La IA no pudo generar sugerencias');
      }

      debugPrint('📄 executeWithMenu response (${jsonString.length} chars)');

      final parsedEntries = _decodeSuggestionPayload(jsonString);
      final suggestions = <RecipeSuggestion>[];
      for (final entry in parsedEntries) {
        final effectiveMenuNum = entry.menuNumber != null
            ? (entry.menuNumber! >= startMenuNumber
                ? entry.menuNumber!
                : startMenuNumber + entry.menuNumber! - 1)
            : startMenuNumber + (suggestions.length ~/ components.length);
        final parsed = _parseSuggestionEntry(
          entry.recipeMap,
          suggestions.length,
          menuNumber: effectiveMenuNum,
        );
        if (parsed != null) suggestions.add(parsed);
      }

      if (suggestions.isEmpty) {
        throw Exception(
            'La IA no encontró recetas válidas con tus ingredientes actuales.');
      }

      return suggestions;
    } catch (e, stackTrace) {
      debugPrint('❌ Error in executeWithMenu: $e');
      debugPrint('📋 Stack trace: $stackTrace');
      throw Exception('Error al generar sugerencias con IA: $e');
    }
  }

  String _buildUserPrefsContext(ChefPreferences? userPreferences) {
    if (userPreferences == null || !userPreferences.hasAnyPreferences) {
      return '';
    }
    final prefsParts = <String>[];
    if (userPreferences.favoriteCategories.isNotEmpty) {
      prefsParts.add(
          'Categorías favoritas: ${userPreferences.favoriteCategories.join(", ")}');
    }
    if (userPreferences.spiceLevel != null) {
      prefsParts.add('Nivel de picante: ${userPreferences.spiceLevel}');
    }
    if (userPreferences.portionSize != null) {
      prefsParts.add('Tamaño de porción: ${userPreferences.portionSize}');
    }
    if (userPreferences.typicalServings != null) {
      prefsParts
          .add('Porciones típicas: ${userPreferences.typicalServings} personas');
    }
    if (userPreferences.dietaryRestrictions.isNotEmpty) {
      prefsParts.add(
          'Restricciones: ${userPreferences.dietaryRestrictions.join(", ")}');
    }
    if (userPreferences.wantsSoup != null) {
      prefsParts.add(userPreferences.wantsSoup!
          ? 'Incluir sopa cuando aplique'
          : 'Evitar sopas');
    }
    if (userPreferences.wantsDessert != null) {
      prefsParts.add(userPreferences.wantsDessert!
          ? 'Incluir opción de postre'
          : 'Sin postre');
    }
    if (userPreferences.wantsDrink != null) {
      prefsParts.add(userPreferences.wantsDrink!
          ? 'Incluir bebida/refresco'
          : 'Sin bebida');
    }
    if (prefsParts.isEmpty) return '';
    return '''
👤 PREFERENCIAS PERSONALES DEL USUARIO:
${prefsParts.join('\n')}

Adapta las sugerencias a estas preferencias.
''';
  }
}

class RecipeSuggestion {
  final Recipe recipe;
  final int matchPercentage; // 0-100
  final int missingIngredients;
  final int? menuNumber;

  const RecipeSuggestion({
    required this.recipe,
    required this.matchPercentage,
    required this.missingIngredients,
    this.menuNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'recipe': recipe.toJson(),
      'matchPercentage': matchPercentage,
      'missingIngredients': missingIngredients,
      if (menuNumber != null) 'menuNumber': menuNumber,
    };
  }

  factory RecipeSuggestion.fromJson(Map<String, dynamic> json) {
    return RecipeSuggestion(
      recipe: Recipe.fromJson(json['recipe'] as Map<String, dynamic>),
      matchPercentage: (json['matchPercentage'] as num).toInt(),
      missingIngredients: (json['missingIngredients'] as num).toInt(),
      menuNumber: (json['menuNumber'] as num?)?.toInt(),
    );
  }
}
