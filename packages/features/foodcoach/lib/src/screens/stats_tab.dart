import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/foodcoach_provider.dart';

class StatsTab extends ConsumerWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(foodCoachProvider);
    final stats = state.weeklyStats;

    if (stats == null || stats.totalMeals == 0) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_outlined, size: 64, color: Colors.white12),
            SizedBox(height: 12),
            Text('Aún no hay datos esta semana',
                style: TextStyle(color: Colors.white38, fontSize: 17)),
          ],
        ),
      );
    }

    final avgPct = (stats.averageHealthScore * 100).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen semanal
          const Text('RESUMEN SEMANAL',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 12),

          // Score central
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _scoreColor(stats.averageHealthScore).withAlpha(40),
                  _scoreColor(stats.averageHealthScore).withAlpha(10),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text('$avgPct',
                    style: TextStyle(
                        color: _scoreColor(stats.averageHealthScore),
                        fontSize: 64,
                        fontWeight: FontWeight.w900)),
                Text('puntos de salud promedio',
                    style: TextStyle(
                        color: _scoreColor(stats.averageHealthScore)
                            .withAlpha(180),
                        fontSize: 12)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: stats.averageHealthScore,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        _scoreColor(stats.averageHealthScore)),
                    minHeight: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Distribución
          const Text('DISTRIBUCIÓN',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _ClassCard(
                      emoji: '💚',
                      label: 'Saludable',
                      count: stats.healthyCount,
                      total: stats.totalMeals,
                      color: const Color(0xFF4CAF50))),
              const SizedBox(width: 8),
              Expanded(
                  child: _ClassCard(
                      emoji: '💛',
                      label: 'Balanceado',
                      count: stats.balancedCount,
                      total: stats.totalMeals,
                      color: const Color(0xFFFFB74D))),
              const SizedBox(width: 8),
              Expanded(
                  child: _ClassCard(
                      emoji: '🔴',
                      label: 'Chatarra',
                      count: stats.junkCount,
                      total: stats.totalMeals,
                      color: const Color(0xFFFF5252))),
            ],
          ),
          const SizedBox(height: 20),

          // Barra de distribución
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 16,
              child: Row(
                children: [
                  if (stats.healthyCount > 0)
                    Expanded(
                      flex: stats.healthyCount,
                      child: Container(color: const Color(0xFF4CAF50)),
                    ),
                  if (stats.balancedCount > 0)
                    Expanded(
                      flex: stats.balancedCount,
                      child: Container(color: const Color(0xFFFFB74D)),
                    ),
                  if (stats.junkCount > 0)
                    Expanded(
                      flex: stats.junkCount,
                      child: Container(color: const Color(0xFFFF5252)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Consejo semanal
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF00C896).withAlpha(50)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: Color(0xFF00C896), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Consejo de la semana',
                          style: TextStyle(
                              color: Color(0xFF00C896),
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        _weeklyTip(stats.averageHealthScore, stats.junkPercent),
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Total de comidas
          Text(
            '${stats.totalMeals} comidas evaluadas esta semana',
            style: const TextStyle(color: Colors.white24, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 0.68) return const Color(0xFF4CAF50);
    if (score >= 0.40) return const Color(0xFFFFB74D);
    return const Color(0xFFFF5252);
  }

  String _weeklyTip(double avg, double junkPct) {
    if (avg >= 0.68) {
      return 'Semana excelente. Mantén el ritmo incluyendo proteína en cada comida.';
    }
    if (avg >= 0.50) {
      return 'Buen progreso. Intenta reemplazar una comida chatarra por ensalada esta semana.';
    }
    if (junkPct >= 0.5) {
      return 'Más del 50% de tus comidas fueron poco saludables. Planea tu menú con anticipación.';
    }
    return 'Hay espacio para mejorar. Comienza añadiendo una fruta a tu desayuno cada día.';
  }
}

class _ClassCard extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;
  final int total;
  final Color color;

  const _ClassCard({
    required this.emoji,
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : (count / total * 100).round();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border(bottom: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text('$count',
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.w900)),
          Text('$pct%',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.38),
                  fontSize: 11)),
          Text(label,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.54),
                  fontSize: 10),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
