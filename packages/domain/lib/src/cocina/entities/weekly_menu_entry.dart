import 'package:equatable/equatable.dart';

/// Entrada del menú semanal de Cocina (desacoplada de la capa de datos Drift).
class WeeklyMenuEntry extends Equatable {
  final String id;
  final int dayOfWeek;
  final int mealType;
  final String recipeId;
  final bool isCustom;

  const WeeklyMenuEntry({
    required this.id,
    required this.dayOfWeek,
    required this.mealType,
    required this.recipeId,
    this.isCustom = false,
  });

  WeeklyMenuEntry copyWith({
    String? id,
    int? dayOfWeek,
    int? mealType,
    String? recipeId,
    bool? isCustom,
  }) =>
      WeeklyMenuEntry(
        id: id ?? this.id,
        dayOfWeek: dayOfWeek ?? this.dayOfWeek,
        mealType: mealType ?? this.mealType,
        recipeId: recipeId ?? this.recipeId,
        isCustom: isCustom ?? this.isCustom,
      );

  @override
  List<Object?> get props => [id, dayOfWeek, mealType, recipeId, isCustom];
}
