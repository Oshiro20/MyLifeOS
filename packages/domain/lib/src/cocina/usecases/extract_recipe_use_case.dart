import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../entities/recipe.dart';
import '../repositories/i_ai_recipe_extractor.dart';
import '../../utils/ai_json_parser.dart';

class ExtractRecipeUseCase {
  final IAIRecipeExtractor aiExtractor;

  ExtractRecipeUseCase(this.aiExtractor);

  Future<Recipe?> execute({String? textContext, String? mediaPath}) async {
    final list = await executeMany(
      textContext: textContext,
      mediaPath: mediaPath,
    );
    return list.isEmpty ? null : list.first;
  }

  /// Extrae una o múltiples recetas si el video/texto/enlace contiene varias preparaciones independientes.
  Future<List<Recipe>> executeMany({
    String? textContext,
    String? mediaPath,
  }) async {
    final jsonString = await aiExtractor.extractRecipeJson(
      textContext: textContext,
      mediaPath: mediaPath,
    );

    if (jsonString == null || jsonString.isEmpty) return const [];
    return parseManyFromJson(jsonString);
  }

  /// Parses a raw JSON string (possibly with markdown/extra text) into a Recipe.
  /// This is the single source of truth for JSON → Recipe parsing.
  Recipe parseFromJson(String jsonString, {String? sourceUrl}) {
    final recipes = parseManyFromJson(jsonString, sourceUrl: sourceUrl);
    if (recipes.isEmpty) {
      throw Exception('La IA no devolvió ninguna receta válida.');
    }
    return recipes.first;
  }

  /// Parsea una o varias recetas desde la respuesta JSON de Gemini (soporta `{ "recetas": [...] }`,
  /// una lista JSON `[...]` o un único objeto `{ ... }`).
  List<Recipe> parseManyFromJson(String jsonString, {String? sourceUrl}) {
    try {
      final cleanJson = _extractJsonFromResponse(jsonString);
      final dynamic decodedRoot = jsonDecode(cleanJson);
      final baseTs = DateTime.now().millisecondsSinceEpoch;

      if (decodedRoot is List) {
        final list = <Recipe>[];
        for (int i = 0; i < decodedRoot.length; i++) {
          final item = decodedRoot[i];
          if (item is Map) {
            list.add(_parseRecipe(
              Map<String, dynamic>.from(item),
              sourceUrl: sourceUrl,
              recipeId: '${baseTs}_$i',
            ));
          }
        }
        if (list.isEmpty) {
          throw const FormatException(
              'La IA devolvió una lista vacía sin recetas.');
        }
        return list;
      }

      if (decodedRoot is! Map) {
        throw const FormatException('Formato JSON inesperado de receta.');
      }

      final decoded = Map<String, dynamic>.from(decodedRoot);
      final err = decoded['error_extraccion']?.toString().trim();
      if (err != null && err.isNotEmpty) {
        throw FormatException(err);
      }

      final rawMulti = decoded['recetas'] ?? decoded['recipes'];
      if (rawMulti is List && rawMulti.isNotEmpty) {
        final list = <Recipe>[];
        for (int i = 0; i < rawMulti.length; i++) {
          final item = rawMulti[i];
          if (item is Map) {
            list.add(_parseRecipe(
              Map<String, dynamic>.from(item),
              sourceUrl: sourceUrl,
              recipeId: '${baseTs}_$i',
            ));
          }
        }
        if (list.isNotEmpty) return list;
      }

      return [
        _parseRecipe(decoded, sourceUrl: sourceUrl, recipeId: baseTs.toString()),
      ];
    } on FormatException catch (e) {
      throw Exception(e.message);
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing recipe JSON: $e');
      debugPrint(
          '📄 Raw JSON was: ${jsonString.substring(0, jsonString.length > 500 ? 500 : jsonString.length)}...');
      debugPrint('📋 Stack trace: $stackTrace');
      throw Exception('Error al parsear receta desde IA: $e');
    }
  }

