import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Lightweight cooking history tracker using SharedPreferences.
/// Stores cooked recipes as JSON list of {name, cookedAt}.
class CookingHistoryService {
  static const _key = 'cooking_history';
  static const _maxDays = 7;

  /// Record a cooked recipe
  Future<void> recordCooked(String recipeName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = _loadEntries(prefs);

      // Add new entry (avoid exact duplicates)
      final alreadyExists = entries
          .any((e) => e['name'] == recipeName && _isWithinDays(e['cookedAt']));
      if (!alreadyExists) {
        entries.add({
          'name': recipeName,
          'cookedAt': DateTime.now().toIso8601String(),
        });
      }

      // Prune old entries
      _pruneOld(entries);

      await prefs.setString(_key, jsonEncode(entries));
    } catch (e) {
      debugPrint('⚠️ Failed to record cooking: $e');
    }
  }

  /// Get recipe names cooked within the last N days
  Future<List<String>> getRecentRecipeNames({int days = _maxDays}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = _loadEntries(prefs);
      return entries
          .where((e) => _isWithinDays(e['cookedAt'], days: days))
          .map((e) => e['name'] as String)
          .toList();
    } catch (e) {
      debugPrint('⚠️ Failed to read cooking history: $e');
      return [];
    }
  }

  /// Clear all cooking history
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('⚠️ Failed to clear cooking history: $e');
    }
  }

  List<Map<String, dynamic>> _loadEntries(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded.cast<Map<String, dynamic>>();
  }

  void _pruneOld(List<Map<String, dynamic>> entries) {
    entries.removeWhere((e) => !_isWithinDays(e['cookedAt']));
  }

  bool _isWithinDays(String isoDate, {int days = _maxDays}) {
    try {
      final cookedAt = DateTime.parse(isoDate);
      final cutoff = DateTime.now().subtract(Duration(days: days));
      return cookedAt.isAfter(cutoff);
    } catch (_) {
      return false;
    }
  }
}
