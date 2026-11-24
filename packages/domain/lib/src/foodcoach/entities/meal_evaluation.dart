import 'package:equatable/equatable.dart';

enum FoodClassification {
  healthy, // Saludable 💚
  balanced, // Balanceado 💛
  junk, // Chatarra 🔴
}

/// Momento del día en que se consumió la comida.
enum MealSlot {
  breakfast,
  lunch,
  dinner,
  snack;

  static MealSlot forHour(int hour) {
    if (hour < 11) return MealSlot.breakfast;
    if (hour < 16) return MealSlot.lunch;
    if (hour < 22) return MealSlot.dinner;
    return MealSlot.snack;
  }

  static MealSlot fromName(String? raw) {
    final norm = (raw ?? '').trim().toLowerCase();
    for (final s in MealSlot.values) {
      if (s.name == norm) return s;
    }
    if (norm.contains('desayuno')) return MealSlot.breakfast;
    if (norm.contains('almuerzo')) return MealSlot.lunch;
    if (norm.contains('cena')) return MealSlot.dinner;
    if (norm.contains('snack') || norm.contains('merienda')) {
      return MealSlot.snack;
    }
    return MealSlot.lunch;
  }

  String get label => switch (this) {
        MealSlot.breakfast => 'Desayuno',
        MealSlot.lunch => 'Almuerzo',
        MealSlot.dinner => 'Cena',
        MealSlot.snack => 'Snack',
      };

  String get emoji => switch (this) {
        MealSlot.breakfast => '🌅',
        MealSlot.lunch => '🍛',
        MealSlot.dinner => '🌙',
        MealSlot.snack => '🍎',
      };
}

/// Método principal de preparación (impacta directamente calorías y grasas).
enum CookingMethod {
  raw,
  boiled,
  grilled,
  stewed,
  baked,
  fried;

  static CookingMethod? fromName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final norm = raw.trim().toLowerCase();
    for (final m in CookingMethod.values) {
      if (m.name == norm) return m;
    }
    return inferFromText(norm);
  }

  static CookingMethod? inferFromText(String text) {
    final t = text.toLowerCase();
    if (t.contains('frit') ||
        t.contains('freir') ||
        t.contains('freír') ||
        t.contains('empaniz') ||
        t.contains('chicharr')) {
      return CookingMethod.fried;
    }
    if (t.contains('horno') ||
        t.contains('hornead') ||
        t.contains('airfryer') ||
        t.contains('air fryer') ||
        t.contains('freidora de aire')) {
      return CookingMethod.baked;
    }
    if (t.contains('plancha') ||
        t.contains('asad') ||
        t.contains('parrilla') ||
        t.contains('brasa')) {
      return CookingMethod.grilled;
    }
    if (t.contains('sancoch') ||
        t.contains('vapor') ||
        t.contains('hervid') ||
        t.contains('hervir') ||
        t.contains('escalf')) {
      return CookingMethod.boiled;
    }
    if (t.contains('guis') ||
        t.contains('estof') ||
        t.contains('aderez') ||
        t.contains('saltad') ||
        t.contains('saltead') ||
        t.contains('sopa') ||
        t.contains('caldo') ||
        t.contains('menestra')) {
      return CookingMethod.stewed;
    }
    if (t.contains('ensalada') ||
        t.contains('crudo') ||
        t.contains('fresco') ||
        t.contains('ceviche') ||
        t.contains('batido') ||
        t.contains('jugo') ||
        t.contains('yogurt')) {
      return CookingMethod.raw;
    }
    return null;
  }

  String get label => switch (this) {
        CookingMethod.raw => 'Crudo / Fresco',
        CookingMethod.boiled => 'Sancochado / Vapor',
        CookingMethod.grilled => 'Plancha / Asado',
        CookingMethod.stewed => 'Guisado / Saltado',
        CookingMethod.baked => 'Horno / Airfryer',
        CookingMethod.fried => 'Frito',
      };

  String get emoji => switch (this) {
        CookingMethod.raw => '🥗',
        CookingMethod.boiled => '♨️',
        CookingMethod.grilled => '🔥',
        CookingMethod.stewed => '🥘',
        CookingMethod.baked => '🥧',
        CookingMethod.fried => '🍳',
      };
}

/// Estimación nutricional de una comida evaluada (por porción servida).
class MealMacros extends Equatable {
  final int caloriesKcal;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final double fiberGrams;

  const MealMacros({
    required this.caloriesKcal,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    this.fiberGrams = 0,
  });

