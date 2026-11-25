import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/wallet_cloud_service.dart';
import 'backup_service.dart';

/// Configuración y ejecución del respaldo automático diario de MyLifeOS.
///
/// La programación periódica real se registra en `apps/mobile/lib/main.dart`
/// mediante WorkManager (tarea `AutoBackupService.workmanagerTaskName`).
class AutoBackupService {
  static const String workmanagerTaskName = 'com.mylifeos.background.autobackup';
  static const String workmanagerUniqueId = 'mylifeos_bg_autobackup_daily';

  static const String _prefsKey = 'auto_backup_enabled';
  static const String _destPrefsKey = 'auto_backup_destination';
  static const String _photosPrefsKey = 'auto_backup_include_photos';
  static const String _lastRunIsoKey = 'auto_backup_last_run_iso';
  static const String _lastRunStatusKey = 'auto_backup_last_run_status';

  /// Callback opcional inyectado por `apps/mobile` para registrar/cancelar WorkManager.
  static Future<void> Function(bool enabled, String destination)?
      onScheduleChanged;

  AutoBackupService();

  static Future<void> initialize() async {
    final enabled = await isEnabled();
    final dest = await getDestination();
    debugPrint(
      '✅ [AutoBackup] Inicializado (enabled=$enabled, dest=$dest)',
    );
  }

  static Future<void> enable({String? destination, bool? includePhotos}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
    if (destination != null) {
      await prefs.setString(_destPrefsKey, destination);
    }
    if (includePhotos != null) {
      await prefs.setBool(_photosPrefsKey, includePhotos);
    }
    final resolvedDest = await getDestination();
    await onScheduleChanged?.call(true, resolvedDest);
    debugPrint('✅ [AutoBackup] Habilitado ($resolvedDest)');
  }

  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, false);
    await onScheduleChanged?.call(false, await getDestination());
    debugPrint('❌ [AutoBackup] Deshabilitado');
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  /// Destinos válidos: `'cloud'`, `'local'`, `'both'`.
  static Future<String> getDestination() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_destPrefsKey) ?? 'cloud';
  }

  static Future<void> setDestination(String destination) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_destPrefsKey, destination);
    if (await isEnabled()) {
      await onScheduleChanged?.call(true, destination);
    }
  }

  static Future<bool> getIncludePhotos() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_photosPrefsKey) ?? false;
  }

  static Future<void> setIncludePhotos(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_photosPrefsKey, value);
  }

  static Future<({String? lastRunIso, String? lastStatus})>
      getLastRunInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      lastRunIso: prefs.getString(_lastRunIsoKey),
      lastStatus: prefs.getString(_lastRunStatusKey),
    );
  }

  static Future<void> _recordRun(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastRunIsoKey, DateTime.now().toIso8601String());
    await prefs.setString(_lastRunStatusKey, status);
  }

  /// Ejecuta el backup automático real desde WorkManager en segundo plano.
  static Future<bool> runScheduledBackup(BackupService backupService) async {
    if (!await isEnabled()) return true;
    final dest = await getDestination();
    final includePhotos = await getIncludePhotos();
    final statuses = <String>[];
    bool allOk = true;

    if (dest == 'local' || dest == 'both') {
      final localRes = await backupService.saveLocalAutoBackup(
        includePhotos: includePhotos,
      );
      if (localRes is BackupSuccess) {
        statuses.add('Local OK');
      } else if (localRes is BackupFailure) {
        allOk = false;
        statuses.add('Local error');
      }
    }

    if (dest == 'cloud' || dest == 'both') {
      final signedIn = await WalletCloudService.isSignedIn();
      if (!signedIn) {
        statuses.add('Nube omitida (sin sesión)');
      } else {
        final cloudRes = await backupService.uploadToCloud(
          includePhotos: includePhotos,
          force: false,
        );
        if (cloudRes.success) {
          statuses.add('Nube OK');
        } else if (cloudRes.hasConflict) {
          statuses.add('Nube pausada (conflicto multi-dispositivo)');
        } else {
          allOk = false;
          statuses.add('Nube error');
        }
      }
    }

    await _recordRun(statuses.isEmpty ? 'Completado' : statuses.join(' · '));
    return allOk;
  }

  static Future<void> scheduleDailyBackup() async {
    final dest = await getDestination();
    await onScheduleChanged?.call(true, dest);
  }

  static Future<void> cancelBackup() async {
    await onScheduleChanged?.call(false, await getDestination());
  }
}
