import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:domain/src/armario/entities/wardrobe_garment.dart';
import 'package:domain/src/armario/repositories/i_armario_repository.dart';
import 'package:data/src/local/database.dart';

class ArmarioRepository implements IArmarioRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  ArmarioRepository(this._db);

  // ── Mappers ──────────────────────────────────────────────────────────────────
  WardrobeGarment _toGarment(WardrobeGarmentEntry e) => WardrobeGarment(
        id: e.id,
        name: e.name,
        type: GarmentType.values[e.typeIndex],
        primaryColor: e.primaryColor,
        secondaryColor: e.secondaryColor,
        style: GarmentStyle.values[e.styleIndex],
        material: e.material,
        season: _parseSeason(e.season),
        isFavorite: e.isFavorite,
        isClean: e.isClean,
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
          hasRemovableHood: Value(g.hasRemovableHood),
          rating: Value(g.rating),
          size: Value(g.size),
          brand: Value(g.brand),
          price: Value(g.price),
          imageAssetId: Value(g.imageAssetId),
          imageDetailsPath: Value(g.imageDetailsPath),
          addedAt: Value(now),
        ));
    return WardrobeGarment(
      id: id, name: g.name, type: g.type,
      primaryColor: g.primaryColor, secondaryColor: g.secondaryColor,
      style: g.style, material: g.material, season: g.season,
      isFavorite: g.isFavorite, isClean: g.isClean, hasRemovableHood: g.hasRemovableHood,
      rating: g.rating, size: g.size, brand: g.brand, price: g.price,
      imageAssetId: g.imageAssetId, imageDetailsPath: g.imageDetailsPath, addedAt: now,
    );
  }

  @override
  Future<void> updateGarment(WardrobeGarment g) async {
    await (_db.update(_db.wardrobeGarments)
          ..where((t) => t.id.equals(g.id)))
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
    await (_db.delete(_db.wardrobeGarments)..where((t) => t.id.equals(id))).go();
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
    return Outfit(id: id, name: o.name, garmentIds: o.garmentIds,
        occasion: o.occasion, season: o.season, createdAt: o.createdAt);
  }

  @override
  Future<void> deleteOutfit(String id) async =>
      (_db.delete(_db.outfits)..where((t) => t.id.equals(id))).go();

  @override
  Future<void> incrementTimesWorn(String id) async {
    final q = await (_db.select(_db.outfits)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (q == null) return;
    await (_db.update(_db.outfits)..where((t) => t.id.equals(id)))
        .write(OutfitsCompanion(timesWorn: Value(q.timesWorn + 1)));
  }

  // ── Sugerencias (color matching offline) ────────────────────────────────────
  @override
  Future<List<List<WardrobeGarment>>> suggestOutfits({
    String? occasion,
    Season? season,
    int limit = 5,
  }) async {
    final all = await getAllGarments();
    final clean = all.where((g) => g.isClean).toList();

    final tops = clean.where((g) =>
        g.type == GarmentType.shirt ||
        g.type == GarmentType.tshirt).toList();
    final bottoms = clean.where((g) =>
        g.type == GarmentType.pants ||
        g.type == GarmentType.jeans).toList();
    final shoes = clean.where((g) => g.type == GarmentType.shoes).toList();

    final suggestions = <List<WardrobeGarment>>[];

    for (final top in tops) {
      for (final bottom in bottoms) {
        // Color compatibility: neutros combinan con todo, complementarios se priorizan
        if (!_colorsCompatible(top.primaryColor, bottom.primaryColor)) continue;
        final shoe = shoes.isNotEmpty ? shoes.first : null;
        final combo = [top, bottom, ?shoe];
        suggestions.add(combo);
        if (suggestions.length >= limit) return suggestions;
      }
    }
    return suggestions;
  }

  bool _colorsCompatible(String a, String b) {
    // Neutros: blanco, negro, gris, beige, navy
    const neutrals = {'#FFFFFF', '#000000', '#808080', '#F5F5DC', '#003153',
        '#FFFAFA', '#1C1C1C', '#D3D3D3', '#FAEBD7', '#9E9E9E'};
    if (neutrals.contains(a.toUpperCase()) || neutrals.contains(b.toUpperCase())) {
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
  Future<void> deleteUserProfile() async =>
      _db.delete(_db.userProfile).go();
}
