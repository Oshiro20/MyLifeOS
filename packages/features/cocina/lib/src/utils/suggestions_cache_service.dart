import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:domain/domain.dart';

/// Service to cache AI suggestions between sessions
/// TTL: 4 hours (configurable)
class SuggestionsCacheService {
  static const String _keySuggestions = 'ai_suggestions_cache';
  static const String _keyTimestamp = 'ai_suggestions_timestamp';
  static const Duration ttl = Duration(hours: 4);

  /// Save suggestions to cache with current timestamp
  Future<void> saveSuggestions(List<RecipeSuggestion> suggestions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = suggestions.map((s) => s.toJson()).toList();
      await prefs.setString(_keySuggestions, jsonEncode(jsonList));
      await prefs.setInt(_keyTimestamp, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Silently fail - cache is optional
      debugPrint('❌ Error saving suggestions cache: $e');
    }
  }

  /// Get cached suggestions if still valid (within TTL)
  Future<List<RecipeSuggestion>?> getCachedSuggestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_keyTimestamp);

      if (timestamp == null) return null;

      final cachedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();

      // Check if cache is still valid
      if (now.difference(cachedTime) > ttl) {
        // Cache expired - clear it
        await clearCache();
        return null;
      }

      final jsonString = prefs.getString(_keySuggestions);
      if (jsonString == null) return null;

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => RecipeSuggestion.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error loading suggestions cache: $e');
      return null;
    }
  }

  /// Clear the cache manually
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keySuggestions);
      await prefs.remove(_keyTimestamp);
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }

  /// Check if cache exists and is valid
  Future<bool> hasValidCache() async {
    final suggestions = await getCachedSuggestions();
    return suggestions != null && suggestions.isNotEmpty;
  }

  /// Get cache age (for debugging)
  Future<Duration?> getCacheAge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_keyTimestamp);
      if (timestamp == null) return null;

      final cachedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateTime.now().difference(cachedTime);
    } catch (e) {
      return null;
    }
  }
}
