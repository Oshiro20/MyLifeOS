import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TikTokService {
  final String apiKey;
  static const String _apiHost =
      'tiktok-download-video-no-watermark.p.rapidapi.com';

  TikTokService(this.apiKey);

  /// Obtiene la información del video de TikTok cuando existe una API key de RapidAPI.
  Future<Map<String, dynamic>?> getTikTokVideoInfo(String tiktokUrl) async {
    if (apiKey.trim().isEmpty) {
      debugPrint('ℹ️ [TikTokService] Sin TIKTOK_API_KEY, omitiendo RapidAPI.');
      return null;
    }

    final encodedUrl = Uri.encodeComponent(tiktokUrl);
    final masked = apiKey.length > 8
        ? '***${apiKey.substring(apiKey.length - 8)}'
        : '***';
    debugPrint('🔍 TikTokService: Trying RapidAPI ($masked) for: $tiktokUrl');

    final endpoints = [
      '/tiktok/info?url=$encodedUrl',
      '/tiktok?url=$encodedUrl',
      '/api?url=$encodedUrl',
    ];

    for (final endpoint in endpoints) {
      final uri = Uri.parse('https://$_apiHost$endpoint');
      try {
        final response = await http.get(
          uri,
          headers: {
            'x-rapidapi-host': _apiHost,
            'x-rapidapi-key': apiKey,
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is Map<String, dynamic> &&
              (decoded.containsKey('data') ||
                  decoded.containsKey('url') ||
                  decoded.containsKey('video_link_nwm'))) {
            return decoded;
          }
        }
      } catch (e) {
        debugPrint('❌ RapidAPI endpoint $endpoint error: $e');
      }
    }
    return null;
  }

  /// Extracción pública alternativa sin API key mediante oEmbed y metadatos HTML
  /// (título, descripción/caption, JSON-LD Recipe e imagen portada).
  Future<({String contextText, String? thumbnailUrl})?>
      extractPublicRecipeMetadata(String rawUrl) async {
    final normalizedUrl =
        rawUrl.startsWith('http://') || rawUrl.startsWith('https://')
            ? rawUrl.trim()
            : 'https://${rawUrl.trim()}';
    final lower = normalizedUrl.toLowerCase();
    final parts = <String>[];
    String? thumbnailUrl;

    // 1. Intentar endpoints oEmbed públicos de TikTok o YouTube
    final Uri? oembedUri;
    if (lower.contains('tiktok.com')) {
      oembedUri = Uri.parse(
        'https://www.tiktok.com/oembed?url=${Uri.encodeComponent(normalizedUrl)}',
      );
    } else if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      oembedUri = Uri.parse(
        'https://www.youtube.com/oembed?url=${Uri.encodeComponent(normalizedUrl)}&format=json',
      );
    } else {
      oembedUri = null;
    }

    if (oembedUri != null) {
      try {
        final resp = await http.get(
          oembedUri,
          headers: {'User-Agent': 'Mozilla/5.0 (compatible; MyLifeOS/3.7)'},
        ).timeout(const Duration(seconds: 12));
        if (resp.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
          if (decoded is Map<String, dynamic>) {
            final title = decoded['title']?.toString().trim() ?? '';
            final author = decoded['author_name']?.toString().trim() ?? '';
            final thumb = decoded['thumbnail_url']?.toString().trim();
            if (title.isNotEmpty) {
              parts.add('Título/Descripción del video: $title');
            }
            if (author.isNotEmpty) {
              parts.add('Autor: $author');
            }
            if (thumb != null && thumb.startsWith('http')) {
              thumbnailUrl = thumb;
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ oEmbed error: $e');
      }
    }

    // 2. Intentar leer HTML público (OpenGraph / meta description / JSON-LD Recipe)
    try {
      final resp = await http.get(
        Uri.parse(normalizedUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml',
        },
      ).timeout(const Duration(seconds: 12));

      if (resp.statusCode >= 200 && resp.statusCode < 400) {
        final html = utf8.decode(resp.bodyBytes, allowMalformed: true);
        final ogTitle = _extractMeta(html, 'og:title') ?? _extractTitle(html);
        final ogDesc = _extractMeta(html, 'og:description') ??
            _extractMeta(html, 'description');
        final ogImg = _extractMeta(html, 'og:image');
        final ldRecipe = _extractRecipeJsonLd(html);

        if (ogTitle != null &&
            ogTitle.isNotEmpty &&
            !parts.any((p) => p.contains(ogTitle))) {
          parts.add('Título página: $ogTitle');
        }
        if (ogDesc != null &&
            ogDesc.isNotEmpty &&
            !parts.any((p) => p.contains(ogDesc))) {
          parts.add('Descripción/Caption: $ogDesc');
        }
        if (ldRecipe != null && ldRecipe.isNotEmpty) {
          parts.add('Datos estructurados de receta: $ldRecipe');
        }
        if (thumbnailUrl == null &&
            ogImg != null &&
            ogImg.startsWith('http')) {
          thumbnailUrl = ogImg;
        }
      }
    } catch (e) {
      debugPrint('⚠️ HTML metadata fetch error: $e');
    }

    final contextText = parts.join('\n').trim();
    if (contextText.isEmpty && thumbnailUrl == null) return null;
    return (contextText: contextText, thumbnailUrl: thumbnailUrl);
  }

  static String? _extractMeta(String html, String propertyOrName) {
    final pattern = RegExp(
      '<meta[^>]+(?:property|name)=["\']${RegExp.escape(propertyOrName)}["\'][^>]+content=["\']([^"\']+)["\']',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(html);
    if (match != null) return _unescapeHtml(match.group(1)!.trim());

    final reversePattern = RegExp(
      '<meta[^>]+content=["\']([^"\']+)["\'][^>]+(?:property|name)=["\']${RegExp.escape(propertyOrName)}["\']',
      caseSensitive: false,
    );
    final revMatch = reversePattern.firstMatch(html);
    return revMatch != null ? _unescapeHtml(revMatch.group(1)!.trim()) : null;
  }

  static String? _extractTitle(String html) {
    final match =
        RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false)
            .firstMatch(html);
    if (match == null) return null;
    return _unescapeHtml(match.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim());
  }

  static String? _extractRecipeJsonLd(String html) {
    final matches = RegExp(
      r'<script[^>]+type=["\x27]application/ld\+json["\x27][^>]*>([\s\S]*?)</script>',
      caseSensitive: false,
    ).allMatches(html);
    for (final m in matches) {
      final raw = m.group(1)?.trim() ?? '';
      if (raw.toLowerCase().contains('recipe')) {
        return raw.length > 3500 ? raw.substring(0, 3500) : raw;
      }
    }
    return null;
  }

  static String _unescapeHtml(String input) => input
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}
