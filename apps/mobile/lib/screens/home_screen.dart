import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:core/core.dart';
import 'package:domain/domain.dart';
import 'package:armario/armario.dart';
import 'package:cocina/cocina.dart';
import 'package:foodcoach/foodcoach.dart';
import '../services/mylifeos_update_service.dart';
import '../widgets/update_dialog.dart';
import '../widgets/ai_dashboard_cards.dart';
import 'search_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _newVersion;

  @override
  void initState() {
    super.initState();
    _checkOtaUpdates();
  }

  Future<void> _checkOtaUpdates() async {
    final updateService = MyLifeOSUpdateService();
    final release = await updateService.checkForUpdate();

    if (release != null && mounted) {
      // Verificar si ya se notificó esta versión
      final lastNotified = await MyLifeOSUpdateService.getLastNotifiedVersion();

      if (lastNotified != release.tagName) {
        setState(() => _newVersion = release.tagName);

        // Guardar que ya se notificó
        await MyLifeOSUpdateService.setLastNotifiedVersion(release.tagName);

        // Mostrar diálogo con descarga automática
        if (mounted) {
          showMyLifeOSUpdateDialog(
            context,
            release,
            onDismiss: () => setState(() => _newVersion = null),
          );
        }
      } else {
        // Ya se notificó, pero aún mostrar banner si hay actualización pendiente
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;
        final latestVersion = release.tagName.replaceAll('v', '');

        if (_isVersionGreater(latestVersion, currentVersion) && mounted) {
          setState(() => _newVersion = release.tagName);
        }
      }
    }
  }

  bool _isVersionGreater(String latest, String current) {
    final latestParts =
        latest.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final currentParts =
        current.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    for (var i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length) return true;
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  void _showNotificationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152019),
        title: const Text('🔔 Notificaciones',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'No hay notificaciones nuevas.\n\nLas notificaciones de actualizaciones y recordatorios aparecerán aquí.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar',
                style: TextStyle(color: Color(0xFF00C896))),
          ),
        ],
      ),
    );
  }

  void _showAssistantChatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AssistantChatSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Buenos días'
        : hour < 18
            ? 'Buenas tardes'
            : 'Buenas noches';

    final userName = ref.watch(userDisplayNameProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAssistantChatSheet(context),
        backgroundColor: const Color(0xFF00C896),
        label: const Text('Asistente IA',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
      body: RefreshIndicator(
        color: primary,
        backgroundColor: isDark ? const Color(0xFF152019) : Colors.white,
        onRefresh: () async {
          ref.invalidate(armarioProvider);
          ref.invalidate(recipesProvider);
          ref.invalidate(foodCoachProvider);
          await Future.delayed(const Duration(milliseconds: 800));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            // ── Header ────────────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: primary.withValues(alpha: 0.2),
                        child: Icon(Icons.person_outline,
                            color: primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(greeting,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                  fontSize: 13)),
                          Text(userName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 20)),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.search_rounded),
                        tooltip: 'Búsqueda global',
                        onPressed: () => showSearch(
                          context: context,
                          delegate: MyLifeOSSearchDelegate(ref),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        tooltip: 'Notificaciones',
                        onPressed: () => _showNotificationsDialog(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Banner de actualización ─────────────────────────────────
                  if (_newVersion != null) _UpdateBanner(version: _newVersion!),
                  if (_newVersion != null) const SizedBox(height: 12),

                  // ── Insight del Día AI (Novedad Phase 2) ───────────────────────────
                  const InsightDelDiaCard(),
                  const SizedBox(height: 20),

                  // ── Score de bienestar ──────────────────────────────────────
                  _WellbeingCard(isDark: isDark, primary: primary),
                  const SizedBox(height: 20),

                  // ── Outfit del Día AI ───────────────────────────────────────
                  const OutfitAIPreviewCard(),
                  const SizedBox(height: 12),

                  // ── Acceso rápido ───────────────────────────────────────────
                  const Text('Módulos',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 12),
                  _QuickAccessGrid(),
                  const SizedBox(height: 20),

                  // ── WalletAI resumen ────────────────────────────────────────
                  const Text('Finanzas',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 12),
                  _FinanceSummary(isDark: isDark, primary: primary),
                  const SizedBox(height: 12),
                  const FinanceHealthCard(),
                  const SizedBox(height: 20),

                  // ── Actividad reciente ──────────────────────────────────────
                  const Text('Actividad reciente',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 12),
                  _RecentActivity(isDark: isDark, primary: primary),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Wellbeing card ────────────────────────────────────────────────────────────
class _WellbeingCard extends ConsumerWidget {
  final bool isDark;
  final Color primary;
  const _WellbeingCard({required this.isDark, required this.primary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final armarioState = ref.watch(armarioProvider);
    final foodCoachState = ref.watch(foodCoachProvider);
    final invState = ref.watch(inventoryProvider);
    final outfitsCount = armarioState.outfits.length;

    final avgScore = foodCoachState.weeklyStats?.averageHealthScore ?? 0.0;
    final healthStr =
        avgScore > 0 ? '${(avgScore * 100).toStringAsFixed(0)}%' : 'N/A';

    // Calcular score real ponderado según los módulos con datos
    final scores = <double>[];
    if (avgScore > 0) {
      scores.add(avgScore.clamp(0.0, 1.0));
    }
    if (armarioState.garments.isNotEmpty) {
      final cleanCount = armarioState.garments.where((g) => g.isClean).length;
      scores.add(cleanCount / armarioState.garments.length);
    }
    if (invState.ingredients.isNotEmpty) {
      final freshCount =
          invState.ingredients.where((i) => !i.isExpired).length;
      scores.add(freshCount / invState.ingredients.length);
    }

    final hasData = scores.isNotEmpty;
    final computedScore = hasData
        ? (scores.reduce((a, b) => a + b) / scores.length).clamp(0.0, 1.0)
        : 0.0;
    final scoreInt = (computedScore * 100).round();

    final statusSubtitle = !hasData
        ? 'Registra datos en tus módulos para calcularlo'
        : scoreInt >= 80
            ? 'Excelente equilibrio en tus módulos'
            : scoreInt >= 50
                ? 'Buen ritmo, sigue cuidando tus hábitos'
                : 'Hay aspectos por mejorar hoy';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF152019), const Color(0xFF1A2E22)]
              : [Colors.white, const Color(0xFFEEF5F2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tu día en balance',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 4),
                Text(statusSubtitle,
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                        fontSize: 13)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _StatPill(
                        label: 'Armario',
                        value: '$outfitsCount outfits',
                        color: primary),
                    const SizedBox(width: 8),
                    _StatPill(
                        label: 'Salud',
                        value: healthStr,
                        color: const Color(0xFFFF6B6B)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Score circular real
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: hasData ? computedScore : 0.0,
                  strokeWidth: 7,
                  backgroundColor: primary.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(primary),
                  strokeCap: StrokeCap.round,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(hasData ? '$scoreInt' : '--',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            color: primary)),
                    Text('/100',
                        style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.4))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style:
                  TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10)),
          const SizedBox(width: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Quick access grid ─────────────────────────────────────────────────────────
class _QuickAccessGrid extends ConsumerStatefulWidget {
  @override
  ConsumerState<_QuickAccessGrid> createState() => _QuickAccessGridState();
}

class _QuickAccessGridState extends ConsumerState<_QuickAccessGrid> {
  WalletSummary? _walletSummary;

  @override
  void initState() {
    super.initState();
    WalletSummaryReader.read().then((v) {
      if (mounted) setState(() => _walletSummary = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF152019) : Colors.white;

    final armarioState = ref.watch(armarioProvider);
    final recipesState = ref.watch(recipesProvider);
    final foodCoachState = ref.watch(foodCoachProvider);

    final String armarioData = '${armarioState.outfits.length} outfits';
    final String cocinaData = '${recipesState.recipes.length} recetas';

    // Count meals in history for now (since MealLog doesn't have nutritionInfo directly)
    final mealCount = foodCoachState.history.length;
    final String foodCoachData =
        mealCount > 0 ? '$mealCount comidas registradas' : '0 kcal';

    final String finanzasData = _walletSummary != null
        ? '${_walletSummary!.currency} ${_walletSummary!.balance.toStringAsFixed(0)}'
        : 'S/ 0';

    final modules = [
      (
        '/armario',
        Icons.checkroom_outlined,
        'Armario',
        armarioData,
        const Color(0xFF00C896)
      ),
      (
        '/cocina',
        Icons.soup_kitchen_outlined,
        'Cocina',
        cocinaData,
        const Color(0xFFF59E0B)
      ),
      (
        '/finanzas',
        Icons.account_balance_wallet_outlined,
        'Finanzas',
        finanzasData,
        const Color(0xFF06B6D4)
      ),
      (
        '/foodcoach',
        Icons.restaurant_menu_outlined,
        'FoodCoach',
        foodCoachData,
        const Color(0xFFFF6B6B)
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: modules.map((m) {
        return GestureDetector(
          onTap: () => context.go(m.$1),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border(left: BorderSide(color: m.$5, width: 3)),
              boxShadow: [
                BoxShadow(
                  color: m.$5.withValues(alpha: isDark ? 0.1 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(m.$2, color: m.$5, size: 22),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.$4,
                        style: TextStyle(
                            color: m.$5,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    Text(m.$3,
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                            fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Finance summary ───────────────────────────────────────────────────────────
class _FinanceSummary extends StatefulWidget {
  final bool isDark;
  final Color primary;
  const _FinanceSummary({required this.isDark, required this.primary});

  @override
  State<_FinanceSummary> createState() => _FinanceSummaryState();
}

class _FinanceSummaryState extends State<_FinanceSummary> {
  WalletSummary? _summary;

  @override
  void initState() {
    super.initState();
    WalletSummaryReader.read().then((s) {
      if (mounted) setState(() => _summary = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.isDark ? const Color(0xFF152019) : Colors.white;

    if (_summary == null) {
      return GestureDetector(
        onTap: () => context.go('/finanzas'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.primary.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  color: widget.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Ver resumen financiero',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.chevron_right, color: widget.primary),
            ],
          ),
        ),
      );
    }

    final s = _summary!;
    final isPositive = s.balance >= 0;

    return GestureDetector(
      onTap: () => context.go('/finanzas'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.primary.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                color: widget.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s.currency} ${s.balance.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: isPositive
                              ? const Color(0xFF00C896)
                              : const Color(0xFFFF6B6B),
                          fontWeight: FontWeight.w700,
                          fontSize: 18)),
                  Text('Balance · ${s.month}',
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                          fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: widget.primary),
          ],
        ),
      ),
    );
  }
}

// ── Recent activity ───────────────────────────────────────────────────────────
class _RecentActivity extends ConsumerWidget {
  final bool isDark;
  final Color primary;
  const _RecentActivity({required this.isDark, required this.primary});

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes.clamp(1, 59)} min';
    }
    if (diff.inHours < 24) {
      return 'Hace ${diff.inHours} h';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = isDark ? const Color(0xFF152019) : Colors.white;
    final foodCoachState = ref.watch(foodCoachProvider);
    final armarioState = ref.watch(armarioProvider);
    final recipesState = ref.watch(recipesProvider);

    final events = <({
      String emoji,
      String title,
      String subtitle,
      DateTime date,
      String route,
    })>[
      for (final meal in foodCoachState.history.take(3))
        (
          emoji: '🥗',
          title: switch (meal.classification) {
            FoodClassification.healthy => 'Comida saludable (${(meal.healthScore * 100).round()}%)',
            FoodClassification.balanced => 'Comida balanceada (${(meal.healthScore * 100).round()}%)',
            FoodClassification.junk => 'Comida chatarra (${(meal.healthScore * 100).round()}%)',
          },
          subtitle: 'FoodCoach · ${_formatDate(meal.timestamp)}',
          date: meal.timestamp,
          route: '/foodcoach',
        ),
      for (final outfit in armarioState.outfits.take(3))
        (
          emoji: '👗',
          title: "Outfit '${outfit.name}'",
          subtitle: 'Armario · ${_formatDate(outfit.createdAt)}',
          date: outfit.createdAt,
          route: '/armario',
        ),
      for (final garment in armarioState.garments.take(3))
        (
          emoji: '👕',
          title: garment.name,
          subtitle: 'Prenda en Armario · ${_formatDate(garment.addedAt)}',
          date: garment.addedAt,
          route: '/armario',
        ),
      for (final recipe in recipesState.recipes.take(3))
        (
          emoji: '🍽️',
          title: recipe.name,
          subtitle: 'Receta en Cocina · ${_formatDate(recipe.createdAt)}',
          date: recipe.createdAt,
          route: '/cocina',
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    final recent = events.take(4).toList();

    if (recent.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primary.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(Icons.history_toggle_off,
                color: primary.withValues(alpha: 0.7), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Aún no hay actividad reciente. Registra una prenda, receta o comida para ver tu historial aquí.',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: List.generate(recent.length, (i) {
          final item = recent[i];
          final isLast = i == recent.length - 1;
          return Column(
            children: [
              ListTile(
                onTap: () => context.go(item.route),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(item.emoji, style: const TextStyle(fontSize: 16)),
                  ),
                ),
                title: Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text(item.subtitle,
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.45),
                        fontSize: 11)),
                trailing: Icon(Icons.chevron_right,
                    size: 18, color: primary.withValues(alpha: 0.5)),
              ),
              if (!isLast)
                Divider(
                    height: 1,
                    indent: 70,
                    color: primary.withValues(alpha: 0.08)),
            ],
          );
        }),
      ),
    );
  }
}

// ── Asistente IA Modal Sheet ──────────────────────────────────────────────────
class _AssistantChatSheet extends ConsumerStatefulWidget {
  const _AssistantChatSheet();

  @override
  ConsumerState<_AssistantChatSheet> createState() =>
      _AssistantChatSheetState();
}

class _AssistantChatSheetState extends ConsumerState<_AssistantChatSheet> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty) return;
    if (preset == null) _ctrl.clear();

    final summary = await WalletSummaryReader.read();
    final walletCtx = summary != null
        ? 'Balance ${summary.currency} ${summary.balance.toStringAsFixed(2)}, '
            'Ingresos ${summary.income.toStringAsFixed(2)}, '
            'Gastos ${summary.expenses.toStringAsFixed(2)} (${summary.month})'
        : null;

    final armarioState = ref.read(armarioProvider);
    final outfitCtx = armarioState.outfits.isNotEmpty
        ? 'Último outfit: ${armarioState.outfits.first.name}'
        : null;

    await ref.read(aiChatProvider.notifier).sendMessage(
          text,
          walletContext: walletCtx,
          outfitContext: outfitCtx,
        );

    if (mounted && _scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(aiChatProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: Color(0xFF00C896), size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Asistente MyLifeOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (messages.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.white54, size: 20),
                      tooltip: 'Limpiar chat',
                      onPressed: () =>
                          ref.read(aiChatProvider.notifier).clearHistory(),
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Pregúntame sobre tu armario, recetas, nutrición o finanzas.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                ActionChip(
                                  label: const Text('¿Qué me pongo hoy?'),
                                  onPressed: () => _send('¿Qué me pongo hoy?'),
                                ),
                                ActionChip(
                                  label: const Text('Tip de ahorro del mes'),
                                  onPressed: () =>
                                      _send('Dame un tip de ahorro para este mes'),
                                ),
                                ActionChip(
                                  label: const Text('Idea rápida de cena'),
                                  onPressed: () =>
                                      _send('Sugiéreme una cena ligera y saludable'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (ctx, i) {
                        final msg = messages[i];
                        return Align(
                          alignment: msg.isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.78,
                            ),
                            decoration: BoxDecoration(
                              color: msg.isUser
                                  ? const Color(0xFF00C896)
                                  : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: msg.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF00C896),
                                    ),
                                  )
                                : Text(
                                    msg.content,
                                    style: TextStyle(
                                      color: msg.isUser
                                          ? Colors.black
                                          : Colors.white,
                                      fontSize: 13.5,
                                      height: 1.4,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(color: Colors.white),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Escribe tu consulta...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _send(),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF00C896),
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner de actualización visible en el home
class _UpdateBanner extends StatelessWidget {
  final String version;
  const _UpdateBanner({required this.version});

  Future<void> _startUpdate(BuildContext context) async {
    final updateService = MyLifeOSUpdateService();
    final release = await updateService.checkForUpdate();
    if (release != null && context.mounted) {
      showMyLifeOSUpdateDialog(context, release);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _startUpdate(context),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF00C896).withValues(alpha: 0.15),
              const Color(0xFF00E5FF).withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFF00C896).withValues(alpha: 0.3),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00C896).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.system_update,
                  color: Color(0xFF00C896), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✨ Actualización disponible',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Versión $version lista para descargar',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF00C896), size: 20),
          ],
        ),
      ),
    );
  }
}
