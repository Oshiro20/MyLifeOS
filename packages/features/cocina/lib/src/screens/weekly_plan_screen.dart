import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';
import '../providers/cocina_providers.dart';
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
                  itemCount: days.length,
                  itemBuilder: (ctx, i) {
                    final day = i + 1;
                    return _DaySection(
                      dayLabel: days[i],
                      meals: meals,
                      entries: state.entries,
                      recipes: recipesState.recipes,
                      day: day,
                      onTapRecipe: (entry) => _showRecipeDetail(context, entry),
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
}

class _DaySection extends StatelessWidget {
  final String dayLabel;
  final List<Map<String, dynamic>> meals;
  final List<dynamic> entries;
  final List<Recipe> recipes;
  final int day;
  final Function(dynamic recipe) onTapRecipe;

  const _DaySection({
    required this.dayLabel,
    required this.meals,
    required this.entries,
    required this.recipes,
    required this.day,
    required this.onTapRecipe,
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
              onTap: entry != null && entry.recipeId.isNotEmpty
                  ? () => onTapRecipe(entry)
                  : null,
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
  final VoidCallback? onTap;

  const _MealTile({
    required this.mealLabel,
    required this.icon,
    required this.recipeId,
    this.recipeName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasRecipe = recipeId != null && recipeId!.isNotEmpty;
    return GestureDetector(
      onTap: hasRecipe ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasRecipe
              ? const Color(0xFF152019)
              : const Color(0xFF2A2A40).withAlpha(100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: hasRecipe ? const Color(0xFF00E676) : Colors.transparent),
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
          ],
        ),
      ),
    );
  }
}
