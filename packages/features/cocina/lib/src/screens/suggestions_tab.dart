import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';
import '../providers/cocina_providers.dart';
import '../providers/what_can_i_cook_provider.dart';
import '../providers/cooking_session_provider.dart';

/// Tab "Sugeridas" — muestra qué puedes cocinar hoy con lo que tienes.
class SuggestionsTab extends ConsumerStatefulWidget {
  const SuggestionsTab({super.key});

  @override
  ConsumerState<SuggestionsTab> createState() => _SuggestionsTabState();
}

class _SuggestionsTabState extends ConsumerState<SuggestionsTab> {
  static const _goalLabels = {
    NutritionGoal.loseWeight: '🥗 Adelgazar',
    NutritionGoal.maintain: '⚖️ Mantener',
    NutritionGoal.gainMuscle: '💪 Ganar músculo',
    NutritionGoal.other: '🍽️ Otro',
  };

  // Estado para preferencia culinaria
  String _selectedCuisine = 'Todas';

  @override
  void initState() {
    super.initState();
    // Auto-load Chef IA suggestions only if needed (meal period change or first time)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final invState = ref.read(inventoryProvider);
      final aiNotifier = ref.read(whatCanICookProvider.notifier);
      // Only auto-load if we have ingredients and it's needed
      if (invState.ingredients.isNotEmpty && aiNotifier.needsRefresh) {
        aiNotifier.generateSuggestions(
            cuisinePreference:
                _selectedCuisine == 'Todas' ? null : _selectedCuisine);
      }
    });
  }

  // Lista de preferencias culinarias
  final List<String> _cuisines = [
    'Todas',
    'Selvática 🌿',
    'Serrana 🏔️',
    'Costeña 🏖️',
    'Italiana 🇮🇹',
    'Asiática 🥢',
    'Mexicana 🇲🇽',
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recipesProvider);
    final invState = ref.watch(inventoryProvider);
    final aiState = ref.watch(whatCanICookProvider);
    final aiNotifier = ref.read(whatCanICookProvider.notifier);
    final cookingSession = ref.watch(cookingSessionProvider);

    final availableNames =
        invState.ingredients.map((i) => i.name.toLowerCase()).toSet();

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cooking Session Banner
          if (cookingSession != null)
            _CookingSessionBanner(session: cookingSession),
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
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mensaje motivante + Botón IA + Preferencias
                  _buildChefIAHeader(context, aiState, aiNotifier),

                  // Preferencias Culinarias
                  _buildCuisineChips(context),

                  // AI Suggestions Section
                  _buildAISuggestions(context, aiState, aiNotifier),

                  // Divider
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white24)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '📋 Desde tu Despensa',
                            style:
                                TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.white24)),
                      ],
                    ),
                  ),

                  // Pantry Suggestions (Local Matching)
                  _buildPantrySuggestions(
                      context, state, invState, availableNames),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChefIAHeader(BuildContext context, WhatCanICookState aiState,
      WhatCanICookNotifier aiNotifier) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              _greeting(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton.icon(
            onPressed: aiState == WhatCanICookState.loading
                ? null
                : () => aiNotifier.generateSuggestions(
                      cuisinePreference:
                          _selectedCuisine == 'Todas' ? null : _selectedCuisine,
                    ),
            icon: aiState == WhatCanICookState.loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(aiState == WhatCanICookState.loading
                ? 'Pensando...'
                : '✨ Chef IA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCuisineChips(BuildContext context) {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _cuisines.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cuisine = _cuisines[index];
          final isSelected = _selectedCuisine == cuisine;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCuisine = cuisine);
              // Trigger refresh immediately with new preference
              ref.read(whatCanICookProvider.notifier).generateSuggestions(
                    cuisinePreference: cuisine == 'Todas' ? null : cuisine,
                  );
            },
            child: Chip(
              label: Text(
                cuisine,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              backgroundColor: isSelected
                  ? const Color(0xFF00E676)
                  : const Color(0xFF2A2A40),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
          );
        },
      ),
    );
  }

  Widget _buildAISuggestions(BuildContext context, WhatCanICookState aiState,
      WhatCanICookNotifier aiNotifier) {
    if (aiState == WhatCanICookState.loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: Color(0xFFFF9800)),
              SizedBox(height: 16),
              Text(
                'El Chef IA está analizando tu inventario...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (aiState == WhatCanICookState.success &&
        aiNotifier.suggestions.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.restaurant_menu,
                    color: Color(0xFFFF9800), size: 18),
                const SizedBox(width: 4),
                Text(
                  'Sugerencias: ${aiNotifier.currentMealLabel}',
                  style: const TextStyle(
                      color: Color(0xFFFF9800),
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh,
                      size: 18, color: Color(0xFFFF9800)),
                  onPressed: () => aiNotifier.generateSuggestions(
                    cuisinePreference:
                        _selectedCuisine == 'Todas' ? null : _selectedCuisine,
                  ),
                  tooltip: 'Obtener nuevas sugerencias',
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => aiNotifier.reset(),
                  tooltip: 'Cerrar sugerencias',
                ),
              ],
            ),
          ),
          SizedBox(
            height: 380,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: aiNotifier.suggestions.length,
              itemBuilder: (ctx, i) {
                final suggestion = aiNotifier.suggestions[i];
                return _AISuggestionCard(
                  suggestion: suggestion,
                  onTap: () => _showRecipeDetail(context, suggestion.recipe),
                  onSave: () =>
                      _saveAISuggestion(context, ref, aiNotifier, suggestion),
                  onCook: () =>
                      _cookAISuggestion(context, ref, aiNotifier, suggestion),
                );
              },
            ),
          ),
        ],
      );
    }

    if (aiState == WhatCanICookState.error) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                aiNotifier.errorMessage ?? 'Error desconocido',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () => aiNotifier.generateSuggestions(
                cuisinePreference:
                    _selectedCuisine == 'Todas' ? null : _selectedCuisine,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPantrySuggestions(BuildContext context, RecipesState state,
      InventoryState invState, Set<String> availableNames) {
    if (state.suggestions.isEmpty) {
      return _EmptyState(
        hasRecipes: state.recipes.isNotEmpty,
        hasIngredients: invState.ingredients.isNotEmpty,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.suggestions.length,
      itemBuilder: (ctx, i) {
        final r = state.suggestions[i];
        return _SuggestionCard(
          recipe: r,
          availableNames: availableNames,
          onTap: () => _showRecipeDetail(context, r),
          onCook: () => _cookRecipe(context, ref, r),
        );
      },
    );
  }

  void _showRecipeDetail(BuildContext context, Recipe recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RecipeDetailSheet(recipe: recipe),
    );
  }

  Future<void> _cookRecipe(
    BuildContext context,
    WidgetRef ref,
    Recipe recipe,
  ) async {
    // Start cooking session
    ref.read(cookingSessionProvider.notifier).startSession(
          recipeName: recipe.name,
          recipeId: recipe.id,
          originalServings: recipe.servings,
          scaledServings: 1,
        );

    final inventoryNotifier = ref.read(inventoryProvider.notifier);
    final deducted =
        await inventoryNotifier.deductRecipeIngredients(recipe.ingredients);

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
                Text(
                  deducted.join(', '),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFF9800),
            duration: const Duration(seconds: 3),
          ),
        );
        // Reload inventory
        inventoryNotifier.load();
      }
    }
  }

  Future<void> _saveAISuggestion(
    BuildContext context,
    WidgetRef ref,
    WhatCanICookNotifier notifier,
    RecipeSuggestion suggestion,
  ) async {
    final saved = await notifier.saveSuggestion(suggestion);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved
              ? '✅ "${suggestion.recipe.name}" guardada en tu recetario'
              : '❌ Error al guardar la receta'),
          backgroundColor: saved ? const Color(0xFF00E676) : Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      // Reload recipes if saved
      if (saved) {
        ref.read(recipesProvider.notifier).load();
      }
    }
  }

  Future<void> _cookAISuggestion(
    BuildContext context,
    WidgetRef ref,
    WhatCanICookNotifier notifier,
    RecipeSuggestion suggestion,
  ) async {
    // Start cooking session
    ref.read(cookingSessionProvider.notifier).startSession(
          recipeName: suggestion.recipe.name,
          recipeId: suggestion.recipe.id,
          originalServings: suggestion.recipe.servings,
          scaledServings: 1,
        );

    final result = await notifier.cookSuggestion(suggestion);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.success ? '🍳 ¡Cocinando!' : '⚠️ Advertencia'),
              if (result.deducted.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Descontados: ${result.deducted.join(", ")}',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ],
          ),
          backgroundColor:
              result.success ? const Color(0xFFFF9800) : Colors.redAccent,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
      // Reload inventory if ingredients were deducted
      if (result.success && result.deducted.isNotEmpty) {
        ref.read(inventoryProvider.notifier).load();
      }
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 10) return '🌅 ¿Qué desayunamos hoy?';
    if (hour < 17) return '🍛 ¿Qué almorzamos hoy?';
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
      msg =
          'Agrega recetas e ingredientes a\ntu despensa para ver sugerencias.';
    } else if (!hasRecipes) {
      icon = Icons.menu_book_outlined;
      msg =
          'Tienes ingredientes pero no recetas.\nAgrega recetas para ver qué puedes cocinar.';
    } else if (!hasIngredients) {
      icon = Icons.kitchen_outlined;
      msg =
          'Tienes recetas pero la despensa está vacía.\nAgrega ingredientes para ver sugerencias.';
    } else {
      icon = Icons.lightbulb_outline;
      msg =
          'No se encontraron recetas que coincidan\ncon tus ingredientes actuales (75%+ cobertura).';
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.white12),
          const SizedBox(height: 12),
          Text(msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.38),
                  fontSize: 14)),
        ],
      ),
    );
  }
}

