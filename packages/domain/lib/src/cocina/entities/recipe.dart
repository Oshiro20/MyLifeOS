import 'package:equatable/equatable.dart';

enum NutritionGoal { loseWeight, maintain, gainMuscle, other }

/// Tipos de comida soportados por la app
enum MealType {
  desayuno('Desayuno', '🌅'),
  almuerzo('Almuerzo', '🍛'),
  cena('Cena', '🌙'),
  entrada('Entrada', '🥗'),
  sopa('Sopa', '🍲'),
  seco('Seco', '🥘'),
  postre('Postre', '🍰'),
  mazamorra('Mazamorra', '🍮'),
  bebida('Bebida', '🥤'),
  snack('Snack', '🍿'),
  jugo('Jugo', '🧃'),
  otro('Otro', '🍽️');

  final String label;
  final String emoji;
  const MealType(this.label, this.emoji);
}

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
  final MealType? tipoComida;

  /// Source URL (TikTok, YouTube, website, etc.) - null means AI-generated
  final String? fuenteUrl;

  /// Source label (e.g. 'TikTok', 'YouTube', 'Chef IA')
  final String? fuenteLabel;

  /// User rating (1-5 stars)
  final int? rating;

  /// Cuisine style (Peruana-sierra, Peruana-selva, Italiana, etc.)
  final String? cuisineStyle;

  /// Active cooking session identifier
  final String? cookingSessionId;

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
    this.tipoComida,
    this.fuenteUrl,
    this.fuenteLabel,
    this.rating,
    this.cuisineStyle,
    this.cookingSessionId,
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
    MealType? tipoComida,
    String? fuenteUrl,
    String? fuenteLabel,
    int? rating,
    String? cuisineStyle,
    String? cookingSessionId,
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
        tipoComida: tipoComida ?? this.tipoComida,
        fuenteUrl: fuenteUrl ?? this.fuenteUrl,
        fuenteLabel: fuenteLabel ?? this.fuenteLabel,
        rating: rating ?? this.rating,
        cuisineStyle: cuisineStyle ?? this.cuisineStyle,
        cookingSessionId: cookingSessionId ?? this.cookingSessionId,
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
        tipoComida,
        fuenteUrl,
        fuenteLabel,
        rating,
        cuisineStyle,
        cookingSessionId,
      ];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'durationMinutes': durationMinutes,
      'servings': servings,
      'instructions': instructions,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'tags': tags,
      'imageAssetId': imageAssetId,
      'goal': goal.name,
      'isFavorite': isFavorite,
      'createdAt': createdAt.toIso8601String(),
      'nutrition': nutrition?.toJson(),
      'alergenos': alergenos,
      'sustitutos': sustitutos.map((s) => s.toJson()).toList(),
      'tipsChef': tipsChef,
      'maridaje': maridaje,
      'variaciones': variaciones.map((v) => v.toJson()).toList(),
      'utensilios': utensilios,
      'caloriasAproximadas': caloriasAproximadas,
      'ingredientesInferidos': ingredientesInferidos,
      'tipoComida': tipoComida?.name,
      'fuenteUrl': fuenteUrl,
      'fuenteLabel': fuenteLabel,
      'rating': rating,
      'cuisineStyle': cuisineStyle,
      'cookingSessionId': cookingSessionId,
    };
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      durationMinutes: json['durationMinutes'] as int? ?? 30,
      servings: json['servings'] as int? ?? 2,
      instructions:
          (json['instructions'] as List<dynamic>?)?.cast<String>() ?? [],
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((i) => RecipeIngredient.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      imageAssetId: json['imageAssetId'] as String?,
      goal: NutritionGoal.values.firstWhere(
        (e) => e.name == json['goal'],
        orElse: () => NutritionGoal.maintain,
      ),
      isFavorite: json['isFavorite'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      nutrition: json['nutrition'] != null
          ? NutritionInfo.fromJson(json['nutrition'] as Map<String, dynamic>)
          : null,
      alergenos: (json['alergenos'] as List<dynamic>?)?.cast<String>() ?? [],
      sustitutos: (json['sustitutos'] as List<dynamic>?)
              ?.map((s) =>
                  IngredientSubstitute.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      tipsChef: (json['tipsChef'] as List<dynamic>?)?.cast<String>() ?? [],
      maridaje: json['maridaje'] as String?,
      variaciones: (json['variaciones'] as List<dynamic>?)
              ?.map((v) => RecipeVariation.fromJson(v as Map<String, dynamic>))
              .toList() ??
          [],
      utensilios: (json['utensilios'] as List<dynamic>?)?.cast<String>() ?? [],
      caloriasAproximadas: json['caloriasAproximadas'] as int?,
      ingredientesInferidos:
          (json['ingredientesInferidos'] as List<dynamic>?)?.cast<String>() ??
              [],
      tipoComida: json['tipoComida'] != null
          ? MealType.values.firstWhere(
              (e) => e.name == json['tipoComida'],
              orElse: () => MealType.otro,
            )
          : null,
      fuenteUrl: json['fuenteUrl'] as String?,
      fuenteLabel: json['fuenteLabel'] as String?,
      rating: json['rating'] as int?,
      cuisineStyle: json['cuisineStyle'] as String?,
      cookingSessionId: json['cookingSessionId'] as String?,
    );
  }
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipeId': recipeId,
      'ingredientName': ingredientName,
      'quantity': quantity,
      'unit': unit,
    };
  }

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      id: json['id'] as String,
      recipeId: json['recipeId'] as String,
      ingredientName: json['ingredientName'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
    );
  }
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

  Map<String, dynamic> toJson() {
    return {
      'proteinasG': proteinasG,
      'carbohidratosG': carbohidratosG,
      'grasasG': grasasG,
      'fibraG': fibraG,
    };
  }

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      proteinasG: (json['proteinasG'] as num?)?.toDouble() ?? 0,
      carbohidratosG: (json['carbohidratosG'] as num?)?.toDouble() ?? 0,
      grasasG: (json['grasasG'] as num?)?.toDouble() ?? 0,
      fibraG: (json['fibraG'] as num?)?.toDouble() ?? 0,
    );
  }
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

  Map<String, dynamic> toJson() {
    return {
      'original': original,
      'sustituto': sustituto,
      'nota': nota,
    };
  }

  factory IngredientSubstitute.fromJson(Map<String, dynamic> json) {
    return IngredientSubstitute(
      original: json['original'] as String,
      sustituto: json['sustituto'] as String,
      nota: json['nota'] as String?,
    );
  }
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

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'cambios': cambios,
    };
  }

  factory RecipeVariation.fromJson(Map<String, dynamic> json) {
    return RecipeVariation(
      nombre: json['nombre'] as String,
      cambios: json['cambios'] as String,
    );
  }
}
