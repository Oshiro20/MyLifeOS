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

    // Try multiple possible endpoints
    final endpoints = [
      '/api?url=$encodedUrl',
      '/tiktok?url=$encodedUrl',
      '/tiktok/info?url=$encodedUrl',
    ];

    for (final endpoint in endpoints) {
      final uri = Uri.parse('https://$_apiHost$endpoint');
      debugPrint('🔍 Trying endpoint: $endpoint');

      try {
        final response = await http.get(
          uri,
          headers: {
            'x-rapidapi-host': _apiHost,
            'x-rapidapi-key': apiKey,
            'Content-Type': 'application/json',
          },
        );

        debugPrint('📡 Response status: ${response.statusCode}');
        debugPrint('📦 Response body: ${response.body}');

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body) as Map<String, dynamic>;

          // Check if response has valid data
          if (decoded.containsKey('data') || decoded.containsKey('url')) {
            debugPrint('✅ Success with endpoint: $endpoint');
            return decoded;
          }
        }
      } catch (e) {
        debugPrint('❌ Exception with endpoint $endpoint: $e');
      }
    }

    debugPrint('❌ All endpoints failed');
    return null;
  }
}
