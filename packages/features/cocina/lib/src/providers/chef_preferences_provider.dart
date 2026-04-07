import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:domain/domain.dart';

class ChefPreferencesNotifier extends Notifier<ChefPreferences> {
  static const String _prefsKey = 'chef_preferences';

  @override
  ChefPreferences build() {
    _loadPreferences();
    return const ChefPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = ChefPreferences(
          favoriteCategories:
              (data['favoriteCategories'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          spiceLevel: data['spiceLevel'] as String?,
          portionSize: data['portionSize'] as String?,
          dietaryRestrictions:
              (data['dietaryRestrictions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          wantsSoup: data['wantsSoup'] as bool?,
          wantsDessert: data['wantsDessert'] as bool?,
          wantsDrink: data['wantsDrink'] as bool?,
          typicalServings: data['typicalServings'] as int?,
          hasCompletedOnboarding: data['hasCompletedOnboarding'] as bool? ?? false,
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading chef preferences: $e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'favoriteCategories': state.favoriteCategories,
        'spiceLevel': state.spiceLevel,
        'portionSize': state.portionSize,
        'dietaryRestrictions': state.dietaryRestrictions,
        'wantsSoup': state.wantsSoup,
        'wantsDessert': state.wantsDessert,
        'wantsDrink': state.wantsDrink,
        'typicalServings': state.typicalServings,
        'hasCompletedOnboarding': state.hasCompletedOnboarding,
      };
      await prefs.setString(_prefsKey, jsonEncode(data));
    } catch (e) {
      debugPrint('❌ Error saving chef preferences: $e');
    }
  }

  /// Toggle a favorite category
  Future<void> toggleFavoriteCategory(String category) async {
    final categories = List<String>.from(state.favoriteCategories);
    if (categories.contains(category)) {
      categories.remove(category);
    } else {
      categories.add(category);
    }
    state = state.copyWith(favoriteCategories: categories);
    await _savePreferences();
  }

  /// Set spice level preference
  Future<void> setSpiceLevel(String? level) async {
    state = state.copyWith(spiceLevel: level);
    await _savePreferences();
  }

  /// Set portion size preference
  Future<void> setPortionSize(String? size) async {
    state = state.copyWith(portionSize: size);
    await _savePreferences();
  }

  /// Set typical servings
  Future<void> setTypicalServings(int servings) async {
    state = state.copyWith(typicalServings: servings);
    await _savePreferences();
  }

  /// Set menu preferences (soup, dessert, drink)
  Future<void> setMenuPreferences({bool? soup, bool? dessert, bool? drink}) async {
    state = state.copyWith(
      wantsSoup: soup,
      wantsDessert: dessert,
      wantsDrink: drink,
    );
    await _savePreferences();
  }

  /// Mark onboarding as completed
  Future<void> completeOnboarding() async {
    state = state.copyWith(hasCompletedOnboarding: true);
    await _savePreferences();
  }

  /// Reset all preferences
  Future<void> resetAll() async {
    state = const ChefPreferences();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

final chefPreferencesProvider =
    NotifierProvider<ChefPreferencesNotifier, ChefPreferences>(
        ChefPreferencesNotifier.new);
