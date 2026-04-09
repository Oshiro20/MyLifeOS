import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Servicio de caché offline para respuestas de Gemini AI.
///
/// Persiste la última respuesta exitosa de cada llamada IA en SharedPreferences.
/// Cuando el dispositivo está sin conexión, se devuelve la respuesta cacheada.
class OfflineCacheService {
  static const String _prefix = 'ai_cache_';
  static const String _tsPrefix = 'ai_cache_ts_';

  /// Guarda una respuesta JSON bajo una clave semántica.
  Future<void> saveString(String key, String jsonValue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$key', jsonValue);
    await prefs.setInt(
        '$_tsPrefix$key', DateTime.now().millisecondsSinceEpoch);
  }

  /// Carga la respuesta cacheada. Retorna null si no existe.
  Future<String?> loadString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix$key');
  }

  /// Retorna true si la caché existe pero tiene más de [maxAge] de antigüedad.
  Future<bool> isStale(String key, {Duration maxAge = const Duration(hours: 24)}) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt('$_tsPrefix$key');
    if (ts == null) return true;
    final saved = DateTime.fromMillisecondsSinceEpoch(ts);
    return DateTime.now().difference(saved) > maxAge;
  }

  /// Guarda un objeto Dart encodificándolo como JSON.
  Future<void> saveMap(String key, Map<String, dynamic> data) async {
    await saveString(key, jsonEncode(data));
  }

  /// Carga un objeto desde caché. Retorna null si no existe o falla el parseo.
  Future<Map<String, dynamic>?> loadMap(String key) async {
    final raw = await loadString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Elimina la caché de una clave específica.
  Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
    await prefs.remove('$_tsPrefix$key');
  }

  /// Retorna el timestamp de cuándo se guardó la caché, o null.
  Future<DateTime?> lastSaved(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt('$_tsPrefix$key');
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts);
  }
}

/// Provider Riverpod para OfflineCacheService.
final offlineCacheProvider = Provider<OfflineCacheService>(
  (ref) => OfflineCacheService(),
);
