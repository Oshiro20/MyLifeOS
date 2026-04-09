import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ai_service.dart';
import 'offline_cache_service.dart';
import 'connectivity_service.dart';

// ── Modelos ───────────────────────────────────────────────────────────────────

/// Resultado del análisis de gastos realizado por Gemini AI.
class FinanceInsight {
  final double totalGastos;
  final String mayorGasto;
  final double mayorGastoMonto;
  final List<String> alertas;
  final String tendencia; // 'positiva' | 'negativa' | 'estable'
  final String consejo;
  final List<CategoryInsight> categoriasSugeridas;
  final bool isFromCache;

  const FinanceInsight({
    required this.totalGastos,
    required this.mayorGasto,
    required this.mayorGastoMonto,
    required this.alertas,
    required this.tendencia,
    required this.consejo,
    required this.categoriasSugeridas,
    this.isFromCache = false,
  });

  factory FinanceInsight.fromJson(
    Map<String, dynamic> json, {
    bool isFromCache = false,
  }) {
    final cats = (json['categoriasSugeridas'] as List<dynamic>? ?? [])
        .map((c) => CategoryInsight.fromJson(c as Map<String, dynamic>))
        .toList();
    final mayorGastoMap =
        json['mayorGasto'] as Map<String, dynamic>? ?? {};
    return FinanceInsight(
      totalGastos: (json['totalGastos'] as num?)?.toDouble() ?? 0.0,
      mayorGasto: mayorGastoMap['categoria'] as String? ?? '--',
      mayorGastoMonto:
          (mayorGastoMap['monto'] as num?)?.toDouble() ?? 0.0,
      alertas: List<String>.from(json['alertas'] as List? ?? []),
      tendencia: json['tendencia'] as String? ?? 'estable',
      consejo: json['consejo'] as String? ?? '',
      categoriasSugeridas: cats,
      isFromCache: isFromCache,
    );
  }

  static FinanceInsight empty() => const FinanceInsight(
        totalGastos: 0,
        mayorGasto: '--',
        mayorGastoMonto: 0,
        alertas: [],
        tendencia: 'estable',
        consejo:
            'Agrega transacciones para obtener análisis personalizados.',
        categoriasSugeridas: [],
      );
}

class CategoryInsight {
  final String nombre;
  final double porcentaje;
  const CategoryInsight({required this.nombre, required this.porcentaje});

  factory CategoryInsight.fromJson(Map<String, dynamic> json) =>
      CategoryInsight(
        nombre: json['nombre'] as String? ?? '',
        porcentaje: (json['porcentaje'] as num?)?.toDouble() ?? 0.0,
      );
}

// ── Servicio ──────────────────────────────────────────────────────────────────

/// Servicio de análisis financiero con Gemini AI.
///
/// Recibe lista de transacciones y devuelve un [FinanceInsight] con tendencias,
/// alertas y consejos. Usa caché offline automático por mes.
class AiFinanceService {
  final GeminiService _gemini;
  final OfflineCacheService _cache;
  final ConnectivityService _connectivity;

  static const _cacheKeyPrefix = 'ai_finance_';

  AiFinanceService(this._gemini, this._cache, this._connectivity);

