import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TikTokService {
  final String apiKey;
  static const String _apiHost =
      'tiktok-download-video-no-watermark.p.rapidapi.com';

  TikTokService(this.apiKey);

  /// Obtiene la información del video de TikTok (incluyendo la URL de descarga sin marca de agua).
  Future<Map<String, dynamic>?> getTikTokVideoInfo(String tiktokUrl) async {
    final encodedUrl = Uri.encodeComponent(tiktokUrl);

    debugPrint('🔍 TikTokService: Trying to get video info for: $tiktokUrl');
    debugPrint(
        '🔑 Using API Key: ${apiKey.isNotEmpty ? '***${apiKey.substring(apiKey.length - 8)}' : 'EMPTY'}');

    // Try the official endpoint as shown in RapidAPI docs
    final endpoints = [
      '/tiktok/info?url=$encodedUrl',
      '/tiktok?url=$encodedUrl',
      '/api?url=$encodedUrl',
    ];

    for (final endpoint in endpoints) {
      final uri = Uri.parse('https://$_apiHost$endpoint');
      debugPrint(' Trying endpoint: $endpoint');

      try {
        final response = await http.get(
          uri,
          headers: {
            'x-rapidapi-host': _apiHost,
            'x-rapidapi-key': apiKey,
            'Content-Type': 'application/json',
          },
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            debugPrint('⏱️ Timeout for endpoint: $endpoint');
            throw Exception('Timeout al conectar con TikTok API');
          },
        );

        debugPrint('📦 Response status: ${response.statusCode}');
        debugPrint(
            '📦 Response body (first 500 chars): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body) as Map<String, dynamic>;

          // Check if response has valid data
          if (decoded.containsKey('data') ||
              decoded.containsKey('url') ||
              decoded.containsKey('video_link_nwm')) {
            debugPrint('✅ Success with endpoint: $endpoint');
            debugPrint('📦 Response keys: ${decoded.keys.toList()}');
            return decoded;
          }

          debugPrint(
              '⚠️ Response missing expected keys. Keys found: ${decoded.keys.toList()}');
        } else {
          debugPrint('❌ HTTP ${response.statusCode} for endpoint: $endpoint');
        }
      } catch (e) {
        debugPrint('❌ Exception with endpoint $endpoint: $e');
      }
    }

    debugPrint('❌ All endpoints failed');
    return null;
  }
}
