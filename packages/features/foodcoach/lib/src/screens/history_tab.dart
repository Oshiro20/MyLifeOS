import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';
import 'package:core/core.dart';
import '../providers/foodcoach_provider.dart';

class HistoryTab extends ConsumerStatefulWidget with AppFeedback {
  const HistoryTab({super.key});

  @override
  ConsumerState<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<HistoryTab> {
  FoodClassification? _filter;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(foodCoachProvider);
    final history = state.history;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    if (state.isLoading && history.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00C896)),
      );
    }

    if (state.error != null && history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'No se pudo cargar el historial',
                style: TextStyle(
                    color: onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: onSurface.withValues(alpha: 0.6), fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.read(foodCoachProvider.notifier).load(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (history.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await ref.read(foodCoachProvider.notifier).load();
        },
        color: const Color(0xFF00C896),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_outlined,
                        size: 64, color: onSurface.withValues(alpha: 0.15)),
                    const SizedBox(height: 12),
                    Text('Sin evaluaciones aún',
                        style: TextStyle(
                            color: onSurface.withValues(alpha: 0.45),
                            fontSize: 17)),
                    const SizedBox(height: 6),
                    Text('Evalúa tu primera comida en la pestaña "Evaluar".',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: onSurface.withValues(alpha: 0.35),
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final visible = _filter == null
        ? history
        : history.where((l) => l.classification == _filter).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(foodCoachProvider.notifier).load();
      },
      color: const Color(0xFF00C896),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text('Todos (${history.length})',
                      style: const TextStyle(fontSize: 11.5)),
                  selected: _filter == null,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                const SizedBox(width: 6),
                for (final c in FoodClassification.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('${_emojiFor(c)} ${_label(c)}',
                          style: const TextStyle(fontSize: 11.5)),
                      selected: _filter == c,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _filter = c),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      'Sin registros en esta categoría.',
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: visible.length,
                    itemBuilder: (ctx, i) {
                      final log = visible[i];
                      return _HistoryTile(
                        log: log,
                        onDelete: () => _confirmDelete(context, log),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, MealLog log) async {
    final confirmed = await widget.showConfirmDelete(
      context,
      itemName: log.mealName ?? _dateLabel(log.timestamp),
      subtitle:
          '${_label(log.classification)} · ${(log.healthScore * 100).round()}pts',
    );
    if (!confirmed) return;
    await ref.read(foodCoachProvider.notifier).deleteFromHistory(log.id);
    if (!context.mounted) return;
    final err = ref.read(foodCoachProvider).error;
    if (err != null) {
      widget.showError(context, err);
    } else {
      widget.showSuccess(context, 'Registro eliminado.');
    }
  }

  String _dateLabel(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _emojiFor(FoodClassification c) => switch (c) {
        FoodClassification.healthy => '💚',
        FoodClassification.balanced => '💛',
        FoodClassification.junk => '🔴',
      };

  String _label(FoodClassification c) => switch (c) {
        FoodClassification.healthy => 'Saludable',
        FoodClassification.balanced => 'Balanceado',
        FoodClassification.junk => 'Chatarra',
      };
}

class _HistoryTile extends StatelessWidget {
  final MealLog log;
  final VoidCallback onDelete;
  const _HistoryTile({required this.log, required this.onDelete});

  Color get _color => switch (log.classification) {
        FoodClassification.healthy => const Color(0xFF4CAF50),
        FoodClassification.balanced => const Color(0xFFFFB74D),
        FoodClassification.junk => const Color(0xFFFF5252),
      };

  String get _emoji => switch (log.classification) {
        FoodClassification.healthy => '💚',
        FoodClassification.balanced => '💛',
        FoodClassification.junk => '🔴',
      };

  @override
  Widget build(BuildContext context) {
    final score = (log.healthScore * 100).round();
    final d = log.timestamp;
    final dateStr =
        '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final title = (log.mealName != null && log.mealName!.isNotEmpty)
        ? log.mealName!
        : '${log.mealSlot.emoji} ${log.mealSlot.label}';
    final metaParts = <String>[
      '${log.mealSlot.emoji} ${log.mealSlot.label}',
      if (log.cookingMethod != null)
        '${log.cookingMethod!.emoji} ${log.cookingMethod!.label}',
      dateStr,
    ];
    final macros = log.macros;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: _color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  metaParts.join(' · '),
                  style: TextStyle(
                    color: onSurface.withValues(alpha: 0.55),
                    fontSize: 11,
                  ),
                ),
                if (macros != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    '🔥 ${macros.caloriesKcal} kcal · P ${macros.proteinGrams}g · C ${macros.carbsGrams}g · G ${macros.fatGrams}g',
                    style: const TextStyle(
                      color: Color(0xFF00C896),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (log.detectedIngredients.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    log.detectedIngredients.take(5).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onSurface.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  log.feedback,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onSurface.withValues(alpha: 0.55),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: log.healthScore,
                    backgroundColor: onSurface.withValues(alpha: 0.1),
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
            icon: Icon(Icons.delete_outline,
                color: onSurface.withValues(alpha: 0.35), size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