  /// Analiza transacciones del mes y retorna un [FinanceInsight].
  ///
  /// Cada map en [transactions] debe tener:
  ///  - 'name'     : String (nombre del comercio o ingreso)
  ///  - 'category' : String (categoría, ej. "Alimentación")
  ///  - 'amount'   : double (negativo = gasto, positivo = ingreso)
  ///  - 'date'     : String (ej. "2026-04-01")
  Future<FinanceInsight> analyzeExpenses({
    required List<Map<String, dynamic>> transactions,
    String? month,
  }) async {
    final cacheKey = '$_cacheKeyPrefix${month ?? _currentMonth()}';

    final online = await _connectivity.isOnline();
    if (!online) {
      debugPrint('[AiFinanceService] Offline — usando caché');
      final cached = await _cache.loadMap(cacheKey);
      if (cached != null) {
        return FinanceInsight.fromJson(cached, isFromCache: true);
      }
      return FinanceInsight.empty();
    }

    if (transactions.isEmpty) return FinanceInsight.empty();

    final txnsText = transactions
        .map((t) =>
            '- ${t['name']} (${t['category']}): '
            'S/${(t['amount'] as num).abs().toStringAsFixed(2)} '
            'el ${t['date']}')
        .join('\n');

    final prompt = '''
Eres un asesor financiero personal. Analiza estas transacciones del mes de un usuario adulto en Perú:

$txnsText

Devuelve EXACTAMENTE este JSON sin markdown ni texto adicional:
{
  "totalGastos": <float total de gastos del mes>,
  "mayorGasto": {"categoria": "<categoria con mayor gasto>", "monto": <float>},
  "alertas": ["<alerta breve 1>", "<alerta breve 2>"],
  "tendencia": "<positiva|negativa|estable>",
  "consejo": "<un consejo de ahorro personalizado de 1 oración>",
  "categoriasSugeridas": [
    {"nombre": "<categoria>", "porcentaje": <float porcentaje del total>}
  ]
}
''';

    try {
      final result = await _gemini.generateText(prompt: prompt);
      if (result == null) return FinanceInsight.empty();

      final clean = result
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final decoded = _tryDecode(clean);
      if (decoded == null) return FinanceInsight.empty();

      await _cache.saveMap(cacheKey, decoded);
      return FinanceInsight.fromJson(decoded);
    } catch (e) {
      debugPrint('[AiFinanceService] Error: $e');
      final cached = await _cache.loadMap(cacheKey);
      if (cached != null) {
        return FinanceInsight.fromJson(cached, isFromCache: true);
      }
      return FinanceInsight.empty();
    }
  }

  static String _currentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic>? _tryDecode(String raw) {
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Predice el gasto del próximo mes basado en el historial.
  Future<String?> predictNextMonth({
    required List<Map<String, dynamic>> history,
  }) async {
    if (history.isEmpty) return null;

    final prompt = '''
Eres un analista de datos financiero. Tengo este historial de gastos de los últimos meses:
${history.toString()}

1. Predice el gasto total aproximado para el próximo mes.
2. Identifica si hay una tendencia al alza o a la baja.
3. Da una recomendación para el cierre del mes.

Responde en formato Markdown ejecutivo.
''';

    return await _gemini.generateText(prompt: prompt, cacheKey: 'finance_prediction');
  }

  /// Detecta "Gastos Hormiga" y suscripciones innecesarias.
  Future<List<String>> detectWastefulExpenses({
    required List<Map<String, dynamic>> transactions,
  }) async {
    if (transactions.isEmpty) return [];

    final prompt = '''
Eres un experto en ahorro. Analiza estas transacciones y busca "gastos hormiga" 
(pequeños gastos recurrentes que sumados son mucho) o suscripciones duplicadas/olvidadas.
$transactions

Devuelve una lista JSON de strings con los hallazgos.
Ejemplo: ["Gasto excesivo en cafeterías (S/120 al mes)", "Suscripción duplicada detectada"]
Solo devuelve el JSON array.
''';

    try {
      final result = await _gemini.generateText(prompt: prompt);
      if (result == null) return [];
      
      final clean = result
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
          
      final decoded = jsonDecode(clean);
      if (decoded is List) {
        return List<String>.from(decoded);
      }
      return [];
    } catch (e) {
      debugPrint('[AiFinanceService] Error detectWastefulExpenses: $e');
      return [];
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final aiFinanceProvider = Provider<AiFinanceService>((ref) {
  return AiFinanceService(
    ref.read(geminiProvider),
    ref.read(offlineCacheProvider),
    ref.read(connectivityProvider),
  );
});
