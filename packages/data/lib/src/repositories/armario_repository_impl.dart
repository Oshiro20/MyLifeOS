import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:domain/domain.dart';
import 'package:data/data.dart';

class ArmarioRepository implements IArmarioRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  ArmarioRepository(this._db);

  // ── Mappers ──────────────────────────────────────────────────────────────────
  WardrobeGarment _toGarment(WardrobeGarmentEntry e) => WardrobeGarment(
        id: e.id,
        name: e.name,
        type: GarmentType
            .values[e.typeIndex.clamp(0, GarmentType.values.length - 1)],
        primaryColor: e.primaryColor,
        secondaryColor: e.secondaryColor,
        style: GarmentStyle
            .values[e.styleIndex.clamp(0, GarmentStyle.values.length - 1)],
        material: e.material,
        season: _parseSeason(e.season),
        isFavorite: e.isFavorite,
        isClean: e.isClean,
        timesWorn: e.timesWorn,
        hasRemovableHood: e.hasRemovableHood,
        rating: e.rating,
        size: e.size,
        brand: e.brand,
        price: e.price,
        imageAssetId: e.imageAssetId,
        imageDetailsPath: e.imageDetailsPath,
        addedAt: e.addedAt,
      );

  Outfit _toOutfit(OutfitEntry e) => Outfit(
        id: e.id,
        name: e.name,
        garmentIds: e.garmentIdsCsv.isEmpty ? [] : e.garmentIdsCsv.split(','),
        occasion: e.occasion,
        season: _parseSeason(e.season),
        timesWorn: e.timesWorn,
        createdAt: e.createdAt,
      );

  UserPhysicalProfile _toProfile(UserProfileEntry e) => UserPhysicalProfile(
        id: e.id,
        skinTone: e.skinTone,
        bodyType: e.bodyType,
        height: e.height,
        weight: e.weight,
        hairType: e.hairType,
        colorimetry: e.colorimetry,
        bodyShape: e.bodyShape,
        consentGranted: e.consentGranted,
        updatedAt: e.updatedAt,
      );

  Season _parseSeason(String s) =>
      Season.values.firstWhere((e) => e.name == s, orElse: () => Season.all);

  // ── Prendas ──────────────────────────────────────────────────────────────────
  @override
  Future<List<WardrobeGarment>> getAllGarments() async {
    final entries = await _db.select(_db.wardrobeGarments).get();
    return entries.map(_toGarment).toList();
  }

  @override
  Future<WardrobeGarment> addGarment(WardrobeGarment g) async {
    final id = g.id.isEmpty ? _uuid.v4() : g.id;
    final now = DateTime.now();
    await _db.into(_db.wardrobeGarments).insert(WardrobeGarmentsCompanion(
          id: Value(id),
          name: Value(g.name),
          typeIndex: Value(g.type.index),
          primaryColor: Value(g.primaryColor),
          secondaryColor: Value(g.secondaryColor),
          styleIndex: Value(g.style.index),
          material: Value(g.material),
          season: Value(g.season.name),
          isFavorite: Value(g.isFavorite),
          isClean: Value(g.isClean),
          timesWorn: Value(g.timesWorn),
          hasRemovableHood: Value(g.hasRemovableHood),
          rating: Value(g.rating),
          size: Value(g.size),
          brand: Value(g.brand),
          price: Value(g.price),
          imageAssetId: Value(g.imageAssetId),
          imageDetailsPath: Value(g.imageDetailsPath),
          addedAt: Value(now),
        ));
    return g.copyWith(id: id, addedAt: now);
  }

  @override
  Future<void> updateGarment(WardrobeGarment g) async {
    await (_db.update(_db.wardrobeGarments)..where((t) => t.id.equals(g.id)))
        .write(WardrobeGarmentsCompanion(
      name: Value(g.name),
      typeIndex: Value(g.type.index),
      primaryColor: Value(g.primaryColor),
      secondaryColor: Value(g.secondaryColor),
      styleIndex: Value(g.style.index),
      material: Value(g.material),
      season: Value(g.season.name),
      isFavorite: Value(g.isFavorite),
      isClean: Value(g.isClean),
      timesWorn: Value(g.timesWorn),
      hasRemovableHood: Value(g.hasRemovableHood),
      rating: Value(g.rating),
      size: Value(g.size),
      brand: Value(g.brand),
      price: Value(g.price),
      imageAssetId: Value(g.imageAssetId),
      imageDetailsPath: Value(g.imageDetailsPath),
    ));
  }

  @override
  Future<void> deleteGarment(String id) async {
    final existing = await (_db.select(_db.wardrobeGarments)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    await (_db.delete(_db.wardrobeGarments)..where((t) => t.id.equals(id)))
        .go();
    await AppDatabase.deleteLocalFileIfPresent(existing?.imageAssetId);
    await AppDatabase.deleteLocalFileIfPresent(existing?.imageDetailsPath);
  }

  @override
  Future<void> toggleClean(String id) async {
    final q = await (_db.select(_db.wardrobeGarments)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (q == null) return;
    await (_db.update(_db.wardrobeGarments)..where((t) => t.id.equals(id)))
        .write(WardrobeGarmentsCompanion(isClean: Value(!q.isClean)));
  }

  @override
  Future<void> toggleFavorite(String id) async {
    final q = await (_db.select(_db.wardrobeGarments)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (q == null) return;
    await (_db.update(_db.wardrobeGarments)..where((t) => t.id.equals(id)))
        .write(WardrobeGarmentsCompanion(isFavorite: Value(!q.isFavorite)));
  }

  // ── Outfits ──────────────────────────────────────────────────────────────────
  @override
  Future<List<Outfit>> getAllOutfits() async {
    final entries = await _db.select(_db.outfits).get();
    return entries.map(_toOutfit).toList();
  }

  @override
  Future<Outfit> saveOutfit(Outfit o) async {
    final id = o.id.isEmpty ? _uuid.v4() : o.id;
    await _db.into(_db.outfits).insertOnConflictUpdate(OutfitsCompanion(
          id: Value(id),
          name: Value(o.name),
          garmentIdsCsv: Value(o.garmentIds.join(',')),
          occasion: Value(o.occasion),
          season: Value(o.season.name),
          timesWorn: Value(o.timesWorn),
          createdAt: Value(o.createdAt),
        ));
    return Outfit(
        id: id,
        name: o.name,
        garmentIds: o.garmentIds,
        occasion: o.occasion,
        season: o.season,
        timesWorn: o.timesWorn,
        createdAt: o.createdAt);
  }

  @override
  Future<void> deleteOutfit(String id) async =>
      (_db.delete(_db.outfits)..where((t) => t.id.equals(id))).go();

  @override
  Future<void> incrementTimesWorn(String id) async {
    await _db.transaction(() async {
      final q = await (_db.select(_db.outfits)..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (q == null) return;
      await (_db.update(_db.outfits)..where((t) => t.id.equals(id))).write(
        OutfitsCompanion(
          timesWorn: Value(q.timesWorn + 1),
          lastWornDate: Value(DateTime.now()),
        ),
      );

      final garmentIds =
          q.garmentIdsCsv.split(',').where((e) => e.trim().isNotEmpty);
      for (final gId in garmentIds) {
        final g = await (_db.select(_db.wardrobeGarments)
              ..where((t) => t.id.equals(gId)))
            .getSingleOrNull();
        if (g != null) {
          await (_db.update(_db.wardrobeGarments)
                ..where((t) => t.id.equals(gId)))
              .write(WardrobeGarmentsCompanion(timesWorn: Value(g.timesWorn + 1)));
        }
      }
    });
  }

  // ── Sugerencias (color matching offline) ────────────────────────────────────
  @override
  Future<List<List<WardrobeGarment>>> suggestOutfits({
    String? occasion,
    Season? season,
    int limit = 5,
  }) async {
    final all = await getAllGarments();
    final clean = all.where((g) {
      if (!g.isClean) return false;
      if (season != null &&
          season != Season.all &&
          g.season != Season.all &&
          g.season != season) {
        return false;
      }
      return true;
    }).toList();

    const topTypes = {
      GarmentType.shirt,
      GarmentType.tshirt,
      GarmentType.polo,
      GarmentType.sweater,
      GarmentType.hoodie,
      GarmentType.jacket,
    };
    const bottomTypes = {
      GarmentType.pants,
      GarmentType.jeans,
      GarmentType.shorts,
      GarmentType.skirt,
    };
    const shoeTypes = {
      GarmentType.shoes,
      GarmentType.sneakers,
      GarmentType.boots,
      GarmentType.sandals,
    };

    final preferredStyles = _preferredStylesForOccasion(occasion);
    int styleScore(WardrobeGarment g) => preferredStyles.contains(g.style) ? 0 : 1;

    final tops = clean.where((g) => topTypes.contains(g.type)).toList()
      ..sort((a, b) => styleScore(a).compareTo(styleScore(b)));
    final bottoms = clean.where((g) => bottomTypes.contains(g.type)).toList()
      ..sort((a, b) => styleScore(a).compareTo(styleScore(b)));
    final dresses = clean.where((g) => g.type == GarmentType.dress).toList()
      ..sort((a, b) => styleScore(a).compareTo(styleScore(b)));
    final shoes = clean.where((g) => shoeTypes.contains(g.type)).toList()
      ..sort((a, b) => styleScore(a).compareTo(styleScore(b)));

    final suggestions = <List<WardrobeGarment>>[];

    for (final top in tops) {
      for (final bottom in bottoms) {
        if (!_colorsCompatible(top.primaryColor, bottom.primaryColor)) continue;
        final shoe = shoes.isNotEmpty
            ? shoes[suggestions.length % shoes.length]
            : null;
        final combo = shoe != null ? [top, bottom, shoe] : [top, bottom];
        suggestions.add(combo);
        if (suggestions.length >= limit) return suggestions;
      }
    }
    for (final dress in dresses) {
      final shoe = shoes.isNotEmpty
          ? shoes[suggestions.length % shoes.length]
          : null;
      suggestions.add(shoe != null ? [dress, shoe] : [dress]);
      if (suggestions.length >= limit) return suggestions;
    }
    return suggestions;
  }

  Set<GarmentStyle> _preferredStylesForOccasion(String? occasion) {
    switch (occasion?.toLowerCase()) {
      case 'trabajo':
      case 'work':
      case 'formal':
        return {
          GarmentStyle.formal,
          GarmentStyle.elegant,
          GarmentStyle.smartCasual,
          GarmentStyle.workwear,
        };
      case 'deporte':
      case 'sport':
        return {GarmentStyle.sport};
      case 'fiesta':
      case 'party':
        return {GarmentStyle.elegant, GarmentStyle.streetwear};
      case 'cita':
        return {GarmentStyle.elegant, GarmentStyle.casual};
      default:
        return {
          GarmentStyle.casual,
          GarmentStyle.streetwear,
          GarmentStyle.smartCasual,
        };
    }
  }

  bool _colorsCompatible(String a, String b) {
    // Neutros: blanco, negro, gris, beige, navy
    const neutrals = {
      '#FFFFFF',
      '#000000',
      '#808080',
      '#F5F5DC',
      '#003153',
      '#FFFAFA',
      '#1C1C1C',
      '#D3D3D3',
      '#FAEBD7',
      '#9E9E9E'
    };
    if (neutrals.contains(a.toUpperCase()) ||
        neutrals.contains(b.toUpperCase())) {
      return true;
    }
    // Si son iguales o muy similares, evitar
    if (a.toLowerCase() == b.toLowerCase()) return false;
    return true; // Heurística simple; se mejorará con IA en Fase 9
  }

  // ── Perfil del usuario ────────────────────────────────────────────────────
  @override
  Future<UserPhysicalProfile?> getUserProfile() async {
    final entries = await _db.select(_db.userProfile).get();
    return entries.isNotEmpty ? _toProfile(entries.first) : null;
  }

  @override
  Future<void> saveUserProfile(UserPhysicalProfile p) async {
    final id = p.id.isEmpty ? 'user_profile_singleton' : p.id;
    await _db.into(_db.userProfile).insertOnConflictUpdate(UserProfileCompanion(
          id: Value(id),
          skinTone: Value(p.skinTone),
          bodyType: Value(p.bodyType),
          height: Value(p.height),
          weight: Value(p.weight),
          hairType: Value(p.hairType),
          colorimetry: Value(p.colorimetry),
          bodyShape: Value(p.bodyShape),
          consentGranted: Value(p.consentGranted),
          updatedAt: Value(DateTime.now()),
        ));
  }

  @override
  Future<void> deleteUserProfile() async => _db.delete(_db.userProfile).go();
}
