import 'package:equatable/equatable.dart';

/// Optional user preferences for Chef IA personalization
/// These are filled gradually as the user answers optional questions
class ChefPreferences extends Equatable {
  /// Favorite categories (user can select which types of food they like)
  final List<String> favoriteCategories;
  
  /// Spiciness preference
  final String? spiceLevel; // suave, medio, picante
  
  /// Portion size preference
  final String? portionSize; // pequeña, normal, grande
  
  /// Dietary restrictions
  final List<String> dietaryRestrictions;
  
  /// Whether user wants soup with lunch
  final bool? wantsSoup;
  
  /// Whether user wants dessert with lunch
  final bool? wantsDessert;
  
  /// Whether user wants drink with lunch
  final bool? wantsDrink;
  
  /// Number of people typically cooking for
  final int? typicalServings;
  
  /// Has the user completed the optional onboarding?
  final bool hasCompletedOnboarding;

  const ChefPreferences({
    this.favoriteCategories = const [],
    this.spiceLevel,
    this.portionSize,
    this.dietaryRestrictions = const [],
    this.wantsSoup,
    this.wantsDessert,
    this.wantsDrink,
    this.typicalServings,
    this.hasCompletedOnboarding = false,
  });

  ChefPreferences copyWith({
    List<String>? favoriteCategories,
    String? spiceLevel,
    String? portionSize,
    List<String>? dietaryRestrictions,
    bool? wantsSoup,
    bool? wantsDessert,
    bool? wantsDrink,
    int? typicalServings,
    bool? hasCompletedOnboarding,
  }) =>
      ChefPreferences(
        favoriteCategories: favoriteCategories ?? this.favoriteCategories,
        spiceLevel: spiceLevel ?? this.spiceLevel,
        portionSize: portionSize ?? this.portionSize,
        dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
        wantsSoup: wantsSoup ?? this.wantsSoup,
        wantsDessert: wantsDessert ?? this.wantsDessert,
        wantsDrink: wantsDrink ?? this.wantsDrink,
        typicalServings: typicalServings ?? this.typicalServings,
        hasCompletedOnboarding:
            hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      );

  /// Returns true if user has any preferences set
  bool get hasAnyPreferences =>
      favoriteCategories.isNotEmpty ||
      spiceLevel != null ||
      portionSize != null ||
      dietaryRestrictions.isNotEmpty ||
      wantsSoup != null ||
      wantsDessert != null ||
      wantsDrink != null ||
      typicalServings != null;

  @override
  List<Object?> get props => [
        favoriteCategories,
        spiceLevel,
        portionSize,
        dietaryRestrictions,
        wantsSoup,
        wantsDessert,
        wantsDrink,
        typicalServings,
        hasCompletedOnboarding,
      ];
}
