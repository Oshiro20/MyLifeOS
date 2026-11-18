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
    ref.listen<int>(cocinaTabProvider, (_, next) {
      if (next != _tab.index && next >= 0 && next < _tab.length && mounted) {
        _tab.animateTo(next);
      }
    });
    final showFabs = _tab.index == 1;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text(
          'Cocina 🍳',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Meta nutricional activa (sincronizada con Arma tu Menú)
          Builder(
            builder: (context) {
              final activeGoal =
                  ref.watch(recipesProvider.select((s) => s.activeGoal));
              const orderedGoals = [
                NutritionGoal.maintain,
                NutritionGoal.loseWeight,
                NutritionGoal.gainMuscle,
                NutritionGoal.light,
                NutritionGoal.other,
              ];
              return PopupMenuButton<NutritionGoal>(
                tooltip: 'Meta nutricional: ${activeGoal.label}',
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C896).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF00C896).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(activeGoal.emoji,
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(
                        activeGoal.label,
                        style: const TextStyle(
                          color: Color(0xFF00C896),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (context) => orderedGoals
                    .map(
                      (g) => PopupMenuItem<NutritionGoal>(
                        value: g,
                        child: Row(
                          children: [
                            Text(g.emoji, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(
                              g.label,
                              style: TextStyle(
                                fontWeight: g == activeGoal
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            if (g == activeGoal) ...[
                              const Spacer(),
                              const Icon(Icons.check,
                                  size: 16, color: Color(0xFF00C896)),
                            ],
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onSelected: (goal) {
                  ref.read(recipesProvider.notifier).setGoal(goal);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Meta nutricional: ${goal.emoji} ${goal.label}'),
                      backgroundColor: const Color(0xFF00C896),
                      duration: const Duration(milliseconds: 1400),
                    ),
                  );
                },
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFF00C896),
          labelColor: const Color(0xFF00C896),
          unselectedLabelColor:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
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
      floatingActionButton: showFabs
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
                        'Importar IA',
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
                      child:
                          const Icon(Icons.movie_outlined, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Add recipe FAB
                FloatingActionButton(
                  heroTag: 'add_recipe',
                  backgroundColor: const Color(0xFF00C896),
                  onPressed: () => RecipesTab.openAddRecipeSheet(context, ref),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            )
          : null,
    );
  }
}
