import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';
import 'package:core/core.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/cocina_providers.dart';
import '../providers/cooking_session_provider.dart';
import '../utils/cooking_history_service.dart';

class RecipesTab extends ConsumerStatefulWidget {
  const RecipesTab({super.key});

  @override
  ConsumerState<RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends ConsumerState<RecipesTab> with AppFeedback {
  MealType? _selectedCategory;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recipesProvider);

    if (state.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00C896)));
    }

    // Sort recipes: by rating (desc), then by name
    final sortedRecipes = List<Recipe>.from(state.recipes);
    sortedRecipes.sort((a, b) {
      final ratingA = a.rating ?? 0;
      final ratingB = b.rating ?? 0;
      if (ratingB != ratingA) return ratingB.compareTo(ratingA);
      return a.name.compareTo(b.name);
    });

    if (sortedRecipes.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await ref.read(recipesProvider.notifier).load();
        },
        color: const Color(0xFF00C896),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book_outlined,
                  size: 64, color: Colors.white12),
              const SizedBox(height: 12),
              const Text('Sin recetas guardadas',
                  style: TextStyle(color: Colors.white38, fontSize: 17)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _showAddRecipeSheet(context, ref),
                icon: const Icon(Icons.add, color: Color(0xFF00C896)),
                label: const Text('Agregar receta',
                    style: TextStyle(color: Color(0xFF00C896))),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => _showLocalRecipesSheet(context, ref),
                icon: const Icon(Icons.menu_book, color: Color(0xFFFF9800)),
                label: const Text('📚 Explorar 315 recetas locales',
                    style: TextStyle(color: Color(0xFFFF9800))),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(recipesProvider.notifier).load();
      },
      color: const Color(0xFF00C896),
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar recetas...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          setState(() {
                            _searchCtrl.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF2A2A40),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          // Category filter chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                // "All" chip
                _CategoryChip(
                  label: 'Todas',
                  isSelected: _selectedCategory == null,
                  onTap: () => setState(() => _selectedCategory = null),
                ),
                const SizedBox(width: 6),
                // Recipe category chips (exclude meal periods: desayuno, almuerzo, cena)
                ...MealType.values
                    .where((t) =>
                        t != MealType.otro &&
                        t != MealType.desayuno &&
                        t != MealType.almuerzo &&
                        t != MealType.cena)
                    .map(
                      (type) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _CategoryChip(
                          label: '${type.emoji} ${type.label}',
                          isSelected: _selectedCategory == type,
                          onTap: () => setState(() => _selectedCategory = type),
                        ),
                      ),
                    ),
              ],
            ),
          ),
          // Explore local recipes button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showLocalRecipesSheet(context, ref),
                icon: const Icon(Icons.menu_book,
                    size: 18, color: Color(0xFFFF9800)),
                label: const Text(
                  '📚 Explorar 315 recetas locales',
                  style: TextStyle(color: Color(0xFFFF9800), fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFF9800), width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
          // Recipe list
          Expanded(
            child: _buildFilteredList(state, sortedRecipes),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredList(RecipesState state, List<Recipe> sortedRecipes) {
    var filtered = sortedRecipes;

    // Filter by category
    if (_selectedCategory != null) {
      filtered =
          filtered.where((r) => r.tipoComida == _selectedCategory).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((r) =>
              r.name.toLowerCase().contains(_searchQuery) ||
              r.description.toLowerCase().contains(_searchQuery) ||
              r.tags.any((t) => t.toLowerCase().contains(_searchQuery)))
          .toList();
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list_off, size: 48, color: Colors.white24),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _selectedCategory != null
                  ? 'No se encontraron recetas con estos filtros'
                  : 'Sin recetas guardadas',
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final recipe = filtered[i];
        return _RecipeTile(
          recipe: recipe,
          onFavorite: () {
            ref.read(recipesProvider.notifier).toggleFavorite(recipe.id);
            final label = recipe.isFavorite ? 'quitado de' : 'añadido a';
            showInfo(context, '"${recipe.name}" $label favoritos');
          },
          onDelete: () => _confirmDelete(context, ref, recipe),
          onTap: () => _showRecipeDetail(context, recipe),
        );
      },
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Recipe recipe) async {
    final confirmed = await showConfirmDelete(context,
        itemName: recipe.name,
        subtitle:
            '${recipe.durationMinutes} min · ${recipe.ingredients.length} ingredientes');
    if (!confirmed) return;
    if (!context.mounted) return;
    await ref.read(recipesProvider.notifier).deleteRecipe(recipe.id);
    if (context.mounted) showSuccess(context, '"${recipe.name}" eliminada.');
  }

  Future<void> _showAddRecipeSheet(BuildContext ctx, WidgetRef ref) async {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Theme.of(ctx).appBarTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddRecipeSheet(
        onSave: (r) async {
          await _saveRecipeWithDuplicateCheck(ctx, ref, r);
        },
      ),
    );
  }

  Future<void> _showLocalRecipesSheet(BuildContext ctx, WidgetRef ref) async {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Theme.of(ctx).appBarTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _LocalRecipesSheet(
        onSave: (r) async {
          await _saveRecipeWithDuplicateCheck(ctx, ref, r);
        },
      ),
    );
  }

  Future<void> _saveRecipeWithDuplicateCheck(
      BuildContext context, WidgetRef ref, Recipe recipe) async {
    final result = await ref
        .read(recipesProvider.notifier)
        .saveRecipeWithDuplicateCheck(recipe);

    if (!context.mounted) return;

    if (result.hasDuplicates) {
      final dupNames = result.duplicates
          .map((d) =>
              '${d.recipe.name} (${(d.similarityScore * 100).round()}% similar)')
          .join('\n');
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('⚠️ Posible duplicado'),
          content: Text(
            'Esta receta es similar a:\n\n$dupNames\n\n¿Deseas guardarla de todos modos?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar igual'),
            ),
          ],
        ),
      );

      if (!context.mounted) return;
      showSuccess(context, '⚠️ "${recipe.name}" guardada (posible duplicado)');
    } else if (result.success) {
      if (!context.mounted) return;
      showSuccess(context, '"${recipe.name}" guardada ✓');
    } else if (result.error != null) {
      if (!context.mounted) return;
      showError(context, 'Error al guardar: ${result.error}');
    }
  }

  void _showRecipeDetail(BuildContext ctx, Recipe recipe) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Theme.of(ctx).appBarTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RecipeDetailSheet(recipe: recipe),
    );
  }
}

