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
      );

  @override
  List<Object?> get props => [
        id, name, description, durationMinutes, servings,
        instructions, ingredients, tags, imageAssetId, goal, isFavorite, createdAt
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
