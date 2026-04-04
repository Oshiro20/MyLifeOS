import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Consulta GitHub releases de WalletAI y notifica si hay una versión nueva.
class WalletUpdateNotifier {
  static const _repoOwner = 'Oshiro20';
  static const _repoName = 'WalletAI';
  static const _prefKey = 'wallet_ai_last_known_version';
  static const _notifId = 9001;

  final FlutterLocalNotificationsPlugin _notifications;

  WalletUpdateNotifier(this._notifications);

  /// Llama esto al iniciar MyLifeOS (ej: en main o en un initState de alto nivel).
  Future<void> checkForUpdates() async {
    try {
      final latestVersion = await _fetchLatestVersion();
      if (latestVersion == null) return;

      final prefs = await SharedPreferences.getInstance();
      final lastKnown = prefs.getString(_prefKey);

      if (lastKnown != latestVersion) {
        await prefs.setString(_prefKey, latestVersion);
        // Solo notifica si ya había una versión conocida (no en el primer arranque)
        if (lastKnown != null) {
          await _showNotification(latestVersion);
        }
      }
    } catch (e) {
      debugPrint('[WalletUpdateNotifier] Error: $e');
    }
  }

  Future<String?> _fetchLatestVersion() async {
    final uri = Uri.parse(
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
    );
    final response =
        await http.get(uri, headers: {'Accept': 'application/vnd.github+json'});
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['tag_name'] as String?;
  }

  Future<void> _showNotification(String version) async {
    const androidDetails = AndroidNotificationDetails(
      'wallet_ai_updates',
      'WalletAI Updates',
      channelDescription: 'Notificaciones de nuevas versiones de WalletAI',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);
    await _notifications.show(
      _notifId,
      '💰 WalletAI actualizado',
      'Nueva versión $version disponible. Actualiza para obtener las últimas mejoras.',
      details,
    );
  }
}