// ── Tarjeta de receta sugerida con % de cobertura ───────────────────────────

class _SuggestionCard extends StatelessWidget {
  final Recipe recipe;
  final Set<String> availableNames;
  final VoidCallback onTap;
  final VoidCallback onCook;
  final ValueChanged<int?>? onRate;

  const _SuggestionCard({
    required this.recipe,
    required this.availableNames,
    required this.onTap,
    required this.onCook,
    this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final total = recipe.ingredients.length;
    final found = recipe.ingredients
        .where((i) => availableNames.contains(i.ingredientName.toLowerCase()))
        .length;
    final coverage = total > 0 ? (found / total * 100).round() : 100;
    final missing = total - found;

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.54),
                      fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            // Calificación
            StarRating(
              rating: recipe.rating,
              size: 18,
              onRatingChanged: (rating) {
                if (rating != null) {
                  final container = ProviderScope.containerOf(context);
                  container
                      .read(recipesProvider.notifier)
                      .updateRecipeRating(recipe.id, rating);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '⭐ Calificaste "${recipe.name}" con $rating estrellas'),
                      backgroundColor: const Color(0xFFFFB300),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
            // Chips de info
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _Chip('⏱ ${recipe.durationMinutes} min'),
                _Chip('👥 ${recipe.servings} porciones'),
                if (missing > 0)
                  _Chip(
                      '🛒 Faltan $missing ingrediente${missing > 1 ? "s" : ""}',
                      highlight: true)
                else
                  _Chip('✅ Tienes todo', highlight: true),
              ],
            ),
            // Botón "Cocinar esta receta"
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onCook,
                icon: const Icon(Icons.whatshot, size: 18),
                label: Text(coverage == 100
                    ? '🍳 ¡Cocinar ahora!'
                    : '🍳 Cocinar de todas formas'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C896),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
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
      ),
    );
  }
}

