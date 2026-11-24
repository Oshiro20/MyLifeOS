import 'package:core/core.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/cocina_providers.dart';
import '../../providers/prepared_meals_provider.dart';
import 'prepared_meals_card.dart';
import 'recipe_cook_helper.dart';
import 'recipe_detail_sheet.dart';

/// Tarjeta de lista rápida de comidas (Desayuno / Almuerzo / Cena) sin espera IA:
/// prioriza Plan Semanal de hoy, Comidas Listas en refri y Top recetas locales
/// ordenadas por disponibilidad real en despensa, rescate de vencimientos y meta.
class QuickMealSuggestionsCard extends ConsumerStatefulWidget {
  final bool compact;
  final EdgeInsetsGeometry margin;
  final void Function(QuickMealPeriod period)? onAskAI;

  const QuickMealSuggestionsCard({
    this.compact = false,
    this.margin = const EdgeInsets.fromLTRB(12, 6, 12, 8),
    this.onAskAI,
    super.key,
  });

  @override
  ConsumerState<QuickMealSuggestionsCard> createState() =>
      _QuickMealSuggestionsCardState();
}

class _QuickMealSuggestionsCardState
    extends ConsumerState<QuickMealSuggestionsCard> {
  static const _useCase = QuickMealSuggestionsUseCase();
  late QuickMealPeriod _period;

  @override
  void initState() {
    super.initState();
    _period = QuickMealPeriod.forHour(DateTime.now().hour);
  }

  @override
  Widget build(BuildContext context) {
    final recipesState = ref.watch(recipesProvider);
    final invState = ref.watch(inventoryProvider);
    final preparedMeals = ref.watch(preparedMealsProvider);
    final weeklyState = ref.watch(weeklyMenuProvider);
    final equivalences = ref.watch(ingredientEquivalencesProvider);
    final learnedAliases = ref.watch(learnedIngredientAliasesProvider);
    final recentCooked =
        ref.watch(recentCookedNamesProvider).asData?.value ?? const <String>[];

    final activeGoal = recipesState.activeGoal;
    final recommendations = _useCase(
      period: _period,
      recipes: recipesState.recipes,
      inventory: invState.ingredients,
      activeGoal: activeGoal,
      recentlyCookedNames: recentCooked.toSet(),
      customGramsPerUnit: equivalences,
      learnedAliases: learnedAliases,
      limit: widget.compact ? 3 : 4,
    );

    // Buscar si ya hay un plato asignado en el Plan Semanal para hoy + periodo
    Recipe? plannedRecipe;
    if (weeklyState is WeeklyMenuLoaded) {
      final today = DateTime.now().weekday;
      final entry = weeklyState.entries
          .where((e) =>
              e.dayOfWeek == today && e.mealType == _period.weeklyMealType)
          .firstOrNull;
      if (entry != null) {
        plannedRecipe = recipesState.recipes
            .where((r) => r.id == entry.recipeId)
            .firstOrNull;
      }
    }

    final showLeftoverShortcut = preparedMeals.isNotEmpty &&
        (_period == QuickMealPeriod.lunch ||
            _period == QuickMealPeriod.dinner ||
            widget.compact);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;

    return Container(
      margin: widget.margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0xFFFF9800).withValues(alpha: 0.25)
              : const Color(0xFF00C896).withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🍽️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sugerencias rápidas de hoy',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${activeGoal.emoji} ${activeGoal.label} · según tu despensa actual',
                      style: TextStyle(
                        fontSize: 11,
                        color: onSurface.withValues(alpha: 0.58),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onAskAI != null)
                TextButton.icon(
                  onPressed: () => widget.onAskAI!(_period),
                  icon: const Icon(Icons.auto_awesome,
                      size: 14, color: Color(0xFFFF9800)),
                  label: const Text(
                    'IA',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF9800),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFFF9800).withValues(alpha: 0.12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Selector rápido Desayuno / Almuerzo / Cena
          Row(
            children: [
              for (final p in QuickMealPeriod.values)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: p == QuickMealPeriod.dinner ? 0 : 6,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _period = p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: _period == p
                              ? const Color(0xFFFF9800)
                              : onSurface.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${p.emoji} ${p.label}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _period == p
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _period == p
                                ? Colors.black
                                : onSurface.withValues(alpha: 0.78),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (showLeftoverShortcut) ...[
            const SizedBox(height: 10),
            _PriorityHighlightBanner(
              emoji: '🥡',
              accent: const Color(0xFF00C896),
              title: 'Listo en refri: ${preparedMeals.first.recipeName}',
              subtitle:
                  '${formatIngredientQty(preparedMeals.first.remainingServings)} porc.${preparedMeals.first.extras.isNotEmpty ? ' · +${preparedMeals.first.extras.length} extra(s)' : ''} · recalienta sin cocinar',
              actionLabel: 'Servir',
              onAction: () =>
                  showServePreparedMealSheet(context, preparedMeals.first),
            ),
          ],
          if (plannedRecipe != null) ...[
            const SizedBox(height: 8),
            _PriorityHighlightBanner(
              emoji: '📅',
              accent: const Color(0xFF00F0FF),
              title: 'Plan de hoy: ${plannedRecipe.name}',
              subtitle:
                  '${plannedRecipe.durationMinutes} min · asignado en tu Plan Semanal',
              actionLabel: 'Cocinar',
              onAction: () => confirmAndCookRecipe(
                context: context,
                recipe: plannedRecipe!,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (recommendations.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Aún no tienes recetas guardadas para ${_period.label.toLowerCase()}. Pide ideas rápidas al Chef IA.',
                      style: TextStyle(
                        fontSize: 12,
                        color: onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                  if (widget.onAskAI != null) ...[
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => widget.onAskAI!(_period),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Generar IA',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            )
          else ...[
            for (final rec in recommendations)
              _QuickMealRow(
                rec: rec,
                onOpenDetail: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (_) => RecipeDetailSheet(recipe: rec.recipe),
                ),
                onCook: () => confirmAndCookRecipe(
                  context: context,
                  recipe: rec.recipe,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PriorityHighlightBanner extends StatelessWidget {
  final String emoji;
  final Color accent;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _PriorityHighlightBanner({
    required this.emoji,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: onSurface.withValues(alpha: 0.65),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel,
              style:
                  const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickMealRow extends StatelessWidget {
  final QuickMealRecommendation rec;
  final VoidCallback onOpenDetail;
  final VoidCallback onCook;

  const _QuickMealRow({
    required this.rec,
    required this.onOpenDetail,
    required this.onCook,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final pct = rec.availabilityPercent;
    final pctColor = pct >= 80
        ? const Color(0xFF00C896)
        : (pct >= 50 ? Colors.amber : Colors.orangeAccent);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onOpenDetail,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: pctColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$pct%',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: pctColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec.recipe.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    [
                      if (rec.recipe.durationMinutes > 0)
                        '${rec.recipe.durationMinutes} min',
                      '${rec.availableCount}/${rec.totalIngredients} listos',
                      if (rec.rescuedExpiringNames.isNotEmpty)
                        '⚡ usa ${rec.rescuedExpiringNames.first}',
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 11,
                      color: rec.rescuedExpiringNames.isNotEmpty
                          ? const Color(0xFFFFB300)
                          : onSurface.withValues(alpha: 0.58),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.local_fire_department_rounded,
                  color: Color(0xFFFF9800), size: 20),
              tooltip: 'Cocinar ahora',
              onPressed: onCook,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            ),
          ],
        ),
      ),
    );
  }
}
