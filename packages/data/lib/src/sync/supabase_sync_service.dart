import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:domain/domain.dart';
import 'package:data/src/local/database.dart';

class SupabaseSyncService implements ISyncService {
  SupabaseClient? _client;

  @override
  Future<SyncResult> initializeDriver(String url, String anonKey) async {
    try {
      if (url.isEmpty || anonKey.isEmpty) {
        return SyncFailure('Credenciales inválidas');
      }
      
      // Asegurar que no re-inicialicemos inútilmente
      if (_client != null) {
        return SyncSuccess();
      }

      await Supabase.initialize(url: url, anonKey: anonKey);
      _client = Supabase.instance.client;
      return SyncSuccess();
    } catch (e) {
      return SyncFailure('Error conectando a Supabase: \$e');
    }
  }

  @override
  Future<void> disconnect() async {
    _client = null;
    // Note: Supabase SDK doesn't have a direct "disconnect" destroying the singleton, 
    // but nullifying our reference works for stopping further syncs in this session.
  }

  @override
  Future<SyncResult> syncAll(dynamic localDatabase) async {
    if (_client == null) return SyncFailure('No conectado a la nube');
    
    try {
      final db = localDatabase as AppDatabase;
      
      final wardrobeRes = await syncWardrobe(db);
      if (wardrobeRes is SyncFailure) return wardrobeRes;
      
      final outfitsRes = await syncOutfits(db);
      if (outfitsRes is SyncFailure) return outfitsRes;

      final profileRes = await syncUserProfile(db);
      if (profileRes is SyncFailure) return profileRes;

      final foodCoachRes = await syncFoodCoach(db);
      if (foodCoachRes is SyncFailure) return foodCoachRes;


      final cocinaRes = await syncCocina(db);
      if (cocinaRes is SyncFailure) return cocinaRes;

      return SyncSuccess();
    } catch (e) {
      return SyncFailure('Error en sincro general: \$e');
    }
  }

  @override
  Future<SyncResult> syncWardrobe(dynamic localDatabase) async {
    if (_client == null) return SyncFailure('No conectado');
    final db = localDatabase as AppDatabase;

    try {
      final localGarments = await db.select(db.wardrobeGarments).get();
      
      // Upsert a la tabla 'wardrobe_garments' en Supabase.
      // Asume que la tabla remoto existe y comparte el mismo schema que Drift.
      final payload = localGarments.map((g) => {
        'id': g.id,
        'name': g.name,
        'type_index': g.typeIndex,
        'primary_color': g.primaryColor,
        'secondary_color': g.secondaryColor,
        'style_index': g.styleIndex,
        'material': g.material,
        'season': g.season,
        'is_favorite': g.isFavorite,
        'is_clean': g.isClean,
        'has_removable_hood': g.hasRemovableHood,
        'rating': g.rating,
        'size': g.size,
        'brand': g.brand,
        'price': g.price,
        'image_asset_id': g.imageAssetId,
        'image_details_path': g.imageDetailsPath,
        'added_at': g.addedAt.toIso8601String(),
      }).toList();

      if (payload.isNotEmpty) {
        await _client!.from('wardrobe_garments').upsert(payload);
      }
      return SyncSuccess();
    } catch (e) {
      return SyncFailure('Fallo al sincronizar prendas: \$e');
    }
  }

  @override
  Future<SyncResult> syncFoodCoach(dynamic localDatabase) async {
    if (_client == null) return SyncFailure('No conectado');
    final db = localDatabase as AppDatabase;

    try {
      final logs = await db.select(db.mealLogs).get();
      
      final payload = logs.map((l) => {
        'id': l.id,
        'timestamp': l.timestamp.toIso8601String(),
        'classification_index': l.classificationIndex,
        'feedback': l.feedback,
        'detected_ingredients_csv': l.detectedIngredientsCsv,
      }).toList();

      if (payload.isNotEmpty) {
        await _client!.from('meal_logs').upsert(payload);
      }
      return SyncSuccess();
    } catch (e) {
      return SyncFailure('Fallo al sincronizar evaluaciones: $e');
    }
  }

