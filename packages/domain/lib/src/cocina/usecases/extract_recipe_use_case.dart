import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../entities/recipe.dart';
import '../repositories/i_ai_recipe_extractor.dart';
import '../../utils/ai_json_parser.dart';

class ExtractRecipeUseCase {
  final IAIRecipeExtractor aiExtractor;

  ExtractRecipeUseCase(this.aiExtractor);

  Future<Recipe?> execute({String? textContext, String? mediaPath}) async {
    final jsonString = await aiExtractor.extractRecipeJson(
      textContext: textContext,
      mediaPath: mediaPath,
    );

    if (jsonString == null || jsonString.isEmpty) return null;
    return parseFromJson(jsonString);
  }

  /// Parses a raw JSON string (possibly with markdown/extra text) into a Recipe.
  /// This is the single source of truth for JSON → Recipe parsing.
  Recipe parseFromJson(String jsonString, {String? sourceUrl}) {
    try {
      // Robust JSON cleaning - handle markdown, extra text, etc.
      String cleanJson = _extractJsonFromResponse(jsonString);

      final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
      final err = decoded['error_extraccion']?.toString().trim();
      if (err != null && err.isNotEmpty) {
        throw FormatException(err);
      }
      return _parseRecipe(decoded, sourceUrl: sourceUrl);
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

  Recipe _parseRecipe(Map<String, dynamic> decoded, {String? sourceUrl}) {
    // Support BOTH old and new JSON formats
    final name =
        decoded['name'] ?? decoded['nombre_receta'] ?? 'Receta Importada';
    final description = decoded['description'] ?? decoded['descripcion'] ?? '';

    // Support both formats for time (num/string safe)
    final rawDuration =
        decoded['durationMinutes'] ?? decoded['tiempo_total_min'];
    final durationMinutes = rawDuration is num
        ? rawDuration.round()
        : (rawDuration is String
            ? (double.tryParse(rawDuration.replaceAll(',', '.'))?.round() ?? 30)
            : 30);

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
    final recipeId = DateTime.now().millisecondsSinceEpoch.toString();

    for (int i = 0; i < rawIngredients.length; i++) {
      final rawEntry = rawIngredients[i];
      if (rawEntry is String && rawEntry.trim().isNotEmpty) {
        ingredients.add(RecipeIngredient(
          id: '${recipeId}_ing_$i',
          recipeId: recipeId,
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
        id: '${recipeId}_ing_$i',
        recipeId: recipeId,
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

    // Support both tag formats
    final rawTags = decoded['tags'] as List<dynamic>? ?? [];
    final tags = rawTags.map((e) => e.toString()).toList();

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

    // Parsear tipo de comida
    MealType? tipoComida;
    final rawTipoComida = decoded['tipo_comida']?.toString();
    if (rawTipoComida != null) {
      tipoComida = parseMealType(rawTipoComida);
    }

    // Parsear fuente (source URL)
    final fuenteUrl =
        decoded['fuente_url'] as String? ?? decoded['url_origen'] as String?;
    final fuenteLabel =
        decoded['fuente_label'] as String? ?? decoded['tipo_fuente'] as String?;

    return Recipe(
      id: recipeId,
      name: name,
      description: description,
      durationMinutes: durationMinutes,
      servings: servingsInt,
      instructions: instructions,
      ingredients: ingredients,
      tags: tags,
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
      fuenteUrl: fuenteUrl ?? sourceUrl,
      fuenteLabel:
          fuenteLabel ?? (sourceUrl != null ? 'Video/Red social' : 'Chef IA'),
    );
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
    if (lower.contains('bebida') ||
        lower.contains('refresco') ||
        lower.contains('jugo') ||
        lower.contains('zumo') ||
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
}
