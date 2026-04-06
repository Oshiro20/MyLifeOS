import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to store and retrieve import history (URLs, video imports, etc.)
class ImportHistoryService {
  static const String _key = 'import_history';
  static const int _maxHistory = 10;

  /// Saves a URL to import history
  Future<void> saveImport(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getHistory();

      // Remove if already exists (to move to top)
      history.remove(url);

      // Add to beginning
      history.insert(0, url);

      // Keep only last N items
      if (history.length > _maxHistory) {
        history.removeRange(_maxHistory, history.length);
      }

      await prefs.setString(_key, jsonEncode(history));
      debugPrint('💾 Import history saved: ${history.length} items');
    } catch (e) {
      debugPrint('❌ Error saving import history: $e');
    }
  }

  /// Gets the import history list (most recent first)
  Future<List<String>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_key);
      if (jsonString == null || jsonString.isEmpty) return [];

      final decoded = jsonDecode(jsonString) as List<dynamic>;
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('❌ Error loading import history: $e');
      return [];
    }
  }

  /// Clears all import history
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      debugPrint('🗑️ Import history cleared');
    } catch (e) {
      debugPrint('❌ Error clearing import history: $e');
    }
  }

  /// Removes a specific URL from history
  Future<void> removeItem(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getHistory();
      history.remove(url);
      await prefs.setString(_key, jsonEncode(history));
    } catch (e) {
      debugPrint('❌ Error removing history item: $e');
    }
  }

  /// Checks if a URL is in history
  Future<bool> isInHistory(String url) async {
    final history = await getHistory();
    return history.contains(url);
  }
}
