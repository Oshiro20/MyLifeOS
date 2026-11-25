import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class MyLifeOSCloudBackupMeta {
  final bool exists;
  final String? deviceId;
  final String? deviceName;
  final int schemaVersion;
  final bool includesPhotos;
  final String? checksum;
  final int sizeBytes;
  final String? updatedAt;

  const MyLifeOSCloudBackupMeta({
    required this.exists,
    this.deviceId,
    this.deviceName,
    this.schemaVersion = 16,
    this.includesPhotos = false,
    this.checksum,
    this.sizeBytes = 0,
    this.updatedAt,
  });

  factory MyLifeOSCloudBackupMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null || json['exists'] != true) {
      return const MyLifeOSCloudBackupMeta(exists: false);
    }
    return MyLifeOSCloudBackupMeta(
      exists: true,
      deviceId: json['deviceId'] as String?,
      deviceName: json['deviceName'] as String?,
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 16,
      includesPhotos: json['includesPhotos'] == true,
      checksum: json['checksum'] as String?,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

/// Cliente seguro para conectar MyLifeOS con el backend unificado en Render.
///
/// Gestiona:
/// - Cuenta única del Ecosistema (WalletAI + MyLifeOS): login, registro, edición de perfil,
///   cambio de contraseña y recuperación (clave de recuperación + correo vinculado).
/// - Backup en la nube específico de MyLifeOS (`/api/mylifeos/backup/*`).
/// - Lectura del resumen enriquecido publicado por WalletAI (`GET /api/ecosystem/summary`).
/// - Envío de transacciones pendientes hacia WalletAI (`POST /api/ecosystem/pending-transactions`).
/// - Proxy de IA (`POST /api/ai/generate`).
class WalletCloudService {
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api-gastos-6iri.onrender.com/api',
  );

  static const _tokenKey = 'walletai_cloud_token';
  static const _usernameKey = 'walletai_cloud_username';
  static const _displayNameKey = 'walletai_cloud_display_name';
  static const _emailKey = 'walletai_cloud_email';
  static const _hasRecoveryKeyPref = 'walletai_cloud_has_recovery_key';
  static const _baseUrlKey = 'walletai_cloud_base_url';
  static const _deviceIdPrefKey = 'mylifeos_cloud_device_id';
  static const _serverUpdatedAtPrefKey = 'mylifeos_cloud_backup_updated_at';
  static const _lastCloudSyncedPrefKey = 'mylifeos_cloud_backup_last_synced';

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

  static Future<({String deviceId, String deviceName})>
      getOrCreateDeviceIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_deviceIdPrefKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdPrefKey, deviceId);
    }
    final platformName = Platform.isAndroid
        ? 'Android'
        : Platform.isIOS
            ? 'iOS'
            : Platform.operatingSystem;
    final host = Platform.localHostname.trim();
    final deviceName = host.isNotEmpty && host.toLowerCase() != 'localhost'
        ? '$platformName ($host)'
        : '$platformName MyLifeOS';
    return (deviceId: deviceId, deviceName: deviceName);
  }

  static Future<void> _saveProfileMeta(Map<String, dynamic>? userMap) async {
    if (userMap == null) return;
    final username = userMap['username'] as String?;
    if (username != null && username.isNotEmpty) {
      await _storage.write(key: _usernameKey, value: username);
    }
    final displayName = userMap['displayName'] as String?;
    if (displayName != null && displayName.trim().isNotEmpty) {
      await _storage.write(key: _displayNameKey, value: displayName.trim());
    } else {
      await _storage.delete(key: _displayNameKey);
    }
    final email = userMap['email'] as String?;
    if (email != null && email.trim().isNotEmpty) {
      await _storage.write(key: _emailKey, value: email.trim());
    } else {
      await _storage.delete(key: _emailKey);
    }
    if (userMap.containsKey('hasRecoveryKey')) {
      await _storage.write(
        key: _hasRecoveryKeyPref,
        value: userMap['hasRecoveryKey'] == true ? 'true' : 'false',
      );
    }
  }

  static Future<
      ({
        String? token,
        String? username,
        String? displayName,
        String? email,
        bool hasRecoveryKey,
        String? serverUpdatedAt,
        String? lastCloudSyncedAt,
      })> getSession() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final username = await _storage.read(key: _usernameKey);
      final displayName = await _storage.read(key: _displayNameKey);
      final email = await _storage.read(key: _emailKey);
      final hasKeyRaw = await _storage.read(key: _hasRecoveryKeyPref);
      final prefs = await SharedPreferences.getInstance();
      return (
        token: token,
        username: username,
        displayName: displayName,
        email: email,
        hasRecoveryKey: hasKeyRaw == 'true',
        serverUpdatedAt: prefs.getString(_serverUpdatedAtPrefKey),
        lastCloudSyncedAt: prefs.getString(_lastCloudSyncedPrefKey),
      );
    } catch (_) {
      return (
        token: null,
        username: null,
        displayName: null,
        email: null,
        hasRecoveryKey: false,
        serverUpdatedAt: null,
        lastCloudSyncedAt: null,
      );
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
      await _storage.delete(key: _displayNameKey);
      await _storage.delete(key: _emailKey);
      await _storage.delete(key: _hasRecoveryKeyPref);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_serverUpdatedAtPrefKey);
      await prefs.remove(_lastCloudSyncedPrefKey);
    } catch (_) {}
  }

  /// Inicia sesión o registra la Cuenta única del Ecosistema (WalletAI + MyLifeOS).
  static Future<
      ({
        bool success,
        String message,
        String? username,
        String? recoveryKey,
        MyLifeOSCloudBackupMeta? myLifeOSBackup,
      })> authenticate({
    required String username,
    required String password,
    bool isRegister = false,
    String? displayName,
    String? email,
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
              if (isRegister &&
                  displayName != null &&
                  displayName.trim().isNotEmpty)
                'displayName': displayName.trim(),
              if (isRegister && email != null && email.trim().isNotEmpty)
                'email': email.trim(),
            }),
          )
          .timeout(const Duration(seconds: 35));

      final body = _tryDecodeMap(response.bodyBytes);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final token = body?['token'] as String?;
        final userMap = body?['user'] as Map<String, dynamic>?;
        final resolvedUser = userMap?['username'] as String? ?? username.trim();
        if (token != null && token.isNotEmpty) {
          await _storage.write(key: _tokenKey, value: token);
          await _saveProfileMeta(userMap ?? {'username': resolvedUser});
        }
        final backupMeta = MyLifeOSCloudBackupMeta.fromJson(
          body?['myLifeOSBackup'] as Map<String, dynamic>?,
        );
        return (
          success: true,
          message: isRegister
              ? 'Cuenta del ecosistema creada y vinculada'
              : 'Sesión iniciada en tu cuenta del ecosistema',
          username: resolvedUser,
          recoveryKey: body?['recoveryKey'] as String?,
          myLifeOSBackup: backupMeta,
        );
      }

      return (
        success: false,
        message: _friendlyErrorMessage(response.statusCode, body),
        username: null,
        recoveryKey: null,
        myLifeOSBackup: null,
      );
    } catch (e) {
      return (
        success: false,
        message: 'Error conectando con la nube: $e',
        username: null,
        recoveryKey: null,
        myLifeOSBackup: null,
      );
    }
  }

  /// Sincroniza los datos del perfil desde el servidor (`GET /api/auth/me`).
  static Future<({bool success, String message})> fetchProfile() async {
    final session = await getSession();
    if (session.token == null || session.token!.isEmpty) {
      return (success: false, message: 'No hay sesión activa.');
    }
    try {
      final baseUrl = await getBaseUrl();
      final response = await http
          .get(
            Uri.parse('$baseUrl/auth/me'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode == 401) {
        await signOut();
        return (success: false, message: 'Sesión expirada.');
      }
      final body = _tryDecodeMap(response.bodyBytes);
      if (response.statusCode == 200) {
        await _saveProfileMeta(body?['user'] as Map<String, dynamic>?);
        return (success: true, message: 'OK');
      }
      return (
        success: false,
        message: _friendlyErrorMessage(response.statusCode, body),
      );
    } catch (e) {
      return (success: false, message: 'Error consultando perfil: $e');
    }
  }

  /// Edita nombre visible, correo vinculado y/o @usuario.
  static Future<({bool success, String message})> updateProfile({
    String? displayName,
    String? email,
    String? username,
    String? currentPassword,
  }) async {
    final session = await getSession();
    if (session.token == null || session.token!.isEmpty) {
      return (success: false, message: 'Inicia sesión primero.');
    }
    try {
      final baseUrl = await getBaseUrl();
      final payload = <String, dynamic>{};
      if (displayName != null) payload['displayName'] = displayName.trim();
      if (email != null) payload['email'] = email.trim();
      if (username != null) payload['username'] = username.trim();
      if (currentPassword != null && currentPassword.isNotEmpty) {
        payload['currentPassword'] = currentPassword;
      }

      final response = await http
          .patch(
            Uri.parse('$baseUrl/auth/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.token}',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      final body = _tryDecodeMap(response.bodyBytes);
      if (response.statusCode == 401) {
        await signOut();
        return (success: false, message: 'Tu sesión expiró.');
      }
      if (response.statusCode == 200) {
        final newToken = body?['token'] as String?;
        if (newToken != null && newToken.isNotEmpty) {
          await _storage.write(key: _tokenKey, value: newToken);
        }
        await _saveProfileMeta(body?['user'] as Map<String, dynamic>?);
        return (
          success: true,
          message:
              (body?['message'] ?? 'Perfil actualizado correctamente').toString(),
        );
      }
      return (
        success: false,
        message: _friendlyErrorMessage(response.statusCode, body),
      );
    } catch (e) {
      return (success: false, message: 'Error actualizando perfil: $e');
    }
  }

  /// Cambia la contraseña de la cuenta.
  static Future<({bool success, String message})> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final session = await getSession();
    if (session.token == null || session.token!.isEmpty) {
      return (success: false, message: 'Inicia sesión primero.');
    }
    try {
      final baseUrl = await getBaseUrl();
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/change-password'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.token}',
            },
            body: jsonEncode({
              'currentPassword': currentPassword,
              'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 30));
      final body = _tryDecodeMap(response.bodyBytes);
      if (response.statusCode == 200) {
        return (
          success: true,
          message: (body?['message'] ?? 'Contraseña actualizada').toString(),
        );
      }
      return (
        success: false,
        message: _friendlyErrorMessage(response.statusCode, body),
      );
    } catch (e) {
      return (success: false, message: 'Error cambiando contraseña: $e');
    }
  }

  /// Genera o regenera la clave de recuperación (requiere contraseña actual).
  static Future<({bool success, String message, String? recoveryKey})>
      regenerateRecoveryKey({required String currentPassword}) async {
    final session = await getSession();
    if (session.token == null || session.token!.isEmpty) {
      return (
        success: false,
        message: 'Inicia sesión primero.',
        recoveryKey: null,
      );
    }
    try {
      final baseUrl = await getBaseUrl();
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/recovery-key/regenerate'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.token}',
            },
            body: jsonEncode({'currentPassword': currentPassword}),
          )
          .timeout(const Duration(seconds: 30));
      final body = _tryDecodeMap(response.bodyBytes);
      if (response.statusCode == 200) {
        await _storage.write(key: _hasRecoveryKeyPref, value: 'true');
        return (
          success: true,
          message: (body?['message'] ?? 'Clave generada').toString(),
          recoveryKey: body?['recoveryKey'] as String?,
        );
      }
      return (
        success: false,
        message: _friendlyErrorMessage(response.statusCode, body),
        recoveryKey: null,
      );
    } catch (e) {
      return (
        success: false,
        message: 'Error generando clave de recuperación: $e',
        recoveryKey: null,
      );
    }
  }

  /// Restablece contraseña olvidada usando usuario/correo + clave de recuperación.
  static Future<({bool success, String message, String? username})>
      recoverPassword({
    required String identifier,
    required String recoveryKey,
    required String newPassword,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/recover-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'identifier': identifier.trim(),
              'recoveryKey': recoveryKey.trim(),
              'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 30));
      final body = _tryDecodeMap(response.bodyBytes);
      if (response.statusCode == 200) {
        return (
          success: true,
          message: (body?['message'] ?? 'Contraseña restablecida').toString(),
          username: body?['username'] as String?,
        );
      }
      return (
        success: false,
        message: _friendlyErrorMessage(response.statusCode, body),
        username: null,
      );
    } catch (e) {
      return (
        success: false,
        message: 'Error recuperando contraseña: $e',
        username: null,
      );
    }
  }

  /// Recupera el nombre de usuario usando correo vinculado + contraseña o clave.
  static Future<
      ({
        bool success,
        String message,
        String? username,
        String? displayName,
      })> recoverUsername({
    required String email,
    String? password,
    String? recoveryKey,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/recover-username'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim(),
              if (password != null && password.isNotEmpty) 'password': password,
              if (recoveryKey != null && recoveryKey.trim().isNotEmpty)
                'recoveryKey': recoveryKey.trim(),
            }),
          )
          .timeout(const Duration(seconds: 30));
      final body = _tryDecodeMap(response.bodyBytes);
      if (response.statusCode == 200) {
        return (
          success: true,
          message: 'Usuario encontrado: ${body?['username']}',
          username: body?['username'] as String?,
          displayName: body?['displayName'] as String?,
        );
      }
      return (
        success: false,
        message: _friendlyErrorMessage(response.statusCode, body),
        username: null,
        displayName: null,
      );
    } catch (e) {
      return (
        success: false,
        message: 'Error recuperando usuario: $e',
        username: null,
        displayName: null,
      );
    }
  }

  // ── BACKUP EN LA NUBE DE MYLIFEOS ───────────────────────────────────────────

  static Future<
      ({
        bool success,
        String message,
        MyLifeOSCloudBackupMeta? latestBackup,
      })> fetchMyLifeOSBackupStatus() async {
    final session = await getSession();
    if (session.token == null || session.token!.isEmpty) {
      return (
        success: false,
        message: 'No hay sesión activa.',
        latestBackup: null,
      );
    }
    try {
      final baseUrl = await getBaseUrl();
      final response = await http
          .get(
            Uri.parse('$baseUrl/mylifeos/backup/status'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 401) {
        await signOut();
        return (
          success: false,
          message: 'Sesión expirada.',
          latestBackup: null,
        );
      }
      final body = _tryDecodeMap(response.bodyBytes);
      if (response.statusCode == 200) {
        return (
          success: true,
          message: 'OK',
          latestBackup: MyLifeOSCloudBackupMeta.fromJson(
            body?['latestBackup'] as Map<String, dynamic>?,
          ),
        );
      }
      return (
        success: false,
        message: _friendlyErrorMessage(response.statusCode, body),
        latestBackup: null,
      );
    } catch (e) {
      return (
        success: false,
        message: 'Error consultando respaldo en la nube: $e',
        latestBackup: null,
      );
    }
  }

  static Future<
      ({
        bool success,
        String message,
        bool hasConflict,
        MyLifeOSCloudBackupMeta? serverBackup,
      })> uploadMyLifeOSBackup({
    required Uint8List zipBytes,
    required int schemaVersion,
    required bool includesPhotos,
    bool force = false,
  }) async {
    final session = await getSession();
    if (session.token == null || session.token!.isEmpty) {
      return (
        success: false,
        message: 'Inicia sesión con tu cuenta del ecosistema primero.',
        hasConflict: false,
        serverBackup: null,
      );
    }
    try {
      final baseUrl = await getBaseUrl();
      final identity = await getOrCreateDeviceIdentity();
      final checksum = sha256.convert(zipBytes).toString();
      final response = await http
          .post(
            Uri.parse('$baseUrl/mylifeos/backup/upload'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.token}',
            },
            body: jsonEncode({
              'deviceId': identity.deviceId,
              'deviceName': identity.deviceName,
              'schemaVersion': schemaVersion,
              'includesPhotos': includesPhotos,
              'checksum': checksum,
              'payloadBase64': base64Encode(zipBytes),
              'baseUpdatedAt': session.serverUpdatedAt,
              'force': force,
            }),
          )
          .timeout(const Duration(seconds: 90));

      final body = _tryDecodeMap(response.bodyBytes);
      if (response.statusCode == 401) {
        await signOut();
        return (
          success: false,
          message: 'Tu sesión expiró. Inicia sesión nuevamente.',
          hasConflict: false,
          serverBackup: null,
        );
      }
      if (response.statusCode == 409 &&
          body?['error'] == 'CONFLICT_NEWER_BACKUP') {
        return (
          success: false,
          hasConflict: true,
          serverBackup: MyLifeOSCloudBackupMeta.fromJson(
            body?['latestBackup'] as Map<String, dynamic>?,
          ),
          message: (body?['message'] ??
                  'Otro dispositivo guardó un respaldo más reciente.')
              .toString(),
        );
      }
      if (response.statusCode == 200) {
        final latest = MyLifeOSCloudBackupMeta.fromJson(
          body?['latestBackup'] as Map<String, dynamic>?,
        );
        final prefs = await SharedPreferences.getInstance();
        if (latest.updatedAt != null) {
          await prefs.setString(_serverUpdatedAtPrefKey, latest.updatedAt!);
        }
        await prefs.setString(
          _lastCloudSyncedPrefKey,
          DateTime.now().toIso8601String(),
        );
        return (
          success: true,
          hasConflict: false,
          serverBackup: latest,
          message: '☁️ Backup de MyLifeOS subido a tu cuenta correctamente.',
        );
      }
      return (
        success: false,
        hasConflict: false,
        serverBackup: null,
        message: _friendlyErrorMessage(response.statusCode, body),
      );
    } catch (e) {
      return (
        success: false,
        hasConflict: false,
        serverBackup: null,
        message: 'Error subiendo respaldo de MyLifeOS: $e',
      );
    }
  }

  static Future<
      ({
        bool success,
        String message,
        Uint8List? zipBytes,
        MyLifeOSCloudBackupMeta? latestBackup,
      })> downloadMyLifeOSBackup() async {
    final session = await getSession();
    if (session.token == null || session.token!.isEmpty) {
      return (
        success: false,
        message: 'Inicia sesión primero.',
        zipBytes: null,
        latestBackup: null,
      );
    }
    try {
      final baseUrl = await getBaseUrl();
      final response = await http
          .get(
            Uri.parse('$baseUrl/mylifeos/backup/download'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 90));

      final body = _tryDecodeMap(response.bodyBytes);
      if (response.statusCode == 401) {
        await signOut();
        return (
          success: false,
          message: 'Tu sesión expiró.',
          zipBytes: null,
          latestBackup: null,
        );
      }
      if (response.statusCode != 200 || body == null) {
        return (
          success: false,
          message: _friendlyErrorMessage(response.statusCode, body),
          zipBytes: null,
          latestBackup: null,
        );
      }

      final latest = MyLifeOSCloudBackupMeta.fromJson(
        body['latestBackup'] as Map<String, dynamic>?,
      );
      final rawB64 = body['payloadBase64'] as String?;
      if (rawB64 == null || rawB64.isEmpty) {
        return (
          success: false,
          message: 'El respaldo descargado está vacío.',
          zipBytes: null,
          latestBackup: latest,
        );
      }
      final bytes = Uint8List.fromList(base64Decode(rawB64));
      final actualChecksum = sha256.convert(bytes).toString();
      if (latest.checksum != null &&
          latest.checksum!.isNotEmpty &&
          actualChecksum != latest.checksum) {
        return (
          success: false,
          message:
              'Error de integridad: el archivo descargado no coincide con SHA-256.',
          zipBytes: null,
          latestBackup: latest,
        );
      }
      final prefs = await SharedPreferences.getInstance();
      if (latest.updatedAt != null) {
        await prefs.setString(_serverUpdatedAtPrefKey, latest.updatedAt!);
      }
      await prefs.setString(
        _lastCloudSyncedPrefKey,
        DateTime.now().toIso8601String(),
      );
      return (
        success: true,
        message: 'Respaldo descargado',
        zipBytes: bytes,
        latestBackup: latest,
      );
    } catch (e) {
      return (
        success: false,
        message: 'Error descargando respaldo: $e',
        zipBytes: null,
        latestBackup: null,
      );
    }
  }

  // ── ECOSISTEMA WALLETAI ─────────────────────────────────────────────────────

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
        final decoded = _tryDecodeMap(response.bodyBytes);
        final summary = decoded?['summary'];
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
        message: 'Inicia sesión con tu Cuenta del Ecosistema primero.',
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
          message: 'Tu sesión expiró. Vuelve a iniciar sesión en Ajustes.',
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (
          success: true,
          message: 'Enviado a WalletAI. Se importará al abrir la app.',
        );
      }

      final body = _tryDecodeMap(response.bodyBytes);
      return (
        success: false,
        message: _friendlyErrorMessage(response.statusCode, body),
      );
    } catch (e) {
      return (
        success: false,
        message: 'Error enviando movimiento a WalletAI: $e',
      );
    }
  }

  /// Proxy de IA vía Render (`/api/ai/generate`) con fallback automático.
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
        final decoded = _tryDecodeMap(response.bodyBytes);
        if (decoded == null) return null;
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

  static Map<String, dynamic>? _tryDecodeMap(List<int> bodyBytes) {
    if (bodyBytes.isEmpty) return null;
    try {
      final decoded = jsonDecode(utf8.decode(bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static String _friendlyErrorMessage(
    int statusCode,
    Map<String, dynamic>? body,
  ) {
    final serverMessage = body?['error'] ?? body?['message'];
    if (serverMessage != null && serverMessage.toString().trim().isNotEmpty) {
      return serverMessage.toString();
    }
    if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
      return 'El servidor en la nube está despertando ($statusCode). Inténtalo nuevamente en unos segundos.';
    }
    return 'Error HTTP $statusCode';
  }
}
