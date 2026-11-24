import 'dart:convert';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notifier compartido entre Armario, FoodCoach y Cocina que persiste el
/// perfil corporal (`BodyCompositionProfile`), su historial de check-ins y
/// sincroniza la meta nutricional activa con Cocina.
class BodyProfileNotifier extends Notifier<BodyCompositionProfile> {
  static const storageKey = 'mylifeos_body_composition_profile_v1';
  static const cocinaGoalKey = 'cocina_active_nutrition_goal_v1';

  bool _loaded = false;
  Future<void>? _loadFuture;

  @override
  BodyCompositionProfile build() {
    _loaded = false;
    _loadFuture = null;
    Future.microtask(load);
    return const BodyCompositionProfile();
  }

  Future<void> load() => _loadFuture ??= _readFromPrefs();

  Future<void> _readFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          if (!_loaded) {
            _loaded = true;
            state = BodyCompositionProfile.fromJson(decoded);
            return;
          }
        }
      }
      // Si no hay perfil corporal guardado aún, adoptar meta de Cocina si existe.
      final savedGoal = prefs.getString(cocinaGoalKey);
      if (savedGoal != null && !_loaded) {
        final cocinaGoal = NutritionGoal.values.firstWhere(
          (g) => g.name == savedGoal,
          orElse: () => NutritionGoal.maintain,
        );
        _loaded = true;
        state = state.copyWith(
          goalMode: BodyGoalMode.fromNutritionGoal(cocinaGoal),
        );
        return;
      }
    } catch (_) {}
    _loaded = true;
  }

  Future<void> saveProfile(
    BodyCompositionProfile profile, {
    bool recordCheckIn = false,
    bool syncCocinaGoal = true,
  }) async {
    if (!_loaded) await load();
    final now = DateTime.now();
    var nextHistory = List<BodyCheckIn>.from(profile.history);

    if (recordCheckIn && (profile.weightKg ?? 0) >= 30) {
      final resolved = BodyNutritionCalculator.resolveBodyFat(profile);
      final entry = BodyCheckIn(
        date: now,
        weightKg: profile.weightKg!,
        bodyFatPercent: resolved.percent,
        waistCm: profile.waistCm,
        source: resolved.source,
      );
      nextHistory = _upsertDailyCheckIn(nextHistory, entry);
    }

    final updated = profile.copyWith(
      updatedAt: now,
      history: nextHistory,
    );
    state = updated;
    await _persist(updated, syncCocinaGoal: syncCocinaGoal);
  }

  /// Registra un check-in rápido de seguimiento corporal (peso / cintura / % grasa).
  Future<void> logCheckIn({
    required double weightKg,
    double? waistCm,
    double? manualBodyFatPercent,
  }) async {
    if (!_loaded) await load();
    final next = state.copyWith(
      weightKg: weightKg,
      waistCm: waistCm ?? state.waistCm,
      manualBodyFatPercent: manualBodyFatPercent ?? state.manualBodyFatPercent,
    );
    await saveProfile(next, recordCheckIn: true, syncCocinaGoal: false);
  }

  /// Sincroniza datos básicos y estimación visual orientativa desde el
  /// Escáner Físico de Armario sin sobreescribir medidas de cinta ni edad/sexo.
  Future<void> syncFromPhysicalScanner({
    double? heightCm,
    double? weightKg,
    double? visualBodyFatMin,
    double? visualBodyFatMax,
    String? visualBuildNote,
  }) async {
    if (!_loaded) await load();
    final next = state.copyWith(
      heightCm: heightCm ?? state.heightCm,
      weightKg: weightKg ?? state.weightKg,
      visualBodyFatMin: visualBodyFatMin ?? state.visualBodyFatMin,
      visualBodyFatMax: visualBodyFatMax ?? state.visualBodyFatMax,
      visualBuildNote: visualBuildNote ?? state.visualBuildNote,
    );
    await saveProfile(
      next,
      recordCheckIn: weightKg != null && weightKg >= 30,
      syncCocinaGoal: false,
    );
  }

  List<BodyCheckIn> _upsertDailyCheckIn(
    List<BodyCheckIn> existing,
    BodyCheckIn entry,
  ) {
    final sameDayIdx = existing.indexWhere(
      (e) =>
          e.date.year == entry.date.year &&
          e.date.month == entry.date.month &&
          e.date.day == entry.date.day,
    );
    final list = List<BodyCheckIn>.from(existing);
    if (sameDayIdx >= 0) {
      list[sameDayIdx] = entry;
    } else {
      list.add(entry);
    }
    list.sort((a, b) => a.date.compareTo(b.date));
    if (list.length > 24) {
      return list.sublist(list.length - 24);
    }
    return list;
  }

  Future<void> _persist(
    BodyCompositionProfile profile, {
    required bool syncCocinaGoal,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(profile.toJson()));
      if (syncCocinaGoal) {
        await prefs.setString(
          cocinaGoalKey,
          profile.goalMode.toNutritionGoal().name,
        );
      }
    } catch (_) {}
  }
}

final bodyProfileProvider =
    NotifierProvider<BodyProfileNotifier, BodyCompositionProfile>(
  BodyProfileNotifier.new,
);
