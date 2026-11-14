import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';
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
    try {
      await _repo.toggleClean(id);
      state = state.copyWith(
        garments: [
          for (final g in state.garments)
            if (g.id == id) g.copyWith(isClean: !g.isClean) else g
        ],
      );
      _refreshSuggestions();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleFavorite(String id) async {
    try {
      await _repo.toggleFavorite(id);
      state = state.copyWith(
        garments: [
          for (final g in state.garments)
            if (g.id == id) g.copyWith(isFavorite: !g.isFavorite) else g
        ],
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Incrementa el contador de usos de una prenda individual y lo persiste.
  Future<void> incrementGarmentWear(String id) async {
    WardrobeGarment? target;
    for (final g in state.garments) {
      if (g.id == id) {
        target = g;
        break;
      }
    }
    if (target == null) return;
    final updated = target.copyWith(timesWorn: target.timesWorn + 1);
    try {
      await _repo.updateGarment(updated);
      state = state.copyWith(
        garments: [
          for (final g in state.garments)
            if (g.id == id) updated else g
        ],
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
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
    try {
      Outfit? target;
      for (final o in state.outfits) {
        if (o.id == id) {
          target = o;
          break;
        }
      }
      await _repo.incrementTimesWorn(id);
      final wornIds = target?.garmentIds.toSet() ?? const <String>{};
      state = state.copyWith(
        outfits: [
          for (final o in state.outfits)
            if (o.id == id)
              Outfit(
                  id: o.id,
                  name: o.name,
                  garmentIds: o.garmentIds,
                  occasion: o.occasion,
                  season: o.season,
                  timesWorn: o.timesWorn + 1,
                  createdAt: o.createdAt)
            else
              o
        ],
        garments: [
          for (final g in state.garments)
            if (wornIds.contains(g.id))
              g.copyWith(timesWorn: g.timesWorn + 1)
            else
              g
        ],
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> saveProfile(UserPhysicalProfile p) async {
    try {
      await _repo.saveUserProfile(p);
      state = state.copyWith(userProfile: p);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteProfile() async {
    await _repo.deleteUserProfile();
    state = ArmarioState(
      garments: state.garments,
      outfits: state.outfits,
      suggestions: state.suggestions,
      ootd: state.ootd,
    );
  }

  Future<void> _refreshSuggestions() async {
    final s = await _repo.suggestOutfits(limit: 5);
    state = state.copyWith(suggestions: s);
  }

  Future<void> generateOutfitOfTheDay(
      dynamic aiService, String weatherContext) async {
    state = state.copyWith(isLoadingOotd: true, error: null);
    try {
      final cleanGarments = state.garments.where((g) => g.isClean).toList();
      if (cleanGarments.isEmpty) {
        state = state.copyWith(
            isLoadingOotd: false,
            ootd: null,
            error: 'No hay prendas limpias para sugerir un outfit.');
        return;
      }

      final garmentsPayload = cleanGarments
          .map((g) => {
                'id': g.id,
                'name': g.name,
                'type': g.type.name,
                'color': g.primaryColor,
                'style': g.style.name,
              })
          .toList();

      final profileCtx = state.userProfile != null
          ? 'Estatura: ${state.userProfile!.height}cm, Peso: ${state.userProfile!.weight}kg, Tipo de Cuerpo: ${state.userProfile!.bodyShape ?? 'No especificado'}, Colorimetría: ${state.userProfile!.colorimetry ?? 'No especificada'}'
          : null;

      final resString = await aiService.suggestOutfitOfTheDayJson(
        garments: garmentsPayload,
        weatherContext: weatherContext,
        userProfileContext: profileCtx,
      );

      if (resString == null || resString.isEmpty) {
        state = state.copyWith(isLoadingOotd: false);
        return;
      }

      final match = RegExp(r'\{[\s\S]*\}').firstMatch(resString);
      final cleanJson = match?.group(0) ?? resString.trim();

      final Map<String, dynamic> decoded = dart_convert.jsonDecode(cleanJson);

      final topId = decoded['top_id'];
      final bottomId = decoded['bottom_id'];
      final shoesId = decoded['shoes_id'];
      final explanation = decoded['explanation'];

      WardrobeGarment? findById(dynamic id) {
        if (id == null) return null;
        for (final g in cleanGarments) {
          if (g.id == id.toString()) return g;
        }
        return null;
      }

      final topData = findById(topId);
      final bottomData = findById(bottomId);
      final shoesData = findById(shoesId);

      final validDress =
          topData != null && topData.type == GarmentType.dress;
      if (topData != null && (bottomData != null || validDress)) {
        state = state.copyWith(isLoadingOotd: false, ootd: {
          'top': topData,
          'bottom': bottomData,
          'shoes': shoesData,
          'explanation': explanation,
        });
      } else {
        state = state.copyWith(
            isLoadingOotd: false,
            error: 'La IA sugirió prendas no disponibles.');
      }
    } catch (e) {
      state = state.copyWith(
          isLoadingOotd: false, error: 'Fallo al sugerir outfit: $e');
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

// ── Providers ─────────────────────────────────────────────────────────────────
final armarioRepositoryProvider = Provider<IArmarioRepository>((ref) {
  throw UnimplementedError(
      'Provide IArmarioRepository via ProviderScope.overrides');
});

final armarioProvider =
    NotifierProvider<ArmarioNotifier, ArmarioState>(ArmarioNotifier.new);
