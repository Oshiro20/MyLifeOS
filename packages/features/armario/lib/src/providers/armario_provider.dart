import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/src/armario/entities/wardrobe_garment.dart';
import 'package:domain/src/armario/repositories/i_armario_repository.dart';
import 'dart:convert' as dart_convert;

// ── State ─────────────────────────────────────────────────────────────────────
class ArmarioState {
  final List<WardrobeGarment> garments;
  final List<Outfit> outfits;
  final List<List<WardrobeGarment>> suggestions;
  final UserPhysicalProfile? userProfile;
  final Map<String, dynamic>? ootd;
  final bool isLoadingOotd;
  final bool isLoading;
  final String? error;

  const ArmarioState({
    this.garments = const [],
    this.outfits = const [],
    this.suggestions = const [],
    this.userProfile,
    this.ootd,
    this.isLoadingOotd = false,
    this.isLoading = false,
    this.error,
  });

  ArmarioState copyWith({
    List<WardrobeGarment>? garments,
    List<Outfit>? outfits,
    List<List<WardrobeGarment>>? suggestions,
    UserPhysicalProfile? userProfile,
    Map<String, dynamic>? ootd,
    bool? isLoadingOotd,
    bool? isLoading,
    String? error,
  }) =>
      ArmarioState(
        garments: garments ?? this.garments,
        outfits: outfits ?? this.outfits,
        suggestions: suggestions ?? this.suggestions,
        userProfile: userProfile ?? this.userProfile,
        ootd: ootd ?? this.ootd,
        isLoadingOotd: isLoadingOotd ?? this.isLoadingOotd,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ── Notifier (Riverpod v3) ────────────────────────────────────────────────────
class ArmarioNotifier extends Notifier<ArmarioState> {
  IArmarioRepository get _repo => ref.read(armarioRepositoryProvider);

  @override
  ArmarioState build() {
    Future.microtask(() => load());
    return const ArmarioState();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final garments = await _repo.getAllGarments();
      final outfits = await _repo.getAllOutfits();
      final profile = await _repo.getUserProfile();
      final suggestions = await _repo.suggestOutfits(limit: 5);
      state = state.copyWith(
        garments: garments,
        outfits: outfits,
        userProfile: profile,
        suggestions: suggestions,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<WardrobeGarment> addGarment(WardrobeGarment g) async {
    try {
      final saved = await _repo.addGarment(g);
      state = state.copyWith(garments: [saved, ...state.garments]);
      _refreshSuggestions();
      return saved;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteGarment(String id) async {
    await _repo.deleteGarment(id);
    state = state.copyWith(
        garments: state.garments.where((g) => g.id != id).toList());
    _refreshSuggestions();
  }

  Future<void> toggleClean(String id) async {
    await _repo.toggleClean(id);
    state = state.copyWith(
      garments: [
        for (final g in state.garments)
          if (g.id == id)
            WardrobeGarment(
              id: g.id, name: g.name, type: g.type,
              primaryColor: g.primaryColor, secondaryColor: g.secondaryColor,
              style: g.style, material: g.material, season: g.season,
              isFavorite: g.isFavorite, isClean: !g.isClean,
              imageAssetId: g.imageAssetId, addedAt: g.addedAt,
            )
          else g
      ],
    );
    _refreshSuggestions();
  }

  Future<void> toggleFavorite(String id) async {
    await _repo.toggleFavorite(id);
    state = state.copyWith(
      garments: [
        for (final g in state.garments)
          if (g.id == id)
            WardrobeGarment(
              id: g.id, name: g.name, type: g.type,
              primaryColor: g.primaryColor, secondaryColor: g.secondaryColor,
              style: g.style, material: g.material, season: g.season,
              isFavorite: !g.isFavorite, isClean: g.isClean,
              imageAssetId: g.imageAssetId, addedAt: g.addedAt,
            )
          else g
      ],
    );
  }

  Future<void> saveOutfit(Outfit o) async {
    try {
      final saved = await _repo.saveOutfit(o);
      state = state.copyWith(outfits: [saved, ...state.outfits]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> wearOutfit(String id) async {
    await _repo.incrementTimesWorn(id);
    state = state.copyWith(
      outfits: [
        for (final o in state.outfits)
          if (o.id == id)
            Outfit(id: o.id, name: o.name, garmentIds: o.garmentIds,
                occasion: o.occasion, season: o.season,
                timesWorn: o.timesWorn + 1, createdAt: o.createdAt)
          else o
      ],
    );
  }

  Future<void> saveProfile(UserPhysicalProfile p) async {
    await _repo.saveUserProfile(p);
    state = state.copyWith(userProfile: p);
  }

  Future<void> deleteProfile() async {
    await _repo.deleteUserProfile();
    state = ArmarioState(garments: state.garments, outfits: state.outfits);
  }

  Future<void> _refreshSuggestions() async {
    final s = await _repo.suggestOutfits(limit: 5);
    state = state.copyWith(suggestions: s);
  }

  Future<void> generateOutfitOfTheDay(dynamic aiService, String weatherContext) async {
    state = state.copyWith(isLoadingOotd: true, error: null);
    try {
      final cleanGarments = state.garments.where((g) => g.isClean).toList();
      if (cleanGarments.isEmpty) {
        state = state.copyWith(isLoadingOotd: false, ootd: null, error: 'No hay prendas limpias para sugerir un outfit.');
        return;
      }
      
      final garmentsJson = cleanGarments.map((g) => {
        'id': g.id,
        'name': g.name,
        'type': g.type.name,
        'color': g.primaryColor,
        'style': g.style.name,
      }).toList().toString();

      final profileCtx = state.userProfile != null 
          ? 'Estatura: ${state.userProfile!.height}cm, Peso: ${state.userProfile!.weight}kg, Tipo de Cuerpo: ${state.userProfile!.bodyShape ?? 'No especificado'}, Colorimetría: ${state.userProfile!.colorimetry ?? 'No especificada'}'
          : null;

      final resString = await aiService.suggestOutfitOfTheDay(
        garmentsJson: garmentsJson,
        weatherContext: weatherContext,
        userProfileContext: profileCtx,
      );

      if (resString == null || resString.isEmpty) {
        state = state.copyWith(isLoadingOotd: false);
        return;
      }

      // Parse JSON from Gemini (assuming it replies with raw JSON, but maybe it has markdown blocks)
      String cleanJson = resString.trim();
      if (cleanJson.startsWith('```json')) cleanJson = cleanJson.replaceAll('```json', '');
      if (cleanJson.startsWith('```')) cleanJson = cleanJson.replaceAll('```', '');
      cleanJson = cleanJson.trim();

      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3).trim();
      }

      final Map<String, dynamic> decoded = dart_convert.jsonDecode(cleanJson);
      
      final topId = decoded['top_id'];
      final bottomId = decoded['bottom_id'];
      final shoesId = decoded['shoes_id'];
      final explanation = decoded['explanation'];

      WardrobeGarment? topData;
      WardrobeGarment? bottomData;
      WardrobeGarment? shoesData;

      try {
        topData = cleanGarments.firstWhere((g) => g.id == topId);
      } catch (_) {}
      try {
        bottomData = cleanGarments.firstWhere((g) => g.id == bottomId);
      } catch (_) {}
      try {
        shoesData = cleanGarments.firstWhere((g) => g.id == shoesId);
      } catch (_) {}

      if (topData != null && bottomData != null) {
        state = state.copyWith(
          isLoadingOotd: false,
          ootd: {
            'top': topData,
            'bottom': bottomData,
            'shoes': shoesData,
            'explanation': explanation,
          }
        );
      } else {
        state = state.copyWith(isLoadingOotd: false, error: 'Gemini sugirió prendas no encontradas.');
      }
    } catch (e) {
      state = state.copyWith(isLoadingOotd: false, error: 'Fallo al sugerir outfit: $e');
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

// ── Providers ─────────────────────────────────────────────────────────────────
final armarioRepositoryProvider = Provider<IArmarioRepository>((ref) {
  throw UnimplementedError('Provide IArmarioRepository via ProviderScope.overrides');
});

final armarioProvider =
    NotifierProvider<ArmarioNotifier, ArmarioState>(ArmarioNotifier.new);