// ── Tile de receta ───────────────────────────────────────────────────────────

class _RecipeTile extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _RecipeTile({
    required this.recipe,
    required this.onFavorite,
    required this.onDelete,
    required this.onTap,
  });

  static const _goalEmoji = {
    NutritionGoal.loseWeight: '🥗',
    NutritionGoal.maintain: '⚖️',
    NutritionGoal.gainMuscle: '💪',
    NutritionGoal.other: '🍽️',
  };

  Color _getTimeColor(int minutes) {
    if (minutes < 20) return const Color(0xFF00E676);
    if (minutes <= 45) return const Color(0xFFFFB300);
    return const Color(0xFFFF5252);
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = recipe.tipoComida != null
        ? '${recipe.tipoComida!.emoji} ${recipe.tipoComida!.label}'
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14)),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF2A2A40),
            child: Text(_goalEmoji[recipe.goal] ?? '🍽️',
                style: const TextStyle(fontSize: 22)),
          ),
          title: Text(recipe.name,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (typeLabel != null)
                Text(typeLabel,
                    style: const TextStyle(
                        color: Color(0xFFFF9800),
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(
                '${recipe.durationMinutes} min · ${recipe.servings} porciones · ${recipe.ingredients.length} ingredientes',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.38),
                    fontSize: 12),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: _getTimeColor(recipe.durationMinutes).withAlpha(30),
                    borderRadius: BorderRadius.circular(6)),
                child: Text('${recipe.durationMinutes}m',
                    style: TextStyle(
                        color: _getTimeColor(recipe.durationMinutes),
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                    recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: recipe.isFavorite
                        ? const Color(0xFFFF4D4D)
                        : Colors.white24,
                    size: 20),
                onPressed: onFavorite,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.white24, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Detalle de receta ────────────────────────────────────────────────────────

class _RecipeDetailSheet extends StatefulWidget {
  final Recipe recipe;
  const _RecipeDetailSheet({required this.recipe});

  @override
  State<_RecipeDetailSheet> createState() => _RecipeDetailSheetState();
}

class _RecipeDetailSheetState extends State<_RecipeDetailSheet> {
  int _scaledServings = 1; // Current scaled servings (default 1 person)

  @override
  void initState() {
    super.initState();
    _scaledServings = widget.recipe.servings;
  }

  /// Get scaled quantity for an ingredient
  double _getScaledQuantity(double originalQuantity) {
    final scale = _scaledServings / widget.recipe.servings;
    final result = originalQuantity * scale;
    return (result * 100).round() / 100; // Round to 2 decimal places
  }

  @override
  Widget build(BuildContext context) {
    final isScaled = _scaledServings != widget.recipe.servings;
    final maxServings = widget.recipe.servings * 2;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(24),
        children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)))),
          Text(widget.recipe.name,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          if (widget.recipe.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(widget.recipe.description,
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.54),
                    fontSize: 14)),
          ],
          const SizedBox(height: 14),
          // Porciones Slider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.people, size: 16, color: Colors.white54),
                const SizedBox(width: 8),
                Text('Porciones: $_scaledServings',
                    style: TextStyle(
                        color:
                            isScaled ? const Color(0xFFFF9800) : Colors.white54,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${widget.recipe.servings} orig',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Slider(
            min: 1,
            max: maxServings.toDouble(),
            divisions: maxServings - 1,
            value: _scaledServings.toDouble(),
            activeColor: const Color(0xFFFF9800),
            inactiveColor: Colors.white12,
            onChanged: (v) => setState(() => _scaledServings = v.toInt()),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            _chip(context, '⏱ ${widget.recipe.durationMinutes} min'),
            _chip(
                context, '🍳 ${widget.recipe.ingredients.length} ingredientes'),
            if (isScaled)
              _chip(context,
                  '📏 x${(_scaledServings / widget.recipe.servings).toStringAsFixed(1)}'),
          ]),
          if (widget.recipe.ingredients.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('INGREDIENTES',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5)),
                if (isScaled) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Escalado a $_scaledServings persona${_scaledServings == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
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
                      '${_getScaledQuantity(ing.quantity)} ${ing.unit}',
                      style: TextStyle(
                          color: isScaled
                              ? const Color(0xFFFF9800)
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.38),
                          fontSize: 12,
                          fontWeight:
                              isScaled ? FontWeight.w700 : FontWeight.w400),
                    ),
                  ]),
                )),
          ],
          if (widget.recipe.instructions.isNotEmpty) ...[
            const SizedBox(height: 20),
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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                    fontSize: 14))),
                      ]),
                )),
          ],
          // Botón Cocinar
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  _cookRecipe(context, widget.recipe, _scaledServings),
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
                color: Colors.white54,
                fontSize: 11,
                fontStyle: FontStyle.italic),
          ),
          // Fuente/Origen
          if (widget.recipe.fuenteUrl != null ||
              widget.recipe.fuenteLabel != null) ...[
            const SizedBox(height: 20),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.link, color: Color(0xFF00F0FF), size: 16),
                const SizedBox(width: 6),
                Text(
                  'Fuente: ${widget.recipe.fuenteLabel ?? 'Desconocida'}',
                  style: const TextStyle(
                      color: Color(0xFF00F0FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ],
            ),
            if (widget.recipe.fuenteUrl != null) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: () async {
                  final url = Uri.parse(widget.recipe.fuenteUrl!);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                child: Text(
                  widget.recipe.fuenteUrl!,
                  style: const TextStyle(
                      color: Color(0xFF00F0FF),
                      fontSize: 12,
                      decoration: TextDecoration.underline),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _cookRecipe(
      BuildContext context, Recipe recipe, int scaledServings) async {
    // Start cooking session with scaled servings
    final container = ProviderScope.containerOf(context);
    container.read(cookingSessionProvider.notifier).startSession(
          recipeName: recipe.name,
          recipeId: recipe.id,
          originalServings: recipe.servings,
          scaledServings: scaledServings,
          estimatedDurationMinutes: recipe.durationMinutes,
        );

    // Deduct ingredients with scaling
    final scaleRatio = scaledServings / recipe.servings;
    final scaledIngredients = recipe.ingredients.map((ing) {
      return RecipeIngredient(
        id: ing.id,
        recipeId: ing.recipeId,
        ingredientName: ing.ingredientName,
        quantity: ing.quantity * scaleRatio,
        unit: ing.unit,
      );
    }).toList();

    final inventoryNotifier = container.read(inventoryProvider.notifier);
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
    } else {
      // Record in cooking history
      await CookingHistoryService().recordCooked(recipe.name);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '🍳 ¡Cocinando "${recipe.name}" para $scaledServings persona${scaledServings == 1 ? '' : 's'}!'),
              const SizedBox(height: 4),
              Text(
                'Descontados: ${deducted.join(", ")}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFFF9800),
          duration: const Duration(milliseconds: 1000),
          action: SnackBarAction(
            label: 'Deshacer',
            textColor: Colors.white,
            onPressed: () async {
              await inventoryNotifier.revertDeduction(recipe.ingredients);
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
    }
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  Widget _chip(BuildContext context, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: const Color(0xFF2A2A40),
            borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.54),
                fontSize: 12)),
      );
}

// ── Formulario de receta con ingredientes ────────────────────────────────────

class _AddRecipeSheet extends StatefulWidget {
  final Future<void> Function(Recipe) onSave;
  const _AddRecipeSheet({required this.onSave});
  @override
  State<_AddRecipeSheet> createState() => _AddRecipeSheetState();
}

class _AddRecipeSheetState extends State<_AddRecipeSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _durCtrl = TextEditingController(text: '30');
  final _srvCtrl = TextEditingController(text: '2');
  NutritionGoal _goal = NutritionGoal.maintain;
  String? _nameError;
  String? _durError;
  bool _saving = false;

  // Ingredientes dinámicos
  final List<_IngEntry> _ingredients = [];
  // Instrucciones dinámicas
  final List<TextEditingController> _instructions = [];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: ListView(
          controller: controller,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)))),
            const Text('Nueva receta',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            _field(_nameCtrl, 'Nombre de la receta', Icons.edit_outlined,
                errorText: _nameError,
                onChanged: (_) => setState(() => _nameError = null)),
            const SizedBox(height: 8),
            _field(_descCtrl, 'Descripción (opcional)', Icons.notes_outlined),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _field(_durCtrl, 'Minutos', Icons.timer_outlined,
                      keyboardType: TextInputType.number,
                      errorText: _durError,
                      onChanged: (_) => setState(() => _durError = null))),
              const SizedBox(width: 8),
              Expanded(
                  child: _field(_srvCtrl, 'Porciones', Icons.people_outline,
                      keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 8),
            DropdownButtonFormField<NutritionGoal>(
              initialValue: _goal,
              dropdownColor: Theme.of(context).cardColor,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: _deco('Objetivo nutricional', Icons.flag_outlined),
              items: const [
                DropdownMenuItem(
                    value: NutritionGoal.loseWeight,
                    child: Text('🥗 Adelgazar',
                        style: TextStyle(color: Colors.white))),
                DropdownMenuItem(
                    value: NutritionGoal.maintain,
                    child: Text('⚖️ Mantener',
                        style: TextStyle(color: Colors.white))),
                DropdownMenuItem(
                    value: NutritionGoal.gainMuscle,
                    child: Text('💪 Ganar músculo',
                        style: TextStyle(color: Colors.white))),
                DropdownMenuItem(
                    value: NutritionGoal.other,
                    child: Text('🍽️ Otro',
                        style: TextStyle(color: Colors.white))),
              ],
              onChanged: (v) => setState(() => _goal = v!),
            ),

            // ── Sección Ingredientes ────────────────────────────────────────
            const SizedBox(height: 16),
            Row(children: [
              const Icon(Icons.restaurant_outlined,
                  color: Color(0xFF00C896), size: 18),
              const SizedBox(width: 8),
              const Text('Ingredientes',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: _addIngredient,
                icon: const Icon(Icons.add, size: 16, color: Color(0xFF00C896)),
                label: const Text('Agregar',
                    style: TextStyle(color: Color(0xFF00C896), fontSize: 12)),
              ),
            ]),
            if (_ingredients.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Agrega ingredientes para mejorar las sugerencias',
                    style: TextStyle(color: Colors.white24, fontSize: 12)),
              ),
            ..._ingredients.asMap().entries.map((e) => _IngredientRow(
                  entry: e.value,
                  onRemove: () => setState(() => _ingredients.removeAt(e.key)),
                )),

            // ── Sección Instrucciones ───────────────────────────────────────
            const SizedBox(height: 16),
            Row(children: [
              const Icon(Icons.format_list_numbered,
                  color: Color(0xFF00C896), size: 18),
              const SizedBox(width: 8),
              const Text('Instrucciones',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _instructions.add(TextEditingController())),
                icon: const Icon(Icons.add, size: 16, color: Color(0xFF00C896)),
                label: const Text('Agregar',
                    style: TextStyle(color: Color(0xFF00C896), fontSize: 12)),
              ),
            ]),
            if (_instructions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Opcional: añade los pasos de preparación',
                    style: TextStyle(color: Colors.white24, fontSize: 12)),
              ),
            ..._instructions.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
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
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                      controller: e.value,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Paso ${e.key + 1}...',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                    )),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _instructions.removeAt(e.key)),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child:
                            Icon(Icons.close, color: Colors.white24, size: 16),
                      ),
                    ),
                  ]),
                )),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C896),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Guardar receta',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(_IngEntry(
        nameCtrl: TextEditingController(),
        qtyCtrl: TextEditingController(text: '1'),
        unit: 'unidad',
      ));
    });
  }

  Future<void> _save() async {
    final nameVal = Validator.recipeName(_nameCtrl.text);
    final durVal = Validator.recipeDuration(int.tryParse(_durCtrl.text));
    final combined = Validator.combine([nameVal, durVal]);

    if (!combined.isValid) {
      setState(() {
        _nameError = nameVal.errorMessage;
        _durError = durVal.errorMessage;
      });
      return;
    }

    // Build ingredient list
    final uuid = const Uuid();
    final ings = _ingredients
        .where((e) => e.nameCtrl.text.trim().isNotEmpty)
        .map((e) => RecipeIngredient(
              id: uuid.v4(),
              recipeId: '',
              ingredientName: e.nameCtrl.text.trim(),
              quantity: double.tryParse(e.qtyCtrl.text) ?? 1,
              unit: e.unit,
            ))
        .toList();

    // Build instructions list
    final steps = _instructions
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() => _saving = true);
    try {
      await widget.onSave(Recipe(
        id: '',
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        durationMinutes: int.tryParse(_durCtrl.text) ?? 30,
        servings: int.tryParse(_srvCtrl.text) ?? 2,
        goal: _goal,
        ingredients: ings,
        instructions: steps,
        createdAt: DateTime.now(),
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al guardar: $e'),
              backgroundColor: const Color(0xFFFF5252)),
        );
      }
    }
  }

  Widget _field(
    TextEditingController c,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? errorText,
    void Function(String)? onChanged,
  }) =>
      TextField(
        controller: c,
        keyboardType: keyboardType,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        onChanged: onChanged,
        decoration: _deco(hint, icon).copyWith(
          errorText: errorText,
          errorStyle: const TextStyle(color: Color(0xFFFF5252), fontSize: 11),
        ),
      );

  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.38)),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF00C896), width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.5)),
      );
}

