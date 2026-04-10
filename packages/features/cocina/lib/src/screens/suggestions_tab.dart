import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';

import '../providers/cocina_providers.dart';
import '../providers/what_can_i_cook_provider.dart';
import '../providers/cooking_session_provider.dart';
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
  int _menuCount = 5; // Número de menús a generar (por defecto 5)

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
    final cookingSession = ref.watch(cookingSessionProvider);

    _listenInventoryChanges(ref);

    final availableNames =
        invState.ingredients.map((i) => i.name.toLowerCase()).toSet();

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cooking Session Banner
          if (cookingSession != null)
            _CookingSessionBanner(session: cookingSession),

          // Header con saludo
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              _greeting(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700),
            ),
          ),

          // Creador de Menú
          _MenuCreatorCard(
            selectedMealPeriod: _selectedMealPeriod,
            selectedComponents: _selectedComponents,
            menuCount: _menuCount,
            onMealPeriodChanged: (period) =>
                setState(() => _selectedMealPeriod = period),
            onComponentToggle: (component) {
              setState(() {
                if (_selectedComponents.contains(component)) {
                  // Don't allow deselecting the last component
                  if (_selectedComponents.length > 1) {
                    _selectedComponents.remove(component);
                  }
                } else {
                  _selectedComponents.add(component);
                }
              });
            },
            onMenuCountChanged: (count) => setState(() => _menuCount = count),
            onGenerate: () {
              aiNotifier.generateSuggestions(
                mealPeriod: _selectedMealPeriod,
                components: _selectedComponents.toList(),
                menuCount: _menuCount,
              );
            },
            isLoading: aiState == WhatCanICookState.loading,
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

    if (aiState == WhatCanICookState.initial) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_menu,
                size: 64, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text(
              'Arma tu menú arriba y toca "Generar"',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'El Chef IA sugerirá menús completos\nbasados en tu despensa',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (aiState == WhatCanICookState.loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFFF9800)),
            SizedBox(height: 16),
            Text(
              'El Chef IA está armando tu menú...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (aiState == WhatCanICookState.error) {
      return _buildFallbackWithSuggestions(
        context,
        ref,
        availableNames,
        aiNotifier,
        child: Center(
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
        ),
      );
    }

    if (aiState == WhatCanICookState.success && visibleSuggestions.isEmpty) {
      return _buildFallbackWithSuggestions(
        context,
        ref,
        availableNames,
        aiNotifier,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_meals_outlined,
                  size: 64, color: Colors.orange),
              const SizedBox(height: 12),
              const Text(
                'No se encontraron menús con esos componentes.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Intenta con menos componentes o agrega más ingredientes a tu despensa.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Group suggestions into menus
    if (visibleSuggestions.isNotEmpty) {
      final menuGroups = <int, List<RecipeSuggestion>>{};
      for (int i = 0; i < visibleSuggestions.length; i++) {
        final menuNum = (i / _menuCount).floor() + 1;
        if (!menuGroups.containsKey(menuNum)) {
          menuGroups[menuNum] = [];
        }
        menuGroups[menuNum]!.add(visibleSuggestions[i]);
      }

      return ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF00E676), size: 18),
                const SizedBox(width: 6),
                Text(
                  '${visibleSuggestions.length} platos encontrados en ${menuGroups.length} menús',
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
              onCook: (suggestion) =>
                  _cookAISuggestion(context, ref, aiNotifier, suggestion),
              onDismiss: () =>
                  aiNotifier.dismissRecipe(entry.value.first.recipe.id),
              menuMatchPercentage: menuMatchPercentage,
            );
          }),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildFallbackWithSuggestions(
    BuildContext context,
    WidgetRef ref,
    Set<String> availableNames,
    WhatCanICookNotifier aiNotifier, {
    required Widget child,
  }) {
    final invState = ref.watch(inventoryProvider);
    final hybridAsync = ref.watch(hybridSuggestionsProvider);

    if (invState.ingredients.isEmpty) {
      return child;
    }

    return hybridAsync.when(
      data: (localSuggestions) {
        if (localSuggestions.isEmpty) return child;

        return ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            // Header for local fallback
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A40),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF00E676).withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    ' Sugerencias sin IA (instantaneas)',
                    style: TextStyle(
                      color: Color(0xFFFF9800),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${localSuggestions.length} recetas encontradas en tu biblioteca local',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // AI error or empty message (if any)
            child,
            // Local recipe cards
            const SizedBox(height: 8),
            ...localSuggestions.map((suggestion) => _LocalRecipeCard(
                  suggestion: suggestion,
                  onTap: (recipe) => _showRecipeDetail(context, recipe),
                  onSave: (s) =>
                      _saveLocalSuggestion(context, ref, aiNotifier, s),
                )),
          ],
        );
      },
      loading: () => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(height: 16),
          const CircularProgressIndicator(
              color: Color(0xFFFF9800), strokeWidth: 2),
          const SizedBox(height: 8),
          Text(
            'Buscando en recetas locales...',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
          ),
        ],
      ),
      error: (_, __) => child,
    );
  }

  Future<void> _saveLocalSuggestion(
    BuildContext context,
    WidgetRef ref,
    WhatCanICookNotifier notifier,
    RecipeSuggestion suggestion,
  ) async {
    final recipeNotifier = ref.read(recipesProvider.notifier);
    try {
      await recipeNotifier.saveRecipe(suggestion.recipe);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(' "${suggestion.recipe.name}" guardada'),
          backgroundColor: const Color(0xFF00E676),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(milliseconds: 2000),
        ),
      );
    }
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
    }

    if (result.success && context.mounted) {
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

  Future<void> _cookAISuggestion(
    BuildContext context,
    WidgetRef ref,
    WhatCanICookNotifier notifier,
    RecipeSuggestion suggestion,
  ) async {
    ref.read(cookingSessionProvider.notifier).startSession(
          recipeName: suggestion.recipe.name,
          recipeId: suggestion.recipe.id,
          originalServings: suggestion.recipe.servings,
          scaledServings: 1,
          estimatedDurationMinutes: suggestion.recipe.durationMinutes,
        );

    final result = await notifier.cookSuggestion(suggestion);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success
              ? '🍳 ¡Cocinando ${suggestion.recipe.name}!'
              : '⚠️ ${result.message}'),
          backgroundColor:
              result.success ? const Color(0xFFFF9800) : Colors.redAccent,
          duration: const Duration(milliseconds: 1500),
        ),
      );
      if (result.success) {
        ref.read(inventoryProvider.notifier).load();
      }
    }
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
  platoFuerte('Plato Fuerte', '🥘', 'almuerzo'),
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
  final Function(MealPeriod) onMealPeriodChanged;
  final Function(MenuComponent) onComponentToggle;
  final Function(int) onMenuCountChanged;
  final VoidCallback onGenerate;
  final bool isLoading;

  const _MenuCreatorCard({
    required this.selectedMealPeriod,
    required this.selectedComponents,
    required this.menuCount,
    required this.onMealPeriodChanged,
    required this.onComponentToggle,
    required this.onMenuCountChanged,
    required this.onGenerate,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2F1A), Color(0xFF0F1F0F)],
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
          // Title
          const Text(
            '🍽️ Arma tu Menú',
            style: TextStyle(
                color: Color(0xFF00E676),
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // 1. Meal Period Selector
          const Text('1. ¿Qué comida es?',
              style: TextStyle(
                  color: Colors.white70,
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
                        color: isSelected
                            ? const Color(0xFFFF9800)
                            : const Color(0xFF2A2A40),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${period.emoji} ${period.label}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
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
          const Text('2. ¿Qué partes quieres?',
              style: TextStyle(
                  color: Colors.white70,
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
                        ? const Color(0xFF00E676).withValues(alpha: 0.3)
                        : const Color(0xFF2A2A40),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00E676)
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
                              ? const Color(0xFF00E676)
                              : Colors.white70,
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.check,
                            size: 12, color: Color(0xFF00E676)),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 10),

          // 3. Number of menus
          const Text('3. ¿Cuántos menús?',
              style: TextStyle(
                  color: Colors.white70,
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

          const SizedBox(height: 14),

          // Generate button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onGenerate,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label:
                  Text(isLoading ? 'Generando...' : '✨ Generar Menús con IA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countButton(int count, Function(int) onChanged, int selected) {
    final isSelected = selected == count;
    return GestureDetector(
      onTap: () => onChanged(count),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF9800) : const Color(0xFF2A2A40),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$count',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Complete Menu Card ───────────────────────────────────────────────────────

class _CompleteMenuCard extends StatelessWidget {
  final int menuNumber;
  final List<RecipeSuggestion> recipes;
  final Function(Recipe) onTap;
  final Function(RecipeSuggestion) onSave;
  final Function(RecipeSuggestion) onCook;
  final VoidCallback? onDismiss;
  final double menuMatchPercentage; // Porcentaje global del menú

  const _CompleteMenuCard({
    required this.menuNumber,
    required this.recipes,
    required this.onTap,
    required this.onSave,
    required this.onCook,
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
                Text(
                  '${recipes.length} platos · ${recipes.fold(0, (sum, r) => sum + r.recipe.durationMinutes)} min total',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
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
                    onPressed: () => onSave(recipes.first),
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
                    onPressed: () => onCook(recipes.first),
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

class _CookingSessionBanner extends StatefulWidget {
  final CookingSession session;
  const _CookingSessionBanner({required this.session});

  @override
  State<_CookingSessionBanner> createState() => _CookingSessionBannerState();
}

class _CookingSessionBannerState extends State<_CookingSessionBanner> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ProviderScope.containerOf(context)
        .read(cookingSessionProvider.notifier);

    final elapsed = DateTime.now().difference(widget.session.startedAt);
    final elapsedMinutes = elapsed.inMinutes;
    final estimatedMinutes = widget.session.estimatedDurationMinutes;

    String timeInfo;
    Color bgColor;
    if (estimatedMinutes != null) {
      final remaining = estimatedMinutes - elapsedMinutes;
      if (remaining > 0) {
        timeInfo = '~$remaining min restantes';
        bgColor = const Color(0xFFFF9800);
      } else {
        timeInfo = '⏰ Tiempo cumplido — tocando "X" para terminar';
        bgColor = const Color(0xFF4CAF50);
      }
    } else {
      timeInfo = '$elapsedMinutes min transcurridos';
      bgColor = const Color(0xFFFF9800);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bgColor,
      child: Row(
        children: [
          const Icon(Icons.restaurant_menu, color: Colors.black, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeInfo,
                  style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.session.recipeName,
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
            icon: const Icon(Icons.close, color: Colors.black, size: 20),
            onPressed: notifier.endSession,
            tooltip: 'Terminar sesión',
          ),
        ],
      ),
    );
  }
}

// ── Local Recipe Card (Fallback when AI has no results) ──────────────────────

class _LocalRecipeCard extends StatelessWidget {
  final RecipeSuggestion suggestion;
  final Function(Recipe) onTap;
  final Function(RecipeSuggestion) onSave;

  const _LocalRecipeCard({
    required this.suggestion,
    required this.onTap,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final recipe = suggestion.recipe;
    return GestureDetector(
      onTap: () => onTap(recipe),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2F1A),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 12, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.durationMinutes} min',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.food_bank,
                          size: 12, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.ingredients.length} ingredientes',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => onSave(suggestion),
              icon: const Icon(Icons.save_outlined, size: 14),
              label: const Text('Guardar', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 30),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
