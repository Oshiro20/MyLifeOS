import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';
import 'package:core/core.dart';
import '../providers/foodcoach_provider.dart';

class HistoryTab extends ConsumerWidget with AppFeedback {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(foodCoachProvider).history;

    if (history.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await ref.read(foodCoachProvider.notifier).load();
        },
        color: const Color(0xFF00C896),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_outlined, size: 64, color: Colors.white12),
              SizedBox(height: 12),
              Text('Sin evaluaciones aún',
                  style: TextStyle(color: Colors.white38, fontSize: 17)),
              SizedBox(height: 6),
              Text('Evalúa tu primera comida en la pestaña "Evaluar".',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white24, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(foodCoachProvider.notifier).load();
      },
      color: const Color(0xFF00C896),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: history.length,
        itemBuilder: (ctx, i) {
          final log = history[i];
          return _HistoryTile(
            log: log,
            onDelete: () => _confirmDelete(context, ref, log),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, MealLog log) async {
    final confirmed = await showConfirmDelete(context,
        itemName: _dateLabel(log.timestamp),
        subtitle:
            '${_label(log.classification)} · ${(log.healthScore * 100).round()}pts');
    if (!confirmed) return;
    await ref.read(foodCoachProvider.notifier).deleteFromHistory(log.id);
    if (context.mounted) showSuccess(context, 'Registro eliminado.');
  }

  String _dateLabel(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _label(FoodClassification c) {
    switch (c) {
      case FoodClassification.healthy:
        return 'Saludable';
      case FoodClassification.balanced:
        return 'Balanceado';
      case FoodClassification.junk:
        return 'No recomendable';
    }
  }
}

class _HistoryTile extends StatelessWidget {
  final MealLog log;
  final VoidCallback onDelete;
  const _HistoryTile({required this.log, required this.onDelete});

  Color get _color {
    switch (log.classification) {
      case FoodClassification.healthy:
        return const Color(0xFF4CAF50);
      case FoodClassification.balanced:
        return const Color(0xFFFFB74D);
      case FoodClassification.junk:
        return const Color(0xFFFF5252);
    }
  }

  String get _emoji {
    switch (log.classification) {
      case FoodClassification.healthy:
        return '💚';
      case FoodClassification.balanced:
        return '💛';
      case FoodClassification.junk:
        return '🔴';
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = (log.healthScore * 100).round();
    final d = log.timestamp;
    final dateStr =
        '${d.day}/${d.month}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: _color, width: 3)),
      ),
      child: Row(
        children: [
          Text(_emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(log.feedback,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.38),
                        fontSize: 11)),
                const SizedBox(height: 6),
                // mini barra de salud
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: log.healthScore,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(_color),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 2),
                Text('$score pts',
                    style: TextStyle(color: _color, fontSize: 10)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Colors.white24, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