// ── Recipe Detail Sheet (reutilizado de recipes_tab) ─────────────────────────

class _RecipeDetailSheet extends StatefulWidget {
  final Recipe recipe;
  const _RecipeDetailSheet({required this.recipe});

  @override
  State<_RecipeDetailSheet> createState() => _RecipeDetailSheetState();
}

class _RecipeDetailSheetState extends State<_RecipeDetailSheet> {
  int _scaledServings = 0;

  @override
  void initState() {
    super.initState();
    _scaledServings = widget.recipe.servings;
  }

  double _scaleQuantity(double original) {
    if (widget.recipe.servings == 0) return original;
    return original * (_scaledServings / widget.recipe.servings);
  }

  String _formatQuantity(double value) {
    if (value == value.toInt()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  void _increaseServings() {
    if (_scaledServings < 12) {
      setState(() => _scaledServings++);
    }
  }

  void _decreaseServings() {
    if (_scaledServings > 1) {
      setState(() => _scaledServings--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isScaled = _scaledServings != widget.recipe.servings;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  Text(widget.recipe.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 22)),
                  if (widget.recipe.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(widget.recipe.description,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14)),
                  ],
                  const SizedBox(height: 12),
                  // Calificación
                  StarRating(
                    rating: widget.recipe.rating,
                    size: 24,
                    onRatingChanged: (rating) {
                      if (rating != null) {
                        final container = ProviderScope.containerOf(context);
                        container
                            .read(recipesProvider.notifier)
                            .updateRecipeRating(widget.recipe.id, rating);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '⭐ Calificaste "${widget.recipe.name}" con $rating estrellas'),
                            backgroundColor: const Color(0xFFFFB300),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                  // Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _DetailChip('⏱ ${widget.recipe.durationMinutes} min'),
                      // Porciones con controles +/-
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _decreaseServings,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: _scaledServings > 1
                                    ? const Color(0xFF00C896)
                                    : Colors.grey.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.remove,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: isScaled
                                  ? const Color(0xFFFF9800).withAlpha(40)
                                  : const Color(0xFF2A2A40),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isScaled
                                    ? const Color(0xFFFF9800)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.restaurant,
                                    size: 14, color: Colors.white54),
                                const SizedBox(width: 4),
                                Text(
                                  '$_scaledServings',
                                  style: TextStyle(
                                    color: isScaled
                                        ? const Color(0xFFFF9800)
                                        : Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _increaseServings,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: _scaledServings < 12
                                    ? const Color(0xFF00C896)
                                    : Colors.grey.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      _DetailChip(
                          '🥘 ${widget.recipe.ingredients.length} ingredientes'),
                    ],
                  ),
                  if (isScaled) ...[
                    const SizedBox(height: 8),
                    Text(
                      '📏 Cantidades escaladas (original: ${widget.recipe.servings} porciones)',
                      style: const TextStyle(
                          color: Color(0xFFFF9800),
                          fontSize: 11,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Ingredientes
                  const Text('Ingredientes',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                  const SizedBox(height: 8),
                  ...widget.recipe.ingredients.map((ing) {
                    final scaledQty = _scaleQuantity(ing.quantity);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.circle,
                              size: 6, color: Color(0xFF00C896)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${ing.ingredientName}: ${_formatQuantity(scaledQty)} ${ing.unit}',
                              style: TextStyle(
                                color: isScaled ? Colors.white : Colors.white70,
                                fontSize: 14,
                                fontWeight: isScaled ? FontWeight.w600 : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  // Instrucciones
                  const Text('Preparación',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                  const SizedBox(height: 8),
                  ...widget.recipe.instructions.asMap().entries.map((e) {
                    final i = e.key;
                    final step = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00C896),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(step,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 14)),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  // Botón Cocinar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _cookRecipeFromDetail(context),
                      icon: const Icon(Icons.whatshot, color: Colors.black),
                      label: const Text(
                        '🍳 ¡Cocinar esta receta!',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
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
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.link,
                            color: Color(0xFF00F0FF), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Fuente: ${widget.recipe.fuenteLabel ?? 'Desconocida'}',
                            style: const TextStyle(
                                color: Color(0xFF00F0FF),
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    if (widget.recipe.fuenteUrl != null) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('🔗 ${widget.recipe.fuenteUrl}')),
                          );
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
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cookRecipeFromDetail(BuildContext context) async {
    final container = ProviderScope.containerOf(context);
    final inventoryNotifier = container.read(inventoryProvider.notifier);
    // Start cooking session
    container.read(cookingSessionProvider.notifier).startSession(
          recipeName: widget.recipe.name,
          recipeId: widget.recipe.id,
          originalServings: widget.recipe.servings,
          scaledServings: _scaledServings,
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
                Text(
                  deducted.join(', '),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFF9800),
            duration: const Duration(seconds: 3),
          ),
        );
        // Reload inventory
        inventoryNotifier.load();
        // Close the sheet
        Navigator.of(context).pop();
      }
    }
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  const _DetailChip(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A40),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      );
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

// ── AI Suggestion Card (Horizontal) ─────────────────────────────────────────

class _AISuggestionCard extends StatelessWidget {
  final RecipeSuggestion suggestion;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final VoidCallback onCook;
  final ValueChanged<int?>? onRate;

  const _AISuggestionCard({
    required this.suggestion,
    required this.onTap,
    required this.onSave,
    required this.onCook,
    this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final recipe = suggestion.recipe;
    final matchPercent = suggestion.matchPercentage;
    final mealType = recipe.tipoComida;

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12, bottom: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1F0D), Color(0xFF1F1709)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFFF9800).withAlpha(60), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with meal type badge
          GestureDetector(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (mealType != null)
                        Text(
                          mealType.emoji,
                          style: const TextStyle(fontSize: 22),
                        )
                      else
                        const Text('🍽️', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          recipe.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800).withAlpha(40),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$matchPercent%',
                          style: const TextStyle(
                              color: Color(0xFFFF9800),
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _Chip('⏱ ${recipe.durationMinutes} min'),
                      _Chip('👥 ${recipe.servings}'),
                      if (mealType != null)
                        _Chip('${mealType.emoji} ${mealType.label}'),
                    ],
                  ),
                  // Star Rating
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: StarRating(
                      rating: recipe.rating,
                      size: 16,
                      onRatingChanged: onRate,
                    ),
                  ),
                  if (recipe.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      recipe.description,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  if (suggestion.missingIngredients > 0)
                    Text(
                      '🛒 Faltan ${suggestion.missingIngredients}',
                      style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 10,
                          fontStyle: FontStyle.italic),
                    )
                  else
                    const Text(
                      '✅ Tienes todo',
                      style: TextStyle(
                          color: Color(0xFF66BB6A),
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                // Save button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.save_outlined, size: 14),
                    label:
                        const Text('Guardar', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: const Size(0, 30),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Cook button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onCook,
                    icon: const Icon(Icons.whatshot, size: 14),
                    label:
                        const Text('Cocinar', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: const Size(0, 30),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cooking Session Banner ───────────────────────────────────────────────────

class _CookingSessionBanner extends StatelessWidget {
  final CookingSession session;
  const _CookingSessionBanner({required this.session});

  @override
  Widget build(BuildContext context) {
    final notifier = ProviderScope.containerOf(context)
        .read(cookingSessionProvider.notifier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFFF9800),
      child: Row(
        children: [
          const Icon(Icons.restaurant_menu, color: Colors.black),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🔥 Cocinando ahora...',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  session.recipeName,
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: notifier.endSession,
            tooltip: 'Terminar sesión',
          ),
        ],
      ),
    );
  }
}

// ── Star Rating Widget ───────────────────────────────────────────────────────

class StarRating extends StatelessWidget {
  final int? rating;
  final ValueChanged<int?>? onRatingChanged;
  final double size;

  const StarRating({
    super.key,
    this.rating,
    this.onRatingChanged,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final isFilled = rating != null && starValue <= rating!;
        return GestureDetector(
          onTap: onRatingChanged != null
              ? () => onRatingChanged!(starValue)
              : null,
          child: Icon(
            isFilled ? Icons.star : Icons.star_border,
            color: isFilled ? const Color(0xFFFFB300) : Colors.white38,
            size: size,
          ),
        );
      }),
    );
  }
}
