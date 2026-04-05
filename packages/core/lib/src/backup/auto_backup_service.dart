import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de backup automático programado con WorkManager.
/// NOTA: WorkManager temporalmente deshabilitado - actualizar a workmanager 0.9.0+
/// El estado enabled/disabled se guarda en SharedPreferences.
class AutoBackupService {
  static const String _prefsKey = 'auto_backup_enabled';

  AutoBackupService();

  /// Inicializa el servicio de backup automático.
  static Future<void> initialize() async {
    debugPrint(
        '⚠️ [AutoBackup] WorkManager temporalmente deshabilitado - actualizar a 0.9.0+');
  }

  /// Habilita el backup automático y guarda el estado.
  static Future<void> enable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
    debugPrint('✅ [AutoBackup] Backup automático habilitado');
  }

  /// Deshabilita el backup automático y guarda el estado.
  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, false);
    debugPrint('❌ [AutoBackup] Backup automático deshabilitado');
  }

  /// Verifica si el backup automático está habilitado.
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  /// Programa un backup diario cada 24 horas.
  static Future<void> scheduleDailyBackup() async {
    debugPrint('⚠️ [AutoBackup] WorkManager no disponible');
  }

  /// Cancela todas las tareas de backup programadas.
  static Future<void> cancelBackup() async {
    debugPrint('⚠️ [AutoBackup] WorkManager no disponible');
  }
}
