import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Modelo para un release de GitHub
class GithubRelease {
  final String tagName;
  final String body;
  final String apkUrl;
  final String fileName;

  GithubRelease({
    required this.tagName,
    required this.body,
    required this.apkUrl,
    required this.fileName,
  });

  factory GithubRelease.fromJson(Map<String, dynamic> json) {
    final assets = json['assets'] as List<dynamic>;
    final apkAsset = assets.firstWhere(
      (asset) => asset['name'].toString().endsWith('.apk'),
      orElse: () =>
          throw Exception('No se encontró un archivo APK en el release.'),
    );

    return GithubRelease(
      tagName: json['tag_name'],
      body: json['body'] ?? '',
      apkUrl: apkAsset['browser_download_url'],
      fileName: apkAsset['name'],
    );
  }
}

/// Servicio de actualización OTA para MyLifeOS.
/// Descarga e instala el APK automáticamente desde GitHub Releases.
class MyLifeOSUpdateService {
  static const _repoOwner = 'Oshiro20';
  static const _repoName = 'MyLifeOS';
  static const _prefKey = 'mylifeos_last_notified_version';

  final Dio _dio = Dio();

  /// Verifica si hay una nueva versión disponible.
  /// Retorna el release si hay una versión más reciente, null si ya estamos actualizados.
  Future<GithubRelease?> checkForUpdate() async {
    try {
      final response = await _dio.get(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
      );

      if (response.statusCode == 200) {
        final release = GithubRelease.fromJson(response.data);
        final packageInfo = await PackageInfo.fromPlatform();

        final latestVersion = release.tagName.replaceAll('v', '');
        final currentVersion = packageInfo.version;

        if (_isVersionGreater(latestVersion, currentVersion)) {
          return release;
        }
      }
    } catch (e) {
      debugPrint('[MyLifeOSUpdateService] Error al verificar actualización: $e');
    }

    return null;
  }

  /// Compara dos versiones semánticas.
  bool _isVersionGreater(String latest, String current) {
    final latestParts = latest.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final currentParts = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    for (var i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length) return true;
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  /// Descarga e instala el APK automáticamente.
  /// Llama a onProgress con valores de 0.0 a 1.0.
  Future<void> downloadAndInstall({
    required String url,
    required String fileName,
    required Function(double) onProgress,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = p.join(tempDir.path, fileName);

      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      // Abrir el instalador del sistema
      await OpenFilex.open(savePath);
    } catch (e) {
      debugPrint('[MyLifeOSUpdateService] Error durante descarga/instalación: $e');
      rethrow;
    }
  }

  /// Obtiene la última versión notificada para verificar si ya se notificó.
  static Future<String?> getLastNotifiedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey);
  }

  /// Guarda la última versión notificada.
  static Future<void> setLastNotifiedVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, version);
  }
}
