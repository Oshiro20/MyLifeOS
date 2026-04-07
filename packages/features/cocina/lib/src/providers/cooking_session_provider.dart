import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents an active cooking session
class CookingSession {
  final String id;
  final String recipeName;
  final String? recipeId;
  final DateTime startedAt;
  final int originalServings;
  final int scaledServings;

  const CookingSession({
    required this.id,
    required this.recipeName,
    this.recipeId,
    required this.startedAt,
    required this.originalServings,
    this.scaledServings = 1,
  });

  CookingSession copyWith({
    String? id,
    String? recipeName,
    String? recipeId,
    DateTime? startedAt,
    int? originalServings,
    int? scaledServings,
  }) =>
      CookingSession(
        id: id ?? this.id,
        recipeName: recipeName ?? this.recipeName,
        recipeId: recipeId ?? this.recipeId,
        startedAt: startedAt ?? this.startedAt,
        originalServings: originalServings ?? this.originalServings,
        scaledServings: scaledServings ?? this.scaledServings,
      );
}

class CookingSessionNotifier extends Notifier<CookingSession?> {
  @override
  CookingSession? build() => null;

  void startSession({
    required String recipeName,
    String? recipeId,
    required int originalServings,
    int scaledServings = 1,
  }) {
    state = CookingSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      recipeName: recipeName,
      recipeId: recipeId,
      startedAt: DateTime.now(),
      originalServings: originalServings,
      scaledServings: scaledServings,
    );
  }

  void updateScaledServings(int servings) {
    if (state != null) {
      state = state!.copyWith(scaledServings: servings);
    }
  }

  void endSession() {
    state = null;
  }

  bool get isActive => state != null;
}

final cookingSessionProvider =
    NotifierProvider<CookingSessionNotifier, CookingSession?>(
        CookingSessionNotifier.new);
