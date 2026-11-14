import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Cliente seguro para conectar MyLifeOS con el backend de WalletAI en Render.
///
/// Gestiona:
/// - Autenticación con la Cuenta WalletAI (JWT guardado en FlutterSecureStorage)
/// - Lectura del resumen enriquecido publicado por WalletAI (`GET /api/ecosystem/summary`)
/// - Envío de transacciones pendientes hacia WalletAI (`POST /api/ecosystem/pending-transactions`)
/// - Proxy de IA (`POST /api/ai/generate`) para evitar exponer API keys en el APK
class WalletCloudService {
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api-gastos-6iri.onrender.com/api',
  );

  static const _tokenKey = 'walletai_cloud_token';
  static const _usernameKey = 'walletai_cloud_username';
  static const _baseUrlKey = 'walletai_cloud_base_url';

  static const _storage = FlutterSecureStorage();

  static Future<String> getBaseUrl() async {
    try {
      final custom = await _storage.read(key: _baseUrlKey);
      if (custom != null && custom.trim().isNotEmpty) {
        return custom.trim().replaceAll(RegExp(r'/+$'), '');
      }
    } catch (_) {}
    return defaultApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
  }

  static Future<({String? token, String? username})> getSession() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final username = await _storage.read(key: _usernameKey);
      return (token: token, username: username);
    } catch (_) {
      return (token: null, username: null);
    }
  }

  static Future<bool> isSignedIn() async {
    final session = await getSession();
    return session.token != null && session.token!.isNotEmpty;
  }

  static Future<void> signOut() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _usernameKey);
    } catch (_) {}
  }

  /// Inicia sesión o registra una Cuenta WalletAI compartida.
  static Future<({bool success, String message, String? username})> authenticate({
    required String username,
    required String password,
    bool isRegister = false,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final endpoint = isRegister ? 'auth/register' : 'auth/login';
      final response = await http
          .post(
            Uri.parse('$baseUrl/$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 35));

      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final token = body['token'] as String?;
        final userMap = body['user'] as Map<String, dynamic>?;
        final resolvedUser = userMap?['username'] as String? ?? username.trim();
        if (token != null && token.isNotEmpty) {
          await _storage.write(key: _tokenKey, value: token);
          await _storage.write(key: _usernameKey, value: resolvedUser);
        }
        return (
          success: true,
          message: isRegister
              ? 'Cuenta WalletAI creada y vinculada'
              : 'Sesión iniciada con WalletAI',
          username: resolvedUser,
        );
      }

      return (
        success: false,
        message: (body['error'] ??
                body['message'] ??
                'Error HTTP ${response.statusCode}')
            .toString(),
        username: null,
      );
    } catch (e) {
      return (
        success: false,
        message: 'Error conectando con WalletAI Cloud: $e',
        username: null,
      );
    }
  }

  /// Descarga el resumen enriquecido publicado por WalletAI desde la nube.
  static Future<Map<String, dynamic>?> fetchSummaryJson() async {
    final session = await getSession();
    if (session.token == null || session.token!.isEmpty) return null;

    try {
      final baseUrl = await getBaseUrl();
      final response = await http
          .get(
            Uri.parse('$baseUrl/ecosystem/summary'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 401) {
        await signOut();
        return null;
      }

      if (response.statusCode == 200) {
        final decoded =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final summary = decoded['summary'];
        if (summary is Map<String, dynamic>) {
          return summary;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[WalletCloudService] fetchSummaryJson error: $e');
      return null;
    }
  }

  /// Envía un gasto/ingreso pendiente desde MyLifeOS para que WalletAI lo importe.
  static Future<({bool success, String message})> sendPendingTransaction({
    required double amount,
    required String description,
    String type = 'expense',
    String categoryHint = 'Alimentación',
    String currency = 'PEN',
    List<Map<String, dynamic>> items = const [],
  }) async {
    final session = await getSession();
    if (session.token == null || session.token!.isEmpty) {
      return (
        success: false,
        message: 'Inicia sesión con tu Cuenta WalletAI primero.',
      );
    }

    try {
      final baseUrl = await getBaseUrl();
      final response = await http
          .post(
            Uri.parse('$baseUrl/ecosystem/pending-transactions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.token}',
            },
            body: jsonEncode({
              'amount': amount,
              'type': type,
              'currency': currency,
              'description': description,
              'categoryHint': categoryHint,
              'source': 'mylifeos',
              'date': DateTime.now().toIso8601String(),
              'items': items,
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 401) {
        await signOut();
        return (
          success: false,
          message: 'Tu sesión expiró. Vuelve a iniciar sesión en Finanzas.',
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (
          success: true,
          message: 'Enviado a WalletAI. Se importará al abrir la app.',
        );
      }

      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return (
        success: false,
        message: (body['error'] ?? 'HTTP ${response.statusCode}').toString(),
      );
    } catch (e) {
      return (
        success: false,
        message: 'Error enviando movimiento a WalletAI: $e',
      );
    }
  }

  /// Proxy de IA vía Render (`/api/ai/generate`) con fallback automático Gemini -> Groq.
  static Future<String?> generateAI({
    String? systemPrompt,
    required String userMessage,
    bool expectJson = false,
    String? mediaBase64,
    String? mediaMimeType,
    List<Map<String, String>>? mediaItems,
    List<Map<String, String>>? history,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http
          .post(
            Uri.parse('$baseUrl/ai/generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              if (systemPrompt != null) 'systemPrompt': systemPrompt,
              'userMessage': userMessage,
              'expectJson': expectJson,
              if (mediaBase64 != null) 'mediaBase64': mediaBase64,
              if (mediaMimeType != null) 'mediaMimeType': mediaMimeType,
              if (mediaItems != null && mediaItems.isNotEmpty)
                'mediaItems': mediaItems,
              if (history != null && history.isNotEmpty) 'history': history,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final directText = decoded['text'] as String?;
        if (directText != null && directText.isNotEmpty) return directText;

        final choices = decoded['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final first = choices.first as Map<String, dynamic>?;
          final msg = first?['message'] as Map<String, dynamic>?;
          final content = msg?['content'] as String?;
          if (content != null && content.isNotEmpty) return content;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[WalletCloudService] generateAI error: $e');
      return null;
    }
  }
}
