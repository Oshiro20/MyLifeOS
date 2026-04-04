import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:core/core.dart'; // Para secureStorageProvider

// Instancias core
final syncServiceProvider = Provider<ISyncService>((ref) {
  return SupabaseSyncService();
});

final syncDataUseCaseProvider = Provider<SyncDataUseCase>((ref) {
  return SyncDataUseCase(ref.watch(syncServiceProvider));
});

// Providers de estado
class SyncState {
  final bool isConnecting;
  final bool isConnected;
  final bool isSyncing;
  final String? lastError;
  final DateTime? lastSync;

  const SyncState({
    this.isConnecting = false,
    this.isConnected = false,
    this.isSyncing = false,
    this.lastError,
    this.lastSync,
  });

  SyncState copyWith({
    bool? isConnecting,
    bool? isConnected,
    bool? isSyncing,
    String? lastError,
    DateTime? lastSync,
  }) =>
      SyncState(
        isConnecting: isConnecting ?? this.isConnecting,
        isConnected: isConnected ?? this.isConnected,
        isSyncing: isSyncing ?? this.isSyncing,
        lastError: lastError,
        lastSync: lastSync ?? this.lastSync,
      );
}

class SyncNotifier extends Notifier<SyncState> {
  static const _urlKey = 'supabase_url';
  static const _anonKey = 'supabase_anon_key';

  FlutterSecureStorage get _storage => ref.read(secureStorageProvider);
  SyncDataUseCase get _useCase => ref.read(syncDataUseCaseProvider);

  @override
  SyncState build() {
    Future.microtask(_tryAutoConnect);
    return const SyncState();
  }

  Future<void> _tryAutoConnect() async {
    const url = 'https://opxwfwtsdiktjuaajvexp.supabase.co';
    const key =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9weHdmd3NkaWt0anVhYWp2ZXhwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzNzc2OTksImV4cCI6MjA4Nzk1MzY5OX0.x1inE4FzaP6WG_tNTTka0aX9bs2Jw5rhkt3z8ejOp3U';
    await connect(url, key);
  }

  Future<bool> connect(String url, String anonKey) async {
    state = state.copyWith(isConnecting: true, lastError: null);

    final res = await _useCase.connect(url.trim(), anonKey.trim());
    if (res is SyncSuccess) {
      await _storage.write(key: _urlKey, value: url.trim());
      await _storage.write(key: _anonKey, value: anonKey.trim());
      state = state.copyWith(isConnecting: false, isConnected: true);
      return true;
    } else if (res is SyncFailure) {
      state = state.copyWith(isConnecting: false, lastError: res.message);
      return false;
    }
    return false;
  }

  Future<void> disconnect() async {
    await _storage.delete(key: _urlKey);
    await _storage.delete(key: _anonKey);
    await _useCase.stop();
    state = const SyncState();
  }

  Future<bool> triggerSync(dynamic appDatabase) async {
    if (!state.isConnected) return false;
    state = state.copyWith(isSyncing: true, lastError: null);

    final res = await _useCase.executeSync(appDatabase);

    if (res is SyncSuccess) {
      state = state.copyWith(isSyncing: false, lastSync: DateTime.now());
      return true;
    } else if (res is SyncFailure) {
      state = state.copyWith(isSyncing: false, lastError: res.message);
      return false;
    }
    return false;
  }
}

final syncProvider =
    NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);
