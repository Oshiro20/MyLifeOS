import 'package:equatable/equatable.dart';

enum IngredientCategory {
  fruit, vegetable, protein, dairy, grain, spice, beverage, oil, canned, other;

  String get label {
    const labels = {
      fruit: 'Fruta',
      vegetable: 'Verdura',
      protein: 'Proteína',
      dairy: 'Lácteo',
      grain: 'Cereal / Grano',
      spice: 'Condimento',
      beverage: 'Bebida',
      oil: 'Aceite / Grasa',
      canned: 'Enlatado',
      other: 'Otro',
    };
    return labels[this] ?? name;
  }
}

class Ingredient extends Equatable {
  final String id;
  final String name;
  final IngredientCategory category;
  final double quantity;
  final String unit;
  final DateTime? expirationDate;

  const Ingredient({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    this.expirationDate,
  });

  @override
  List<Object?> get props => [
        id, name, category, quantity, unit, expirationDate,
      ];
}
