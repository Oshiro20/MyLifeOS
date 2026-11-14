import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio ligero de clima real usando Open-Meteo (sin API key) con fallback estacional.
class WeatherService {
  static const String _cityKey = 'weather_selected_city';

  static const Map<String, ({double lat, double lon})> presets = {
    'Lima': (lat: -12.0464, lon: -77.0428),
    'Arequipa': (lat: -16.4090, lon: -71.5375),
    'Cusco': (lat: -13.5319, lon: -71.9675),
    'Trujillo': (lat: -8.1116, lon: -79.0287),
    'Bogotá': (lat: 4.7110, lon: -74.0721),
    'Ciudad de México': (lat: 19.4326, lon: -99.1332),
    'Buenos Aires': (lat: -34.6037, lon: -58.3816),
    'Madrid': (lat: 40.4168, lon: -3.7038),
  };

  static String? _cachedCity;
  static String? _cachedSummary;
  static DateTime? _cachedAt;

  static Future<String> getSelectedCity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_cityKey);
      if (saved != null && presets.containsKey(saved)) {
        return saved;
      }
    } catch (_) {}
    return 'Lima';
  }

  static Future<void> setSelectedCity(String city) async {
    if (!presets.containsKey(city)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cityKey, city);
    _cachedCity = null;
    _cachedSummary = null;
    _cachedAt = null;
  }

  /// Devuelve el resumen actual (ej. `Despejado, 21°C (Lima)`), usando Open-Meteo
  /// con caché de 15 min y fallback estacional determinístico si no hay red.
  static Future<String> fetchCurrentWeather({bool forceRefresh = false}) async {
    final city = await getSelectedCity();
    if (!forceRefresh &&
        _cachedCity == city &&
        _cachedSummary != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < const Duration(minutes: 15)) {
      return _cachedSummary!;
    }

    final coords = presets[city] ?? presets['Lima']!;
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${coords.lat}&longitude=${coords.lon}'
        '&current=temperature_2m,weather_code&timezone=auto',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          final current = decoded['current'] as Map<String, dynamic>?;
          final temp = (current?['temperature_2m'] as num?)?.round();
          final code = (current?['weather_code'] as num?)?.toInt();
          if (temp != null && code != null) {
            final label = _weatherCodeToSpanish(code);
            final formatted = '$label, $temp°C · $city';
            _cachedCity = city;
            _cachedSummary = formatted;
            _cachedAt = DateTime.now();
            return formatted;
          }
        }
      }
    } catch (e) {
      debugPrint('[WeatherService] Fallback offline para $city: $e');
    }

    return '${seasonalFallback()} · $city';
  }

  /// Estimación estacional determinística sin red (ej. antes de resolver HTTP).
  static String seasonalFallback() {
    final now = DateTime.now();
    final month = now.month;
    final hour = now.hour;
    final baseTemp = (month >= 12 || month <= 3)
        ? 25
        : (month >= 7 && month <= 9)
            ? 17
            : 21;
    final adjusted = (hour < 8 || hour > 20) ? baseTemp - 3 : baseTemp;
    final condition = (month >= 12 || month <= 3)
        ? 'Soleado'
        : (month >= 7 && month <= 9)
            ? 'Nublado'
            : 'Parcialmente nublado';
    return '$condition, $adjusted°C';
  }

  static String _weatherCodeToSpanish(int code) {
    if (code == 0) return 'Despejado';
    if (code <= 2) return 'Parcialmente nublado';
    if (code == 3) return 'Nublado';
    if (code == 45 || code == 48) return 'Con neblina';
    if (code >= 51 && code <= 67) return 'Llovizna / Lluvioso';
    if (code >= 71 && code <= 77) return 'Frío / Nevado';
    if (code >= 80 && code <= 82) return 'Lluvioso';
    if (code >= 95) return 'Tormenta';
    return 'Templado';
  }
}
