import 'package:equatable/equatable.dart';

enum FoodClassification {
  healthy,   // Saludable 💚
  balanced,  // Balanceado 💛
  junk,      // Chatarra 🔴
}

class MealEvaluation extends Equatable {
  final String id;
  final DateTime timestamp;
  final String? photoPath;          // path de la foto capturada (puede ser null)
  final FoodClassification classification;
  final double healthScore;         // 0.0 – 1.0
  final List<String> detectedIngredients;
  final List<String> positiveFactors;
  final List<String> negativeFactors;
  final String feedback;
  final String recommendation;

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
  });

  @override
  List<Object?> get props => [
    id, timestamp, photoPath, classification,
    healthScore, detectedIngredients, positiveFactors,
    negativeFactors, feedback, recommendation,
  ];
}

class MealLog extends Equatable {
  final String id;
  final DateTime timestamp;
  final String? photoPath;
  final FoodClassification classification;
  final double healthScore;
  final String feedback;

  const MealLog({
    required this.id,
    required this.timestamp,
    this.photoPath,
    required this.classification,
    required this.healthScore,
    required this.feedback,
  });

  @override
  List<Object?> get props => [id, timestamp, photoPath, classification, healthScore, feedback];
}
