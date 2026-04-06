import 'package:equatable/equatable.dart';

/// User food preferences - ingredients they don't like
class UserFoodPreferences extends Equatable {
  /// Ingredients the user doesn't like (will be avoided/replaced in recipes)
  final List<String> dislikedIngredients;

  /// Dietary restrictions
  final List<String> dietaryRestrictions;

  const UserFoodPreferences({
    this.dislikedIngredients = const [],
    this.dietaryRestrictions = const [],
  });

  UserFoodPreferences copyWith({
    List<String>? dislikedIngredients,
    List<String>? dietaryRestrictions,
  }) =>
      UserFoodPreferences(
        dislikedIngredients: dislikedIngredients ?? this.dislikedIngredients,
        dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      );

  @override
  List<Object?> get props => [dislikedIngredients, dietaryRestrictions];
}
