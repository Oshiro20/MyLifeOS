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
  static const _prefKey = 'mylifeos_last_notified_version';
  static const _notifId = 9002;

  final FlutterLocalNotificationsPlugin _notifications;

  MyLifeOSUpdateNotifier(this._notifications);

  /// Devuelve la nueva versión si hay una disponible para instalar,
  /// o null si ya estamos en la más reciente.
  Future<String?> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // Ej: "1.1.4"

      final latestTag = await _fetchLatestTag();
      if (latestTag == null) return null;

      // Limpiar prefijo 'v' si existe
      final latestVersion =
          latestTag.replaceAll('v', ''); // Ej: "v1.1.4" -> "1.1.4"

      // Comparación semántica (igual que WalletAI)
      if (!_isVersionGreater(latestVersion, currentVersion)) {
        return null; // Ya estamos en la versión más reciente
      }

      final prefs = await SharedPreferences.getInstance();
      final lastNotified = prefs.getString(_prefKey);

      // Solo notificar si es una versión diferente a la última notificada
      if (lastNotified != latestTag) {
        await prefs.setString(_prefKey, latestTag);
        await _showNotification(latestTag);
      }

      return latestTag;
    } catch (e) {
      debugPrint('[MyLifeOSUpdateNotifier] Error: $e');
      return null;
    }
  }

  /// Compara dos versiones semánticas.
  /// Retorna true si latest > current.
  bool _isVersionGreater(String latest, String current) {
    final latestParts =
        latest.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final currentParts =
        current.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    for (var i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length) return true;
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  /// Lanza el enlace en el navegador hacia la página de Releases.
  static Future<void> launchUpdater() async {
    final uri =
        Uri.parse('https://github.com/$_repoOwner/$_repoName/releases/latest');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('No se pudo abrir $uri');
    }
  }

  Future<String?> _fetchLatestTag() async {
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
