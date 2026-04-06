import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:domain/domain.dart';

/// Provider for user food preferences (disliked ingredients, etc.)
class UserFoodPreferencesNotifier extends Notifier<UserFoodPreferences> {
  static const String _prefsKey = 'user_food_preferences';

  @override
  UserFoodPreferences build() {
    // Load preferences on init
    _loadPreferences();
    return const UserFoodPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = UserFoodPreferences(
          dislikedIngredients:
              (data['disliked'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          dietaryRestrictions:
              (data['restrictions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading food preferences: $e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'disliked': state.dislikedIngredients,
        'restrictions': state.dietaryRestrictions,
      };
      await prefs.setString(_prefsKey, jsonEncode(data));
    } catch (e) {
      debugPrint('❌ Error saving food preferences: $e');
    }
  }

  /// Add an ingredient to disliked list
  Future<void> addDislikedIngredient(String ingredient) async {
    final lower = ingredient.toLowerCase();
    if (!state.dislikedIngredients.contains(lower)) {
      state = state.copyWith(
        dislikedIngredients: [...state.dislikedIngredients, lower],
      );
      await _savePreferences();
    }
  }

  /// Remove an ingredient from disliked list
  Future<void> removeDislikedIngredient(String ingredient) async {
    final lower = ingredient.toLowerCase();
    state = state.copyWith(
      dislikedIngredients: state.dislikedIngredients.where((i) => i != lower).toList(),
    );
    await _savePreferences();
  }

  /// Check if an ingredient is disliked
  bool isIngredientDisliked(String ingredient) {
    return state.dislikedIngredients.contains(ingredient.toLowerCase());
  }

  /// Clear all preferences
  Future<void> clearAll() async {
    state = const UserFoodPreferences();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

final userFoodPreferencesProvider =
    NotifierProvider<UserFoodPreferencesNotifier, UserFoodPreferences>(
        UserFoodPreferencesNotifier.new);