  MealMacros scale(double factor) {
    final f = factor.clamp(0.1, 10.0);
    return MealMacros(
      caloriesKcal: (caloriesKcal * f).round(),
      proteinGrams: double.parse((proteinGrams * f).toStringAsFixed(1)),
      carbsGrams: double.parse((carbsGrams * f).toStringAsFixed(1)),
      fatGrams: double.parse((fatGrams * f).toStringAsFixed(1)),
      fiberGrams: double.parse((fiberGrams * f).toStringAsFixed(1)),
    );
  }

  Map<String, dynamic> toJson() => {
        'kcal': caloriesKcal,
        'protein': proteinGrams,
        'carbs': carbsGrams,
        'fat': fatGrams,
        'fiber': fiberGrams,
      };

  static MealMacros? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final kcal =
        (json['kcal'] ?? json['caloriesKcal'] ?? json['calorias']) as num?;
    final protein =
        (json['protein'] ?? json['proteinGrams'] ?? json['proteinas']) as num?;
    final carbs =
        (json['carbs'] ?? json['carbsGrams'] ?? json['carbohidratos']) as num?;
    final fat = (json['fat'] ?? json['fatGrams'] ?? json['grasas']) as num?;
    final fiber =
        (json['fiber'] ?? json['fiberGrams'] ?? json['fibra']) as num?;
    if (kcal == null && protein == null && carbs == null && fat == null) {
      return null;
    }
    return MealMacros(
      caloriesKcal: (kcal?.round() ?? 0).clamp(0, 5000),
      proteinGrams: double.parse(
          ((protein?.toDouble() ?? 0.0).clamp(0.0, 400.0)).toStringAsFixed(1)),
      carbsGrams: double.parse(
          ((carbs?.toDouble() ?? 0.0).clamp(0.0, 600.0)).toStringAsFixed(1)),
      fatGrams: double.parse(
          ((fat?.toDouble() ?? 0.0).clamp(0.0, 300.0)).toStringAsFixed(1)),
      fiberGrams: double.parse(
          ((fiber?.toDouble() ?? 0.0).clamp(0.0, 150.0)).toStringAsFixed(1)),
    );
  }

  @override
  List<Object?> get props =>
      [caloriesKcal, proteinGrams, carbsGrams, fatGrams, fiberGrams];
}

class MealEvaluation extends Equatable {
  final String id;
  final DateTime timestamp;
  final String? photoPath; // path de la foto capturada (puede ser null)
  final FoodClassification classification;
  final double healthScore; // 0.0 – 1.0
  final List<String> detectedIngredients;
  final List<String> positiveFactors;
  final List<String> negativeFactors;
  final String feedback;
  final String recommendation;
  final String? mealName;
  final MealSlot mealSlot;
  final CookingMethod? cookingMethod;
  final double servings;
  final MealMacros? macros;

  const MealEvaluation({
    required this.id,
    required this.timestamp,
    this.photoPath,
    required this.classification,
    required this.healthScore,
    required this.detectedIngredients,
    required this.positiveFactors,
    required this.negativeFactors,
    required this.feedback,
    required this.recommendation,
    this.mealName,
    this.mealSlot = MealSlot.lunch,
    this.cookingMethod,
    this.servings = 1.0,
    this.macros,
  });

  @override
  List<Object?> get props => [
        id,
        timestamp,
        photoPath,
        classification,
        healthScore,
        detectedIngredients,
        positiveFactors,
        negativeFactors,
        feedback,
        recommendation,
        mealName,
        mealSlot,
        cookingMethod,
        servings,
        macros,
      ];
}

class MealLog extends Equatable {
  final String id;
  final DateTime timestamp;
  final String? photoPath;
  final FoodClassification classification;
  final double healthScore;
  final String feedback;
  final String? mealName;
  final MealSlot mealSlot;
  final CookingMethod? cookingMethod;
  final double servings;
  final List<String> detectedIngredients;
  final MealMacros? macros;

  const MealLog({
    required this.id,
    required this.timestamp,
    this.photoPath,
    required this.classification,
    required this.healthScore,
    required this.feedback,
    this.mealName,
    this.mealSlot = MealSlot.lunch,
    this.cookingMethod,
    this.servings = 1.0,
    this.detectedIngredients = const [],
    this.macros,
  });

  @override
  List<Object?> get props => [
        id,
        timestamp,
        photoPath,
        classification,
        healthScore,
        feedback,
        mealName,
        mealSlot,
        cookingMethod,
        servings,
        detectedIngredients,
        macros,
      ];
}
