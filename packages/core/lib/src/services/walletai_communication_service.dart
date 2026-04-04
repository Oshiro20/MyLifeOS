import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'shared_identity_service.dart';
import 'wallet_summary_reader.dart';

/// Servicio de comunicación bidireccional con WalletAI.
///
/// Este servicio permite:
/// 1. Enviar solicitudes de sincronización a WalletAI
/// 2. Recibir datos actualizados de WalletAI
/// 3. Verificar el estado de la conexión
/// 4. Abrir WalletAI con parámetros de contexto
class WalletAICommunicationService {
  static const _walletAIScheme = 'walletai';
  static const _requestSyncFileName = 'wallet_sync_request.json';
  static const _responseSyncFileName = 'wallet_sync_response.json';

  /// Abre WalletAI con parámetros de contexto
  static Future<bool> openWalletAI({
    String? context,
    Map<String, String>? extraParams,
  }) async {
    final projectId = await SharedIdentityService.getProjectId();
    final userId = await SharedIdentityService.getUserId();

    // Construir URI con parámetros de contexto
    final params = <String, String>{
      'projectId': projectId,
      'userId': userId,
      'source': 'mylifeos',
      if (context != null) 'context': context,
      if (extraParams != null) ...extraParams,
    };

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    // Intentar deep link primero
    final deepLinkUri = Uri.parse('$_walletAIScheme://open?$queryString');

    try {
      if (await canLaunchUrl(deepLinkUri)) {
        debugPrint('[WalletAICommunication] Abriendo WalletAI con deep link');
        return await launchUrl(deepLinkUri,
            mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[WalletAICommunication] Error con deep link: $e');
    }

    // Fallback: Intentar abrir por scheme directo
    final directUri = Uri.parse('$_walletAIScheme://');
    try {
      if (await canLaunchUrl(directUri)) {
        debugPrint('[WalletAICommunication] Abriendo WalletAI (directo)');
        return await launchUrl(directUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[WalletAICommunication] Error con uri directa: $e');
    }

    // Último fallback: WalletAI no está disponible
    debugPrint(
        '[WalletAICommunication] WalletAI no está instalado o no soporta deep links');
    return false;
  }

  /// Solicita sincronización con WalletAI
  static Future<bool> requestSync() async {
    try {
      final projectId = await SharedIdentityService.getProjectId();
      final userId = await SharedIdentityService.getUserId();

      final docDir = await getApplicationDocumentsDirectory();
      final syncRequest = {
        'type': 'sync_request',
        'projectId': projectId,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'mylifeos',
        'version': '1.0.0',
      };

      final file = File(p.join(docDir.path, _requestSyncFileName));
      await file.writeAsString(jsonEncode(syncRequest));

      debugPrint('[WalletAICommunication] Sync request creado: ${file.path}');

      // Abrir WalletAI para que procese la solicitud
      await openWalletAI(context: 'sync');

      return true;
    } catch (e) {
      debugPrint('[WalletAICommunication] Error al solicitar sync: $e');
      return false;
    }
  }

  /// Lee la respuesta de sincronización de WalletAI
  static Future<Map<String, dynamic>?> readSyncResponse() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final file = File(p.join(docDir.path, _responseSyncFileName));

      if (!await file.exists()) {
        return null;
      }

      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[WalletAICommunication] Error al leer respuesta sync: $e');
      return null;
    }
  }

  /// Verifica el estado de conexión con WalletAI
  static Future<WalletConnectionStatus> checkConnectionStatus() async {
    final isInstalled = await isWalletAIInstalled();
    final isPackageInstalled = await isWalletAIPackageInstalled();
    final hasSummary = await WalletSummaryReader.isWalletAIAvailable();
    final summaryResult = await WalletSummaryReader.readWithValidation();

    // Caso 1: WalletAI no está instalado de ninguna forma
    if (!isInstalled && !isPackageInstalled && !hasSummary) {
      return WalletConnectionStatus(
        isConnected: false,
        isWalletAIAvailable: false,
        isProjectIdMatched: false,
        lastSync: null,
        error: 'WalletAI no está instalado',
      );
    }

    // Caso 2: WalletAI instalado pero versión vieja (sin deep link soporte)
    if (!isInstalled && isPackageInstalled && !hasSummary) {
      return WalletConnectionStatus(
        isConnected: false,
        isWalletAIAvailable: true,
        isProjectIdMatched: false,
        lastSync: null,
        error: 'WalletAI necesita actualizarse a v1.3.0+ para la integración',
      );
    }

    // Caso 3: WalletAI instalado (nuevo) pero no ha exportado datos aún
    if (isInstalled && !hasSummary) {
      return WalletConnectionStatus(
        isConnected: false,
        isWalletAIAvailable: true,
        isProjectIdMatched: false,
        lastSync: null,
        error: 'Abre WalletAI para que exporte los datos automáticamente',
      );
    }

    // Caso 4: Hay datos pero error de lectura
    if (!summaryResult.isConnected) {
      return WalletConnectionStatus(
        isConnected: false,
        isWalletAIAvailable: true,
        isProjectIdMatched: false,
        lastSync: null,
        error: summaryResult.error ?? 'Error al leer datos',
      );
    }

    // Caso 5: Datos leídos correctamente
    final lastSync = await SharedIdentityService.getLastSync();

    return WalletConnectionStatus(
      isConnected: true,
      isWalletAIAvailable: true,
      isProjectIdMatched: summaryResult.isProjectIdMatched,
      lastSync: lastSync,
      summary: summaryResult.summary,
      error: summaryResult.error,
    );
  }

  /// Envía datos financieros a WalletAI (si WalletAI lo soporta)
  static Future<bool> sendFinanceData(Map<String, dynamic> data) async {
    try {
      final walletAIDir = Directory(
        await WalletSummaryReader.getPreferredWalletAIDirectory(),
      );

      if (!await walletAIDir.exists()) {
        await walletAIDir.create(recursive: true);
      }

      final dataWithMeta = {
        ...data,
        'source': 'mylifeos',
        'timestamp': DateTime.now().toIso8601String(),
        'projectId': await SharedIdentityService.getProjectId(),
      };

      final fileName =
          'mylifeos_data_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(p.join(walletAIDir.path, fileName));
      await file.writeAsString(jsonEncode(dataWithMeta));

      debugPrint(
          '[WalletAICommunication] Datos enviados a WalletAI: ${file.path}');
      return true;
    } catch (e) {
      debugPrint('[WalletAICommunication] Error al enviar datos: $e');
      return false;
    }
  }

  /// Fuerza una rescane de conexión con WalletAI
  static Future<WalletConnectionStatus> forceConnectionRescan() async {
    await WalletSummaryReader.forceRescan();
    return await checkConnectionStatus();
  }

  /// Genera un código de emparejamiento para compartir con WalletAI
  static Future<String> generatePairingCode() async {
    return await SharedIdentityService.generateSharingCode();
  }

  /// Verifica si WalletAI está instalado mediante deep link
  static Future<bool> isWalletAIInstalled() async {
    try {
      final uri = Uri.parse('$_walletAIScheme://');
      return await canLaunchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  /// Verifica si WalletAI está instalado por package name (incluso si es versión vieja)
  static Future<bool> isWalletAIPackageInstalled() async {
    try {
      // Intentar abrir con package name directo
      final uri = Uri.parse(
          'intent://wallet_ai#Intent;scheme=walletai;package=com.oshiro.wallet_ai;end');
      return await canLaunchUrl(uri);
    } catch (_) {
      return false;
    }
  }
}

/// Estado de conexión con WalletAI
class WalletConnectionStatus {
  final bool isConnected;
  final bool isWalletAIAvailable;
  final bool isProjectIdMatched;
  final DateTime? lastSync;
  final WalletSummary? summary;
  final String? error;

  const WalletConnectionStatus({
    required this.isConnected,
    required this.isWalletAIAvailable,
    required this.isProjectIdMatched,
    this.lastSync,
    this.summary,
    this.error,
  });

  /// Obtiene un mensaje descriptivo del estado
  String getStatusMessage() {
    if (!isConnected) {
      return error ?? 'WalletAI no está conectado';
    }

    if (!isWalletAIAvailable) {
      return 'WalletAI no está instalado o no ha exportado datos';
    }

    if (!isProjectIdMatched) {
      return 'Los Project IDs no coinciden. Verifica la configuración en ambas apps.';
    }

    if (lastSync == null) {
      return 'Conectado pero sin sincronización reciente';
    }

    final now = DateTime.now();
    final diff = now.difference(lastSync!);

    if (diff.inMinutes < 5) {
      return 'Sincronizado hace unos momentos';
    } else if (diff.inHours < 1) {
      return 'Sincronizado hace ${diff.inMinutes} minutos';
    } else if (diff.inDays < 1) {
      return 'Sincronizado hace ${diff.inHours} horas';
    } else {
      return 'Última sincronización: ${lastSync!.day}/${lastSync!.month}/${lastSync!.year}';
    }
  }

  @override
  String toString() {
    return 'WalletConnectionStatus(connected: $isConnected, matched: $isProjectIdMatched, error: $error)';
  }
}
