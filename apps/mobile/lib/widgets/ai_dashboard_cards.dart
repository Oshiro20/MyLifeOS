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

/// Card que sugiere el outfit del día basado en el clima (simulado) y el armario.
class OutfitAIPreviewCard extends ConsumerWidget {
  const OutfitAIPreviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiService = ref.watch(geminiProvider);
    final armarioState = ref.watch(armarioProvider);
    final garments = armarioState.garments;

    if (garments.isEmpty) return const SizedBox.shrink();

    final suggestionAsync =
        ref.watch(_outfitSuggestionProvider((aiService, garments)));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF152019),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checkroom, color: Color(0xFFF59E0B), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Outfit sugerido con IA',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const Text('Hoy · Personalizado',
                  style: TextStyle(color: Colors.white24, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          suggestionAsync.when(
            data: (suggestion) => Row(
              children: [
                _GarmentMiniature(icon: '🎨', color: Colors.blueGrey),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion ?? 'Organizando tu look...',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            loading: () => _LoadingShimmer(),
            error: (_, __) => const Text('Error al sugerir outfit',
                style: TextStyle(color: Colors.white24)),
          ),
        ],
      ),
    )
        .animate()
        .scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack);
  }
}

final _outfitSuggestionProvider =
    FutureProvider.family<String?, (GeminiService, List<WardrobeGarment>)>(
        (ref, args) async {
  final (service, garments) = args;
  final description = garments
      .map((g) =>
          '${g.type.name}: ${g.brand ?? 'Sin marca'} (${g.primaryColor})')
      .join(', ');
  return await service.suggestOutfitOfTheDay(
    occasion: 'Diario',
    garmentsDescription: [description],
    userProfileContext: 'Clima soleado, 24°C',
  );
});

/// Card de salud financiera con IA.
class FinanceHealthCard extends ConsumerWidget {
  const FinanceHealthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiFinance = ref.watch(aiFinanceProvider);
    // TODO: Obtener transacciones reales del provider de finanzas
    final transactions = <Map<String, dynamic>>[];

    final wasteDetectAsync =
        ref.watch(_wasteDetectionProvider((aiFinance, transactions)));

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
          Row(
            children: [
              const Icon(Icons.account_balance_wallet,
                  color: Color(0xFF818CF8), size: 20),
              const SizedBox(width: 8),
              const Text(
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
          wasteDetectAsync.when(
            data: (alerts) => alerts.isEmpty
                ? const Text(
                    'Tus finanzas se ven impecables hoy. ¡Sigue así!',
                    style: TextStyle(color: Colors.white, fontSize: 14),
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
                style: TextStyle(color: Colors.white24)),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }
}

final _wasteDetectionProvider = FutureProvider.family<List<String>,
    (AiFinanceService, List<Map<String, dynamic>>)>((ref, args) async {
  final (service, transactions) = args;
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
