import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AIAnalysisCard extends ConsumerStatefulWidget {
  final WalletSummary? summary;
  const AIAnalysisCard({super.key, this.summary});

  @override
  ConsumerState<AIAnalysisCard> createState() => _AIAnalysisCardState();
}

class _AIAnalysisCardState extends ConsumerState<AIAnalysisCard> {
  bool _loading = false;
  FinanceInsight? _insight;
  String? _error;

  Future<void> _analyze() async {
    if (widget.summary == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Por ahora, como no tenemos la lista completa de transacciones aquí,
      // enviamos una lista vacía y el servicio debería manejarlo o podemos
      // expandirlo para que acepte el resumen.
      // NOTA: En una versión futura, WalletAI debería exportar 'transactions' también.
      
      final financeService = ref.read(aiFinanceProvider);
      
      // Intentamos simular las transacciones desde el resumen si es posible
      final mockTransactions = [
        {
          'name': 'Resumen del mes',
          'category': 'General',
          'amount': -widget.summary!.expenses,
          'date': widget.summary!.month,
        },
        {
          'name': 'Ingresos totales',
          'category': 'Ingresos',
          'amount': widget.summary!.income,
          'date': widget.summary!.month,
        }
      ];

      final result = await financeService.analyzeExpenses(
        transactions: mockTransactions,
        month: widget.summary!.month,
      );

      if (mounted) {
        setState(() {
          _insight = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al analizar: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = const Color(0xFF00C896);
    final surface = isDark ? const Color(0xFF152019) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primary.withValues(alpha: isDark ? 0.2 : 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primary.withValues(alpha: 0.1),
                  primary.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF00C896), size: 20),
                const SizedBox(width: 10),
                const Text(
                  'Análisis con IA',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (_insight != null && !_loading)
                  Text(
                    _insight!.isFromCache ? 'Caché' : 'Actualizado',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildBody(),
          ),

          if (_insight == null && !_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.summary != null ? _analyze : null,
                  icon: const Icon(Icons.analytics_outlined, size: 18),
                  label: const Text('Generar Insights'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00C896)),
              SizedBox(height: 12),
              Text('Gemini está analizando tu salud financiera...',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Column(
        children: [
          Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          TextButton(onPressed: _analyze, child: const Text('Reintentar')),
        ],
      );
    }

    if (_insight == null) {
      return const Text(
        'Obtén un análisis detallado de tus tendencias de gasto y sugerencias de ahorro personalizadas.',
        style: TextStyle(fontSize: 13, color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tendencia
        Row(
          children: [
            _TendenciaBadge(tendencia: _insight!.tendencia),
            const Spacer(),
            Text(
              'Gasto Mayor: ${_insight!.mayorGasto}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Alertas
        if (_insight!.alertas.isNotEmpty) ...[
          const Text('Alertas',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          ..._insight!.alertas.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(a,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70))),
                  ],
                ),
              )),
          const SizedBox(height: 16),
        ],

        // Consejo
        const Text('Consejo del Chef Financiero',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF00C896).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00C896).withValues(alpha: 0.1)),
          ),
          child: MarkdownBody(
            data: _insight!.consejo,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(fontSize: 13, color: Colors.white),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _analyze,
            child: const Text('Actualizar Análisis', style: TextStyle(fontSize: 12, color: Color(0xFF00C896))),
          ),
        ),
      ],
    );
  }
}

class _TendenciaBadge extends StatelessWidget {
  final String tendencia;
  const _TendenciaBadge({required this.tendencia});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label;

    switch (tendencia.toLowerCase()) {
      case 'positiva':
        color = const Color(0xFF00C896);
        icon = Icons.trending_up;
        label = 'Mejorando';
        break;
      case 'negativa':
        color = const Color(0xFFFF6B6B);
        icon = Icons.trending_down;
        label = 'Alerta de Gasto';
        break;
      default:
        color = Colors.blueAccent;
        icon = Icons.trending_flat;
        label = 'Estable';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
