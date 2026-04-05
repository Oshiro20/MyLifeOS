import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'inventory_tab.dart';
import 'recipes_tab.dart';
import 'suggestions_tab.dart';
import 'shopping_tab.dart';

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
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Solo mostrar FABs en el tab de Recetas (índice 1)
    final showFabs = _tab.index == 1;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: const Text(
          'Cocina 🍳',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFF00C896),
          labelColor: const Color(0xFF00C896),
          unselectedLabelColor: Colors.white38,
          isScrollable: false,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.kitchen_outlined, size: 20), text: 'Despensa'),
            Tab(
                icon: Icon(Icons.menu_book_outlined, size: 20),
                text: 'Recetas'),
            Tab(
                icon: Icon(Icons.lightbulb_outline, size: 20),
                text: 'Sugeridas'),
            Tab(
                icon: Icon(Icons.shopping_cart_outlined, size: 20),
                text: 'Lista'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          InventoryTab(),
          RecipesTab(),
          SuggestionsTab(),
          ShoppingTab(),
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
                  onPressed: () {
                    // Trigger the add recipe sheet via a provider or event
                    // For now, we'll use a simple approach
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
