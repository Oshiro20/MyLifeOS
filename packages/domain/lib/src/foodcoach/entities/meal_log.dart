import 'package:equatable/equatable.dart';

enum MealClassification {
  healthy,
  junk,
  balanced,
  unknown,
}

class MealLog extends Equatable {
  final String id;
  final DateTime timestamp;
  final String photoPath;
  final MealClassification classification;
  final String feedback;
  final List<String> detectedIngredients;

  const MealLog({
    required this.id,
    required this.timestamp,
    required this.photoPath,
    required this.classification,
    required this.feedback,
    this.detectedIngredients = const [],
  });

  @override
  List<Object?> get props => [
        id,
        timestamp,
        photoPath,
        classification,
        feedback,
        detectedIngredients,
      ];
}