// ── Helpers para ingredientes dinámicos ──────────────────────────────────────

class _IngEntry {
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  String unit;
  _IngEntry(
      {required this.nameCtrl, required this.qtyCtrl, required this.unit});
}

class _IngredientRow extends StatefulWidget {
  final _IngEntry entry;
  final VoidCallback onRemove;
  const _IngredientRow({required this.entry, required this.onRemove});
  @override
  State<_IngredientRow> createState() => _IngredientRowState();
}

class _IngredientRowState extends State<_IngredientRow> {
  static const _units = [
    'unidad',
    'g',
    'kg',
    'ml',
    'L',
    'taza',
    'cda',
    'cdta',
    'pizca'
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        // Nombre
        Expanded(
          flex: 4,
          child: TextField(
            controller: widget.entry.nameCtrl,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Ingrediente',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Cantidad
        Expanded(
          flex: 2,
          child: TextField(
            controller: widget.entry.qtyCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Cant.',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Unidad
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            initialValue: widget.entry.unit,
            dropdownColor: Theme.of(context).cardColor,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface, fontSize: 12),
            decoration: InputDecoration(
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            items: _units
                .map((u) => DropdownMenuItem(
                    value: u,
                    child: Text(u,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 12))))
                .toList(),
            onChanged: (v) => setState(() => widget.entry.unit = v!),
          ),
        ),
        // Eliminar
        GestureDetector(
          onTap: widget.onRemove,
          child: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.close, color: Colors.white24, size: 16),
          ),
        ),
      ]),
    );
  }
}

