import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../entities/inventory_ingredient.dart';
import '../entities/recipe.dart';
import '../entities/chef_preferences.dart';
import '../repositories/i_ai_recipe_extractor.dart';

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
    String userPrefsContext = '';
    if (userPreferences != null && userPreferences.hasAnyPreferences) {
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
        prefsParts.add(
            'Porciones típicas: ${userPreferences.typicalServings} personas');
      }
      if (userPreferences.dietaryRestrictions.isNotEmpty) {
        prefsParts.add(
            'Restricciones: ${userPreferences.dietaryRestrictions.join(", ")}');
      }
      if (prefsParts.isNotEmpty) {
        userPrefsContext = '''
👤 PREFERENCIAS PERSONALES DEL USUARIO:
${prefsParts.join('\n')}

Adapta las sugerencias a estas preferencias.
''';
      }
    }

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
6. ⚠️ IMPORTANTE: CADA receta DEBE tener AL MENOS 3 ingredientes reales en el array "ingredientes". NO devuelvas recetas vacías o sin ingredientes.
7. Variedad: Incluye diferentes tipos de plato. DEBES mezclar entre:
   - Postres (🍰): tortas, flanes, mazamorras, gelatinas
   - Entradas (🥗): ceviches, ensaladas, causa, tiraditos
   - Sopas (🍲): caldos, cremas, aguaditos
   - Platos fuertes (🍛): arroces, tallarines, carnes
   - Bebidas (🥤): jugos, chicha, limonadas, emolientes
   - Snacks (🍿): botanas, pasabocas
8. Para CADA receta incluye "cuisine_style" con el estilo de cocina (ej: "Peruana-sierra", "Italiana", "Selvática")

📝 FORMATO DE SALIDA (JSON PURO - SIN MARKDOWN):
IMPORTANTE: Devuelve SOLAMENTE el array JSON. Sin texto antes ni después. Sin backticks de markdown.

[
  {
    "nombre_receta": "Arroz chaufa sencillo",
    "descripcion": "Delicioso arroz chaufa peruano con huevo y cebollita china",
    "porciones": 4,
    "tiempo_preparacion_min": 10,
    "tiempo_coccion_min": 20,
    "tiempo_total_min": 30,
    "dificultad": "Fácil",
    "tipo_comida": "Almuerzo",
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
    "tags": ["fácil", "peruano", "rápido"],
    "ingredientes_disponibles": 8,
    "ingredientes_totales": 10,
    "nivel_confianza": "Alto",
    "observaciones": "Puedes cocinar esto ahora con lo que tienes"
  }
]

