import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de caché offline para respuestas de IA.
///
/// Usa claves normalizadas con SHA-256, expiración por TTL y límite máximo de entradas
/// para evitar crecimiento ilimitado en SharedPreferences.
class OfflineCacheService {
  static const String _prefix = 'ai_cache_';
  static const String _tsPrefix = 'ai_cache_ts_';
  static const Duration defaultMaxAge = Duration(days: 7);
  static const int maxEntries = 100;

  static String _normalizeKey(String rawKey) {
    final digest = sha256.convert(utf8.encode(rawKey)).toString();
    return digest.substring(0, 24);
  }

  /// Guarda una respuesta bajo una clave normalizada y limpia entradas expiradas.
  Future<void> saveString(String key, String jsonValue) async {
    final prefs = await SharedPreferences.getInstance();
    final hashed = _normalizeKey(key);
    await prefs.setString('$_prefix$hashed', jsonValue);
    await prefs.setInt(
      '$_tsPrefix$hashed',
      DateTime.now().millisecondsSinceEpoch,
    );
    await _evictIfNeeded(prefs);
  }

  /// Carga la respuesta cacheada. Retorna null si no existe o expiró según [maxAge].
  Future<String?> loadString(String key, {Duration? maxAge}) async {
    final prefs = await SharedPreferences.getInstance();
    final hashed = _normalizeKey(key);
    final value = prefs.getString('$_prefix$hashed');
    if (value == null) return null;

    final effectiveMaxAge = maxAge ?? defaultMaxAge;
    final ts = prefs.getInt('$_tsPrefix$hashed');
    if (ts != null) {
      final saved = DateTime.fromMillisecondsSinceEpoch(ts);
      if (DateTime.now().difference(saved) > effectiveMaxAge) {
        await prefs.remove('$_prefix$hashed');
        await prefs.remove('$_tsPrefix$hashed');
        return null;
      }
    }
    return value;
  }

  /// Retorna true si la caché no existe o supera [maxAge].
  Future<bool> isStale(
    String key, {
    Duration maxAge = const Duration(hours: 24),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final hashed = _normalizeKey(key);
    final ts = prefs.getInt('$_tsPrefix$hashed');
    if (ts == null) return true;
    final saved = DateTime.fromMillisecondsSinceEpoch(ts);
    return DateTime.now().difference(saved) > maxAge;
  }

  /// Guarda un objeto Dart encodificándolo como JSON.
  Future<void> saveMap(String key, Map<String, dynamic> data) async {
    await saveString(key, jsonEncode(data));
  }

  /// Carga un objeto desde caché. Retorna null si no existe o falla el parseo.
  Future<Map<String, dynamic>?> loadMap(String key, {Duration? maxAge}) async {
    final raw = await loadString(key, maxAge: maxAge);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Elimina la caché de una clave específica.
  Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final hashed = _normalizeKey(key);
    await prefs.remove('$_prefix$hashed');
    await prefs.remove('$_tsPrefix$hashed');
  }

  /// Elimina entradas expiradas y excedentes de [maxEntries].
  Future<void> evictExpired({Duration maxAge = defaultMaxAge}) async {
    final prefs = await SharedPreferences.getInstance();
    await _evictIfNeeded(prefs, maxAge: maxAge);
  }

  /// Retorna el timestamp de cuándo se guardó la caché, o null.
  Future<DateTime?> lastSaved(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final hashed = _normalizeKey(key);
    final ts = prefs.getInt('$_tsPrefix$hashed');
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts);
  }

  Future<void> _evictIfNeeded(
    SharedPreferences prefs, {
    Duration maxAge = defaultMaxAge,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final maxAgeMs = maxAge.inMilliseconds;
    final entries = <({String hashed, int ts})>[];

    for (final fullKey in prefs.getKeys()) {
      if (!fullKey.startsWith(_prefix)) continue;
      final hashed = fullKey.substring(_prefix.length);
      final ts = prefs.getInt('$_tsPrefix$hashed') ?? 0;
      if (ts > 0 && (nowMs - ts) > maxAgeMs) {
        await prefs.remove(fullKey);
        await prefs.remove('$_tsPrefix$hashed');
      } else {
        entries.add((hashed: hashed, ts: ts));
      }
    }

    if (entries.length > maxEntries) {
      entries.sort((a, b) => a.ts.compareTo(b.ts));
      final toRemove = entries.length - maxEntries;
      for (var i = 0; i < toRemove; i++) {
        final hashed = entries[i].hashed;
        await prefs.remove('$_prefix$hashed');
        await prefs.remove('$_tsPrefix$hashed');
      }
    }
  }
}

/// Provider Riverpod para OfflineCacheService.
final offlineCacheProvider = Provider<OfflineCacheService>(
  (ref) => OfflineCacheService(),
);
