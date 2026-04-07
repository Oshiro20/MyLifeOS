import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:core/core.dart';
import 'package:armario/armario.dart';
import 'package:cocina/cocina.dart';
import 'package:foodcoach/foodcoach.dart';
import '../services/mylifeos_update_service.dart';
import '../widgets/update_dialog.dart';
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

    return Scaffold(
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
                          const Text('Joel',
                              style: TextStyle(
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

                  // ── Score de bienestar ──────────────────────────────────────
                  _WellbeingCard(isDark: isDark, primary: primary),
                  const SizedBox(height: 20),

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
    final outfitsCount = armarioState.outfits.length;

    final avgScore = foodCoachState.weeklyStats?.averageHealthScore ?? 0.0;
    final healthStr =
        avgScore > 0 ? '${(avgScore * 100).toStringAsFixed(0)}%' : 'N/A';

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
                Text('Vas por buen camino hoy',
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
          // Score circular
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 0.85,
                  strokeWidth: 7,
                  backgroundColor: primary.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(primary),
                  strokeCap: StrokeCap.round,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('85',
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
class _RecentActivity extends StatelessWidget {
  final bool isDark;
  final Color primary;
  const _RecentActivity({required this.isDark, required this.primary});

  static const _items = [
    ('💰', 'Café Starbucks', 'Finanzas · 10:30 AM', '-S/4.50', false),
    ('👗', "Outfit 'Cena' guardado", 'Armario · 08:15 AM', '', null),
    ('💧', 'Agua 500ml registrada', 'FoodCoach · 07:45 AM', '', null),
  ];

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF152019) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: List.generate(_items.length, (i) {
          final item = _items[i];
          final isLast = i == _items.length - 1;
          return Column(
            children: [
              ListTile(
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
                    child: Text(item.$1, style: const TextStyle(fontSize: 16)),
                  ),
                ),
                title: Text(item.$2,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text(item.$3,
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.45),
                        fontSize: 11)),
                trailing: item.$4.isNotEmpty
                    ? Text(item.$4,
                        style: const TextStyle(
                            color: Color(0xFFFF6B6B),
                            fontWeight: FontWeight.w700,
                            fontSize: 13))
                    : null,
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
