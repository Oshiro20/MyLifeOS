import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Modelo del resumen exportado por WalletAI.
class WalletSummary {
  final String version;
  final String month;
  final double balance;
  final double income;
  final double expenses;
  final String currency;
  final DateTime exportedAt;

  const WalletSummary({
    required this.version,
    required this.month,
    required this.balance,
    required this.income,
    required this.expenses,
    required this.currency,
    required this.exportedAt,
  });

  factory WalletSummary.fromJson(Map<String, dynamic> json) => WalletSummary(
        version: json['version'] as String? ?? '',
        month: json['month'] as String? ?? '',
        balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
        income: (json['income'] as num?)?.toDouble() ?? 0.0,
        expenses: (json['expenses'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency'] as String? ?? 'PEN',
        exportedAt: DateTime.tryParse(json['exportedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Lee el wallet_summary.json generado por WalletAI.
class WalletSummaryReader {
  static const _fileName = 'wallet_summary.json';

  /// Retorna el resumen si WalletAI lo ha exportado, o null si no existe.
  static Future<WalletSummary?> read() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, _fileName));
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return WalletSummary.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Verifica si WalletAI está instalado en el dispositivo (el archivo existe).
  static Future<bool> isWalletAIAvailable() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File(p.join(dir.path, _fileName)).exists();
    } catch (_) {
      return false;
    }
  }
}
