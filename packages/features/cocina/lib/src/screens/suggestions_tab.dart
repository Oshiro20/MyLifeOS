import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';

import '../providers/cocina_providers.dart';
import '../providers/what_can_i_cook_provider.dart';
import '../providers/cooking_session_provider.dart';
import 'widgets/prepared_meals_card.dart';
import 'widgets/quick_meal_suggestions_card.dart';
import 'widgets/recipe_cook_helper.dart';
import 'widgets/recipe_detail_sheet.dart';

/// Tab "Sugeridas" — Creador de Menú personalizado con IA
class SuggestionsTab extends ConsumerStatefulWidget {
  const SuggestionsTab({super.key});

  @override
  ConsumerState<SuggestionsTab> createState() => _SuggestionsTabState();
}

class _SuggestionsTabState extends ConsumerState<SuggestionsTab> {
  // Estado del creador de menú
  MealPeriod _selectedMealPeriod = MealPeriod.almuerzo;
  final Set<MenuComponent> _selectedComponents = {
    MenuComponent.platoFuerte,
  };
  int _menuCount = 3; // Número de menús a generar (por defecto 3)
  bool _budgetSaverMode = false; // Priorizar ahorro usando despensa
  bool _isMenuCreatorExpanded = true; // Controlar si la tarjeta está expandida

