import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';
import '../../providers/cocina_providers.dart';
import '../../providers/cooking_session_provider.dart';

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
        return _RecipeDetailContent(recipe: recipe);
      },
    );
  }
}

class _RecipeDetailContent extends StatefulWidget {
  final Recipe recipe;
  const _RecipeDetailContent({required this.recipe});

  @override
  State<_RecipeDetailContent> createState() => _RecipeDetailContentState();
}

class _RecipeDetailContentState extends State<_RecipeDetailContent> {
  int _scaledServings = 1;

  @override
  void initState() {
    super.initState();
    _scaledServings = widget.recipe.servings;
  }

  double _getScaledQuantity(double original) {
    if (widget.recipe.servings == 0) return original;
    return original * (_scaledServings / widget.recipe.servings);
  }

  String _formatQuantity(double value) {
    if (value == value.toInt()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final isScaled = _scaledServings != widget.recipe.servings;
    final maxServings = widget.recipe.servings * 2;

    return ListView(
      controller: PrimaryScrollController.of(context),
      padding: const EdgeInsets.all(16),
      children: [
        Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        Text(widget.recipe.name,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20)),
        if (widget.recipe.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(widget.recipe.description,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
        ],
        const SizedBox(height: 12),
        // Servings controls
        Row(
          children: [
            const Icon(Icons.people, size: 16, color: Colors.white54),
            const SizedBox(width: 8),
            Text('Porciones: $_scaledServings',
                style: TextStyle(
                    color: isScaled ? const Color(0xFFFF9800) : Colors.white54,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              color: _scaledServings > 1
                  ? const Color(0xFFFF9800)
                  : Colors.white24,
              onPressed: _scaledServings > 1
                  ? () => setState(() => _scaledServings--)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              color: _scaledServings < maxServings
                  ? const Color(0xFFFF9800)
                  : Colors.white24,
              onPressed: _scaledServings < maxServings
                  ? () => setState(() => _scaledServings++)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          _chip('⏱ ${widget.recipe.durationMinutes} min'),
          _chip('🍳 ${widget.recipe.ingredients.length} ingredientes'),
          if (isScaled)
            _chip(
                '📏 x${(_scaledServings / widget.recipe.servings).toStringAsFixed(1)}'),
        ]),
        // Ingredients
        if (widget.recipe.ingredients.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('INGREDIENTES',
              style: TextStyle(
                  color: Colors.white38,
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
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  const Spacer(),
                  Text(
                    '${_formatQuantity(_getScaledQuantity(ing.quantity))} ${ing.unit}',
                    style: TextStyle(
                        color:
                            isScaled ? const Color(0xFFFF9800) : Colors.white54,
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
          const Text('INSTRUCCIONES',
              style: TextStyle(
                  color: Colors.white38,
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
                                  color: Colors.white.withValues(alpha: 0.7),
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
        const Text(
          '💡 Al cocinar, se descontarán los ingredientes de tu despensa',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A40),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
    );
  }

  Future<void> _cookRecipe(BuildContext context) async {
    final container = ProviderScope.containerOf(context);
    final inventoryNotifier = container.read(inventoryProvider.notifier);

    container.read(cookingSessionProvider.notifier).startSession(
          recipeName: widget.recipe.name,
          recipeId: widget.recipe.id,
          originalServings: widget.recipe.servings,
          scaledServings: _scaledServings,
          estimatedDurationMinutes: widget.recipe.durationMinutes,
        );

    final deducted = await inventoryNotifier
        .deductRecipeIngredients(widget.recipe.ingredients);

    if (context.mounted) {
      if (deducted.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('⚠️ No tienes ingredientes coincidentes en tu despensa.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
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
            duration: const Duration(milliseconds: 1500),
            action: SnackBarAction(
              label: 'Deshacer',
              textColor: Colors.white,
              onPressed: () async {
                await inventoryNotifier
                    .revertDeduction(widget.recipe.ingredients);
                await inventoryNotifier.load();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('↩️ Deducción revertida'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
          ),
        );
        inventoryNotifier.load();
        Navigator.of(context).pop();
      }
    }
  }
}
