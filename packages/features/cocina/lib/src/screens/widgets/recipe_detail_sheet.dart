import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:domain/domain.dart';
import 'package:go_router/go_router.dart';
import '../../providers/cocina_providers.dart';
import '../../providers/cooking_session_provider.dart';
import '../../utils/cooking_history_service.dart';

/// Shared recipe detail sheet widget used across all tabs.
class RecipeDetailSheet extends StatelessWidget {
  final Recipe recipe;
  const RecipeDetailSheet({required this.recipe, super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return _RecipeDetailContent(
          recipe: recipe,
          scrollController: scrollController,
        );
      },
    );
  }
}

class _RecipeDetailContent extends ConsumerStatefulWidget {
  final Recipe recipe;
  final ScrollController scrollController;
  const _RecipeDetailContent({
    required this.recipe,
    required this.scrollController,
  });

  @override
  ConsumerState<_RecipeDetailContent> createState() =>
      _RecipeDetailContentState();
}

class _RecipeDetailContentState extends ConsumerState<_RecipeDetailContent> {
  int _scaledServings = 1;
  MealType? _tipoComida;

  int get _baseServings => widget.recipe.servings > 0 ? widget.recipe.servings : 1;

  @override
  void initState() {
    super.initState();
    _scaledServings = _baseServings;
    _tipoComida = widget.recipe.tipoComida;
  }

  static const _editableMealTypes = [
    MealType.desayuno,
    MealType.entrada,
    MealType.sopa,
    MealType.seco,
    MealType.postre,
    MealType.mazamorra,
    MealType.bebida,
    MealType.jugo,
    MealType.snack,
  ];

  Future<void> _pickCategory(BuildContext context) async {
    final isSaved = ref
        .read(recipesProvider)
        .recipes
        .any((r) => r.id == widget.recipe.id);
    if (!isSaved) return;

    final chosen = await showModalBottomSheet<MealType>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              title: Text(
                'Cambiar categoría de receta',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final type in _editableMealTypes)
              ListTile(
                leading: Text(type.emoji, style: const TextStyle(fontSize: 20)),
                title: Text(type.label),
                trailing: _tipoComida == type
                    ? const Icon(Icons.check, color: Color(0xFF00C896))
                    : null,
                onTap: () => Navigator.pop(ctx, type),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() => _tipoComida = chosen);
    await ref
        .read(recipesProvider.notifier)
        .saveRecipe(widget.recipe.copyWith(tipoComida: chosen));
  }

  double _getScaledQuantity(double original) {
    return original * (_scaledServings / _baseServings);
  }

