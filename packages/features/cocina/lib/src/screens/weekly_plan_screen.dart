import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:core/core.dart';
import 'package:domain/domain.dart';
import '../providers/cocina_providers.dart';
import '../utils/cooking_history_service.dart';
import 'widgets/prepared_meals_card.dart';
import 'widgets/recipe_detail_sheet.dart';

class WeeklyPlanScreen extends ConsumerStatefulWidget {
  const WeeklyPlanScreen({super.key});

  @override
  ConsumerState<WeeklyPlanScreen> createState() => _WeeklyPlanScreenState();
}

class _WeeklyPlanScreenState extends ConsumerState<WeeklyPlanScreen> {
  @override
  void initState() {
    super.initState();
    // Load menu on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(weeklyMenuProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(weeklyMenuProvider);
    final recipesState = ref.watch(recipesProvider);
    final invState = ref.watch(inventoryProvider);
    final days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final meals = [
      {'type': 0, 'label': 'Desayuno', 'icon': '🌅'},
      {'type': 1, 'label': 'Almuerzo', 'icon': '🍛'},
      {'type': 2, 'label': 'Cena', 'icon': '🌙'},
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('📅 Menú Semanal',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme:
            IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined,
                color: Color(0xFF00E676)),
            onPressed: () => _addMissingIngredientsToList(context),
            tooltip: 'Añadir faltantes a lista de compras',
          ),
          IconButton(
            icon: const Icon(Icons.ios_share, color: Color(0xFF00F0FF)),
            onPressed: () => _shareMenu(context),
            tooltip: 'Exportar Menú',
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Color(0xFFFF9800)),
            onPressed: () => _generateMenu(context),
            tooltip: 'Generar Menú Automático',
          ),
        ],
      ),
      body: state is WeeklyMenuLoading
          ? const Center(child: CircularProgressIndicator())
          : state is WeeklyMenuLoaded
              ? ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: days.length + 1,
                  itemBuilder: (ctx, i) {
                    // First item: cooking history & estimated missing budget banner
                    if (i == 0) {
                      final catalogState =
                          ref.watch(ingredientPriceCatalogProvider);
                      final missing = _collectMissingItems(
                        entries: state.entries,
                        recipes: recipesState.recipes,
                        inventory: invState.ingredients,
                      );
                      final estimate = IngredientPriceService.estimateList(
                        catalog: catalogState.catalog,
                        items: missing.map((m) => (
                              name: m.name,
                              quantity: m.quantity,
                              unit: m.unit,
                            )),
                      );
                      return Column(
                        children: [
                          const PreparedMealsTrayCard(
                            margin: EdgeInsets.only(bottom: 10),
                          ),
                          _CookingHistoryBanner(),
                          if (missing.isNotEmpty)
                            _WeeklyBudgetBanner(
                              missingCount: missing.length,
                              estimate: estimate,
                              onSendToShoppingList: () =>
                                  _addMissingIngredientsToList(context),
                            ),
                        ],
                      );
                    }
                    final day = i; // shifted by 1
                    return _DaySection(
                      dayLabel: days[i - 1],
                      meals: meals,
                      entries: state.entries,
                      recipes: recipesState.recipes,
                      inventory: invState.ingredients,
                      day: day,
                      onTapRecipe: (entry) => _showRecipeDetail(context, entry),
                      onClearSlot: (entry) => ref
                          .read(weeklyMenuProvider.notifier)
                          .clearSlot(entry),
                      onAssignEmpty: (d, mealType) => _showRecipePicker(
                          context, d, mealType, state.entries),
                    );
                  },
                )
              : state is WeeklyMenuError
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.redAccent, size: 48),
                          const SizedBox(height: 12),
                          Text('Error cargando menú: ${state.message}',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () =>
                                ref.read(weeklyMenuProvider.notifier).load(),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_outlined,
                                color: Color(0xFF00E676), size: 56),
                            const SizedBox(height: 12),
                            Text(
                              'Sin menú semanal planificado aún',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Genera un plan automático basado en tus recetas y despensa.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _generateMenu(context),
        label: const Text('Planificar Semana'),
        icon: const Icon(Icons.auto_awesome),
        backgroundColor: const Color(0xFF00E676),
      ),
    );
  }

  Future<void> _generateMenu(BuildContext context) async {
    final activeGoal = ref.read(recipesProvider).activeGoal;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final onSurface = Theme.of(ctx).colorScheme.onSurface;
        return AlertDialog(
          backgroundColor: Theme.of(ctx).cardColor,
          title: Text('📅 Generar Menú Semanal',
              style: TextStyle(color: onSurface)),
          content: Text(
              'Se priorizarán ingredientes disponibles y por vencer según tu meta (${activeGoal.emoji} ${activeGoal.label}). ¿Cómo prefieres generarlo?',
              style: TextStyle(color: onSurface.withValues(alpha: 0.72))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            OutlinedButton(
                onPressed: () => Navigator.pop(ctx, 'local'),
                child: const Text('⚡ Rápido')),
            ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, 'ai'),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Con Gemini IA')),
          ],
        );
      },
    );

    if (choice == 'local' || choice == 'ai') {
      try {
        await ref
            .read(weeklyMenuProvider.notifier)
            .generate(useAI: choice == 'ai');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(choice == 'ai'
                    ? '✨ Menú semanal optimizado con IA (${activeGoal.label})'
                    : '✅ Menú semanal generado'),
                backgroundColor: const Color(0xFF00E676)),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error al generar menú: $e'),
                backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  List<({String name, double quantity, String unit})> _collectMissingItems({
    required List<WeeklyMenuEntry> entries,
    required List<Recipe> recipes,
    required List<InventoryIngredient> inventory,
  }) {
    final availableKeys = inventory
        .map((i) => IngredientPriceService.normalizeKey(i.name))
        .toSet();
    final aggregated =
        <String, ({String name, double quantity, String unit})>{};

    for (final entry in entries) {
      if (entry.recipeId.isEmpty) continue;
      final recipe = recipes.firstWhere(
        (r) => r.id == entry.recipeId,
        orElse: () => Recipe(
          id: '',
          name: '',
          description: '',
          durationMinutes: 0,
          servings: 0,
          instructions: [],
          ingredients: [],
          tags: [],
          createdAt: DateTime.now(),
        ),
      );
      if (recipe.id.isEmpty) continue;

      for (final ing in recipe.ingredients) {
        final key = IngredientPriceService.normalizeKey(ing.ingredientName);
        if (key.isEmpty || availableKeys.contains(key)) continue;

        final existing = aggregated[key];
        if (existing == null) {
          aggregated[key] = (
            name: ing.ingredientName.trim(),
            quantity: ing.quantity > 0 ? ing.quantity : 1.0,
            unit: ing.unit,
          );
        } else {
          final converted = IngredientUnitNormalizer.convert(
            ing.quantity > 0 ? ing.quantity : 1.0,
            MeasurementUnit.fromString(ing.unit),
            MeasurementUnit.fromString(existing.unit),
          );
          if (converted != null) {
            aggregated[key] = (
              name: existing.name,
              quantity: existing.quantity + converted,
              unit: existing.unit,
            );
          }
        }
      }
    }
    return aggregated.values.toList();
  }

  Future<void> _addMissingIngredientsToList(BuildContext context) async {
    final state = ref.read(weeklyMenuProvider);
    if (state is! WeeklyMenuLoaded || state.entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No hay menú generado para agregar ingredientes.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final recipes = ref.read(recipesProvider).recipes;
    final inventory = ref.read(inventoryProvider).ingredients;
    final missingItems = _collectMissingItems(
      entries: state.entries,
      recipes: recipes,
      inventory: inventory,
    );
    final recipeCount =
        state.entries.where((e) => e.recipeId.isNotEmpty).length;

    if (missingItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✅ Ya tienes todos los ingredientes del plan'),
            backgroundColor: Color(0xFF00E676)),
      );
      return;
    }

    // Add to shopping list (deduplicating against existing unbought items)
    final existingPending = ref
        .read(recipesProvider)
        .shoppingList
        .where((s) => !s.bought)
        .map((s) => IngredientPriceService.normalizeKey(s.name))
        .toSet();
    const uuid = Uuid();
    final notifier = ref.read(recipesProvider.notifier);
    int added = 0;
    for (final item in missingItems) {
      final key = IngredientPriceService.normalizeKey(item.name);
      if (existingPending.contains(key)) continue;
      existingPending.add(key);
      await notifier.addShoppingItem(ShoppingItem(
        id: uuid.v4(),
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        bought: false,
        createdAt: DateTime.now(),
      ));
      added++;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(added == 0
              ? '✅ Todos los ingredientes faltantes ya están en tu lista de compras'
              : '🛒 $added ingredientes añadidos a la lista de compras ($recipeCount recetas)'),
          backgroundColor: const Color(0xFF00E676),
          duration: const Duration(milliseconds: 1800),
          action: SnackBarAction(
            label: 'VER',
            textColor: Colors.white,
            onPressed: () {
              ref.read(cocinaTabProvider.notifier).setTab(4);
            },
          ),
        ),
      );
    }
  }

  void _shareMenu(BuildContext context) {
    final state = ref.read(weeklyMenuProvider);
    if (state is! WeeklyMenuLoaded || state.entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No hay menú generado para compartir.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    final recipes = ref.read(recipesProvider).recipes;
    final buffer = StringBuffer();
    buffer.writeln('📅 *Menú Semanal - MyLifeOS*');
    buffer.writeln('');

    for (int d = 1; d <= 7; d++) {
      buffer.writeln('*${days[d - 1]}*');
      final dayEntries = state.entries.where((e) => e.dayOfWeek == d).toList();
      for (final entry in dayEntries) {
        final meal = _getMealLabel(entry.mealType.toString());
        final recipe = recipes.firstWhere((r) => r.id == entry.recipeId,
            orElse: () => Recipe(
                id: '',
                name: 'Sin asignar',
                description: '',
                durationMinutes: 0,
                servings: 0,
                instructions: [],
                ingredients: [],
                tags: [],
                createdAt: DateTime.now()));
        buffer.writeln('  ${_getMealEmoji(meal)} $meal: ${recipe.name}');
      }
      buffer.writeln('');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('📋 Menú copiado al portapapeles'),
          backgroundColor: Color(0xFF00E676)),
    );
  }

  String _getMealEmoji(String type) {
    switch (type) {
      case 'Desayuno':
        return '🌅';
      case 'Almuerzo':
        return '🍛';
      case 'Cena':
        return '🌙';
      default:
        return '🍽️';
    }
  }

  void _showRecipeDetail(BuildContext context, WeeklyMenuEntry entry) {
    // entry is a WeeklyMenuEntry, we need to fetch the actual Recipe
    final recipes = ref.read(recipesProvider).recipes;
    final recipe = recipes.firstWhere(
      (r) => r.id == entry.recipeId,
      orElse: () => Recipe(
        id: '',
        name: 'Receta no encontrada',
        description: 'Esta receta ya no existe en tu recetario.',
        durationMinutes: 0,
        servings: 0,
        instructions: [],
        ingredients: [],
        tags: [],
        createdAt: DateTime.now(),
      ),
    );

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

  Future<void> _showRecipePicker(BuildContext context, int day, String mealType,
      List<WeeklyMenuEntry> currentEntries) async {
    final recipesState = ref.read(recipesProvider);
    final allRecipes = recipesState.recipes;

    if (allRecipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No tienes recetas guardadas para asignar.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final selected = await showModalBottomSheet<Recipe>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Seleccionar receta para ${_getMealLabel(mealType)}',
                style: const TextStyle(
                    color: Color(0xFF00E676),
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: allRecipes.length,
                itemBuilder: (ctx, i) {
                  final onSurface = Theme.of(ctx).colorScheme.onSurface;
                  return ListTile(
                    title: Text(allRecipes[i].name,
                        style: TextStyle(color: onSurface)),
                    subtitle: Text('${allRecipes[i].durationMinutes} min',
                        style:
                            TextStyle(color: onSurface.withValues(alpha: 0.6))),
                    trailing: const Icon(Icons.add_circle_outline,
                        color: Color(0xFF00E676)),
                    onTap: () => Navigator.pop(ctx, allRecipes[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      // Save to weekly menu (preserving slot entry ID if updating an existing row)
      final parsedMeal = int.parse(mealType);
      String? existingId;
      for (final e in currentEntries) {
        if (e.dayOfWeek == day && e.mealType == parsedMeal) {
          existingId = e.id;
          break;
        }
      }
      final repo = ref.read(cocinaRepositoryProvider);
      await repo.saveWeeklyMenuEntry(WeeklyMenuEntry(
        id: existingId ?? const Uuid().v4(),
        dayOfWeek: day,
        mealType: parsedMeal,
        recipeId: selected.id,
        isCustom: false,
      ));
      ref.read(weeklyMenuProvider.notifier).load();
    }
  }

  String _getMealLabel(String type) {
    switch (type) {
      case '0':
        return 'Desayuno';
      case '1':
        return 'Almuerzo';
      case '2':
        return 'Cena';
      default:
        return 'Comida';
    }
  }
}

class _DaySection extends StatelessWidget {
  final String dayLabel;
  final List<Map<String, dynamic>> meals;
  final List<WeeklyMenuEntry> entries;
  final List<Recipe> recipes;
  final List<InventoryIngredient> inventory;
  final int day;
  final Function(WeeklyMenuEntry entry) onTapRecipe;
  final Function(WeeklyMenuEntry entry) onClearSlot;
  final Function(int day, String mealType) onAssignEmpty;

  const _DaySection({
    required this.dayLabel,
    required this.meals,
    required this.entries,
    required this.recipes,
    required this.inventory,
    required this.day,
    required this.onTapRecipe,
    required this.onClearSlot,
    required this.onAssignEmpty,
  });

  String? _getRecipeName(String? recipeId) {
    if (recipeId == null || recipeId.isEmpty) return null;
    try {
      final recipe = recipes.firstWhere((r) => r.id == recipeId);
      return recipe.name;
    } catch (e) {
      return null;
    }
  }

  int _getMatchPercentage(String? recipeId) {
    if (recipeId == null || recipeId.isEmpty) return 0;
    try {
      final recipe = recipes.firstWhere((r) => r.id == recipeId);
      final available = inventory.map((i) => i.name.toLowerCase()).toSet();
      final total = recipe.ingredients.length;
      if (total == 0) return 100;
      final match = recipe.ingredients
          .where((i) => available.contains(i.ingredientName.toLowerCase()))
          .length;
      return (match / total * 100).round();
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayEntries = entries.where((e) => e.dayOfWeek == day).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(dayLabel,
              style: const TextStyle(
                  color: Color(0xFFFF9800),
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ),
        ...meals.map((m) {
          WeeklyMenuEntry? entry;
          for (final e in dayEntries) {
            if (e.mealType == m['type']) {
              entry = e;
              break;
            }
          }

          final activeEntry =
              (entry != null && entry.recipeId.isNotEmpty) ? entry : null;
          final recipeName =
              activeEntry != null ? _getRecipeName(activeEntry.recipeId) : null;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MealTile(
              mealLabel: m['label'],
              icon: m['icon'],
              recipeId: activeEntry?.recipeId,
              recipeName: recipeName,
              matchPercentage: _getMatchPercentage(activeEntry?.recipeId),
              onTap: activeEntry != null
                  ? () => onTapRecipe(activeEntry)
                  : () => onAssignEmpty(day, m['type'].toString()),
              onClear:
                  activeEntry != null ? () => onClearSlot(activeEntry) : null,
            ),
          );
        }),
      ],
    );
  }
}

class _MealTile extends StatelessWidget {
  final String mealLabel;
  final String icon;
  final String? recipeId;
  final String? recipeName;
  final int matchPercentage;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const _MealTile({
    required this.mealLabel,
    required this.icon,
    required this.recipeId,
    this.recipeName,
    this.matchPercentage = 0,
    this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasRecipe = recipeId != null && recipeId!.isNotEmpty;
    return GestureDetector(
      onTap: onTap, // Always tappable now
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasRecipe
              ? Theme.of(context).cardColor
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: hasRecipe
                  ? const Color(0xFF00E676)
                  : const Color(0xFFFF9800).withAlpha(60)),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mealLabel,
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                      recipeName ??
                          (hasRecipe ? 'Receta asignada' : 'Sin planificar'),
                      style: TextStyle(
                          color: hasRecipe
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.45),
                          fontSize: 14,
                          fontWeight:
                              hasRecipe ? FontWeight.w500 : FontWeight.normal),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(hasRecipe ? Icons.check_circle : Icons.add_circle_outline,
                color: hasRecipe
                    ? const Color(0xFF00E676)
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3)),
            if (hasRecipe) ...[
              const SizedBox(width: 8),
              Text(
                '$matchPercentage%',
                style: TextStyle(
                    color: matchPercentage == 100
                        ? const Color(0xFF00E676)
                        : matchPercentage >= 50
                            ? const Color(0xFFFFB300)
                            : const Color(0xFFFF5252),
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
              if (onClear != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.only(left: 4),
                  constraints: const BoxConstraints(),
                  tooltip: 'Quitar del plan',
                  icon: Icon(Icons.close,
                      size: 18,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.45)),
                  onPressed: onClear,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows recipes cooked in the last 7 days to help plan variety
class _CookingHistoryBanner extends StatefulWidget {
  @override
  State<_CookingHistoryBanner> createState() => _CookingHistoryBannerState();
}

class _CookingHistoryBannerState extends State<_CookingHistoryBanner> {
  late Future<List<String>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = CookingHistoryService().getRecentRecipeNames(days: 7);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final recentRecipes = snapshot.data!;
        if (recentRecipes.isEmpty) {
          final theme = Theme.of(context);
          final onSurface = theme.colorScheme.onSurface;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: onSurface.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.history,
                    color: onSurface.withValues(alpha: 0.45), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Aún no has cocinado esta semana. ¡Empieza a planificar!',
                    style: TextStyle(
                        color: onSurface.withValues(alpha: 0.6), fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9800).withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFF9800).withAlpha(60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.history, color: Color(0xFFFF9800), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Cocinado esta semana:',
                    style: TextStyle(
                        color: Color(0xFFFF9800),
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: recentRecipes
                    .map((name) => Chip(
                          label: Text(name,
                              style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      Theme.of(context).colorScheme.onSurface)),
                          backgroundColor:
                              const Color(0xFFFF9800).withAlpha(40),
                          labelPadding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 0),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WeeklyBudgetBanner extends StatelessWidget {
  final int missingCount;
  final GroceryBudgetEstimate estimate;
  final VoidCallback onSendToShoppingList;

  const _WeeklyBudgetBanner({
    required this.missingCount,
    required this.estimate,
    required this.onSendToShoppingList,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    const accent = Color(0xFF00C896);
    final hasEstimate = estimate.pricedCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.savings_outlined, color: accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasEstimate
                      ? 'Estimado faltante: ${estimate.currency} ${estimate.totalEstimated.toStringAsFixed(2)}'
                      : '$missingCount ingredientes faltantes esta semana',
                  style: TextStyle(
                    color: onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  hasEstimate
                      ? '${estimate.pricedCount}/$missingCount con precio histórico WalletAI'
                      : 'Registra compras en WalletAI para estimar el costo semanal',
                  style: TextStyle(
                    color: onSurface.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onSendToShoppingList,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'A Lista',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
