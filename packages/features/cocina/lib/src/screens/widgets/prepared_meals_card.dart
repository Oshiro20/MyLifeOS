import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/prepared_meals_provider.dart';
import 'recipe_cook_helper.dart';

/// Bandeja de comidas ya preparadas / sobras guardadas en el refrigerador,
/// separadas de los ingredientes crudos de Despensa.
class PreparedMealsTrayCard extends ConsumerWidget {
  final EdgeInsetsGeometry margin;

  const PreparedMealsTrayCard({
    this.margin = const EdgeInsets.fromLTRB(12, 6, 12, 8),
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(preparedMealsProvider);
    if (meals.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF00C896).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00C896).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🥡', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comidas listas en refri (${meals.length})',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF00C896),
                      ),
                    ),
                    Text(
                      'Porciones guardadas para recalentar sin volver a cocinar',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final meal in meals) _PreparedMealTile(meal: meal),
        ],
      ),
    );
  }
}

class _PreparedMealTile extends ConsumerWidget {
  final PreparedMeal meal;

  const _PreparedMealTile({required this.meal});

  String _expiryLabel() {
    if (meal.isExpired) return 'Vencido';
    final hours = meal.expiresAt.difference(DateTime.now()).inHours;
    if (hours < 24) return 'Vence hoy';
    final days = (hours / 24).ceil();
    return 'Vence en ${days}d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final expiryColor = meal.isExpired
        ? Colors.redAccent
        : (meal.isExpiringSoon
            ? Colors.amber
            : theme.colorScheme.onSurface.withValues(alpha: 0.6));

    final parts = <String>[
      if (meal.remainingServings > 0.001)
        '${formatIngredientQty(meal.remainingServings)} porc.',
      for (final ex in meal.extras)
        '${formatIngredientQty(ex.remainingQty)} ${ex.unit} ${ex.name}',
      _expiryLabel(),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: meal.isExpired || meal.isExpiringSoon
              ? expiryColor.withValues(alpha: 0.45)
              : theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.recipeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  parts.join(' · '),
                  style: TextStyle(fontSize: 11.5, color: expiryColor),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _openServeSheet(context, meal),
            icon: const Icon(Icons.restaurant, size: 15),
            label: const Text('Servir', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF00C896),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            tooltip: 'Descartar sobras',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: () async {
              await ref
                  .read(preparedMealsProvider.notifier)
                  .removeMeal(meal.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🗑️ "${meal.recipeName}" retirado'),
                    duration: const Duration(milliseconds: 1600),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openServeSheet(BuildContext context, PreparedMeal meal) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ServePreparedMealSheet(meal: meal),
    );
  }
}

class _ServePreparedMealSheet extends ConsumerStatefulWidget {
  final PreparedMeal meal;

  const _ServePreparedMealSheet({required this.meal});

  @override
  ConsumerState<_ServePreparedMealSheet> createState() =>
      _ServePreparedMealSheetState();
}

class _ServePreparedMealSheetState
    extends ConsumerState<_ServePreparedMealSheet> {
  late double _servingsToEat;
  final Map<String, double> _extrasToEat = {};
  bool _sendToFoodCoach = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _servingsToEat = widget.meal.remainingServings >= 1.0
        ? 1.0
        : widget.meal.remainingServings;
    for (final ex in widget.meal.extras) {
      _extrasToEat[ex.name] = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    final theme = Theme.of(context);
    final hasAnySelected = _servingsToEat > 0.001 ||
        _extrasToEat.values.any((q) => q > 0.001);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '🍽️ Servir "${meal.recipeName}"',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (meal.remainingServings > 0.001) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Porciones del plato (quedan ${formatIngredientQty(meal.remainingServings)})',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: _servingsToEat > 0
                      ? () => setState(() {
                            _servingsToEat = (_servingsToEat - 0.5)
                                .clamp(0.0, meal.remainingServings);
                          })
                      : null,
                ),
                Text(
                  '${formatIngredientQty(_servingsToEat)} porc.',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: _servingsToEat < meal.remainingServings
                      ? () => setState(() {
                            _servingsToEat = (_servingsToEat + 0.5)
                                .clamp(0.0, meal.remainingServings);
                          })
                      : null,
                ),
              ],
            ),
          ],
          if (meal.extras.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Acompañamientos guardados',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            ...meal.extras.map((ex) {
              final cur = _extrasToEat[ex.name] ?? 0.0;
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      '${ex.name} (quedan ${formatIngredientQty(ex.remainingQty)} ${ex.unit})',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: cur > 0
                        ? () => setState(() {
                              _extrasToEat[ex.name] =
                                  (cur - 1.0).clamp(0.0, ex.remainingQty);
                            })
                        : null,
                  ),
                  Text(
                    '${formatIngredientQty(cur)} ${ex.unit}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    onPressed: cur < ex.remainingQty
                        ? () => setState(() {
                              _extrasToEat[ex.name] =
                                  (cur + 1.0).clamp(0.0, ex.remainingQty);
                            })
                        : null,
                  ),
                ],
              );
            }),
          ],
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '📊 Evaluar esta comida en FoodCoach',
              style: TextStyle(fontSize: 13),
            ),
            subtitle: const Text(
              'Pre-carga el plato y sus extras en FoodCoach para analizar macros',
              style: TextStyle(fontSize: 11),
            ),
            value: _sendToFoodCoach,
            activeTrackColor: const Color(0xFF00C896),
            onChanged: (v) => setState(() => _sendToFoodCoach = v),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: !hasAnySelected || _saving ? null : _confirmServe,
              icon: const Icon(Icons.check, color: Colors.black),
              label: const Text(
                'Confirmar consumo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C896),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmServe() async {
    setState(() => _saving = true);
    try {
      await ref.read(preparedMealsProvider.notifier).consumeServings(
            widget.meal.id,
            servings: _servingsToEat,
            extraQuantities: _extrasToEat,
          );

      if (_sendToFoodCoach) {
        final eatenExtras = [
          for (final ex in widget.meal.extras)
            if ((_extrasToEat[ex.name] ?? 0) > 0.001)
              '${formatIngredientQty(_extrasToEat[ex.name]!)} ${ex.unit} ${ex.name}',
        ];
        ref.read(pendingMealEvaluationProvider.notifier).queue(
              recipeName: widget.meal.recipeName,
              ingredients: [
                if (_servingsToEat > 0.001)
                  '${formatIngredientQty(_servingsToEat)} porción(es) de ${widget.meal.recipeName}',
                ...eatenExtras,
              ],
            );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      if (_sendToFoodCoach) {
        GoRouter.maybeOf(context)?.go('/foodcoach');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🍽️ Registrado consumo de "${widget.meal.recipeName}"'),
            backgroundColor: const Color(0xFF00C896),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
