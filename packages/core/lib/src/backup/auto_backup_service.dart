import 'package:flutter/foundation.dart';

/// Servicio de backup automático programado con WorkManager.
/// NOTA: WorkManager temporalmente deshabilitado - actualizar a workmanager 0.9.0+
/// Las referencias a WorkManager están comentadas para permitir la compilación.
class AutoBackupService {
  AutoBackupService();

  /// Inicializa el servicio de backup automático.
  static Future<void> initialize() async {
    debugPrint(
        '⚠️ [AutoBackup] WorkManager temporalmente deshabilitado - actualizar a 0.9.0+');
  }

  /// Habilita el backup automático y programa la tarea.
  static Future<void> enable() async {
    debugPrint(
        '⚠️ [AutoBackup] WorkManager no disponible - actualizar dependencia');
  }

  /// Deshabilita el backup automático y cancela la tarea.
  static Future<void> disable() async {
    debugPrint('❌ [AutoBackup] Backup automático deshabilitado');
  }

  /// Verifica si el backup automático está habilitado.
  static Future<bool> isEnabled() async {
    return false;
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
