import 'package:equatable/equatable.dart';

enum GarmentType {
  shirt,
  tshirt,
  pants,
  jeans,
  shoes,
  jacket,
  accessories,
  other,
}

enum GarmentStyle {
  casual,
  formal,
  sport,
  streetwear,
}

class Garment extends Equatable {
  final String id;
  final String imageUrl;
  final GarmentType type;
  final String primaryColor;
  final String secondaryColor;
  final GarmentStyle style;
  final bool isFavorite;

  const Garment({
    required this.id,
    required this.imageUrl,
    required this.type,
    required this.primaryColor,
    this.secondaryColor = '',
    required this.style,
    this.isFavorite = false,
  });

  @override
  List<Object?> get props => [
        id,
        imageUrl,
        type,
        primaryColor,
        secondaryColor,
        style,
        isFavorite,
      ];
}
