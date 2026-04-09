import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:domain/domain.dart';
import 'inventory_tab.dart';
import 'recipes_tab.dart';
import 'suggestions_tab.dart';
import 'antojos_tab.dart';
import 'shopping_tab.dart';
import 'weekly_plan_screen.dart';
import '../providers/cocina_providers.dart';

class CocinaScreen extends ConsumerStatefulWidget {
  const CocinaScreen({super.key});

  @override
  ConsumerState<CocinaScreen> createState() => _CocinaScreenState();
}

class _CocinaScreenState extends ConsumerState<CocinaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
    _tab.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _generateFromPantry() {
    // Switch to suggestions tab
    setState(() => _tab.index = 2);
    // Refresh suggestions
    ref.read(recipesProvider.notifier).refreshSuggestions();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🍳 Generando recetas desde tu despensa...'),
        backgroundColor: Color(0xFF00C896),
        duration: Duration(seconds: 2),
      ),
    );
  }

  List<Widget> _buildTabs(WidgetRef ref) {
    final invState = ref.watch(inventoryProvider);
    final expiringCount = invState.ingredients
        .where((i) => i.isExpired || i.isExpiringSoon)
        .length;

    return [
      Tab(
        icon: expiringCount > 0
            ? Badge(
                label: Text('$expiringCount',
                    style: const TextStyle(fontSize: 10)),
                backgroundColor: Colors.red,
                child: const Icon(Icons.kitchen_outlined, size: 20),
              )
            : const Icon(Icons.kitchen_outlined, size: 20),
        text: 'Despensa',
      ),
      const Tab(
          icon: Icon(Icons.menu_book_outlined, size: 20), text: 'Recetas'),
      const Tab(
          icon: Icon(Icons.lightbulb_outline, size: 20), text: 'Sugeridas'),
      const Tab(icon: Icon(Icons.cookie, size: 20), text: 'Antojos'),
      const Tab(
          icon: Icon(Icons.shopping_cart_outlined, size: 20), text: 'Lista'),
      const Tab(icon: Icon(Icons.calendar_month, size: 20), text: 'Plan'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final showFabs = _tab.index == 1;
    final showGenerate = _tab.index == 2;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: const Text(
          'Cocina 🍳',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          // Nutrition goal selector - always visible
          PopupMenuButton<NutritionGoal>(
            icon: const Icon(Icons.fitness_center, color: Color(0xFF00C896)),
            tooltip: 'Objetivo nutricional',
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: NutritionGoal.loseWeight,
                child: Row(
                  children: [
                    Text('🥗', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text('Adelgazar'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: NutritionGoal.maintain,
                child: Row(
                  children: [
                    Text('⚖️', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text('Mantener'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: NutritionGoal.gainMuscle,
                child: Row(
                  children: [
                    Text('💪', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text('Ganar músculo'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: NutritionGoal.other,
                child: Row(
                  children: [
                    Text('🍽️', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text('Otro'),
                  ],
                ),
              ),
            ],
            onSelected: (goal) {
              ref.read(recipesProvider.notifier).setGoal(goal);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Objetivo cambiado: ${goal.name}'),
                  backgroundColor: const Color(0xFF00C896),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFF00C896),
          labelColor: const Color(0xFF00C896),
          unselectedLabelColor: Colors.white38,
          isScrollable: false,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: _buildTabs(ref),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          const InventoryTab(),
          const RecipesTab(),
          const SuggestionsTab(),
          const AntojosTab(),
          const ShoppingTab(),
          const WeeklyPlanScreen(),
        ],
      ),
      floatingActionButton: showGenerate
          ? FloatingActionButton.extended(
              heroTag: 'generate_from_pantry',
              backgroundColor: const Color(0xFF00C896),
              onPressed: _generateFromPantry,
              icon: const Icon(Icons.auto_awesome, color: Colors.white),
              label: const Text('Generar desde Despensa',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : showFabs
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Chef IA FAB with label
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Chef IA',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FloatingActionButton(
                          heroTag: 'import_tiktok',
                          backgroundColor: const Color(0xFFFF4D4D),
                          onPressed: () {
                            context.go('/cocina/import');
                          },
                          child: const Icon(Icons.movie_outlined,
                              color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Add recipe FAB
                    FloatingActionButton(
                      heroTag: 'add_recipe',
                      backgroundColor: const Color(0xFF00C896),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Desliza hacia abajo en la lista de recetas para ver opciones'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ],
                )
              : null,
    );
  }
}