⚠️ REGLAS OBLIGATORIAS PARA EL JSON:
1. El resultado DEBE ser un array JSON válido que empieza con [ y termina con ]
2. NO incluyas texto fuera del array JSON
3. NO uses backticks (```) ni markdown
4. TODOS los campos son obligatorios en cada receta
5. "cantidad" debe ser NÚMERO (ej: 2, 1.5, 0.25)
6. "unidad" en ESPAÑOL (ej: "tazas", "unidades", "gramos")
7. "ingredientes": array con AL MENOS 3 ingredientes
8. "pasos": array con AL MENOS 3 pasos
9. "tiempo_total_min": número realista entre 15 y 180
10. "porciones": número entero entre 1 y 12
11. NO uses ingredientes que el usuario no le gustan. Si son esenciales, sustitúyelos.
12. Incluye "cuisine_style" con el estilo de cocina

${cuisineContext.isNotEmpty ? cuisineContext : ''}
${dislikedWarning.isNotEmpty ? dislikedWarning : ''}
${recentlyUsedWarning.isNotEmpty ? recentlyUsedWarning : ''}
${modeContext.isNotEmpty ? modeContext : ''}
${userPrefsContext.isNotEmpty ? userPrefsContext : ''}

🍳 AHORA DEVUELVE SOLAMENTE EL ARRAY JSON CON LAS $maxSuggestions RECETAS:''';

    try {
      final jsonString = await aiExtractor.extractRecipeJson(
        textContext: prompt,
        mediaPath: null,
      );

      if (jsonString == null || jsonString.isEmpty) {
        throw Exception('La IA no pudo generar sugerencias');
      }

      // Debug: log raw response
      debugPrint('📄 WhatCanICook raw response (${jsonString.length} chars)');
      if (jsonString.length < 1000) {
        debugPrint('📄 Full: $jsonString');
      } else {
        debugPrint('📄 First 1000: ${jsonString.substring(0, 1000)}');
      }

      // Try multiple extraction strategies in order of preference
      dynamic decoded;
      List<String> extractionAttempts = [
        _extractJsonFromResponse(jsonString, expectList: true),
        _aggressiveJsonClean(jsonString),
        _bruteForceJsonExtract(jsonString),
      ];

      bool parseSuccess = false;
      for (int i = 0; i < extractionAttempts.length; i++) {
        final attempt = extractionAttempts[i];
        if (attempt.isEmpty || attempt.length < 2) continue;

        debugPrint(
            '🧹 Attempt ${i + 1} (${attempt.length} chars): ${attempt.substring(0, attempt.length > 100 ? 100 : attempt.length)}');
        try {
          decoded = jsonDecode(attempt);
          debugPrint('✅ Parse succeeded on attempt ${i + 1}');
          parseSuccess = true;
          break;
        } catch (e) {
          debugPrint('❌ Attempt ${i + 1} failed: $e');
        }
      }

      if (!parseSuccess) {
        throw Exception(
          'La IA devolvió un formato inválido.\n\n'
          'Consejos para mejores resultados:\n'
          '• Ten al menos 5-7 ingredientes en tu despensa\n'
          '• Incluye ingredientes variados (proteínas, verduras, granos)\n'
          '• Toca "Reintentar" para probar de nuevo',
        );
      }

      // Handle both List and single Map (wrap in list if single)
      List<dynamic> recipeList;
      if (decoded is List) {
        recipeList = decoded;
      } else if (decoded is Map<String, dynamic>) {
        debugPrint('⚠️ Gemini returned a single object, wrapping in list');
        recipeList = [decoded];
      } else {
        throw Exception(
          'Formato inesperado de la IA (tipo: ${decoded.runtimeType}). '
          'Intenta de nuevo.',
        );
      }

      if (recipeList.isEmpty) {
        throw Exception(
            'La IA no encontró recetas con tus ingredientes actuales.');
      }

      final suggestions = <RecipeSuggestion>[];

      for (final recipeData in recipeList) {
        if (recipeData is! Map<String, dynamic>) continue;

        final name = recipeData['nombre_receta'] as String? ?? 'Receta';
        final description = recipeData['descripcion'] as String? ?? '';
        final tiempoTotal = recipeData['tiempo_total_min'] as int? ?? 30;
        final porciones = recipeData['porciones'] as int? ?? 2;
        final ingredientesDisponibles =
            recipeData['ingredientes_disponibles'] as int? ?? 0;
        final ingredientesTotales =
            recipeData['ingredientes_totales'] as int? ?? 0;

        // Parse ingredients
        final ingredients = <RecipeIngredient>[];
        final recipeId = DateTime.now().millisecondsSinceEpoch.toString();
        final rawIngredients =
            recipeData['ingredientes'] as List<dynamic>? ?? [];

        for (int i = 0; i < rawIngredients.length; i++) {
          final item = rawIngredients[i] as Map<String, dynamic>;
          final ingName = item['nombre'] as String? ?? 'Ingrediente $i';
          final rawQty = item['cantidad'];
          final qty = rawQty is num
              ? rawQty.toDouble()
              : (rawQty is String ? double.tryParse(rawQty) ?? 1.0 : 1.0);
          final unit = item['unidad'] as String? ?? 'unidades';

          ingredients.add(RecipeIngredient(
            id: '${recipeId}_ing_$i',
            recipeId: recipeId,
            ingredientName: ingName,
            quantity: qty,
            unit: unit,
          ));
        }

        // Skip empty recipes (no ingredients or too few)
        if (ingredients.length < 2) {
          debugPrint(
              '⚠️ Skipping empty recipe: $name (${ingredients.length} ingredients)');
          continue;
        }

        // Parse steps
        final steps = <String>[];
        final rawSteps = recipeData['pasos'] as List<dynamic>? ?? [];
        final sortedSteps = List<Map<String, dynamic>>.from(rawSteps)
          ..sort((a, b) {
            final numA = a['numero'] as int? ?? 0;
            final numB = b['numero'] as int? ?? 0;
            return numA.compareTo(numB);
          });

        for (final step in sortedSteps) {
          steps.add(step['descripcion'] as String? ?? '');
        }

        // Parse tags
        final rawTags = recipeData['tags'] as List<dynamic>? ?? [];
        final tags = rawTags.map((e) => e.toString()).toList();

        // Parse additional fields
        final utensilios = (recipeData['utensilios'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final ingredientesInferidos =
            (recipeData['ingredientes_inferidos'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
        final caloriasAproximadas = recipeData['calorias_aproximadas'] as int?;

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
        );

        suggestions.add(RecipeSuggestion(
          recipe: recipe,
          matchPercentage: ingredientesTotales > 0
              ? ((ingredientesDisponibles / ingredientesTotales) * 100).round()
              : 0,
          missingIngredients: ingredientesTotales - ingredientesDisponibles,
        ));
      }

      return suggestions;
    } catch (e, stackTrace) {
      debugPrint('❌ Error in WhatCanICookUseCase: $e');
      debugPrint('📋 Stack trace: $stackTrace');
      throw Exception('Error al generar sugerencias con IA: $e');
    }
  }

  /// Robustly extracts JSON from a response string
  String _extractJsonFromResponse(String response, {bool expectList = false}) {
    String text = response.trim();

    if (text.contains('```')) {
      text = text.replaceAll(RegExp(r'^```json\s*', multiLine: true), '');
      text = text.replaceAll(RegExp(r'^```\s*', multiLine: true), '');
      text = text.replaceAll(RegExp(r'\s*```$', multiLine: true), '');
    }

    // If we expect a list, look for brackets first
    if (expectList) {
      final firstBracket = text.indexOf('[');
      final lastBracket = text.lastIndexOf(']');

      if (firstBracket != -1 &&
          lastBracket != -1 &&
          lastBracket > firstBracket) {
        return text.substring(firstBracket, lastBracket + 1);
      }
    }

    // Fallback to braces (object)
    final firstBrace = text.indexOf('{');
    final lastBrace = text.lastIndexOf('}');

    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      return text.substring(firstBrace, lastBrace + 1);
    }

    // Last resort: try brackets anyway
    final firstBracket = text.indexOf('[');
    final lastBracket = text.lastIndexOf(']');

    if (firstBracket != -1 && lastBracket != -1 && lastBracket > firstBracket) {
      return text.substring(firstBracket, lastBracket + 1);
    }

    return text;
  }

  /// Aggressive JSON cleaning for when normal extraction fails
  String _aggressiveJsonClean(String response) {
    String text = response.trim();

    // Remove ALL markdown code blocks completely
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    text = text.replaceAll(RegExp(r'```json\s*'), '');
    text = text.replaceAll(RegExp(r'```\s*'), '');

    // Find the first [ and last ] that could be a valid JSON array
    final firstBracket = text.indexOf('[');
    final lastBracket = text.lastIndexOf(']');

    if (firstBracket != -1 && lastBracket != -1 && lastBracket > firstBracket) {
      var candidate = text.substring(firstBracket, lastBracket + 1);
      // Remove any trailing text after ]
      final trailingNewline = candidate.indexOf('\n]');
      if (trailingNewline != -1) {
        candidate = candidate.substring(0, candidate.lastIndexOf(']') + 1);
      }
      return candidate;
    }

    // Try braces as fallback
    final firstBrace = text.indexOf('{');
    final lastBrace = text.lastIndexOf('}');

    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      return text.substring(firstBrace, lastBrace + 1);
    }

    return text;
  }

  /// Brute force: finds the outermost matching bracket/brace pair
  String _bruteForceJsonExtract(String text) {
    // Remove markdown
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    text = text.replaceAll(RegExp(r'```json\s*'), '');
    text = text.replaceAll(RegExp(r'```\s*'), '');

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

  /// NEW: Execute with personalized menu components
  Future<List<RecipeSuggestion>> executeWithMenu({
    required List<InventoryIngredient> inventory,
    required dynamic mealPeriod, // MealPeriod enum
    required List<dynamic> components, // List<MenuComponent>
    required int menuCount,
    List<String>? dislikedIngredients,
    String? cuisinePreference,
    List<String>? recentlyUsedRecipeNames,
    ChefPreferences? userPreferences,
  }) async {
    if (inventory.isEmpty) {
      throw Exception(
          'No tienes ingredientes en tu inventario. Agrega algunos primero.');
    }

    final inventoryDescription = inventory.map((item) {
      return '- ${item.name}: ${item.quantity} ${item.unit}${item.preparation.isNotEmpty ? ' (${item.preparation})' : ''}';
    }).join('\n');

    // Build component requirements string
    final componentNames = components.map((c) {
      // MenuComponent has: label, emoji, mealTypeName
      final label =
          c.toString().split('.').last; // e.g., "MenuComponent.entrada"
      final Map<String, String> componentMap = {
        'entrada': '🥗 Entrada',
        'sopa': '🍲 Sopa',
        'platoFuerte': '🥘 Plato Fuerte (Segundo)',
        'refresco': '🥤 Refresco/Bebida',
        'postre': '🍰 Postre',
      };
      return componentMap[label] ?? label;
    }).join(', ');

    // Map components to MealType names
    final mealTypeNames = components.map((c) {
      final label = c.toString().split('.').last;
      final Map<String, String> typeMap = {
        'entrada': 'entrada',
        'sopa': 'sopa',
        'platoFuerte': 'almuerzo',
        'refresco': 'bebida',
        'postre': 'postre',
      };
      return typeMap[label] ?? 'almuerzo';
    }).toSet();

    final mealTypeList = mealTypeNames.join(', ');

    final mealPeriodName = mealPeriod.toString().split('.').last;
    final mealPeriodEmoji = {
      'desayuno': '🌅',
      'almuerzo': '🍛',
      'cena': '🌙',
    };
    final emoji = mealPeriodEmoji[mealPeriodName] ?? '🍽️';

    // Dinner-specific note: light dishes only
    String dinnerNote = '';
    if (mealPeriodName == 'cena') {
      dinnerNote = '''
🌙 IMPORTANTE: Es para la CENA. Sugiere platos LIGEROS y fáciles de digerir:
- Sopas livianas, ensaladas, sandwiches, tortillas, ceviches pequeños
- EVITA platos pesados: frituras, carnes rojas grandes, guisos pesados
- Porciones moderadas, tiempos de preparación cortos
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
🌍 PREFERENCIA CULINARIA: "$cuisinePreference"
Prioriza recetas de esta cocina.
''';
    }

    String recentlyUsedWarning = '';
    if (recentlyUsedRecipeNames != null && recentlyUsedRecipeNames.isNotEmpty) {
      recentlyUsedWarning = '''
📅 RECETAS USADAS RECIENTEMENTE (NO REPETIR):
${recentlyUsedRecipeNames.take(10).map((e) => '- $e').join('\n')}
''';
    }

    final totalRecipes = menuCount * components.length;

    final prompt = '''
Chef peruano. Genera ${totalRecipes} recetas JSON.

COMPONENTES: $componentNames
TIPOS: $mealTypeList
${dinnerNote}
REGLAS: recetas peruanas reales, NO repetir, tipos validos: entrada/sopa/seco/postre/bebida/mazamorra, min 3 ingredientes y 3 pasos.

FORMATO JSON array exacto:
[{"nombre_receta":"Nombre","descripcion":"Desc","porciones":4,"tiempo_preparacion_min":10,"tiempo_coccion_min":20,"tiempo_total_min":30,"dificultad":"Facil","tipo_comida":"seco","cocina":"Peruana","cuisine_style":"Peruana","ingredientes":[{"nombre":"Ing","cantidad":1,"unidad":"unidades"}],"ingredientes_inferidos":["sal"],"pasos":[{"numero":1,"descripcion":"Paso"}],"utensilios":["olla"],"calorias_aproximadas":300,"tags":["tag"],"ingredientes_disponibles":2,"ingredientes_totales":3,"nivel_confianza":"Alto","observaciones":"Nota"}]

Genera SOLO el array JSON:''';

    try {
      final jsonString = await aiExtractor.extractRecipeJson(
        textContext: prompt,
        mediaPath: null,
      );

      if (jsonString == null || jsonString.isEmpty) {
        throw Exception('La IA no pudo generar sugerencias');
      }

      debugPrint('📄 executeWithMenu response (${jsonString.length} chars)');
      if (jsonString.length < 2000) {
        debugPrint('📄 Full: $jsonString');
      } else {
        debugPrint('📄 First 2000: ${jsonString.substring(0, 2000)}');
      }

      // Parse JSON with multiple extraction strategies
      dynamic decoded;
      List<String> extractionAttempts = [
        _extractJsonFromResponse(jsonString, expectList: true),
        _aggressiveJsonClean(jsonString),
        _bruteForceJsonExtract(jsonString),
      ];

      bool parseSuccess = false;
      for (int i = 0; i < extractionAttempts.length; i++) {
        final attempt = extractionAttempts[i];
        if (attempt.isEmpty || attempt.length < 2) continue;

        debugPrint('🧹 JSON parse attempt ${i + 1} (${attempt.length} chars)');
        try {
          decoded = jsonDecode(attempt);
          debugPrint('✅ Parse succeeded on attempt ${i + 1}');
          parseSuccess = true;
          break;
        } catch (e) {
          debugPrint('❌ Attempt ${i + 1} failed: $e');
        }
      }

      if (!parseSuccess) {
        throw Exception(
          'La IA devolvió un formato inválido.\n\n'
          'Consejos:\n'
          '• Ten al menos 5-7 ingredientes en tu despensa\n'
          '• Incluye ingredientes variados\n'
          '• Toca "Regenerar" para probar de nuevo',
        );
      }

      List<dynamic> recipeList;
      if (decoded is List) {
        recipeList = decoded;
      } else if (decoded is Map<String, dynamic>) {
        recipeList = [decoded];
      } else {
        throw Exception(
            'Formato inesperado de la IA (tipo: ${decoded.runtimeType})');
      }

      if (recipeList.isEmpty) {
        throw Exception(
            'La IA no encontró recetas con tus ingredientes actuales.');
      }

      final suggestions = <RecipeSuggestion>[];

      for (final recipeData in recipeList) {
        if (recipeData is! Map<String, dynamic>) continue;

        final name = recipeData['nombre_receta'] as String? ?? 'Receta';
        final description = recipeData['descripcion'] as String? ?? '';
        final tiempoTotal = recipeData['tiempo_total_min'] as int? ?? 30;
        final porciones = recipeData['porciones'] as int? ?? 2;
        final ingredientesDisponibles =
            recipeData['ingredientes_disponibles'] as int? ?? 0;
        final ingredientesTotales =
            recipeData['ingredientes_totales'] as int? ?? 0;

        final ingredients = <RecipeIngredient>[];
        final recipeId = DateTime.now().millisecondsSinceEpoch.toString() +
            '_${suggestions.length}';
        final rawIngredients =
            recipeData['ingredientes'] as List<dynamic>? ?? [];

        for (int i = 0; i < rawIngredients.length; i++) {
          final item = rawIngredients[i] as Map<String, dynamic>;
          final ingName = item['nombre'] as String? ?? 'Ingrediente $i';
          final rawQty = item['cantidad'];
          final qty = rawQty is num
              ? rawQty.toDouble()
              : (rawQty is String ? double.tryParse(rawQty) ?? 1.0 : 1.0);
          final unit = item['unidad'] as String? ?? 'unidades';

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
          continue;
        }

        final steps = <String>[];
        final rawSteps = recipeData['pasos'] as List<dynamic>? ?? [];
        final sortedSteps = List<Map<String, dynamic>>.from(rawSteps)
          ..sort((a, b) {
            final numA = a['numero'] as int? ?? 0;
            final numB = b['numero'] as int? ?? 0;
            return numA.compareTo(numB);
          });

        for (final step in sortedSteps) {
          steps.add(step['descripcion'] as String? ?? '');
        }

        final rawTags = recipeData['tags'] as List<dynamic>? ?? [];
        final tags = rawTags.map((e) => e.toString()).toList();
        final utensilios = (recipeData['utensilios'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final ingredientesInferidos =
            (recipeData['ingredientes_inferidos'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
        final caloriasAproximadas = recipeData['calorias_aproximadas'] as int?;

        // Map tipo_comida string to MealType enum
        MealType? mealType;
        final tipoComidaStr =
            (recipeData['tipo_comida'] as String?)?.toLowerCase();
        if (tipoComidaStr != null) {
          mealType = MealType.values.cast<MealType?>().firstWhere(
                (m) => m!.name == tipoComidaStr,
                orElse: () => null,
              );
        }

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

        suggestions.add(RecipeSuggestion(
          recipe: recipe,
          matchPercentage: ingredientesTotales > 0
              ? ((ingredientesDisponibles / ingredientesTotales) * 100).round()
              : 0,
          missingIngredients: ingredientesTotales - ingredientesDisponibles,
        ));
      }

      return suggestions;
    } catch (e, stackTrace) {
      debugPrint('❌ Error in executeWithMenu: $e');
      debugPrint('📋 Stack trace: $stackTrace');
      throw Exception('Error al generar sugerencias con IA: $e');
    }
  }
}

class RecipeSuggestion {
  final Recipe recipe;
  final int matchPercentage; // 0-100
  final int missingIngredients;

  const RecipeSuggestion({
    required this.recipe,
    required this.matchPercentage,
    required this.missingIngredients,
  });

  Map<String, dynamic> toJson() {
    return {
      'recipe': recipe.toJson(),
      'matchPercentage': matchPercentage,
      'missingIngredients': missingIngredients,
    };
  }

  factory RecipeSuggestion.fromJson(Map<String, dynamic> json) {
    return RecipeSuggestion(
      recipe: Recipe.fromJson(json['recipe'] as Map<String, dynamic>),
      matchPercentage: json['matchPercentage'] as int,
      missingIngredients: json['missingIngredients'] as int,
    );
  }
}
