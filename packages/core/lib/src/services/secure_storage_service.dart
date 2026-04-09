import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider para FlutterSecureStorage.
/// Útil para almacenar tokens y credenciales de forma segura.
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(
      // encryptedSharedPreferences is deprecated and ignored in newer versions
    ),
  );
});
