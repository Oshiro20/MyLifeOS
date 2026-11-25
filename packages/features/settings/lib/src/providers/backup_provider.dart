import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

// ── Estado ────────────────────────────────────────────────────────────────────
enum BackupStatus {
  idle,
  exportingInProgress,
  importingInProgress,
  done,
  error
}

class BackupState {
  final BackupStatus status;
  final String? lastMessage;
  final int dbSizeBytes;
  final DateTime? lastModified;

  const BackupState({
    this.status = BackupStatus.idle,
    this.lastMessage,
    this.dbSizeBytes = 0,
    this.lastModified,
  });

  bool get isLoading =>
      status == BackupStatus.exportingInProgress ||
      status == BackupStatus.importingInProgress;

  BackupState copyWith({
    BackupStatus? status,
    String? lastMessage,
    bool clearMessage = false,
    int? dbSizeBytes,
    DateTime? lastModified,
  }) =>
      BackupState(
        status: status ?? this.status,
        lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
        dbSizeBytes: dbSizeBytes ?? this.dbSizeBytes,
        lastModified: lastModified ?? this.lastModified,
      );
}

// ── Notifier (Riverpod v3) ────────────────────────────────────────────────────
class BackupNotifier extends Notifier<BackupState> {
  BackupService get _service => ref.read(backupServiceProvider);

  @override
  BackupState build() {
    Future.microtask(() => _loadInfo());
    return const BackupState();
  }

  Future<void> _loadInfo() async {
    final size = await _service.getDbSizeBytes();
    final lastMod = await _service.getLastBackupDate();
    state = state.copyWith(dbSizeBytes: size, lastModified: lastMod);
  }

  Future<BackupResult> exportBackup({bool includePhotos = false}) async {
    state = state.copyWith(
      status: BackupStatus.exportingInProgress,
      clearMessage: true,
    );
    final result = await _service.exportBackup(includePhotos: includePhotos);
    switch (result) {
      case BackupSuccess():
        state = state.copyWith(
          status: BackupStatus.done,
          lastMessage:
              'Backup exportado correctamente (${_formatSize(result.sizeBytes)}).',
        );
      case BackupFailure():
        state = state.copyWith(
          status: BackupStatus.error,
          lastMessage: result.message,
        );
      case RestoreSuccess():
        break;
    }
    await _loadInfo();
    return result;
  }

  Future<BackupResult> importBackup(String filePath) async {
    state = state.copyWith(
      status: BackupStatus.importingInProgress,
      clearMessage: true,
    );
    final result = await _service.importBackup(filePath);
    switch (result) {
      case RestoreSuccess():
        state = state.copyWith(
          status: BackupStatus.done,
          lastMessage:
              '¡Restauración exitosa! Reinicia la app para aplicar los cambios.',
        );
      case BackupFailure():
        state = state.copyWith(
          status: BackupStatus.error,
          lastMessage: result.message,
        );
      case BackupSuccess():
        break;
    }
    await _loadInfo();
    return result;
  }

  Future<CloudBackupOperationResult> uploadToCloud({
    bool includePhotos = false,
    bool force = false,
  }) async {
    state = state.copyWith(
      status: BackupStatus.exportingInProgress,
      clearMessage: true,
    );
    final result = await _service.uploadToCloud(
      includePhotos: includePhotos,
      force: force,
    );
    state = state.copyWith(
      status: result.success ? BackupStatus.done : BackupStatus.error,
      lastMessage: result.message,
    );
    await _loadInfo();
    return result;
  }

  Future<BackupResult> restoreFromCloud() async {
    state = state.copyWith(
      status: BackupStatus.importingInProgress,
      clearMessage: true,
    );
    final result = await _service.restoreFromCloud();
    switch (result) {
      case RestoreSuccess():
        state = state.copyWith(
          status: BackupStatus.done,
          lastMessage:
              '¡Respaldo en la nube restaurado! Reinicia la app para aplicar todos los datos.',
        );
      case BackupFailure():
        state = state.copyWith(
          status: BackupStatus.error,
          lastMessage: result.message,
        );
      case BackupSuccess():
        break;
    }
    await _loadInfo();
    return result;
  }

  void clearStatus() =>
      state = state.copyWith(status: BackupStatus.idle, clearMessage: true);

  Future<void> refreshInfo() => _loadInfo();

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────
final backupServiceProvider = Provider<BackupService>((ref) => BackupService());

/// Callback opcional provisto por la app principal para limpiar Drift + estado.
final clearAllDataCallbackProvider =
    Provider<Future<void> Function()?>((ref) => null);

final backupProvider =
    NotifierProvider<BackupNotifier, BackupState>(BackupNotifier.new);
