import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

/// Servicio de identidad compartida entre MyLifeOS y WalletAI.
///
/// Este servicio genera un Project ID único que ambas aplicaciones pueden usar
/// para identificarse y compartir datos de forma segura.
///
/// El Project ID se almacena en SharedPreferences y puede ser leído por
/// ambas aplicaciones si comparten el mismo esquema de almacenamiento.
///
/// ## Ejemplo de uso:
/// ```dart
/// // Obtener Project ID
/// final projectId = await SharedIdentityService.getProjectId();
///
/// // Obtener información completa
/// final info = await SharedIdentityService.getIdentityInfo();
/// print('Project ID: ${info['projectId']}');
///
/// // Generar código de compartición
/// final code = await SharedIdentityService.generateSharingCode();
/// print('Código: $code');
/// ```
class SharedIdentityService {
  SharedIdentityService._();

  // Keys de SharedPreferences
  static const _projectIdKey = 'mylifeos_project_id';
  static const _userIdKey = 'mylifeos_user_id';
  static const _userNameKey = 'mylifeos_user_name';
  static const _walletAICustomKey = 'mylifeos_walletai_custom_id';
  static const _createdAtKey = 'mylifeos_identity_created_at';
  static const _lastSyncKey = 'mylifeos_last_sync_at';
  static const _syncCountKey = 'mylifeos_sync_count';
  static const _isLinkedKey = 'mylifeos_is_linked';

  // Cache en memoria para evitar lecturas repetidas
  static String? _cachedProjectId;
  static String? _cachedUserId;

  /// Obtiene o genera un Project ID único.
  ///
  /// El Project ID es un UUID v4 que se genera la primera vez que se llama
  /// a este método y se mantiene constante en futuras llamadas.
  ///
  /// Retorna:
  /// - String con el Project ID (32 caracteres sin guiones)
  static Future<String> getProjectId() async {
    if (_cachedProjectId != null && _cachedProjectId!.isNotEmpty) {
      return _cachedProjectId!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      var projectId = prefs.getString(_projectIdKey);

      if (projectId == null || projectId.isEmpty) {
        projectId = _generateUniqueId();
        await prefs.setString(_projectIdKey, projectId);
        await prefs.setString(_createdAtKey, DateTime.now().toIso8601String());
        debugPrint('[SharedIdentity] Nuevo Project ID generado: $projectId');
      }

      _cachedProjectId = projectId;
      return projectId;
    } catch (e) {
      debugPrint('[SharedIdentity] Error al obtener Project ID: $e');
      // Fallback: generar uno nuevo sin persistencia
      _cachedProjectId = _generateUniqueId();
      return _cachedProjectId!;
    }
  }

  /// Obtiene el ID de usuario (puede ser personalizado o generado).
  ///
  /// El User ID tiene el formato `user_XXXXXXXXXXXX` donde X son
  /// caracteres hexadecimales del UUID.
  ///
  /// Retorna:
  /// - String con el User ID
  static Future<String> getUserId() async {
    if (_cachedUserId != null && _cachedUserId!.isNotEmpty) {
      return _cachedUserId!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      var userId = prefs.getString(_userIdKey);

      if (userId == null || userId.isEmpty) {
        userId = 'user_${_generateUniqueId().substring(0, 12)}';
        await prefs.setString(_userIdKey, userId);
        debugPrint('[SharedIdentity] Nuevo User ID generado: $userId');
      }

      _cachedUserId = userId;
      return userId;
    } catch (e) {
      debugPrint('[SharedIdentity] Error al obtener User ID: $e');
      _cachedUserId = 'user_${_generateUniqueId().substring(0, 12)}';
      return _cachedUserId!;
    }
  }

