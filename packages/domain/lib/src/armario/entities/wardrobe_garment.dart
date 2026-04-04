import 'package:equatable/equatable.dart';

enum GarmentType {
  shirt,
  tshirt,
  pants,
  jeans,
  shoes,
  jacket,
  accessories,
  dress,
  shorts,
  sweater,
  hoodie,
  skirt,
  other,
  polo,
  sneakers,
  boots,
  sandals;

  String get label {
    const labels = {
      shirt: 'Camisa',
      tshirt: 'Camiseta (Deportiva/Interior)',
      pants: 'Pantalón',
      jeans: 'Jeans',
      shoes: 'Zapatos/Calzado Formal',
      jacket: 'Chaqueta',
      accessories: 'Accesorios',
      dress: 'Vestido',
      shorts: 'Shorts',
      sweater: 'Suéter',
      hoodie: 'Polera/Hoodie',
      skirt: 'Falda',
      other: 'Otro',
      polo: 'Polo (Cuello/Casual)',
      sneakers: 'Zapatillas/Sneakers',
      boots: 'Botas',
      sandals: 'Sandalias',
    };
    return labels[this] ?? name;
  }
}

enum GarmentStyle {
  casual,
  formal,
  sport,
  streetwear,
  elegant,
  smartCasual,
  workwear;

  String get label {
    const labels = {
      casual: 'Casual',
      formal: 'Formal',
      sport: 'Deportivo',
      streetwear: 'Urbano',
      elegant: 'Elegante',
      smartCasual: 'Smart Casual / Semi-Formal',
      workwear: 'Útiles / Trabajo / Drill',
    };
    return labels[this] ?? name;
  }
}

enum Season {
  all,
  spring,
  summer,
  autumn,
  winter;

  String get label {
    const labels = {
      all: 'Todo el año',
      spring: 'Primavera',
      summer: 'Verano',
      autumn: 'Otoño',
      winter: 'Invierno',
    };
    return labels[this] ?? name;
  }
}

class WardrobeGarment extends Equatable {
  final String id;
  final String name;
  final GarmentType type;
  final String primaryColor;
  final String secondaryColor;
  final GarmentStyle style;
  final String material;
  final Season season;
  final bool isFavorite;
  final bool isClean;
  final bool hasRemovableHood;
  final int rating;
  final String? size;
  final String? brand;
  final double? price;
  final String? imageAssetId;
  final String? imageDetailsPath;
  final DateTime addedAt;

  const WardrobeGarment({
    required this.id,
    required this.name,
    required this.type,
    required this.primaryColor,
    this.secondaryColor = '',
    this.style = GarmentStyle.casual,
    this.material = '',
    this.season = Season.all,
    this.isFavorite = false,
    this.isClean = true,
    this.hasRemovableHood = false,
    this.rating = 0,
    this.size,
    this.brand,
    this.price,
    this.imageAssetId,
    this.imageDetailsPath,
    required this.addedAt,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        primaryColor,
        secondaryColor,
        style,
        material,
        season,
        isFavorite,
        isClean,
        hasRemovableHood,
        rating,
        size,
        brand,
        price,
        imageAssetId,
        imageDetailsPath,
        addedAt
      ];
}

class Outfit extends Equatable {
  final String id;
  final String name;
  final List<String> garmentIds;
  final String occasion;
  final Season season;
  final int timesWorn;
  final DateTime createdAt;

  const Outfit({
    required this.id,
    required this.name,
    required this.garmentIds,
    this.occasion = 'casual',
    this.season = Season.all,
    this.timesWorn = 0,
    required this.createdAt,
  });

  @override
  List<Object?> get props =>
      [id, name, garmentIds, occasion, season, timesWorn, createdAt];
}

class UserPhysicalProfile extends Equatable {
  final String id;
  final String? skinTone;
  final String? bodyType; // delgado, atlético, promedio, robusto
  final String? height; // ej: "170"
  final String? weight; // ej: "70"
  final String? hairType;
  final String? colorimetry;
  final String? bodyShape;
  final bool consentGranted;
  final DateTime updatedAt;

  const UserPhysicalProfile({
    required this.id,
    this.skinTone,
    this.bodyType,
    this.height,
    this.weight,
    this.hairType,
    this.colorimetry,
    this.bodyShape,
    this.consentGranted = false,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        skinTone,
        bodyType,
        height,
        weight,
        hairType,
        colorimetry,
        bodyShape,
        consentGranted,
        updatedAt
      ];
}
