import 'package:domain/src/sync/i_sync_service.dart';

class SyncDataUseCase {
  final ISyncService _syncService;

  SyncDataUseCase(this._syncService);

  Future<SyncResult> connect(String url, String anonKey) async {
    return _syncService.initializeDriver(url, anonKey);
  }

  Future<SyncResult> executeSync(dynamic localDatabase) async {
    return _syncService.syncAll(localDatabase);
  }

  Future<void> stop() async {
    return _syncService.disconnect();
  }
}
