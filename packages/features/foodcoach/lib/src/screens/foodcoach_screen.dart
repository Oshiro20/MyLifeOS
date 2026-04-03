import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'evaluate_tab.dart';
import 'history_tab.dart';
import 'stats_tab.dart';

class FoodCoachScreen extends ConsumerStatefulWidget {
  const FoodCoachScreen({super.key});

  @override
  ConsumerState<FoodCoachScreen> createState() => _FoodCoachScreenState();
}

class _FoodCoachScreenState extends ConsumerState<FoodCoachScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
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
          'Food Coach 🥗',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFF00C896),
          labelColor: const Color(0xFF00C896),
          unselectedLabelColor: Colors.white38,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.restaurant_outlined, size: 20), text: 'Evaluar'),
            Tab(icon: Icon(Icons.history_outlined, size: 20), text: 'Historial'),
            Tab(icon: Icon(Icons.bar_chart_outlined, size: 20), text: 'Progreso'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          EvaluateTab(),
          HistoryTab(),
          StatsTab(),
        ],
      ),
    );
  }
}