  Recipe _parseRecipe(
    Map<String, dynamic> decoded, {
    String? sourceUrl,
    String? recipeId,
  }) {
    // Support BOTH old and new JSON formats
    final name =
        decoded['name'] ?? decoded['nombre_receta'] ?? 'Receta Importada';
    final description = decoded['description'] ?? decoded['descripcion'] ?? '';

    // Parsear desglose de tiempos (preparación + cocción vs refrigeración/reposo)
    final prepMin = _parseMinutes(decoded['tiempo_preparacion_min']);
    final cookMin = _parseMinutes(decoded['tiempo_coccion_min']);
    final chillMin = _parseMinutes(
      decoded['tiempo_refrigeracion_min'] ?? decoded['tiempo_reposo_min'],
    );
    final rawDuration = _parseMinutes(
      decoded['durationMinutes'] ?? decoded['tiempo_total_min'],
    );

    final activeMin =
        (prepMin != null || cookMin != null) ? (prepMin ?? 0) + (cookMin ?? 0) : null;
    final chill = chillMin ?? 0;

    int durationMinutes;
    if (rawDuration != null && rawDuration > 0) {
      durationMinutes = rawDuration;
    } else if ((activeMin ?? 0) + chill > 0) {
      durationMinutes = (activeMin ?? 0) + chill;
    } else {
      durationMinutes = 30;
    }
    if (activeMin != null && chill > 0 && durationMinutes < activeMin + chill) {
      durationMinutes = activeMin + chill;
    }

    // Support both formats for servings
    final servings = decoded['servings'] ?? decoded['porciones'];
    final servingsInt = servings is num
        ? servings.round()
        : (servings is String
            ? (double.tryParse(servings.replaceAll(',', '.'))?.round() ?? 2)
            : 2);

    // Support both ingredient formats
    final rawIngField = decoded['ingredients'] ?? decoded['ingredientes'];
    final rawIngredients = rawIngField is List ? rawIngField : const [];

    final List<RecipeIngredient> ingredients = [];
    final resolvedId =
        recipeId ?? DateTime.now().millisecondsSinceEpoch.toString();

    for (int i = 0; i < rawIngredients.length; i++) {
      final rawEntry = rawIngredients[i];
      if (rawEntry is String && rawEntry.trim().isNotEmpty) {
        ingredients.add(RecipeIngredient(
          id: '${resolvedId}_ing_$i',
          recipeId: resolvedId,
          ingredientName: rawEntry.trim(),
          quantity: 1.0,
          unit: 'unidades',
        ));
        continue;
      }
      if (rawEntry is! Map) continue;
      final item = Map<String, dynamic>.from(rawEntry);

      final ingName =
          (item['ingredientName'] ?? item['nombre'])?.toString() ??
              'Ingrediente $i';

      double qty;
      final rawQty = item['quantity'] ?? item['cantidad'];
      if (rawQty is num) {
        qty = rawQty.toDouble();
      } else if (rawQty is String) {
        qty = double.tryParse(rawQty.replaceAll(',', '.')) ?? 1.0;
      } else {
        qty = 1.0;
      }

      final rawUnit =
          (item['unit'] ?? item['unidad'])?.toString() ?? 'unidades';

      ingredients.add(RecipeIngredient(
        id: '${resolvedId}_ing_$i',
        recipeId: resolvedId,
        ingredientName: ingName,
        quantity: qty,
        unit: rawUnit,
      ));
    }

    // Support both instruction formats
    List<dynamic> rawInstructions = [];
    if (decoded['instructions'] is List) {
      rawInstructions = decoded['instructions'] as List<dynamic>;
    } else if (decoded['pasos'] is List) {
      final pasosList = List<dynamic>.from(decoded['pasos'] as List);
      final mapSteps = <Map<String, dynamic>>[];
      final stringSteps = <String>[];
      for (final p in pasosList) {
        if (p is Map) {
          mapSteps.add(Map<String, dynamic>.from(p));
        } else if (p != null && p.toString().trim().isNotEmpty) {
          stringSteps.add(p.toString().trim());
        }
      }
      if (mapSteps.isNotEmpty) {
        mapSteps.sort((a, b) {
          final numA = (a['numero'] as num?)?.toInt() ?? 0;
          final numB = (b['numero'] as num?)?.toInt() ?? 0;
          return numA.compareTo(numB);
        });
        rawInstructions =
            mapSteps.map((p) => p['descripcion']?.toString() ?? '').toList();
      } else {
        rawInstructions = stringSteps;
      }
    }

    // VALIDATION AUTOMÁTICA: Verificar que la receta tenga contenido mínimo
    if (rawIngredients.length < 2) {
      debugPrint('⚠️ Validation: Less than 2 ingredients detected');
    }
    if (rawInstructions.length < 3) {
      debugPrint('⚠️ Validation: Less than 3 steps detected');
    }

    final instructions = rawInstructions.map((e) => e.toString()).toList();

    // Support both tag formats y preservar desglose activo/refri sin migrar DB
    final rawTags = decoded['tags'] as List<dynamic>? ?? [];
    final tags = rawTags
        .map((e) => e.toString())
        .where((t) =>
            !t.toLowerCase().startsWith('activo:') &&
            !t.toLowerCase().startsWith('refri:'))
        .toList();
    if (chill > 0) {
      final resolvedActive = activeMin ??
          (durationMinutes > chill ? durationMinutes - chill : 15);
      tags.add('activo:${resolvedActive}m');
      tags.add('refri:${chill}m');
    }

    // Parsear campos adicionales si existen
    final utensilios = (decoded['utensilios'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final ingredientesInferidos =
        (decoded['ingredientes_inferidos'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

    final rawCal = decoded['calorias_aproximadas'];
    final caloriasAproximadas = rawCal is num
        ? rawCal.round()
        : (rawCal is String ? int.tryParse(rawCal) : null);

    // Parsear información nutricional
    NutritionInfo? nutrition;
    if (decoded['nutricion'] is Map) {
      final nutriData = Map<String, dynamic>.from(decoded['nutricion'] as Map);
      nutrition = NutritionInfo(
        proteinasG: (nutriData['proteinas_g'] as num?)?.toDouble() ?? 0,
        carbohidratosG: (nutriData['carbohidratos_g'] as num?)?.toDouble() ?? 0,
        grasasG: (nutriData['grasas_g'] as num?)?.toDouble() ?? 0,
        fibraG: (nutriData['fibra_g'] as num?)?.toDouble() ?? 0,
      );
    }

    // Parsear alérgenos
    final alergenos = (decoded['alergenos'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    // Parsear sustitutos
    final sustitutos = <IngredientSubstitute>[];
    if (decoded['sustitutos'] != null) {
      final sustitutosData = decoded['sustitutos'] as List<dynamic>;
      for (final sust in sustitutosData) {
        if (sust is Map<String, dynamic>) {
          sustitutos.add(IngredientSubstitute(
            original: sust['original'] as String? ?? '',
            sustituto: sust['sustituto'] as String? ?? '',
            nota: sust['nota'] as String?,
          ));
        }
      }
    }

    // Parsear tips del chef
    final tipsChef = (decoded['tips_chef'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    // Parsear maridaje
    final maridaje = decoded['maridaje'] as String?;

    // Parsear variaciones
    final variaciones = <RecipeVariation>[];
    if (decoded['variaciones'] != null) {
      final variacionesData = decoded['variaciones'] as List<dynamic>;
      for (final varData in variacionesData) {
        if (varData is Map<String, dynamic>) {
          variaciones.add(RecipeVariation(
            nombre: varData['nombre'] as String? ?? '',
            cambios: varData['cambios'] as String? ?? '',
          ));
        }
      }
    }

    // Parsear tipo de comida y estilo de cocina
    MealType? tipoComida;
    final rawTipoComida = decoded['tipo_comida']?.toString();
    if (rawTipoComida != null) {
      tipoComida = parseMealType(rawTipoComida);
    }
    final rawCocina = (decoded['cocina'] ??
            decoded['cuisineStyle'] ??
            decoded['region'])
        ?.toString()
        .trim();
    final cuisineStyle =
        (rawCocina != null && rawCocina.isNotEmpty) ? rawCocina : null;

    // Parsear fuente (source URL)
    final fuenteUrl =
        decoded['fuente_url'] as String? ?? decoded['url_origen'] as String?;
    final fuenteLabel =
        decoded['fuente_label'] as String? ?? decoded['tipo_fuente'] as String?;
    final rawGoal = (decoded['objetivo_nutricional'] ??
            decoded['objetivo'] ??
            decoded['goal'])
        ?.toString();
    final goal = parseNutritionGoal(rawGoal) ?? NutritionGoal.maintain;

    return Recipe(
      id: resolvedId,
      name: name,
      description: description,
      durationMinutes: durationMinutes,
      servings: servingsInt,
      instructions: instructions,
      ingredients: ingredients,
      tags: tags,
      goal: goal,
      createdAt: DateTime.now(),
      utensilios: utensilios,
      ingredientesInferidos: ingredientesInferidos,
      caloriasAproximadas: caloriasAproximadas,
      nutrition: nutrition,
      alergenos: alergenos,
      sustitutos: sustitutos,
      tipsChef: tipsChef,
      maridaje: maridaje,
      variaciones: variaciones,
      tipoComida: tipoComida,
      cuisineStyle: cuisineStyle,
      fuenteUrl: fuenteUrl ?? sourceUrl,
      fuenteLabel:
          fuenteLabel ?? (sourceUrl != null ? 'Video/Red social' : 'Chef IA'),
    );
  }

  static int? _parseMinutes(dynamic raw) {
    if (raw is num) return raw.round();
    if (raw is String) {
      return double.tryParse(raw.trim().replaceAll(',', '.'))?.round();
    }
    return null;
  }

  /// Robustly extracts JSON from a response string that may contain markdown, extra text, etc.
  String _extractJsonFromResponse(String response) =>
      AiJsonParser.extractJson(response);

  /// Parses a meal type string from AI response to [MealType] enum.
  static MealType? parseMealType(String value) {
    final lower = value.toLowerCase().trim();
    if (lower.contains('desayun')) {
      return MealType.desayuno;
    }
    if (lower.contains('almuerz')) {
      return MealType.almuerzo;
    }
    if (lower.contains('cena')) {
      return MealType.cena;
    }
    if (lower.contains('entrad') || lower.contains('aperitivo')) {
      return MealType.entrada;
    }
    if (lower.contains('sop') ||
        lower.contains('caldo') ||
        lower.contains('crema')) {
      return MealType.sopa;
    }
    if (lower.contains('seco') ||
        lower.contains('segundo') ||
        lower.contains('plato fuerte') ||
        lower.contains('fondo')) {
      return MealType.seco;
    }
    if (lower.contains('postre') || lower.contains('dulc')) {
      return MealType.postre;
    }
    if (lower.contains('mazamorr') || lower.contains('gelatin')) {
      return MealType.mazamorra;
    }
    if (lower.contains('jugo') ||
        lower.contains('zumo') ||
        lower.contains('batido') ||
        lower.contains('smoothie')) {
      return MealType.jugo;
    }
    if (lower.contains('bebida') ||
        lower.contains('refresco') ||
        lower.contains('limonad') ||
        lower.contains('chicha') ||
        lower.contains('emolient')) {
      return MealType.bebida;
    }
    if (lower.contains('snack') ||
        lower.contains('botan') ||
        lower.contains('pasaboc')) {
      return MealType.snack;
    }
    return null;
  }

  /// Parses an AI nutrition goal string to [NutritionGoal].
  static NutritionGoal? parseNutritionGoal(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final lower = value.toLowerCase().trim();
    if (lower.contains('adelgaz') ||
        lower.contains('bajar') ||
        lower.contains('loseweight') ||
        lower.contains('deficit') ||
        lower.contains('dieta') ||
        lower.contains('fitness')) {
      return NutritionGoal.loseWeight;
    }
    if (lower.contains('muscul') ||
        lower.contains('gainmuscle') ||
        lower.contains('prote') ||
        lower.contains('volumen') ||
        lower.contains('masa')) {
      return NutritionGoal.gainMuscle;
    }
    if (lower.contains('liger') ||
        lower.contains('suave') ||
        lower.contains('blanda') ||
        lower.contains('light') ||
        lower.contains('digest')) {
      return NutritionGoal.light;
    }
    if (lower.contains('otro') ||
        lower.contains('other') ||
        lower.contains('personal')) {
      return NutritionGoal.other;
    }
    if (lower.contains('normal') ||
        lower.contains('mantener') ||
        lower.contains('maintain') ||
        lower.contains('balance')) {
      return NutritionGoal.maintain;
    }
    return null;
  }
}
