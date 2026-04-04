import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';
import '../providers/cocina_providers.dart';

/// Tab "Sugeridas" — muestra qué puedes cocinar hoy con lo que tienes.
class SuggestionsTab extends ConsumerWidget {
  const SuggestionsTab({super.key});

  static const _goalLabels = {
    NutritionGoal.loseWeight: '🥗 Adelgazar',
    NutritionGoal.maintain: '⚖️ Mantener',
    NutritionGoal.gainMuscle: '💪 Ganar músculo',
    NutritionGoal.other: '🍽️ Otro',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recipesProvider);
    final invState = ref.watch(inventoryProvider);

    final availableNames =
        invState.ingredients.map((i) => i.name.toLowerCase()).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector de objetivo nutricional
        Container(
          height: 52,
          color: Theme.of(context).appBarTheme.backgroundColor,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: NutritionGoal.values.map((goal) {
              final selected = state.activeGoal == goal;
              return GestureDetector(
                onTap: () => ref.read(recipesProvider.notifier).setGoal(goal),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF00C896)
                        : const Color(0xFF2A2A40),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _goalLabels[goal]!,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white54,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Mensaje motivante
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                '${invState.ingredients.length} ingredientes en tu despensa · ${state.recipes.length} recetas guardadas',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 12),
              ),
            ],
          ),
        ),

        // Sugerencias
        Expanded(
          child: state.suggestions.isEmpty
              ? _EmptyState(
                  hasRecipes: state.recipes.isNotEmpty,
                  hasIngredients: invState.ingredients.isNotEmpty,
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: state.suggestions.length,
                  itemBuilder: (ctx, i) {
                    final r = state.suggestions[i];
                    return _SuggestionCard(
                      recipe: r,
                      availableNames: availableNames,
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '🌅 ¿Qué desayunamos hoy?';
    if (hour < 17) return '🍳 ¿Qué almorzamos hoy?';
    return '🌙 ¿Qué cenamos hoy?';
  }
}

// ── Estado vacío contextual ──────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasRecipes;
  final bool hasIngredients;
  const _EmptyState({required this.hasRecipes, required this.hasIngredients});

  @override
  Widget build(BuildContext context) {
    String msg;
    IconData icon;

    if (!hasRecipes && !hasIngredients) {
      icon = Icons.restaurant_outlined;
      msg = 'Agrega recetas e ingredientes a\ntu despensa para ver sugerencias.';
    } else if (!hasRecipes) {
      icon = Icons.menu_book_outlined;
      msg = 'Tienes ingredientes pero no recetas.\nAgrega recetas para ver qué puedes cocinar.';
    } else if (!hasIngredients) {
      icon = Icons.kitchen_outlined;
      msg = 'Tienes recetas pero la despensa está vacía.\nAgrega ingredientes para ver sugerencias.';
    } else {
      icon = Icons.lightbulb_outline;
      msg = 'No se encontraron recetas que coincidan\ncon tus ingredientes actuales (75%+ cobertura).';
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.white12),
          const SizedBox(height: 12),
          Text(msg,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 14)),
        ],
      ),
    );
  }
}

// ── Tarjeta de receta sugerida con % de cobertura ───────────────────────────

class _SuggestionCard extends StatelessWidget {
  final Recipe recipe;
  final Set<String> availableNames;
  const _SuggestionCard(
      {required this.recipe, required this.availableNames});

  @override
  Widget build(BuildContext context) {
    final total = recipe.ingredients.length;
    final found = recipe.ingredients
        .where(
            (i) => availableNames.contains(i.ingredientName.toLowerCase()))
        .length;
    final coverage = total > 0 ? (found / total * 100).round() : 100;
    final missing = total - found;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF152019), Color(0xFF1A2E22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF00C896).withAlpha(60), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(recipe.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ),
            _CoverageBadge(percent: coverage),
          ]),
          if (recipe.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(recipe.description,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 10),
          // Chips de info
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _Chip('⏱ ${recipe.durationMinutes} min'),
              _Chip('👥 ${recipe.servings} porciones'),
              if (missing > 0)
                _Chip('🛒 Faltan $missing ingrediente${missing > 1 ? "s" : ""}',
                    highlight: true)
              else
                _Chip('✅ Tienes todo', highlight: true),
            ],
          ),
          // Ingredientes con disponibilidad
          if (recipe.ingredients.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...recipe.ingredients.map((ing) {
              final have =
                  availableNames.contains(ing.ingredientName.toLowerCase());
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(children: [
                  Icon(
                    have ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 14,
                    color: have
                        ? const Color(0xFF66BB6A)
                        : const Color(0xFFFF5252),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${ing.ingredientName} (${ing.quantity} ${ing.unit})',
                    style: TextStyle(
                      color: have ? Colors.white54 : Colors.white30,
                      fontSize: 12,
                      decoration: have ? null : TextDecoration.lineThrough,
                    ),
                  ),
                ]),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _CoverageBadge extends StatelessWidget {
  final int percent;
  const _CoverageBadge({required this.percent});
  @override
  Widget build(BuildContext context) {
    final color = percent == 100
        ? const Color(0xFF66BB6A)
        : percent >= 75
            ? const Color(0xFFFFB74D)
            : const Color(0xFFFF5252);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$percent%',
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool highlight;
  const _Chip(this.label, {this.highlight = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: highlight
              ? const Color(0xFF00C896).withAlpha(30)
              : const Color(0xFF2A2A40),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                color: highlight ? const Color(0xFF00C896) : Colors.white54,
                fontSize: 11)),
      );
}