  @override
  Future<SyncResult> syncOutfits(dynamic localDatabase) async {
    if (_client == null) return SyncFailure('No conectado');
    final db = localDatabase as AppDatabase;

    try {
      final localOutfits = await db.select(db.outfits).get();
      final payload = localOutfits.map((o) => {
        'id': o.id,
        'name': o.name,
        'garment_ids_csv': o.garmentIdsCsv,
        'occasion': o.occasion,
        'season': o.season,
        'times_worn': o.timesWorn,
        'created_at': o.createdAt.toIso8601String(),
      }).toList();

      if (payload.isNotEmpty) {
        await _client!.from('outfits').upsert(payload);
      }
      return SyncSuccess();
    } catch (e) {
      return SyncFailure('Fallo al sincronizar outfits: $e');
    }
  }

  @override
  Future<SyncResult> syncUserProfile(dynamic localDatabase) async {
    if (_client == null) return SyncFailure('No conectado');
    final db = localDatabase as AppDatabase;

    try {
      final profiles = await db.select(db.userProfile).get();
      final payload = profiles.map((p) => {
        'id': p.id,
        'skin_tone': p.skinTone,
        'body_type': p.bodyType,
        'height': p.height,
        'weight': p.weight,
        'hair_type': p.hairType,
        'colorimetry': p.colorimetry,
        'body_shape': p.bodyShape,
        'consent_granted': p.consentGranted,
        'updated_at': p.updatedAt.toIso8601String(),
      }).toList();

      if (payload.isNotEmpty) {
        await _client!.from('user_profiles').upsert(payload);
      }
      return SyncSuccess();
    } catch (e) {
      return SyncFailure('Fallo al sincronizar el perfil: $e');
    }
  }

  @override
  Future<SyncResult> syncCocina(dynamic localDatabase) async {
    if (_client == null) return SyncFailure('No conectado');
    final db = localDatabase as AppDatabase;

    try {
      // 1. InventoryIngredients
      final inventory = await db.select(db.inventoryIngredients).get();
      final invPayload = inventory.map((i) => {
        'id': i.id,
        'name': i.name,
        'primary_category': i.primaryCategory,
        'sub_category': i.subCategory,
        'quantity': i.quantity,
        'unit': i.unit,
        'expiration_date': i.expirationDate?.toIso8601String(),
        'image_asset_id': i.imageAssetId,
        'storage_area': i.storageArea,
      }).toList();
      if (invPayload.isNotEmpty) {
        await _client!.from('inventory_ingredients').upsert(invPayload);
      }

      // 2. Recipes
      final recipes = await db.select(db.recipes).get();
      final recPayload = recipes.map((r) => {
        'id': r.id,
        'name': r.name,
        'description': r.description,
        'duration_minutes': r.durationMinutes,
        'servings': r.servings,
        'instructions_json': r.instructionsJson,
        'tags_csv': r.tagsCsv,
        'image_asset_id': r.imageAssetId,
        'goal_index': r.goalIndex,
        'is_favorite': r.isFavorite,
        'created_at': r.createdAt.toIso8601String(),
      }).toList();
      if (recPayload.isNotEmpty) {
        await _client!.from('recipes').upsert(recPayload);
      }

      // 3. Shopping List
      final shopping = await db.select(db.shoppingItems).get();
      final shopPayload = shopping.map((s) => {
        'id': s.id,
        'name': s.name,
        'quantity': s.quantity,
        'unit': s.unit,
        'bought': s.bought,
        'created_at': s.createdAt.toIso8601String(),
      }).toList();
      if (shopPayload.isNotEmpty) {
        await _client!.from('shopping_items').upsert(shopPayload);
      }

      // RecipeIngredients (Relationships) skip to avoid bloat for now, 
      // but conceptually you'd sync it similarly if desired.

      return SyncSuccess();
    } catch (e) {
      return SyncFailure('Fallo al sincronizar cocina: $e');
    }
  }
}