  // Listen for inventory changes
  void _listenInventoryChanges(WidgetRef ref) {
    ref.listen(inventoryProvider, (prev, next) {
      if (prev != null && prev.ingredients.length != next.ingredients.length) {
        final aiNotifier = ref.read(whatCanICookProvider.notifier);
        if (aiNotifier.visibleSuggestions.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFFFF9800), size: 18),
                  SizedBox(width: 8),
                  Text(
                      'Despensa actualizada — toca "Generar" para nuevas sugerencias',
                      style: TextStyle(fontSize: 12)),
                ],
              ),
              backgroundColor: const Color(0xFF152019),
              duration: const Duration(milliseconds: 1500),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final invState = ref.watch(inventoryProvider);
    final aiState = ref.watch(whatCanICookProvider);
    final aiNotifier = ref.read(whatCanICookProvider.notifier);
    final activeGoal = ref.watch(recipesProvider.select((s) => s.activeGoal));

    _listenInventoryChanges(ref);

    final availableNames =
        invState.ingredients.map((i) => i.name.toLowerCase()).toSet();

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con saludo
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              _greeting(),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w700),
            ),
          ),

          // Creador de Menú (colapsable)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            constraints: BoxConstraints(
              maxHeight: _isMenuCreatorExpanded ? 640.0 : 0.0,
            ),
            child: _isMenuCreatorExpanded
                ? SingleChildScrollView(
                    child: _MenuCreatorCard(
                      selectedMealPeriod: _selectedMealPeriod,
                      selectedComponents: _selectedComponents,
                      menuCount: _menuCount,
                      budgetSaverMode: _budgetSaverMode,
                      activeGoal: activeGoal,
                      onMealPeriodChanged: (period) =>
                          setState(() => _selectedMealPeriod = period),
                      onComponentToggle: (component) {
                        setState(() {
                          if (_selectedComponents.contains(component)) {
                            if (_selectedComponents.length > 1) {
                              _selectedComponents.remove(component);
                            }
                          } else {
                            _selectedComponents.add(component);
                          }
                        });
                      },
                      onMenuCountChanged: (count) =>
                          setState(() => _menuCount = count),
                      onGoalChanged: (goal) =>
                          ref.read(recipesProvider.notifier).setGoal(goal),
                      onBudgetSaverChanged: (val) =>
                          setState(() => _budgetSaverMode = val),
                      onGenerateAI: () {
                        ref.read(menuConfigProvider.notifier).update(
                              mealPeriod: _selectedMealPeriod,
                              components: _selectedComponents.toList(),
                              menuCount: _menuCount,
                              budgetSaverMode: _budgetSaverMode,
                            );
                        aiNotifier.generateSuggestions(
                          mealPeriod: _selectedMealPeriod,
                          components: _selectedComponents.toList(),
                          menuCount: _menuCount,
                          budgetSaverMode: _budgetSaverMode,
                          nutritionGoal: activeGoal,
                          forceRefresh: true,
                        );
                        setState(() => _isMenuCreatorExpanded = false);
                      },
                      onGenerateLocal: () {
                        ref.read(menuConfigProvider.notifier).update(
                              mealPeriod: _selectedMealPeriod,
                              components: _selectedComponents.toList(),
                              menuCount: _menuCount,
                              budgetSaverMode: _budgetSaverMode,
                            );
                        aiNotifier.generateRapidMenus(
                          nutritionGoal: activeGoal,
                        );
                        setState(() => _isMenuCreatorExpanded = false);
                      },
                      isLoading: aiState == WhatCanICookState.loading,
                      onCollapse: () =>
                          setState(() => _isMenuCreatorExpanded = false),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // Botón para expandir el creador de menú cuando está colapsado
          if (!_isMenuCreatorExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _isMenuCreatorExpanded = true),
                icon: const Icon(Icons.expand_more,
                    size: 18, color: Color(0xFFFF9800)),
                label: const Text(
                  '✏️ Armar nuevo menú',
                  style: TextStyle(color: Color(0xFFFF9800), fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFF9800), width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

          // AI Suggestions
          Expanded(
            child: _buildSuggestions(
                context, ref, aiState, aiNotifier, availableNames),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(
    BuildContext context,
    WidgetRef ref,
    WhatCanICookState aiState,
    WhatCanICookNotifier aiNotifier,
    Set<String> availableNames,
  ) {
    final visibleSuggestions = aiNotifier.visibleSuggestions;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    if (aiState == WhatCanICookState.initial) {
      return CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: PreparedMealsTrayCard()),
          SliverToBoxAdapter(
            child: QuickMealSuggestionsCard(
              onAskAI: (period) {
                final mapped = switch (period) {
                  QuickMealPeriod.breakfast => MealPeriod.desayuno,
                  QuickMealPeriod.lunch => MealPeriod.almuerzo,
                  QuickMealPeriod.dinner => MealPeriod.cena,
                };
                setState(() {
                  _selectedMealPeriod = mapped;
                  _isMenuCreatorExpanded = false;
                });
                ref.read(menuConfigProvider.notifier).update(
                      mealPeriod: mapped,
                      components: _selectedComponents.toList(),
                      menuCount: _menuCount,
                      budgetSaverMode: _budgetSaverMode,
                    );
                aiNotifier.generateSuggestions(
                  mealPeriod: mapped,
                  components: _selectedComponents.toList(),
                  menuCount: _menuCount,
                  budgetSaverMode: _budgetSaverMode,
                  nutritionGoal: ref.read(recipesProvider).activeGoal,
                  forceRefresh: true,
                );
              },
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restaurant_menu,
                      size: 64, color: onSurface.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text(
                    'Arma tu menú arriba y toca "Menús IA"',
                    style: TextStyle(
                        color: onSurface.withValues(alpha: 0.55), fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'El Chef IA sugerirá menús completos\nbasados en tu despensa',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: onSurface.withValues(alpha: 0.4), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (aiState == WhatCanICookState.loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFFF9800)),
            const SizedBox(height: 16),
            Text(
              'El Chef IA está armando tu menú...',
              style: TextStyle(
                  color: onSurface.withValues(alpha: 0.72), fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (aiState == WhatCanICookState.error) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                aiNotifier.errorMessage ?? 'Error desconocido',
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => aiNotifier.generateSuggestions(
                  mealPeriod: _selectedMealPeriod,
                  components: _selectedComponents.toList(),
                  menuCount: _menuCount,
                  budgetSaverMode: _budgetSaverMode,
                  nutritionGoal: ref.read(recipesProvider).activeGoal,
                  forceRefresh: true,
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9800),
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (aiState == WhatCanICookState.success && visibleSuggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_meals_outlined, size: 64, color: Colors.orange),
            const SizedBox(height: 12),
            Text(
              'No se encontraron menús con esos componentes.',
              style: TextStyle(
                  color: onSurface.withValues(alpha: 0.72), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta con menos componentes o agrega más ingredientes a tu despensa.',
              style: TextStyle(
                  color: onSurface.withValues(alpha: 0.55), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group suggestions by explicit menuNumber from AI/local engine (fallback to perMenu)
    if (visibleSuggestions.isNotEmpty) {
      final configComponents = ref.watch(menuConfigProvider).components.length;
      final perMenu =
          (configComponents > 0 ? configComponents : _selectedComponents.length)
              .clamp(1, visibleSuggestions.length);
      final menuGroups = <int, List<RecipeSuggestion>>{};
      for (int i = 0; i < visibleSuggestions.length; i++) {
        final item = visibleSuggestions[i];
        final menuNum = item.menuNumber ?? ((i ~/ perMenu) + 1);
        menuGroups.putIfAbsent(menuNum, () => []).add(item);
      }

      return ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          const PreparedMealsTrayCard(),
          if (aiNotifier.statusNotice != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.orange.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      aiNotifier.statusNotice!,
                      style: TextStyle(
                          color: onSurface.withValues(alpha: 0.85),
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF00E676), size: 18),
                const SizedBox(width: 6),
                Text(
                  '${visibleSuggestions.length} platos en ${menuGroups.length} menús',
                  style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => aiNotifier.generateSuggestions(
                    mealPeriod: _selectedMealPeriod,
                    components: _selectedComponents.toList(),
                    menuCount: _menuCount,
                    budgetSaverMode: _budgetSaverMode,
                    nutritionGoal: ref.read(recipesProvider).activeGoal,
                    forceRefresh: true,
                  ),
                  icon: const Icon(Icons.refresh, size: 14),
                  label:
                      const Text('Regenerar', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF9800),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          ...menuGroups.entries.map((entry) {
            // Calcular porcentaje global del menú (promedio de todas las recetas)
            final menuMatchPercentage = entry.value.isNotEmpty
                ? entry.value.fold<double>(
                      0.0,
                      (sum, suggestion) => sum + suggestion.matchPercentage,
                    ) /
                    entry.value.length
                : 0.0;

            return _CompleteMenuCard(
              menuNumber: entry.key,
              recipes: entry.value,
              onTap: (recipe) => _showRecipeDetail(context, recipe),
              onSave: (suggestion) =>
                  _saveAISuggestion(context, ref, aiNotifier, suggestion),
              onSaveMenu: () =>
                  _saveMenuSuggestions(context, ref, aiNotifier, entry.value),
              onCook: (suggestion) =>
                  _cookAISuggestion(context, ref, aiNotifier, suggestion),
              onCookMenu: () =>
                  _cookMenuSuggestions(context, ref, aiNotifier, entry.value),
              onDismiss: () => aiNotifier
                  .dismissMenu(entry.value.map((s) => s.recipe.id).toList()),
              menuMatchPercentage: menuMatchPercentage,
            );
          }),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  void _showRecipeDetail(BuildContext context, Recipe recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => RecipeDetailSheet(recipe: recipe),
    );
  }

  Future<void> _saveAISuggestion(
    BuildContext context,
    WidgetRef ref,
    WhatCanICookNotifier notifier,
    RecipeSuggestion suggestion,
  ) async {
    final result = await notifier.saveSuggestion(suggestion);
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
      final forced = await notifier.saveSuggestion(suggestion, forceSave: true);
      if (!context.mounted) return;
      if (forced.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ "${suggestion.recipe.name}" guardada'),
            backgroundColor: Colors.orange,
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } else if (result.success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ "${suggestion.recipe.name}" guardada'),
          backgroundColor: const Color(0xFF00E676),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
    ref.read(recipesProvider.notifier).load();
  }

  Future<void> _saveMenuSuggestions(
    BuildContext context,
    WidgetRef ref,
    WhatCanICookNotifier notifier,
    List<RecipeSuggestion> menuRecipes,
  ) async {
    int savedCount = 0;
    for (final suggestion in menuRecipes) {
      var res = await notifier.saveSuggestion(suggestion);
      if (!context.mounted) return;
      if (res.hasDuplicates) {
        final dupNames = res.duplicates
            .map((d) =>
                '${d.recipe.name} (${(d.similarityScore * 100).round()}% similar)')
            .join('\n');
        final shouldContinue = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('⚠️ Posible duplicado'),
                content: Text(
                  '"${suggestion.recipe.name}" es similar a:\n\n$dupNames\n\n¿Guardar de todos modos?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Omitir'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Guardar igual'),
                  ),
                ],
              ),
            ) ??
            false;
        if (shouldContinue && context.mounted) {
          res = await notifier.saveSuggestion(suggestion, forceSave: true);
        }
      }
      if (res.success) savedCount++;
    }
    if (!context.mounted) return;
    ref.read(recipesProvider.notifier).load();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('✅ $savedCount de ${menuRecipes.length} recetas guardadas'),
        backgroundColor:
            savedCount > 0 ? const Color(0xFF00E676) : Colors.orange,
        duration: const Duration(milliseconds: 1800),
      ),
    );
  }

  Future<void> _cookMenuSuggestions(
    BuildContext context,
    WidgetRef ref,
    WhatCanICookNotifier notifier,
    List<RecipeSuggestion> menuRecipes,
  ) async {
    if (menuRecipes.isEmpty) return;
    final allDeducted = <String>[];
    for (final s in menuRecipes) {
      final res = await notifier.cookSuggestion(s);
      if (res.success) {
        allDeducted.addAll(res.deducted);
      }
    }
    if (!context.mounted) return;
    if (allDeducted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('⚠️ No tienes ingredientes coincidentes en tu despensa.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final first = menuRecipes.first.recipe;
    ref.read(cookingSessionProvider.notifier).startSession(
          recipeName: menuRecipes.length == 1
              ? first.name
              : '${first.name} (+${menuRecipes.length - 1})',
          recipeId: first.id,
          originalServings: first.servings > 0 ? first.servings : 1,
          scaledServings: first.servings > 0 ? first.servings : 1,
          estimatedDurationMinutes: menuRecipes.fold<int>(
              0, (sum, r) => sum + r.recipe.durationMinutes),
        );
    ref.read(inventoryProvider.notifier).load();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '🍳 ¡Cocinando menú (${menuRecipes.length} platos)! Descontados: ${allDeducted.length} ítems'),
        backgroundColor: const Color(0xFFFF9800),
        duration: const Duration(milliseconds: 1800),
      ),
    );
  }

  Future<void> _cookAISuggestion(
    BuildContext context,
    WidgetRef ref,
    WhatCanICookNotifier notifier,
    RecipeSuggestion suggestion,
  ) async {
    await confirmAndCookRecipe(
      context: context,
      recipe: suggestion.recipe,
      scaledServings:
          suggestion.recipe.servings > 0 ? suggestion.recipe.servings : 1,
      popSheetOnSuccess: false,
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 10) return '🌅 ¡Buenos días!';
    if (hour < 17) return '☀️ ¡Buenas tardes!';
    return '🌙 ¡Buenas noches!';
  }
}

// ── Meal Period Enum ─────────────────────────────────────────────────────────

enum MealPeriod {
  desayuno('Desayuno', '🌅'),
  almuerzo('Almuerzo', '🍛'),
  cena('Cena', '🌙');

  final String label;
  final String emoji;
  const MealPeriod(this.label, this.emoji);
}

// ── Menu Component Enum ──────────────────────────────────────────────────────

enum MenuComponent {
  entrada('Entrada', '🥗', 'entrada'),
  sopa('Sopa', '🍲', 'sopa'),
  platoFuerte('Plato Fuerte', '🥘', 'seco'),
  refresco('Refresco', '🥤', 'bebida'),
  postre('Postre', '🍰', 'postre');

  final String label;
  final String emoji;
  final String mealTypeName; // Maps to MealType.name

  const MenuComponent(this.label, this.emoji, this.mealTypeName);
}

// ── Menu Creator Card ────────────────────────────────────────────────────────

class _MenuCreatorCard extends StatelessWidget {
  final MealPeriod selectedMealPeriod;
  final Set<MenuComponent> selectedComponents;
  final int menuCount;
  final bool budgetSaverMode;
  final NutritionGoal activeGoal;
  final Function(MealPeriod) onMealPeriodChanged;
  final Function(MenuComponent) onComponentToggle;
  final Function(int) onMenuCountChanged;
  final ValueChanged<NutritionGoal> onGoalChanged;
  final ValueChanged<bool> onBudgetSaverChanged;
  final VoidCallback onGenerateAI;
  final VoidCallback onGenerateLocal;
  final bool isLoading;
  final VoidCallback? onCollapse;

  const _MenuCreatorCard({
    required this.selectedMealPeriod,
    required this.selectedComponents,
    required this.menuCount,
    required this.budgetSaverMode,
    required this.activeGoal,
    required this.onMealPeriodChanged,
    required this.onComponentToggle,
    required this.onMenuCountChanged,
    required this.onGoalChanged,
    required this.onBudgetSaverChanged,
    required this.onGenerateAI,
    required this.onGenerateLocal,
    required this.isLoading,
    this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final chipBg = isDark
        ? const Color(0xFF2A2A40)
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF1A2F1A), Color(0xFF0F1F0F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  const Color(0xFF00C896).withValues(alpha: 0.12),
                  Theme.of(context).cardColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with collapse button
          Row(
            children: [
              const Text(
                '🍽️ Arma tu Menú',
                style: TextStyle(
                    color: Color(0xFF00C896),
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (onCollapse != null)
                IconButton(
                  onPressed: onCollapse,
                  icon: const Icon(Icons.expand_less,
                      size: 20, color: Color(0xFF00C896)),
                  tooltip: 'Colapsar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. Meal Period Selector
          Text('1. ¿Qué comida es?',
              style: TextStyle(
                  color: onSurface.withValues(alpha: 0.72),
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: MealPeriod.values.map((period) {
              final isSelected = selectedMealPeriod == period;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    onTap: () => onMealPeriodChanged(period),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFF9800) : chipBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${period.emoji} ${period.label}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.black
                              : onSurface.withValues(alpha: 0.75),
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 10),

          // 2. Menu Components
          Text('2. ¿Qué partes quieres?',
              style: TextStyle(
                  color: onSurface.withValues(alpha: 0.72),
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: MenuComponent.values.map((component) {
              final isSelected = selectedComponents.contains(component);
              return GestureDetector(
                onTap: () => onComponentToggle(component),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00C896).withValues(alpha: 0.22)
                        : chipBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00C896)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(component.emoji,
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(
                        component.label,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF00C896)
                              : onSurface.withValues(alpha: 0.75),
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.check,
                            size: 12, color: Color(0xFF00C896)),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 10),

          // 3. Number of menus
          Text('3. ¿Cuántos menús?',
              style: TextStyle(
                  color: onSurface.withValues(alpha: 0.72),
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _countButton(1, onMenuCountChanged, menuCount)),
              const SizedBox(width: 6),
              Expanded(child: _countButton(2, onMenuCountChanged, menuCount)),
              const SizedBox(width: 6),
              Expanded(child: _countButton(3, onMenuCountChanged, menuCount)),
              const SizedBox(width: 6),
              Expanded(child: _countButton(4, onMenuCountChanged, menuCount)),
              const SizedBox(width: 6),
              Expanded(child: _countButton(5, onMenuCountChanged, menuCount)),
            ],
          ),

          const SizedBox(height: 10),

          // 4. Meta nutricional / estilo
          Text('4. Meta / Estilo de alimentación',
              style: TextStyle(
                  color: onSurface.withValues(alpha: 0.72),
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: const [
              NutritionGoal.maintain,
              NutritionGoal.loseWeight,
              NutritionGoal.gainMuscle,
              NutritionGoal.light,
              NutritionGoal.other,
            ].map((goal) {
              final isSelected = activeGoal == goal;
              return GestureDetector(
                onTap: () => onGoalChanged(goal),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00C896).withValues(alpha: 0.22)
                        : chipBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00C896)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(goal.emoji, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      Text(
                        goal.label,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF00C896)
                              : onSurface.withValues(alpha: 0.78),
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          Text(
            activeGoal.hint,
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.55),
              fontSize: 11,
            ),
          ),

          const SizedBox(height: 8),

          // Modo ahorro opcional
          FilterChip(
            avatar: Icon(
              Icons.savings_outlined,
              size: 16,
              color: budgetSaverMode
                  ? const Color(0xFF00C896)
                  : onSurface.withValues(alpha: 0.65),
            ),
            label: Text(
              'Modo Ahorro (economizar con despensa)',
              style: TextStyle(
                fontSize: 11,
                color: budgetSaverMode
                    ? const Color(0xFF00C896)
                    : onSurface.withValues(alpha: 0.78),
                fontWeight:
                    budgetSaverMode ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
            selected: budgetSaverMode,
            onSelected: onBudgetSaverChanged,
            selectedColor: const Color(0xFF00C896).withValues(alpha: 0.18),
            checkmarkColor: const Color(0xFF00C896),
          ),

          const SizedBox(height: 10),

          // Two generate buttons: IA (orange) and Local (blue)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : onGenerateAI,
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: Text(isLoading ? 'Generando...' : '✨ Menús IA',
                      style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : onGenerateLocal,
                  icon: const Icon(Icons.restaurant_menu, size: 16),
                  label: const Text('📚 Menú Local',
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countButton(int count, Function(int) onChanged, int selected) {
    final isSelected = selected == count;
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final onSurface = Theme.of(context).colorScheme.onSurface;
        return GestureDetector(
          onTap: () => onChanged(count),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFF9800)
                  : (isDark
                      ? const Color(0xFF2A2A40)
                      : Theme.of(context).colorScheme.surfaceContainerHighest),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected
                    ? Colors.black
                    : onSurface.withValues(alpha: 0.75),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Complete Menu Card ───────────────────────────────────────────────────────

class _CompleteMenuCard extends StatelessWidget {
  final int menuNumber;
  final List<RecipeSuggestion> recipes;
  final Function(Recipe) onTap;
  final Function(RecipeSuggestion) onSave;
  final VoidCallback? onSaveMenu;
  final Function(RecipeSuggestion) onCook;
  final VoidCallback? onCookMenu;
  final VoidCallback? onDismiss;
  final double menuMatchPercentage; // Porcentaje global del menú

  const _CompleteMenuCard({
    required this.menuNumber,
    required this.recipes,
    required this.onTap,
    required this.onSave,
    this.onSaveMenu,
    required this.onCook,
    this.onCookMenu,
    this.onDismiss,
    this.menuMatchPercentage = 0.0,
  });

  String _getMealTypeLabel(Recipe recipe) {
    final tipo = recipe.tipoComida;
    if (tipo == null) return '🍽️ Plato';
    return '${tipo.emoji} ${tipo.label}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2F1A), Color(0xFF0F1F0F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF00E676).withValues(alpha: 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Menu header
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'MENÚ $menuNumber',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Builder(
                  builder: (_) {
                    final totalKcal = recipes.fold<int>(
                      0,
                      (sum, r) => sum + (r.recipe.caloriasAproximadas ?? 0),
                    );
                    final totalMin = recipes.fold<int>(
                      0,
                      (sum, r) => sum + r.recipe.durationMinutes,
                    );
                    final goal = recipes.first.recipe.goal;
                    return Text(
                      '${recipes.length} platos · $totalMin min${totalKcal > 0 ? ' · ~$totalKcal kcal' : ''} · ${goal.emoji}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    );
                  },
                ),
                if (onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close, size: 16),
                    tooltip: 'Descartar este menú',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Global menu match percentage
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF00E676).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    menuMatchPercentage >= 70
                        ? Icons.check_circle
                        : menuMatchPercentage >= 40
                            ? Icons.warning_amber
                            : Icons.shopping_cart,
                    color: menuMatchPercentage >= 70
                        ? const Color(0xFF00E676)
                        : menuMatchPercentage >= 40
                            ? Colors.orangeAccent
                            : Colors.redAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ingredientes disponibles',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        LinearProgressIndicator(
                          value: menuMatchPercentage / 100,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            menuMatchPercentage >= 70
                                ? const Color(0xFF00E676)
                                : menuMatchPercentage >= 40
                                    ? Colors.orangeAccent
                                    : Colors.redAccent,
                          ),
                          minHeight: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${menuMatchPercentage.round()}%',
                    style: TextStyle(
                      color: menuMatchPercentage >= 70
                          ? const Color(0xFF00E676)
                          : menuMatchPercentage >= 40
                              ? Colors.orangeAccent
                              : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Recipe list
            ...recipes.map((suggestion) {
              final recipe = suggestion.recipe;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GestureDetector(
                  onTap: () => onTap(recipe),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              const Color(0xFFFF9800).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _getMealTypeLabel(recipe),
                          style: const TextStyle(
                              color: Color(0xFFFF9800),
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                recipe.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (suggestion.missingIngredients > 0)
                                Text(
                                  '🛒 Faltan ${suggestion.missingIngredients}',
                                  style: const TextStyle(
                                      color: Colors.orangeAccent, fontSize: 10),
                                )
                              else
                                const Text(
                                  '✅ Tienes todo',
                                  style: TextStyle(
                                      color: Color(0xFF66BB6A), fontSize: 10),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${recipe.durationMinutes}min',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 10),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: recipes.isEmpty
                        ? null
                        : (onSaveMenu ?? () => onSave(recipes.first)),
                    icon: const Icon(Icons.save_outlined, size: 14),
                    label: const Text('Guardar todo',
                        style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: recipes.isEmpty
                        ? null
                        : (onCookMenu ?? () => onCook(recipes.first)),
                    icon: const Icon(Icons.whatshot, size: 14),
                    label:
                        const Text('Cocinar', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cooking Session Banner ───────────────────────────────────────────────────


