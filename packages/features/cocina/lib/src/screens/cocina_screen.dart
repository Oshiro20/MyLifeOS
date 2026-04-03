import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.kitchen_outlined, size: 20), text: 'Despensa'),
            Tab(icon: Icon(Icons.menu_book_outlined, size: 20), text: 'Recetas'),
            Tab(icon: Icon(Icons.lightbulb_outline, size: 20), text: 'Sugeridas'),
            Tab(icon: Icon(Icons.shopping_cart_outlined, size: 20), text: 'Lista'),
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
    );
  }
}
