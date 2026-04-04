import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:domain/domain.dart';

/// Resultado de análisis de una prenda.
class GarmentSuggestion {
  final String? suggestedName;
  final GarmentType? type;
  final GarmentStyle? style;
  final String? material;
  final Season? season;
  final String? colorHex;

  const GarmentSuggestion({
    this.suggestedName,
    this.type,
    this.style,
    this.material,
    this.season,
    this.colorHex,
  });
}

/// Motor offline de análisis de prendas basado en diccionarios.
class GarmentAnalyzer {
  // ── Auto-detectar tipo por nombre ────────────────────────────────────────────
  static GarmentSuggestion analyzeByName(String name) {
    final lower = name.trim().toLowerCase();

    GarmentType? type;
    GarmentStyle? style;
    String? material;
    Season? season;

    // Tipo de prenda
    for (final entry in _nameToType.entries) {
      if (lower.contains(entry.key)) {
        type = entry.value;
        break;
      }
    }

    // Material sugerido
    for (final entry in _nameToMaterial.entries) {
      if (lower.contains(entry.key)) {
        material = entry.value;
        break;
      }
    }
    material ??= _typeDefaultMaterial[type];

    // Estilo
    for (final entry in _nameToStyle.entries) {
      if (lower.contains(entry.key)) {
        style = entry.value;
        break;
      }
    }
    style ??= _typeDefaultStyle[type];

    // Temporada
    for (final entry in _nameToSeason.entries) {
      if (lower.contains(entry.key)) {
        season = entry.value;
        break;
      }
    }
    season ??= _typeDefaultSeason[type];

    return GarmentSuggestion(
      type: type,
      style: style,
      material: material,
      season: season,
    );
  }

  // ── Extraer color dominante de foto ──────────────────────────────────────────
  static Future<String?> extractColorFromPhoto(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      int r = 0, g = 0, b = 0, count = 0;
      const step = 8;
      // Analizar la zona central (donde suele estar la prenda)
      final startY = image.height ~/ 4;
      final endY = (image.height * 3) ~/ 4;
      final startX = image.width ~/ 4;
      final endX = (image.width * 3) ~/ 4;

      for (int y = startY; y < endY; y += step) {
        for (int x = startX; x < endX; x += step) {
          final pixel = image.getPixel(x, y);
          r += pixel.r.toInt();
          g += pixel.g.toInt();
          b += pixel.b.toInt();
          count++;
        }
      }
      if (count == 0) return null;

      final hex = '#${(r ~/ count).toRadixString(16).padLeft(2, '0')}'
          '${(g ~/ count).toRadixString(16).padLeft(2, '0')}'
          '${(b ~/ count).toRadixString(16).padLeft(2, '0')}';
      return hex.toUpperCase();
    } catch (_) {
      return null;
    }
  }

  // ── Diccionarios ────────────────────────────────────────────────────────────
  static const _nameToType = <String, GarmentType>{
    'camisa': GarmentType.shirt,
    'blusa': GarmentType.shirt,
    'polo': GarmentType.tshirt,
    'camiseta': GarmentType.tshirt,
    'playera': GarmentType.tshirt,
    't-shirt': GarmentType.tshirt,
    'pantalón': GarmentType.pants,
    'pantalon': GarmentType.pants,
    'jean': GarmentType.jeans,
    'vaquero': GarmentType.jeans,
    'denim': GarmentType.jeans,
    'zapato': GarmentType.shoes,
    'zapatilla': GarmentType.shoes,
    'tenis': GarmentType.shoes,
    'bota': GarmentType.shoes,
    'sandalia': GarmentType.shoes,
    'chaqueta': GarmentType.jacket,
    'casaca': GarmentType.jacket,
    'abrigo': GarmentType.jacket,
    'chamarra': GarmentType.jacket,
    'saco': GarmentType.jacket,
    'blazer': GarmentType.jacket,
    'chaleco': GarmentType.jacket,
    'vestido': GarmentType.dress,
    'falda': GarmentType.skirt,
    'short': GarmentType.shorts,
    'bermuda': GarmentType.shorts,
    'suéter': GarmentType.sweater,
    'sueter': GarmentType.sweater,
    'chompa': GarmentType.sweater,
    'buzo': GarmentType.hoodie,
    'hoodie': GarmentType.hoodie,
    'polera': GarmentType.hoodie,
    'sudadera': GarmentType.hoodie,
    'gorra': GarmentType.accessories,
    'sombrero': GarmentType.accessories,
    'bufanda': GarmentType.accessories,
    'cinturón': GarmentType.accessories,
    'cinturon': GarmentType.accessories,
    'reloj': GarmentType.accessories,
    'collar': GarmentType.accessories,
    'pulsera': GarmentType.accessories,
    'anillo': GarmentType.accessories,
    'lente': GarmentType.accessories,
    'corbata': GarmentType.accessories,
  };

  static const _nameToMaterial = <String, String>{
    'algodón': 'Algodón',
    'algodon': 'Algodón',
    'seda': 'Seda',
    'lana': 'Lana',
    'cuero': 'Cuero',
    'denim': 'Denim',
    'jean': 'Denim',
    'nylon': 'Nylon',
    'poliéster': 'Poliéster',
    'poliester': 'Poliéster',
    'lino': 'Lino',
    'gamuza': 'Gamuza',
    'terciopelo': 'Terciopelo',
  };

  static const _typeDefaultMaterial = <GarmentType, String>{
    GarmentType.shirt: 'Algodón',
    GarmentType.tshirt: 'Algodón',
    GarmentType.pants: 'Algodón',
    GarmentType.jeans: 'Denim',
    GarmentType.shoes: 'Cuero sintético',
    GarmentType.jacket: 'Poliéster',
    GarmentType.dress: 'Algodón',
    GarmentType.sweater: 'Lana',
    GarmentType.hoodie: 'Algodón / Poliéster',
    GarmentType.shorts: 'Algodón',
    GarmentType.skirt: 'Algodón',
  };

  static const _nameToStyle = <String, GarmentStyle>{
    'formal': GarmentStyle.formal,
    'elegante': GarmentStyle.elegant,
    'blazer': GarmentStyle.formal,
    'saco': GarmentStyle.formal,
    'corbata': GarmentStyle.formal,
    'deportivo': GarmentStyle.sport,
    'sport': GarmentStyle.sport,
    'tenis': GarmentStyle.sport,
    'running': GarmentStyle.sport,
    'urbano': GarmentStyle.streetwear,
    'street': GarmentStyle.streetwear,
  };

  static const _typeDefaultStyle = <GarmentType, GarmentStyle>{
    GarmentType.shirt: GarmentStyle.casual,
    GarmentType.tshirt: GarmentStyle.casual,
    GarmentType.jeans: GarmentStyle.casual,
    GarmentType.hoodie: GarmentStyle.streetwear,
    GarmentType.sweater: GarmentStyle.casual,
    GarmentType.shoes: GarmentStyle.casual,
    GarmentType.dress: GarmentStyle.elegant,
  };

  static const _nameToSeason = <String, Season>{
    'abrigo': Season.winter,
    'lana': Season.winter,
    'chompa': Season.winter,
    'bufanda': Season.winter,
    'sandalia': Season.summer,
    'bermuda': Season.summer,
  };

  static const _typeDefaultSeason = <GarmentType, Season>{
    GarmentType.jacket: Season.winter,
    GarmentType.sweater: Season.winter,
    GarmentType.hoodie: Season.autumn,
    GarmentType.shorts: Season.summer,
  };
}
