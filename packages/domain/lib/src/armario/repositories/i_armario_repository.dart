import '../entities/wardrobe_garment.dart';

abstract interface class IArmarioRepository {
  // ── Prendas ──────────────────────────────────────────────────────────────────
  Future<List<WardrobeGarment>> getAllGarments();
  Future<WardrobeGarment> addGarment(WardrobeGarment garment);
  Future<void> updateGarment(WardrobeGarment garment);
  Future<void> deleteGarment(String id);
  Future<void> toggleClean(String id);
  Future<void> toggleFavorite(String id);

  // ── Outfits ──────────────────────────────────────────────────────────────────
  Future<List<Outfit>> getAllOutfits();
  Future<Outfit> saveOutfit(Outfit outfit);
  Future<void> deleteOutfit(String id);
  Future<void> incrementTimesWorn(String outfitId);

  // ── Sugerencias de outfit ─────────────────────────────────────────────────
  Future<List<List<WardrobeGarment>>> suggestOutfits({
    String? occasion,
    Season? season,
    int limit = 5,
  });

  // ── Perfil del usuario ────────────────────────────────────────────────────
  Future<UserPhysicalProfile?> getUserProfile();
  Future<void> saveUserProfile(UserPhysicalProfile profile);
  Future<void> deleteUserProfile();
}
