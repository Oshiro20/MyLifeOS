import 'dart:io';
import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final assets = (json['assets'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final apks = assets
        .where((asset) =>
            (asset['name']?.toString().toLowerCase() ?? '').endsWith('.apk'))
        .toList();
    if (apks.isEmpty) {
      throw Exception('No se encontró un archivo APK en el release.');
    }

    // Preferir APK arm64 o universal antes que builds x86 / armeabi
    final abiHint = Platform.version.toLowerCase();
    final preferArm64 = !abiHint.contains('arm_x64') &&
        (abiHint.contains('arm64') || abiHint.contains('aarch64'));
    final apkAsset = apks.firstWhere(
      (a) {
        final name = a['name'].toString().toLowerCase();
        if (preferArm64 && name.contains('arm64')) return true;
        return !name.contains('armeabi') &&
            !name.contains('x86') &&
            !name.contains('arm64');
      },
      orElse: () => apks.first,
    );

    return GithubRelease(
      tagName: json['tag_name']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      apkUrl: apkAsset['browser_download_url']?.toString() ?? '',
      fileName: apkAsset['name']?.toString() ?? 'MyLifeOS-update.apk',
    );
  }
}

/// Servicio de actualización OTA para MyLifeOS.
/// Descarga e instala el APK automáticamente desde GitHub Releases.
class MyLifeOSUpdateService {
  static const _repoOwner = 'Oshiro20';
  static const _repoName = 'MyLifeOS';
  static const _prefKey = 'mylifeos_dialog_last_notified_version';

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

        if (isVersionGreater(release.tagName, packageInfo.version)) {
          return release;
        }
      }
    } catch (e) {
      debugPrint(
          '[MyLifeOSUpdateService] Error al verificar actualización: $e');
    }

    return null;
  }

  /// Compara dos versiones semánticas delegando al helper compartido en core.
  static bool isVersionGreater(String latest, String current) =>
      MyLifeOSUpdateNotifier.isVersionGreater(latest, current);

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

      // Abrir el instalador del sistema y verificar resultado
      final openResult = await OpenFilex.open(savePath);
      if (openResult.type != ResultType.done) {
        throw Exception(
          'No se pudo abrir el instalador (${openResult.message}).',
        );
      }
    } catch (e) {
      debugPrint(
          '[MyLifeOSUpdateService] Error durante descarga/instalación: $e');
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
