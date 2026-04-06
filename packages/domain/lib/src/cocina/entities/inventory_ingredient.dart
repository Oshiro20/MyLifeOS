import 'package:equatable/equatable.dart';
export 'ingredient.dart';

class InventoryIngredient extends Equatable {
  final String id;
  final String name;
  final String primaryCategory;
  final String? subCategory;
  final String
      preparation; // "entero", "licuado", "molido", "fresco", "picado", etc.
  final double quantity;
  final String unit;
  final DateTime? expirationDate;
  final String? imageAssetId;
  final String? storageArea; // e.g. "Alacena", "Refrigerador", "Congelador"

  const InventoryIngredient({
    required this.id,
    required this.name,
    required this.primaryCategory,
    this.subCategory,
    this.preparation = '',
    required this.quantity,
    required this.unit,
    this.expirationDate,
    this.imageAssetId,
    this.storageArea,
  });

  /// Display name includes preparation if available
  String get displayName {
    if (preparation.isNotEmpty) {
      return '$name ($preparation)';
    }
    return name;
  }

  bool get isExpiringSoon {
    if (expirationDate == null) return false;
    return expirationDate!.difference(DateTime.now()).inDays <= 3;
  }

  bool get isExpired {
    if (expirationDate == null) return false;
    return expirationDate!.isBefore(DateTime.now());
  }

  @override
  List<Object?> get props => [
        id,
        name,
        primaryCategory,
        subCategory,
        preparation,
        quantity,
        unit,
        expirationDate,
        imageAssetId,
        storageArea
      ];
}

class ShoppingItem extends Equatable {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final bool bought;
  final DateTime createdAt;

  const ShoppingItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.bought = false,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, name, quantity, unit, bought, createdAt];
}
