import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'wardrobe_tab.dart';
import 'outfits_tab.dart';
import 'suggestions_outfit_tab.dart';
import 'dashboard_tab.dart';

class ArmarioScreen extends ConsumerStatefulWidget {
  const ArmarioScreen({super.key});

  @override
  ConsumerState<ArmarioScreen> createState() => _ArmarioScreenState();
}

class _ArmarioScreenState extends ConsumerState<ArmarioScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
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
          'Armario 👔',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFF00C896),
          labelColor: const Color(0xFF00C896),
          unselectedLabelColor: Colors.white38,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.home_filled, size: 20), text: 'Inicio'),
            Tab(icon: Icon(Icons.checkroom_outlined, size: 20), text: 'Ropa'),
            Tab(icon: Icon(Icons.snowshoeing, size: 20), text: 'Calzado'),
            Tab(icon: Icon(Icons.style_outlined, size: 20), text: 'Outfits'),
            Tab(icon: Icon(Icons.auto_awesome_outlined, size: 20), text: 'Asistente'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          DashboardTab(),
          WardrobeTab(filterByType: 'ropa'),
          WardrobeTab(filterByType: 'calzado'),
          OutfitsTab(),
          SuggestionsOutfitTab(),
        ],
      ),
    );
  }
}
