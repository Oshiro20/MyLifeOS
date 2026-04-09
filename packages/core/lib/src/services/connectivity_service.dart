import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Servicio de conectividad que detecta el estado de red en tiempo real.
///
/// Usa `connectivity_plus` para proveer un ``Stream<bool>`` y una verificación
/// one-shot de si el dispositivo tiene acceso a internet.
class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  /// Stream que emite `true` cuando hay conexión y `false` cuando no la hay.
  Stream<bool> get onConnectivityChanged => _connectivity.onConnectivityChanged
      .map((results) => _isConnected(results));

  /// Verificación rápida del estado de red actual (one-shot).
  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _isConnected(results);
    } catch (_) {
      return false;
    }
  }

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
  }
}

/// Provider Riverpod para ConnectivityService.
final connectivityProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityService(),
);

/// Provider que expone el estado de conectividad actual como ``AsyncValue<bool>``.
final isOnlineProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(connectivityProvider);
  return service.isOnline();
});