// ── Category Filter Chip ─────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF9800) : const Color(0xFF2A2A40),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Local Recipes Browser ────────────────────────────────────────────────────

class _LocalRecipesSheet extends StatefulWidget {
  final Future<void> Function(Recipe) onSave;
  const _LocalRecipesSheet({required this.onSave});

  @override
  State<_LocalRecipesSheet> createState() => _LocalRecipesSheetState();
}

class _LocalRecipesSheetState extends State<_LocalRecipesSheet>
    with AppFeedback {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  List<Recipe> _allRecipes = [];
  bool _isLoading = true;
  final Map<String, bool> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    final localDb = LocalRecipeDatabaseService();
    final recipes = await localDb.loadRecipes();
    setState(() {
      _allRecipes = recipes;
      _isLoading = false;
    });
  }

  List<Recipe> _getFilteredRecipes() {
    if (_searchQuery.isEmpty) return _allRecipes;
    return _allRecipes.where((r) {
      return r.name.toLowerCase().contains(_searchQuery) ||
          r.description.toLowerCase().contains(_searchQuery) ||
          r.ingredients.any(
              (i) => i.ingredientName.toLowerCase().contains(_searchQuery));
    }).toList();
  }

  Map<String, List<Recipe>> _groupByType(List<Recipe> recipes) {
    final groups = <String, List<Recipe>>{};
    for (final recipe in recipes) {
      final typeName = recipe.tipoComida?.label ?? 'Otras';
      groups.putIfAbsent(typeName, () => []).add(recipe);
    }
    // Sort each group by name
    for (final key in groups.keys) {
      groups[key]!.sort((a, b) => a.name.compareTo(b.name));
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF00C896)),
        ),
      );
    }

    final filteredRecipes = _getFilteredRecipes();
    final groupedRecipes = _groupByType(filteredRecipes);
    final sortedGroupNames = groupedRecipes.keys.toList()..sort();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '📚 Explorar recetas locales',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_allRecipes.length} recetas disponibles',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, descripcion o ingrediente...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          setState(() {
                            _searchCtrl.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF2A2A40),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          // Recipe count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${filteredRecipes.length} receta${filteredRecipes.length == 1 ? '' : 's'} encontrada${filteredRecipes.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          // Recipe list
          Expanded(
            child: sortedGroupNames.isEmpty
                ? const Center(
                    child: Text(
                      'No se encontraron recetas',
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                    itemCount: sortedGroupNames.length,
                    itemBuilder: (ctx, i) {
                      final groupName = sortedGroupNames[i];
                      final recipes = groupedRecipes[groupName]!;
                      final isExpanded = _expandedGroups[groupName] ?? true;
                      return _RecipeGroupTile(
                        groupName: groupName,
                        recipes: recipes,
                        isExpanded: isExpanded,
                        onToggle: () {
                          setState(() {
                            _expandedGroups[groupName] = !isExpanded;
                          });
                        },
                        onSave: widget.onSave,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecipeGroupTile extends StatefulWidget {
  final String groupName;
  final List<Recipe> recipes;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Future<void> Function(Recipe) onSave;

  const _RecipeGroupTile({
    required this.groupName,
    required this.recipes,
    required this.isExpanded,
    required this.onToggle,
    required this.onSave,
  });

  @override
  State<_RecipeGroupTile> createState() => _RecipeGroupTileState();
}

class _RecipeGroupTileState extends State<_RecipeGroupTile> with AppFeedback {
  final Set<String> _savingIds = {};

  static const Map<String, String> _groupEmojis = {
    'Desayunos': '🌅',
    'Almuerzos': '🍲',
    'Cenas': '🌙',
    'Snacks': '🍿',
    'Postres': '🍰',
    'Bebidas': '🥤',
    'Entradas': '🥗',
    'Sopas': '🍜',
    'Otras': '🍽️',
  };

  Future<void> _handleSave(Recipe recipe) async {
    setState(() {
      _savingIds.add(recipe.id);
    });
    try {
      await widget.onSave(recipe);
      if (mounted) {
        showSuccess(context, '"${recipe.name}" guardada');
      }
    } catch (e) {
      if (mounted) {
        showError(context, 'Error al guardar: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingIds.remove(recipe.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final emoji = _groupEmojis[widget.groupName] ?? '🍽️';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: const Color(0xFF2A2A40),
      child: ExpansionTile(
        initiallyExpanded: widget.isExpanded,
        onExpansionChanged: (_) => widget.onToggle(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Text(emoji, style: const TextStyle(fontSize: 20)),
        title: Text(
          '${widget.groupName} (${widget.recipes.length})',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        children: widget.recipes.map((recipe) {
          final isSaving = _savingIds.contains(recipe.id);
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            dense: true,
            title: Text(
              recipe.name,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${recipe.durationMinutes} min · ${recipe.ingredients.length} ingredientes',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            trailing: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Color(0xFF00C896),
                      strokeWidth: 2,
                    ),
                  )
                : TextButton(
                    onPressed: () => _handleSave(recipe),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Guardar',
                      style: TextStyle(
                        color: Color(0xFF00C896),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          );
        }).toList(),
      ),
    );
  }
}