  /// Establece un nombre personalizado para el usuario.
  ///
  /// Este nombre es opcional y puede usarse para mostrar un identificador
  /// más amigable en la UI.
  ///
  /// Parámetros:
  /// - [name]: Nombre del usuario (máximo 50 caracteres)
  static Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = name.trim().substring(0, name.length.clamp(0, 50));
    await prefs.setString(_userNameKey, trimmed);
    debugPrint('[SharedIdentity] User Name establecido: $trimmed');
  }

  /// Obtiene el nombre del usuario si existe.
  ///
  /// Retorna:
  /// - String con el nombre del usuario, o null si no está configurado
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  /// Establece un ID personalizado para WalletAI.
  ///
  /// Este ID se usa cuando se quiere usar un identificador específico
  /// en lugar del Project ID generado automáticamente.
  ///
  /// Parámetros:
  /// - [customId]: ID personalizado (vacío para eliminar)
  static Future<void> setWalletAICustomId(String customId) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = customId.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_walletAICustomKey);
      debugPrint('[SharedIdentity] Custom ID eliminado');
    } else {
      await prefs.setString(_walletAICustomKey, trimmed);
      debugPrint('[SharedIdentity] Custom ID establecido: $trimmed');
    }
  }

  /// Obtiene el ID personalizado de WalletAI si existe.
  ///
  /// Retorna:
  /// - String con el ID personalizado, o null si no está configurado
  static Future<String?> getWalletAICustomId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_walletAICustomKey);
  }

  /// Obtiene la fecha de creación de la identidad.
  ///
  /// Retorna:
  /// - DateTime de creación, o null si no existe
  static Future<DateTime?> getCreatedAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getString(_createdAtKey);
      if (timestamp != null) {
        return DateTime.tryParse(timestamp);
      }
    } catch (e) {
      debugPrint('[SharedIdentity] Error al obtener createdAt: $e');
    }
    return null;
  }

  /// Actualiza el timestamp de última sincronización.
  ///
  /// Este método también incrementa el contador de sincronizaciones.
  static Future<void> updateLastSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

      // Incrementar contador
      final count = prefs.getInt(_syncCountKey) ?? 0;
      await prefs.setInt(_syncCountKey, count + 1);

      debugPrint('[SharedIdentity] Sync actualizada (total: ${count + 1})');
    } catch (e) {
      debugPrint('[SharedIdentity] Error al actualizar lastSync: $e');
    }
  }

  /// Obtiene la última sincronización.
  ///
  /// Retorna:
  /// - DateTime de última sync, o null si nunca se ha sincronizado
  static Future<DateTime?> getLastSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getString(_lastSyncKey);
      if (timestamp != null) {
        return DateTime.tryParse(timestamp);
      }
    } catch (e) {
      debugPrint('[SharedIdentity] Error al obtener lastSync: $e');
    }
    return null;
  }

  /// Obtiene el número total de sincronizaciones realizadas.
  ///
  /// Retorna:
  /// - int con el contador de syncs (0 si nunca se ha sincronizado)
  static Future<int> getSyncCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_syncCountKey) ?? 0;
    } catch (e) {
      debugPrint('[SharedIdentity] Error al obtener syncCount: $e');
      return 0;
    }
  }

  /// Establece el estado de vinculación con WalletAI.
  ///
  /// Parámetros:
  /// - [isLinked]: true si las apps están vinculadas correctamente
  static Future<void> setLinkedStatus(bool isLinked) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLinkedKey, isLinked);
      debugPrint('[SharedIdentity] Estado de vinculación: $isLinked');
    } catch (e) {
      debugPrint('[SharedIdentity] Error al establecer isLinked: $e');
    }
  }

  /// Verifica si MyLifeOS está vinculado con WalletAI.
  ///
  /// Retorna:
  /// - true si las apps están vinculadas
  static Future<bool> isLinked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isLinkedKey) ?? false;
    } catch (e) {
      debugPrint('[SharedIdentity] Error al verificar isLinked: $e');
      return false;
    }
  }

  /// Genera un hash único para compartir con WalletAI.
  ///
  /// El código de compartición es un hash SHA-256 truncado a 16 caracteres
  /// que se puede usar para verificar manualmente que ambas apps están
  /// usando la misma identidad.
  ///
  /// Retorna:
  /// - String con el código de 16 caracteres (hexadecimal, mayúsculas)
  static Future<String> generateSharingCode() async {
    try {
      final projectId = await getProjectId();
      final userId = await getUserId();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final data = '$projectId:$userId:$timestamp';
      final bytes = utf8.encode(data);
      final hash = sha256.convert(bytes);

      return hash.toString().substring(0, 16).toUpperCase();
    } catch (e) {
      debugPrint('[SharedIdentity] Error al generar sharing code: $e');
      return 'ERROR00000000000';
    }
  }

  /// Verifica si la identidad está configurada.
  ///
  /// Retorna:
  /// - true si el Project ID existe y no está vacío
  static Future<bool> isIdentitySetup() async {
    try {
      final projectId = await getProjectId();
      return projectId.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Resetea la identidad (útil para testing o reinstalación).
  ///
  /// Este método elimina TODOS los datos de identidad almacenados.
  /// La próxima llamada a [getProjectId] generará uno nuevo.
  ///
  /// ⚠️ Advertencia: Esto romperá la conexión con WalletAI hasta que
  /// se vuelva a configurar el nuevo Project ID.
  static Future<void> resetIdentity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_projectIdKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_userNameKey);
      await prefs.remove(_walletAICustomKey);
      await prefs.remove(_createdAtKey);
      await prefs.remove(_lastSyncKey);
      await prefs.remove(_syncCountKey);
      await prefs.remove(_isLinkedKey);

      // Limpiar cache
      _cachedProjectId = null;
      _cachedUserId = null;

      debugPrint('[SharedIdentity] Identidad reseteada completamente');
    } catch (e) {
      debugPrint('[SharedIdentity] Error al resetear identidad: $e');
    }
  }

  /// Obtiene información completa de la identidad.
  ///
  /// Este método es útil para mostrar en la pantalla de configuración
  /// o para debugging.
  ///
  /// Retorna un mapa con:
  /// - `projectId`: Project ID actual
  /// - `userId`: User ID actual
  /// - `userName`: Nombre del usuario (si existe)
  /// - `createdAt`: Fecha de creación (ISO 8601)
  /// - `lastSync`: Fecha de última sync (ISO 8601)
  /// - `syncCount`: Número de syncs realizadas
  /// - `customWalletAId`: ID personalizado de WalletAI (si existe)
  /// - `sharingCode`: Código de compartición actual
  /// - `isLinked`: Estado de vinculación
  static Future<Map<String, dynamic>> getIdentityInfo() async {
    final projectId = await getProjectId();
    final userId = await getUserId();
    final userName = await getUserName();
    final createdAt = await getCreatedAt();
    final lastSync = await getLastSync();
    final syncCount = await getSyncCount();
    final customId = await getWalletAICustomId();
    final linkedStatus = await isLinked();

    return {
      'projectId': projectId,
      'userId': userId,
      'userName': userName,
      'createdAt': createdAt?.toIso8601String(),
      'lastSync': lastSync?.toIso8601String(),
      'syncCount': syncCount,
      'customWalletAId': customId,
      'sharingCode': await generateSharingCode(),
      'isLinked': linkedStatus,
    };
  }

  /// Genera un UUID v4 único sin guiones.
  ///
  /// Retorna:
  /// - String de 32 caracteres hexadecimales
  static String _generateUniqueId() {
    const uuid = Uuid();
    return uuid.v4().replaceAll('-', '');
  }

  /// Limpia la cache en memoria.
  ///
  /// Esto fuerza a que las próximas lecturas vuelvan a leer desde
  /// SharedPreferences. Útil para testing.
  @visibleForTesting
  static void clearCache() {
    _cachedProjectId = null;
    _cachedUserId = null;
  }
}