  String _formatQuantity(double value) {
    if (value == value.toInt()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final isScaled = _scaledServings != _baseServings;
    final maxServings = (_baseServings * 2).clamp(2, 24);

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        Text(widget.recipe.name,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 20)),
        if (widget.recipe.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(widget.recipe.description,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.65),
                  fontSize: 14)),
        ],
        const SizedBox(height: 12),
        // Servings controls
        Row(
          children: [
            Icon(Icons.people,
                size: 16,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            Text('Porciones: $_scaledServings',
                style: TextStyle(
                    color: isScaled
                        ? const Color(0xFFFF9800)
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              color: _scaledServings > 1
                  ? const Color(0xFFFF9800)
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.24),
              onPressed: _scaledServings > 1
                  ? () => setState(() => _scaledServings--)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              color: _scaledServings < maxServings
                  ? const Color(0xFFFF9800)
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.24),
              onPressed: _scaledServings < maxServings
                  ? () => setState(() => _scaledServings++)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _chip(context, '⏱ ${widget.recipe.durationMinutes} min'),
          _chip(context, '🍳 ${widget.recipe.ingredients.length} ingredientes'),
          GestureDetector(
            onTap: () => _pickCategory(context),
            child: _chip(
              context,
              _tipoComida != null
                  ? '${_tipoComida!.emoji} ${_tipoComida!.label} ▾'
                  : '🏷️ Sin categoría ▾',
            ),
          ),
          if (widget.recipe.cuisineStyle != null &&
              widget.recipe.cuisineStyle!.isNotEmpty)
            _chip(context, '🌍 ${widget.recipe.cuisineStyle!}'),
          if (isScaled)
            _chip(context,
                '📏 x${(_scaledServings / _baseServings).toStringAsFixed(1)}'),
          Builder(
            builder: (context) {
              final catalogState = ref.watch(ingredientPriceCatalogProvider);
              final estimate = IngredientPriceService.estimateList(
                catalog: catalogState.catalog,
                items: widget.recipe.ingredients.map((i) => (
                      name: i.ingredientName,
                      quantity: _getScaledQuantity(i.quantity),
                      unit: i.unit,
                    )),
              );
              if (estimate.pricedCount == 0) {
                return const SizedBox.shrink();
              }
              final perServing = _scaledServings > 0
                  ? estimate.totalEstimated / _scaledServings
                  : estimate.totalEstimated;
              return _chip(
                context,
                '💰 ≈ ${estimate.currency} ${estimate.totalEstimated.toStringAsFixed(2)} (${perServing.toStringAsFixed(2)}/p)',
              );
            },
          ),
        ]),
        // Ingredients
        if (widget.recipe.ingredients.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('INGREDIENTES',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          ...widget.recipe.ingredients.map((ing) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  const Icon(Icons.fiber_manual_record,
                      size: 8, color: Color(0xFF00C896)),
                  const SizedBox(width: 10),
                  Text(ing.ingredientName,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14)),
                  const Spacer(),
                  Text(
                    '${_formatQuantity(_getScaledQuantity(ing.quantity))} ${ing.unit}',
                    style: TextStyle(
                        color: isScaled
                            ? const Color(0xFFFF9800)
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight:
                            isScaled ? FontWeight.w700 : FontWeight.w400),
                  ),
                ]),
              )),
        ],
        // Instructions
        if (widget.recipe.instructions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('INSTRUCCIONES',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          ...widget.recipe.instructions.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: const Color(0xFF00C896).withAlpha(40),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text('${e.key + 1}',
                            style: const TextStyle(
                                color: Color(0xFF00C896),
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(e.value,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.78),
                                  fontSize: 14))),
                    ]),
              )),
        ],
        // Cook button
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _cookRecipe(context),
            icon: const Icon(Icons.whatshot, color: Colors.black),
            label: const Text('🍳 ¡Cocinar esta receta!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '💡 Al cocinar, se descontarán los ingredientes de tu despensa',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
              fontSize: 11,
              fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 12),
        Consumer(
          builder: (context, ref, _) => SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final ingredients = widget.recipe.ingredients
                    .map((i) => i.ingredientName.trim())
                    .where((n) => n.isNotEmpty)
                    .toList();
                ref.read(pendingMealEvaluationProvider.notifier).queue(
                      recipeName: widget.recipe.name,
                      ingredients: ingredients,
                    );
                Navigator.of(context).pop();
                context.go('/foodcoach');
              },
              icon: const Icon(Icons.health_and_safety_outlined,
                  color: Color(0xFF00C896)),
              label: const Text('Evaluar en FoodCoach',
                  style: TextStyle(
                      color: Color(0xFF00C896), fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF00C896)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _chip(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              fontSize: 12)),
    );
  }

  Future<void> _cookRecipe(BuildContext context) async {
    final container = ProviderScope.containerOf(context);
    final inventoryNotifier = container.read(inventoryProvider.notifier);

    final scaleRatio = _scaledServings / _baseServings;
    final scaledIngredients = widget.recipe.ingredients.map((ing) {
      return RecipeIngredient(
        id: ing.id,
        recipeId: ing.recipeId,
        ingredientName: ing.ingredientName,
        quantity: ing.quantity * scaleRatio,
        unit: ing.unit,
      );
    }).toList();

    final deducted =
        await inventoryNotifier.deductRecipeIngredients(scaledIngredients);

    if (!context.mounted) return;
    if (deducted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('⚠️ No tienes ingredientes coincidentes en tu despensa.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    container.read(cookingSessionProvider.notifier).startSession(
          recipeName: widget.recipe.name,
          recipeId: widget.recipe.id,
          originalServings: _baseServings,
          scaledServings: _scaledServings,
          estimatedDurationMinutes: widget.recipe.durationMinutes,
        );
    await CookingHistoryService().recordCooked(widget.recipe.name);

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🍳 ¡Cocinando! Ingredientes descontados:'),
            const SizedBox(height: 4),
            Text(deducted.join(', '), style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: const Color(0xFFFF9800),
        duration: const Duration(milliseconds: 2500),
        action: SnackBarAction(
          label: 'Deshacer',
          textColor: Colors.white,
          onPressed: () async {
            await inventoryNotifier.revertDeduction(scaledIngredients);
            await inventoryNotifier.load();
            messenger.showSnackBar(
              const SnackBar(
                content: Text('↩️ Deducción revertida'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    );
    await inventoryNotifier.load();
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
