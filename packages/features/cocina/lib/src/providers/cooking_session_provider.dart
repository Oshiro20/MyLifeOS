import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents an active cooking session
class CookingSession {
  final String id;
  final String recipeName;
  final String? recipeId;
  final DateTime startedAt;
  final int originalServings;
  final int scaledServings;
  final int? estimatedDurationMinutes; // Tiempo estimado de la receta

  const CookingSession({
    required this.id,
    required this.recipeName,
    this.recipeId,
    required this.startedAt,
    required this.originalServings,
    this.scaledServings = 1,
    this.estimatedDurationMinutes,
  });

  /// Check if session has exceeded estimated time + 30min buffer
  bool get isExpired {
    if (estimatedDurationMinutes == null) return false;
    final elapsed = DateTime.now().difference(startedAt);
    final limit = Duration(minutes: estimatedDurationMinutes! + 30);
    return elapsed > limit;
  }

  /// Check if session is older than 2 hours (safety limit)
  bool get isTooOld {
    final elapsed = DateTime.now().difference(startedAt);
    return elapsed > const Duration(hours: 2);
  }

  CookingSession copyWith({
    String? id,
    String? recipeName,
    String? recipeId,
    DateTime? startedAt,
    int? originalServings,
    int? scaledServings,
    int? estimatedDurationMinutes,
  }) =>
      CookingSession(
        id: id ?? this.id,
        recipeName: recipeName ?? this.recipeName,
        recipeId: recipeId ?? this.recipeId,
        startedAt: startedAt ?? this.startedAt,
        originalServings: originalServings ?? this.originalServings,
        scaledServings: scaledServings ?? this.scaledServings,
        estimatedDurationMinutes:
            estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      );
}

class CookingSessionNotifier extends Notifier<CookingSession?> {
  Timer? _autoEndTimer;

  @override
  CookingSession? build() {
    // Auto-cleanup when provider is disposed
    ref.onDispose(() {
      _autoEndTimer?.cancel();
    });
    return null;
  }

  void startSession({
    required String recipeName,
    String? recipeId,
    required int originalServings,
    int scaledServings = 1,
    int? estimatedDurationMinutes,
  }) {
    _autoEndTimer?.cancel();

    state = CookingSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      recipeName: recipeName,
      recipeId: recipeId,
      startedAt: DateTime.now(),
      originalServings: originalServings,
      scaledServings: scaledServings,
      estimatedDurationMinutes: estimatedDurationMinutes,
    );

    // Auto-end after estimated time + 30min buffer, or 2 hours max
    final autoEndMinutes = estimatedDurationMinutes != null
        ? (estimatedDurationMinutes + 30).clamp(30, 120)
        : 120;

    _autoEndTimer = Timer(Duration(minutes: autoEndMinutes), () {
      endSession();
    });
  }

  void updateScaledServings(int servings) {
    if (state != null) {
      state = state!.copyWith(scaledServings: servings);
    }
  }

  void endSession() {
    _autoEndTimer?.cancel();
    _autoEndTimer = null;
    state = null;
  }

  bool get isActive => state != null;
}

final cookingSessionProvider =
    NotifierProvider<CookingSessionNotifier, CookingSession?>(
        CookingSessionNotifier.new);
