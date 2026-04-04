import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Consulta GitHub releases de MyLifeOS y notifica si hay una versión nueva.
class MyLifeOSUpdateNotifier {
  static const _repoOwner = 'Oshiro20';
  static const _repoName = 'MyLifeOS';
  static const _prefKey = 'mylifeos_last_known_version';
  static const _notifId = 9002;

  final FlutterLocalNotificationsPlugin _notifications;

  MyLifeOSUpdateNotifier(this._notifications);

  /// Devuelve la nueva versión si hay una disponible para instalar,
  /// o null si ya estamos en la más reciente.
  Future<String?> checkForUpdates() async {
    try {
      final latestVersion = await _fetchLatestVersion();
      if (latestVersion == null) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = 'v${packageInfo.version}';

      final prefs = await SharedPreferences.getInstance();
      final lastKnown = prefs.getString(_prefKey);

      // Si la versión más reciente es diferente a la instalada, hay actualización.
      if (latestVersion != currentVersion) {
        // Siempre mostrar notificación si es una versión diferente a la última conocida
        // O si nunca se había chequeado antes
        if (lastKnown == null || lastKnown != latestVersion) {
          await prefs.setString(_prefKey, latestVersion);
          await _showNotification(latestVersion);
        }
        return latestVersion;
      }
      return null;
    } catch (e) {
      debugPrint('[MyLifeOSUpdateNotifier] Error: $e');
      return null;
    }
  }

  /// Lanza el enlace en el navegador hacia la página principal de "Releases" o los asstes.
  static Future<void> launchUpdater() async {
    final uri =
        Uri.parse('https://github.com/$_repoOwner/$_repoName/releases/latest');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('No se pudo abrir $uri');
    }
  }

  Future<String?> _fetchLatestVersion() async {
    final uri = Uri.parse(
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
    );
    final response = await http.get(
      uri,
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['tag_name'] as String?;
  }

  Future<void> _showNotification(String version) async {
    // Crear canal de notificación si no existe
    await _notifications.resolvePlatformSpecificCommunication();
    const androidDetails = AndroidNotificationDetails(
      'mylifeos_updates',
      'MyLifeOS Updates',
      channelDescription: 'Notificaciones de nuevas versiones de MyLifeOS',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);
    await _notifications.show(
      _notifId,
      '✨ Nueva versión disponible',
      'MyLifeOS $version está lista. Toca para descargar e instalar.',
      details,
    );
  }
}
