import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'shared_identity_service.dart';

/// Modelo del resumen exportado por WalletAI.
class WalletSummary {
  final String version;
  final String month;
  final double balance;
  final double income;
  final double expenses;
  final String currency;
  final DateTime exportedAt;
  final String? projectId;
  final Map<String, dynamic>? rawMetadata;

  const WalletSummary({
    required this.version,
    required this.month,
    required this.balance,
    required this.income,
    required this.expenses,
    required this.currency,
    required this.exportedAt,
    this.projectId,
    this.rawMetadata,
  });

  factory WalletSummary.fromJson(Map<String, dynamic> json) => WalletSummary(
        version: json['version'] as String? ?? '',
        month: json['month'] as String? ?? '',
        balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
        income: (json['income'] as num?)?.toDouble() ?? 0.0,
        expenses: (json['expenses'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency'] as String? ?? 'PEN',
        exportedAt: DateTime.tryParse(json['exportedAt'] as String? ?? '') ??
            DateTime.now(),
        projectId: json['projectId'] as String?,
        rawMetadata: json['metadata'] as Map<String, dynamic>?,
      );

  Map<String, dynamic> toJson() => {
        'version': version,
        'month': month,
        'balance': balance,
        'income': income,
        'expenses': expenses,
        'currency': currency,
        'exportedAt': exportedAt.toIso8601String(),
        if (projectId != null) 'projectId': projectId,
        if (rawMetadata != null) 'metadata': rawMetadata,
      };
}

/// Resultado de la lectura con información de validación
class WalletReadResult {
  final WalletSummary? summary;
  final bool isConnected;
  final bool isProjectIdMatched;
  final String? error;
  final DateTime? lastSync;

  const WalletReadResult({
    this.summary,
    required this.isConnected,
    this.isProjectIdMatched = false,
    this.error,
    this.lastSync,
  });

  factory WalletReadResult.success(WalletSummary summary,
      {bool projectIdMatched = false}) {
    return WalletReadResult(
      summary: summary,
      isConnected: true,
      isProjectIdMatched: projectIdMatched,
      lastSync: DateTime.now(),
    );
  }

  factory WalletReadResult.disconnected({String? error}) {
    return WalletReadResult(
      isConnected: false,
      error: error,
    );
  }
}

/// Lee el wallet_summary.json generado por WalletAI con soporte de Project ID.
class WalletSummaryReader {
  static const _fileName = 'wallet_summary.json';
  static const _walletAIDirName = 'walletai';

  /// Retorna el resumen si WalletAI lo ha exportado, o null si no existe.
  static Future<WalletSummary?> read() async {
    final result = await readWithValidation();
    return result.summary;
  }

  /// Lee el resumen con información de validación y Project ID
  static Future<WalletReadResult> readWithValidation() async {
    try {
      final myLifeOSProjectId = await SharedIdentityService.getProjectId();

      // Intentar leer desde múltiples ubicaciones
      final file = await _findSummaryFile();
      if (file == null) {
        return WalletReadResult.disconnected(
          error: 'No se encontró el archivo wallet_summary.json',
        );
      }

      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final summary = WalletSummary.fromJson(json);

      // Verificar si los Project IDs coinciden
      final isMatch =
          summary.projectId == null || summary.projectId == myLifeOSProjectId;

      if (isMatch) {
        await SharedIdentityService.updateLastSync();
        return WalletReadResult.success(summary, projectIdMatched: true);
      } else {
        return WalletReadResult.success(summary, projectIdMatched: false);
      }
    } catch (e) {
      return WalletReadResult.disconnected(
        error: 'Error al leer: ${e.toString()}',
      );
    }
  }

  /// Busca el archivo de resumen en múltiples ubicaciones
  static Future<File?> _findSummaryFile() async {
    final docDir = await getApplicationDocumentsDirectory();

    // Ubicación 1: Directorio raíz de documentos
    final rootFile = File(p.join(docDir.path, _fileName));
    if (await rootFile.exists()) return rootFile;

    // Ubicación 2: Subdirectorio walletai
    final walletaiDir = Directory(p.join(docDir.path, _walletAIDirName));
    if (await walletaiDir.exists()) {
      final walletaiFile = File(p.join(walletaiDir.path, _fileName));
      if (await walletaiFile.exists()) return walletaiFile;
    }

    // Ubicación 3: Con ID personalizado
    final customId = await SharedIdentityService.getWalletAICustomId();
    if (customId != null && customId.isNotEmpty) {
      final customDir = Directory(p.join(docDir.path, 'walletai_$customId'));
      if (await customDir.exists()) {
        final customFile = File(p.join(customDir.path, _fileName));
        if (await customFile.exists()) return customFile;
      }
    }

    return null;
  }

  /// Obtiene la ruta preferida para escritura (para compatibilidad con WalletAI)
  static Future<String> getPreferredWalletAIDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();

    final customId = await SharedIdentityService.getWalletAICustomId();
    if (customId != null && customId.isNotEmpty) {
      return p.join(docDir.path, 'walletai_$customId');
    }

    return p.join(docDir.path, _walletAIDirName);
  }

  /// Verifica si WalletAI está instalado en el dispositivo (el archivo existe).
  static Future<bool> isWalletAIAvailable() async {
    try {
      final file = await _findSummaryFile();
      return file != null;
    } catch (_) {
      return false;
    }
  }

  /// Verifica si el Project ID de WalletAI coincide con el de MyLifeOS
  static Future<bool> isProjectIdMatched() async {
    final result = await readWithValidation();
    return result.isProjectIdMatched;
  }

  /// Fuerza un reescaneo del archivo de resumen
  static Future<WalletReadResult> forceRescan() async {
    return await readWithValidation();
  }
}
