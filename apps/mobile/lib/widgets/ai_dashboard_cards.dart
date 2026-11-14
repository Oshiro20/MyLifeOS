import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:core/core.dart';
import 'package:armario/armario.dart';

/// Un card premium que muestra un insight diario generado por IA.
class InsightDelDiaCard extends ConsumerWidget {
  const InsightDelDiaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiService = ref.watch(geminiProvider);
    final insightAsync = ref.watch(_dailyInsightProvider(aiService));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF00C896).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline,
                  color: Color(0xFF00C896), size: 20),
              const SizedBox(width: 8),
              Text(
                'INSIGHT DEL DÍA',
                style: TextStyle(
                  color: const Color(0xFF00C896).withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              const Icon(Icons.auto_awesome, color: Colors.white24, size: 16),
            ],
          ),
          const SizedBox(height: 16),
          insightAsync.when(
            data: (text) => MarkdownBody(
              data: text ?? 'Cargando sabiduria...',
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
            loading: () => _LoadingShimmer(),
            error: (e, _) => const Text(
              'La IA está descansando ahora mismo.',
              style: TextStyle(color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }
}

final _dailyInsightProvider =
    FutureProvider.family<String?, GeminiService>((ref, service) async {
  return await service.generateDailyInsight();
});

/// Card que muestra el Outfit del Día unificado con `armarioProvider` y clima real.
class OutfitAIPreviewCard extends ConsumerWidget {
  const OutfitAIPreviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiService = ref.watch(geminiProvider);
    final armarioState = ref.watch(armarioProvider);
    final garments = armarioState.garments;

    if (garments.isEmpty) return const SizedBox.shrink();

    final cleanGarments = garments.where((g) => g.isClean).toList();
    if (armarioState.ootd == null &&
        !armarioState.isLoadingOotd &&
        cleanGarments.isNotEmpty) {
      ref.watch(_autoOotdBootstrapProvider((aiService, cleanGarments.length)));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF152019) : Colors.white;
    final titleColor = isDark ? Colors.white70 : const Color(0xFF35594A);
    final subtleColor = isDark ? Colors.white24 : const Color(0xFF5D7A6E);
    final textColor = isDark ? Colors.white : const Color(0xFF0A1F16);

    final ootd = armarioState.ootd;
    final top = ootd?['top'] as WardrobeGarment?;
    final bottom = ootd?['bottom'] as WardrobeGarment?;
    final shoes = ootd?['shoes'] as WardrobeGarment?;
    final explanation = ootd?['explanation']?.toString();
    final pieces = [
      if (top != null) top.name,
      if (bottom != null) bottom.name,
      if (shoes != null) shoes.name,
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark
                ? Colors.white12
                : const Color(0xFF00A37A).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checkroom, color: Color(0xFFF59E0B), size: 18),
              const SizedBox(width: 8),
              Text(
                'Outfit sugerido con IA',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text('Hoy · Armario',
                  style: TextStyle(color: subtleColor, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          if (armarioState.isLoadingOotd)
            _LoadingShimmer()
          else if (ootd != null && pieces.isNotEmpty)
            Row(
              children: [
                _GarmentMiniature(icon: '👔', color: Colors.amber),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pieces.join(' + '),
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (explanation != null && explanation.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          explanation,
                          style: TextStyle(color: titleColor, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            )
          else
            Text(
              cleanGarments.isEmpty
                  ? 'No hay prendas limpias disponibles hoy'
                  : (armarioState.error ?? 'Organizando tu look del día...'),
              style: TextStyle(color: titleColor, fontSize: 12),
            ),
        ],
      ),
    )
        .animate()
        .scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack);
  }
}

final _autoOotdBootstrapProvider =
    FutureProvider.family<void, (GeminiService, int)>((ref, args) async {
  final (aiService, _) = args;
  final weather = await WeatherService.fetchCurrentWeather();
  await ref
      .read(armarioProvider.notifier)
      .generateOutfitOfTheDay(aiService, weather);
});

/// Card de salud financiera con IA.
class FinanceHealthCard extends ConsumerWidget {
  const FinanceHealthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiFinance = ref.watch(aiFinanceProvider);
    final summaryAsync = ref.watch(walletSummaryProvider);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet,
                  color: Color(0xFF818CF8), size: 20),
              SizedBox(width: 8),
              Text(
                'SALUD FINANCIERA',
                style: TextStyle(
                  color: Color(0xFFC7D2FE),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          summaryAsync.when(
            data: (summary) {
              if (summary == null) {
                return const Text(
                  'Conecta WalletAI en la pestaña Finanzas para analizar tus gastos reales.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                );
              }

              if (summary.expenses <= 0 && summary.income <= 0) {
                return const Text(
                  'Sin movimientos registrados este mes en WalletAI.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                );
              }

              final wasteDetectAsync = ref.watch(_wasteDetectionProvider(
                (aiFinance, summary.month, summary.income, summary.expenses),
              ));

              return wasteDetectAsync.when(
                data: (alerts) => alerts.isEmpty
                    ? Text(
                        'Balance ${summary.currency} ${summary.balance.toStringAsFixed(2)} · Sin alertas detectadas en ${summary.month}.',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      )
                    : Column(
                        children: alerts
                            .map((a) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded,
                                          color: Colors.orangeAccent, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(a,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13))),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                loading: () => _LoadingShimmer(),
                error: (_, __) => const Text('Error en el análisis de gastos',
                    style: TextStyle(color: Colors.white54)),
              );
            },
            loading: () => _LoadingShimmer(),
            error: (_, __) => const Text(
              'No se pudo leer el resumen de WalletAI.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }
}

final _wasteDetectionProvider = FutureProvider.family<List<String>,
    (AiFinanceService, String, double, double)>((ref, args) async {
  final (service, month, income, expenses) = args;
  final transactions = <Map<String, dynamic>>[
    if (expenses > 0)
      {
        'name': 'Gastos del mes ($month)',
        'category': 'Gastos mensuales',
        'amount': -expenses,
        'date': month,
      },
    if (income > 0)
      {
        'name': 'Ingresos del mes ($month)',
        'category': 'Ingresos mensuales',
        'amount': income,
        'date': month,
      },
  ];
  return await service.detectWastefulExpenses(transactions: transactions);
});

class _GarmentMiniature extends StatelessWidget {
  final String icon;
  final Color color;
  const _GarmentMiniature({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Center(
        child: Text(icon, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

/// Shimmer para carga
class _LoadingShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(4),
          ),
        ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms),
        const SizedBox(height: 8),
        Container(
          width: 200,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(4),
          ),
        ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms),
      ],
    );
  }
}
