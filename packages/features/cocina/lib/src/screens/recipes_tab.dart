import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';
import 'package:core/core.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/cocina_providers.dart';
import 'widgets/recipe_cook_helper.dart';

class RecipesTab extends ConsumerStatefulWidget {
  const RecipesTab({super.key});

  static Future<void> openAddRecipeSheet(
      BuildContext ctx, WidgetRef ref) async {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Theme.of(ctx).appBarTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddRecipeSheet(
        onSave: (r) async {
          await saveRecipeWithDuplicateCheckDialog(ctx, ref, r);
        },
      ),
    );
  }

  static Future<void> saveRecipeWithDuplicateCheckDialog(
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
      final shouldContinue = await showDialog<bool>(
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
          ) ??
          false;

      if (!shouldContinue || !context.mounted) return;
      final forced = await ref
          .read(recipesProvider.notifier)
          .saveRecipeWithDuplicateCheck(recipe, forceSave: true);
      if (!context.mounted) return;
      if (forced.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ "${recipe.name}" guardada (posible duplicado)'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      } else if (forced.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: ${forced.error}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } else if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${recipe.name}" guardada ✓'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    } else if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: ${result.error}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  ConsumerState<RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends ConsumerState<RecipesTab> with AppFeedback {
  MealType? _selectedCategory;
  NutritionGoal? _selectedGoal;
  String _searchQuery = '';
  bool _autoCategorizing = false;
  final TextEditingController _searchCtrl = TextEditingController();

  bool _needsCategorization(Recipe r) =>
      r.tipoComida == null ||
      r.tipoComida == MealType.otro ||
      r.tipoComida == MealType.almuerzo ||
      r.tipoComida == MealType.cena;

  Future<void> _autoCategorizeWithGemini(List<Recipe> candidates) async {
    if (_autoCategorizing || candidates.isEmpty) return;
    setState(() => _autoCategorizing = true);
    try {
      final gemini = ref.read(geminiProvider);
      final mapping = await gemini.categorizeRecipesDetailedWithGemini(
        candidates
            .map((r) => (
                  id: r.id,
                  name: r.name,
                  ingredients:
                      r.ingredients.map((i) => i.ingredientName).toList(),
                  description: r.description,
                ))
            .toList(),
      );

      if (mapping.isEmpty) {
        if (mounted) {
          showError(context,
              'No se pudo categorizar automáticamente. Verifica tu conexión.');
        }
        return;
      }

      final notifier = ref.read(recipesProvider.notifier);
      int updated = 0;
      for (final recipe in candidates) {
        final info = mapping[recipe.id];
        if (info == null) continue;
        final parsedType = info.mealType != null
            ? ExtractRecipeUseCase.parseMealType(info.mealType!)
            : null;
        final parsedGoal = ExtractRecipeUseCase.parseNutritionGoal(info.goal);
        final nextType = parsedType ?? recipe.tipoComida;
        final nextGoal = parsedGoal ?? recipe.goal;
        final nextKcal = info.calories ?? recipe.caloriasAproximadas;

        if (nextType != recipe.tipoComida ||
            nextGoal != recipe.goal ||
            nextKcal != recipe.caloriasAproximadas) {
          await notifier.saveRecipe(recipe.copyWith(
            tipoComida: nextType,
            goal: nextGoal,
            caloriasAproximadas: nextKcal,
          ));
          updated++;
        }
      }

      if (mounted) {
        showSuccess(context,
            '✨ $updated receta(s) categorizadas automáticamente con IA');
      }
    } catch (e) {
      if (mounted) {
        showError(context, 'Error al categorizar con IA: $e');
      }
    } finally {
      if (mounted) setState(() => _autoCategorizing = false);
    }
  }

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
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book_outlined,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.18)),
                    const SizedBox(height: 12),
                    Text('Sin recetas guardadas',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.45),
                            fontSize: 17)),
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
                      icon:
                          const Icon(Icons.menu_book, color: Color(0xFFFF9800)),
                      label: const Text('📚 Explorar 315 recetas locales',
                          style: TextStyle(color: Color(0xFFFF9800))),
                    ),
                  ],
                ),
              ),
            ),
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
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Buscar recetas...',
                hintStyle: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45)),
                prefixIcon: Icon(Icons.search,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.55)),
                        onPressed: () {
                          setState(() {
                            _searchCtrl.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
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
                // Recipe category chips (exclude generic meal periods: almuerzo, cena, otro)
                ...MealType.values
                    .where((t) =>
                        t != MealType.otro &&
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
          // Meta nutricional filter chips (dieta / normal / ganar músculo / ligera)
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              children: [
                _CategoryChip(
                  label: '🎯 Todas metas',
                  isSelected: _selectedGoal == null,
                  onTap: () => setState(() => _selectedGoal = null),
                ),
                const SizedBox(width: 6),
                for (final goal in const [
                  NutritionGoal.maintain,
                  NutritionGoal.loseWeight,
                  NutritionGoal.gainMuscle,
                  NutritionGoal.light,
                  NutritionGoal.other,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _CategoryChip(
                      label: '${goal.emoji} ${goal.label}',
                      isSelected: _selectedGoal == goal,
                      onTap: () => setState(() => _selectedGoal = goal),
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
          // Auto-categorize banner for uncategorized / generic recipes
          Builder(
            builder: (context) {
              final uncategorized =
                  state.recipes.where(_needsCategorization).toList();
              if (uncategorized.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _autoCategorizing
                        ? null
                        : () => _autoCategorizeWithGemini(uncategorized),
                    icon: _autoCategorizing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome,
                            size: 16, color: Color(0xFF00C896)),
                    label: Text(
                      _autoCategorizing
                          ? 'Categorizando con Gemini...'
                          : '✨ Auto-categorizar ${uncategorized.length} receta(s) con IA',
                      style: const TextStyle(
                          color: Color(0xFF00C896), fontSize: 12.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      side:
                          const BorderSide(color: Color(0xFF00C896), width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              );
            },
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

    // Filter by nutrition goal
    if (_selectedGoal != null) {
      filtered = filtered.where((r) => r.goal == _selectedGoal).toList();
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
            Icon(Icons.filter_list_off,
                size: 48,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.28)),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty ||
                      _selectedCategory != null ||
                      _selectedGoal != null
                  ? 'No se encontraron recetas con estos filtros'
                  : 'Sin recetas guardadas',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45),
                  fontSize: 14),
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

  Future<void> _showAddRecipeSheet(BuildContext ctx, WidgetRef ref) =>
      RecipesTab.openAddRecipeSheet(ctx, ref);

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
          BuildContext context, WidgetRef ref, Recipe recipe) =>
      RecipesTab.saveRecipeWithDuplicateCheckDialog(context, ref, recipe);

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
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            child:
                Text(recipe.goal.emoji, style: const TextStyle(fontSize: 22)),
          ),
          title: Text(recipe.name,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (typeLabel != null)
                    Text(typeLabel,
                        style: const TextStyle(
                            color: Color(0xFFFF9800),
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C896).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${recipe.goal.emoji} ${recipe.goal.label}',
                      style: const TextStyle(
                        color: Color(0xFF00C896),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${RecipeTimeBreakdown.summaryLabel(recipe)} · ${recipe.servings} porciones · ${recipe.ingredients.length} ingredientes',
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
                child: Text(RecipeTimeBreakdown.compactChip(recipe),
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
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.35),
                    size: 20),
                onPressed: onFavorite,
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.35),
                    size: 20),
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

class _RecipeDetailSheet extends ConsumerStatefulWidget {
  final Recipe recipe;
  const _RecipeDetailSheet({required this.recipe});

  @override
  ConsumerState<_RecipeDetailSheet> createState() => _RecipeDetailSheetState();
}

class _RecipeDetailSheetState extends ConsumerState<_RecipeDetailSheet> {
  int _scaledServings = 1; // Current scaled servings (default 1 person)
  Map<String, AdaptedSubstitute> _adaptedSubstitutes = const {};
  Map<int, double> _quantityOverrides = const {};

  int get _baseServings =>
      widget.recipe.servings > 0 ? widget.recipe.servings : 1;

  @override
  void initState() {
    super.initState();
    _scaledServings = _baseServings;
  }

  @override
  Widget build(BuildContext context) {
    final liveRecipe = ref.watch(
          recipesProvider.select(
            (s) => s.recipes.where((r) => r.id == widget.recipe.id).firstOrNull,
          ),
        ) ??
        widget.recipe;
    final isScaled = _scaledServings != _baseServings;
    final maxServings = (_baseServings * 2).clamp(2, 24);

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
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.24),
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
                Text('${widget.recipe.servings} orig',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.45),
                        fontSize: 11)),
              ],
            ),
          ),
          Slider(
            min: 1,
            max: maxServings.toDouble(),
            divisions: maxServings - 1,
            value: _scaledServings.clamp(1, maxServings).toDouble(),
            activeColor: const Color(0xFFFF9800),
            inactiveColor:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.14),
            onChanged: (v) => setState(() => _scaledServings = v.toInt()),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            Builder(
              builder: (context) {
                final tb = RecipeTimeBreakdown.extract(widget.recipe);
                if (tb.chillMinutes != null && tb.chillMinutes! > 0) {
                  final active = tb.activeMinutes ??
                      (widget.recipe.durationMinutes > tb.chillMinutes!
                          ? widget.recipe.durationMinutes - tb.chillMinutes!
                          : widget.recipe.durationMinutes);
                  return Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _chip(context,
                          '⏱ ${RecipeTimeBreakdown.formatMinutes(active)} activo'),
                      _chip(context,
                          '❄️ ${RecipeTimeBreakdown.formatMinutes(tb.chillMinutes!)} refri'),
                    ],
                  );
                }
                return _chip(context,
                    '⏱ ${RecipeTimeBreakdown.formatMinutes(widget.recipe.durationMinutes)}');
              },
            ),
            _chip(
                context, '🍳 ${widget.recipe.ingredients.length} ingredientes'),
            if (isScaled)
              _chip(context,
                  '📏 x${(_scaledServings / _baseServings).toStringAsFixed(1)}'),
          ]),
          if (widget.recipe.ingredients.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Text('INGREDIENTES',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.45),
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
            RecipeIngredientCheckList(
              scaledIngredients:
                  scaleRecipeIngredients(liveRecipe, _scaledServings),
              isScaled: isScaled,
              recipeName: liveRecipe.name,
              recipe: liveRecipe,
              scaleRatio: _scaledServings / _baseServings,
              onSubstitutesChanged: (subs) => _adaptedSubstitutes = subs,
              onQuantityOverridesChanged: (ov) => _quantityOverrides = ov,
            ),
          ],
          if (widget.recipe.instructions.isNotEmpty) ...[
            const SizedBox(height: 20),
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
          // Fuente/Origen
          if (widget.recipe.fuenteUrl != null ||
              widget.recipe.fuenteLabel != null) ...[
            const SizedBox(height: 20),
            Divider(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.16)),
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
    final liveRecipe = ref
            .read(recipesProvider)
            .recipes
            .where((r) => r.id == recipe.id)
            .firstOrNull ??
        recipe;
    await confirmAndCookRecipe(
      context: context,
      recipe: liveRecipe,
      scaledServings: scaledServings,
      popSheetOnSuccess: true,
      adaptedSubstitutes: _adaptedSubstitutes,
      quantityOverrides: _quantityOverrides,
    );
  }

  Widget _chip(BuildContext context, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _durCtrl.dispose();
    _srvCtrl.dispose();
    for (final ing in _ingredients) {
      ing.nameCtrl.dispose();
      ing.qtyCtrl.dispose();
    }
    for (final inst in _instructions) {
      inst.dispose();
    }
    super.dispose();
  }

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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(2)))),
            Text('Nueva receta',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
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
              items: [
                NutritionGoal.maintain,
                NutritionGoal.loseWeight,
                NutritionGoal.gainMuscle,
                NutritionGoal.light,
                NutritionGoal.other,
              ]
                  .map(
                    (g) => DropdownMenuItem(
                      value: g,
                      child: Text('${g.emoji} ${g.label}',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _goal = v!),
            ),

            // ── Sección Ingredientes ────────────────────────────────────────
            const SizedBox(height: 16),
            Row(children: [
              const Icon(Icons.restaurant_outlined,
                  color: Color(0xFF00C896), size: 18),
              const SizedBox(width: 8),
              Text('Ingredientes',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Agrega ingredientes para mejorar las sugerencias',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.38),
                        fontSize: 12)),
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
              Text('Instrucciones',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Opcional: añade los pasos de preparación',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.38),
                        fontSize: 12)),
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
                        hintStyle: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.38)),
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
        prefixIcon: Icon(icon,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
            size: 18),
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
              hintStyle: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.38)),
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
              hintStyle: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.38)),
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
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.close,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.35),
                size: 16),
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
    if (!mounted) return;
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
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '📚 Explorar recetas locales',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_allRecipes.length} recetas disponibles',
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                      fontSize: 12),
                ),
              ],
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, descripcion o ingrediente...',
                hintStyle: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45),
                    fontSize: 12),
                prefixIcon: Icon(Icons.search,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.55)),
                        onPressed: () {
                          setState(() {
                            _searchCtrl.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
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
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                      fontSize: 12),
                ),
              ],
            ),
          ),
          // Recipe list
          Expanded(
            child: sortedGroupNames.isEmpty
                ? Center(
                    child: Text(
                      'No se encontraron recetas',
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.45),
                          fontSize: 14),
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
    'Desayuno': '🌅',
    'Almuerzo': '🍛',
    'Cena': '🌙',
    'Entrada': '🥗',
    'Sopa': '🍲',
    'Seco': '🥘',
    'Postre': '🍰',
    'Mazamorra': '🍮',
    'Bebida': '🥤',
    'Snack': '🍿',
    'Jugo': '🧃',
    'Otro': '🍽️',
    'Otras': '🍽️',
  };

  Future<void> _handleSave(Recipe recipe) async {
    setState(() {
      _savingIds.add(recipe.id);
    });
    try {
      await widget.onSave(recipe);
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

    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ExpansionTile(
        initiallyExpanded: widget.isExpanded,
        onExpansionChanged: (_) => widget.onToggle(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Text(emoji, style: const TextStyle(fontSize: 20)),
        title: Text(
          '${widget.groupName} (${widget.recipes.length})',
          style: TextStyle(
            color: onSurface,
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
              style: TextStyle(color: onSurface, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${recipe.durationMinutes} min · ${recipe.ingredients.length} ingredientes',
              style: TextStyle(
                  color: onSurface.withValues(alpha: 0.6), fontSize: 11),
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
