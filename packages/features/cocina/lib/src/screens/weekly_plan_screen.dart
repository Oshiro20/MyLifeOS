import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';
import 'package:data/data.dart';
import '../providers/cocina_providers.dart';
import '../utils/cooking_history_service.dart';
import 'suggestions_tab.dart';

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
        title: const Text('📅 Menú Semanal',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
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
                    // First item: cooking history banner
                    if (i == 0) {
                      return _CookingHistoryBanner();
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
                      onAssignEmpty: (d, mealType) => _showRecipePicker(
                          context, d, mealType, state.entries),
                    );
                  },
                )
              : const Center(child: Text('Error cargando menú')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _generateMenu(context),
        label: const Text('Planificar Semana'),
        icon: const Icon(Icons.auto_awesome),
        backgroundColor: const Color(0xFF00E676),
      ),
    );
  }

  Future<void> _generateMenu(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152019),
        title: const Text('¿Generar Menú Semanal?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Se armará un menú variado para la semana usando tus recetas guardadas. ¿Continuar?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Generar')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(weeklyMenuProvider.notifier).generate();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('✅ Menú semanal generado'),
                backgroundColor: Color(0xFF00E676)),
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

  void _showRecipeDetail(BuildContext context, dynamic recipe) {
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
      List<dynamic> currentEntries) async {
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
      backgroundColor: const Color(0xFF152019),
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
                itemBuilder: (ctx, i) => ListTile(
                  title: Text(allRecipes[i].name,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text('${allRecipes[i].durationMinutes} min',
                      style: const TextStyle(color: Colors.white54)),
                  trailing: const Icon(Icons.add_circle_outline,
                      color: Color(0xFF00E676)),
                  onTap: () => Navigator.pop(ctx, allRecipes[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      // Save to weekly menu
      final repo = ref.read(cocinaRepositoryProvider);
      await repo.saveWeeklyMenuEntry(WeeklyMenuEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        dayOfWeek: day,
        mealType: int.parse(mealType),
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
  final List<dynamic> entries;
  final List<Recipe> recipes;
  final List<InventoryIngredient> inventory;
  final int day;
  final Function(dynamic recipe) onTapRecipe;
  final Function(int day, String mealType) onAssignEmpty;

  const _DaySection({
    required this.dayLabel,
    required this.meals,
    required this.entries,
    required this.recipes,
    required this.inventory,
    required this.day,
    required this.onTapRecipe,
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
          dynamic entry;
          try {
            entry = dayEntries.firstWhere((e) => e.mealType == m['type']);
          } catch (e) {
            entry = null;
          }

          final recipeName = entry != null && entry.recipeId.isNotEmpty
              ? _getRecipeName(entry.recipeId)
              : null;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MealTile(
              mealLabel: m['label'],
              icon: m['icon'],
              recipeId: entry?.recipeId,
              recipeName: recipeName,
              matchPercentage: _getMatchPercentage(entry?.recipeId),
              onTap: entry != null && entry.recipeId.isNotEmpty
                  ? () => onTapRecipe(entry)
                  : () => onAssignEmpty(day, m['type'].toString()),
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

  const _MealTile({
    required this.mealLabel,
    required this.icon,
    required this.recipeId,
    this.recipeName,
    this.matchPercentage = 0,
    this.onTap,
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
              ? const Color(0xFF152019)
              : const Color(0xFF2A2A40).withAlpha(100),
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
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                      recipeName ??
                          (hasRecipe ? 'Receta asignada' : 'Sin planificar'),
                      style: TextStyle(
                          color: hasRecipe ? Colors.white : Colors.white38,
                          fontSize: 14,
                          fontWeight:
                              hasRecipe ? FontWeight.w500 : FontWeight.normal),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(hasRecipe ? Icons.check_circle : Icons.add_circle_outline,
                color: hasRecipe ? const Color(0xFF00E676) : Colors.white24),
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
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A40),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Row(
              children: [
                Icon(Icons.history, color: Colors.white38, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Aún no has cocinado esta semana. ¡Empieza a planificar!',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
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
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white)),
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
