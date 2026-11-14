import 'dart:convert';

/// Utilidad compartida para limpiar bloques markdown (` ```json ... ``` `)
/// y extraer payloads JSON válidos desde respuestas generadas por IA.
class AiJsonParser {
  const AiJsonParser._();

  /// Elimina cercos de código Markdown (` ```json `, ` ``` `) y espacios.
  static String stripMarkdownFences(String raw) {
    var text = raw.trim();
    if (text.contains('```')) {
      text = text.replaceAll(RegExp(r'^```(?:json)?\s*', multiLine: true), '');
      text = text.replaceAll(RegExp(r'\s*```$', multiLine: true), '');
      text = text.replaceAll(RegExp(r'```(?:json)?\s*'), '');
      text = text.replaceAll('```', '');
    }
    return text.trim();
  }

  /// Extrae un JSON limpio buscando primero `[`..`]` o `{`..`}` según [expectList].
  static String extractJson(String raw, {bool expectList = false}) {
    final text = stripMarkdownFences(raw);

    if (expectList) {
      final arraySlice = _sliceBetween(text, '[', ']');
      if (arraySlice != null) return arraySlice;
      final objectSlice = _sliceBetween(text, '{', '}');
      if (objectSlice != null) return objectSlice;
      return text;
    }

    final objectSlice = _sliceBetween(text, '{', '}');
    if (objectSlice != null) return objectSlice;
    final arraySlice = _sliceBetween(text, '[', ']');
    if (arraySlice != null) return arraySlice;
    return text;
  }

  /// Intenta decodificar una respuesta de IA como objeto JSON.
  static Map<String, dynamic>? decodeMap(String raw) {
    try {
      final decoded = jsonDecode(extractJson(raw));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Intenta decodificar una respuesta de IA como lista JSON.
  static List<dynamic>? decodeList(String raw) {
    try {
      final decoded = jsonDecode(extractJson(raw, expectList: true));
      return decoded is List<dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static String? _sliceBetween(String text, String open, String close) {
    final start = text.indexOf(open);
    final end = text.lastIndexOf(close);
    if (start != -1 && end > start) {
      return text.substring(start, end + 1);
    }
    return null;
  }
}
