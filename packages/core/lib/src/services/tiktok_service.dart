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
    final uri = Uri.parse('https://$_apiHost/tiktok/info?url=$encodedUrl');

    try {
      final response = await http.get(
        uri,
        headers: {
          'x-rapidapi-host': _apiHost,
          'x-rapidapi-key': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        // Dependiendo de la estructura de la API, aquí buscaremos la llave del video.
        // Por lo general puede venir en decoded['data']['play'] o similar.
        return decoded;
      } else {
        debugPrint(
            'Error consultando TikTok API: \${response.statusCode} - \${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception en TikTokService: \$e');
      return null;
    }
  }
}
