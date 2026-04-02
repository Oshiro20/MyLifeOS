/// Representa el resultado base de una sincronización o intento de conectar.
sealed class SyncResult {}

class SyncSuccess extends SyncResult {}
class SyncFailure extends SyncResult {
  final String message;
  SyncFailure(this.message);
}

/// Define el contrato de los repositorios para sincronizar contenido hacia la Nube (Remote Data Source)
abstract class ISyncService {
  /// Inicializa o actualiza el cliente de conexión con las credenciales
  Future<SyncResult> initializeDriver(String url, String anonKey);

  /// Limpia las credenciales cargadas y cierra el cliente de conexión
  Future<void> disconnect();

  /// Sincroniza bidireccionalmente todos los módulos
  Future<SyncResult> syncAll(dynamic localDatabase);

  // ── Armario ─────────────────────────────────────────────────────────────
  Future<SyncResult> syncWardrobe(dynamic localDatabase);
  Future<SyncResult> syncOutfits(dynamic localDatabase);
  Future<SyncResult> syncUserProfile(dynamic localDatabase);

  // ── Food Coach ──────────────────────────────────────────────────────────
  Future<SyncResult> syncFoodCoach(dynamic localDatabase);


  // ── Cocina ──────────────────────────────────────────────────────────────
  Future<SyncResult> syncCocina(dynamic localDatabase);
}
