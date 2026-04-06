import 'package:equatable/equatable.dart';

enum NutritionGoal { loseWeight, maintain, gainMuscle, other }

class Recipe extends Equatable {
  final String id;
  final String name;
  final String description;
  final int durationMinutes;
  final int servings;
  final List<String> instructions;
  final List<RecipeIngredient> ingredients;
  final List<String> tags;
  final String? imageAssetId;
  final NutritionGoal goal;
  final bool isFavorite;
  final DateTime createdAt;

  // Campos adicionales de Gemini (optimizeRecipe y extractRecipe)
  final NutritionInfo? nutrition;
  final List<String> alergenos;
  final List<IngredientSubstitute> sustitutos;
  final List<String> tipsChef;
  final String? maridaje;
  final List<RecipeVariation> variaciones;
  final List<String> utensilios;
  final int? caloriasAproximadas;
  final List<String> ingredientesInferidos;

  const Recipe({
    required this.id,
    required this.name,
    this.description = '',
    this.durationMinutes = 30,
    this.servings = 2,
    this.instructions = const [],
    this.ingredients = const [],
    this.tags = const [],
    this.imageAssetId,
    this.goal = NutritionGoal.maintain,
    this.isFavorite = false,
    required this.createdAt,
    this.nutrition,
    this.alergenos = const [],
    this.sustitutos = const [],
    this.tipsChef = const [],
    this.maridaje,
    this.variaciones = const [],
    this.utensilios = const [],
    this.caloriasAproximadas,
    this.ingredientesInferidos = const [],
  });

  Recipe copyWith({
    String? id,
    String? name,
    String? description,
    int? durationMinutes,
    int? servings,
    List<String>? instructions,
    List<RecipeIngredient>? ingredients,
    List<String>? tags,
    String? imageAssetId,
    NutritionGoal? goal,
    bool? isFavorite,
    DateTime? createdAt,
    NutritionInfo? nutrition,
    List<String>? alergenos,
    List<IngredientSubstitute>? sustitutos,
    List<String>? tipsChef,
    String? maridaje,
    List<RecipeVariation>? variaciones,
    List<String>? utensilios,
    int? caloriasAproximadas,
    List<String>? ingredientesInferidos,
  }) =>
      Recipe(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        servings: servings ?? this.servings,
        instructions: instructions ?? this.instructions,
        ingredients: ingredients ?? this.ingredients,
        tags: tags ?? this.tags,
        imageAssetId: imageAssetId ?? this.imageAssetId,
        goal: goal ?? this.goal,
        isFavorite: isFavorite ?? this.isFavorite,
        createdAt: createdAt ?? this.createdAt,
        nutrition: nutrition ?? this.nutrition,
        alergenos: alergenos ?? this.alergenos,
        sustitutos: sustitutos ?? this.sustitutos,
        tipsChef: tipsChef ?? this.tipsChef,
        maridaje: maridaje ?? this.maridaje,
        variaciones: variaciones ?? this.variaciones,
        utensilios: utensilios ?? this.utensilios,
        caloriasAproximadas: caloriasAproximadas ?? this.caloriasAproximadas,
        ingredientesInferidos:
            ingredientesInferidos ?? this.ingredientesInferidos,
      );

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        durationMinutes,
        servings,
        instructions,
        ingredients,
        tags,
        imageAssetId,
        goal,
        isFavorite,
        createdAt,
        nutrition,
        alergenos,
        sustitutos,
        tipsChef,
        maridaje,
        variaciones,
        utensilios,
        caloriasAproximadas,
        ingredientesInferidos,
      ];
}

class RecipeIngredient extends Equatable {
  final String id;
  final String recipeId;
  final String ingredientName;
  final double quantity;
  final String unit;

  const RecipeIngredient({
    required this.id,
    required this.recipeId,
    required this.ingredientName,
    required this.quantity,
    required this.unit,
  });

  @override
  List<Object?> get props => [id, recipeId, ingredientName, quantity, unit];
}

/// Información nutricional de la receta
class NutritionInfo extends Equatable {
  final double proteinasG;
  final double carbohidratosG;
  final double grasasG;
  final double fibraG;

  const NutritionInfo({
    this.proteinasG = 0,
    this.carbohidratosG = 0,
    this.grasasG = 0,
    this.fibraG = 0,
  });

  NutritionInfo copyWith({
    double? proteinasG,
    double? carbohidratosG,
    double? grasasG,
    double? fibraG,
  }) =>
      NutritionInfo(
        proteinasG: proteinasG ?? this.proteinasG,
        carbohidratosG: carbohidratosG ?? this.carbohidratosG,
        grasasG: grasasG ?? this.grasasG,
        fibraG: fibraG ?? this.fibraG,
      );

  @override
  List<Object?> get props => [proteinasG, carbohidratosG, grasasG, fibraG];
}

/// Sustituto de ingrediente
class IngredientSubstitute extends Equatable {
  final String original;
  final String sustituto;
  final String? nota;

  const IngredientSubstitute({
    required this.original,
    required this.sustituto,
    this.nota,
  });

  @override
  List<Object?> get props => [original, sustituto, nota];
}

/// Variación de receta
class RecipeVariation extends Equatable {
  final String nombre;
  final String cambios;

  const RecipeVariation({
    required this.nombre,
    required this.cambios,
  });

  @override
  List<Object?> get props => [nombre, cambios];
}
