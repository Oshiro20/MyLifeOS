import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/wallet_ai_summary_card.dart';
import '../widgets/ai_analysis_card.dart';
import '../screens/walletai_connection_screen.dart';
import 'package:core/core.dart';

class FinanzasScreen extends ConsumerStatefulWidget {
  const FinanzasScreen({super.key});

  @override
  ConsumerState<FinanzasScreen> createState() => _FinanzasScreenState();
}

class _FinanzasScreenState extends ConsumerState<FinanzasScreen> {
  bool _hideAmounts = false;

  @override
  void initState() {
    super.initState();
    _loadPrivacy();
  }

  Future<void> _loadPrivacy() async {
    final hidden = await WalletPantryBridgeService.getHideAmounts();
    if (mounted && hidden != _hideAmounts) {
      setState(() => _hideAmounts = hidden);
    }
  }

  Future<void> _toggleHideAmounts() async {
    final next = !_hideAmounts;
    setState(() => _hideAmounts = next);
    await WalletPantryBridgeService.setHideAmounts(next);
  }

  Future<void> _refresh() async {
    ref.invalidate(walletSummaryProvider);
    await ref.read(walletSummaryProvider.future);
  }

  Future<void> _openConnectionSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const WalletAIConnectionSettingsScreen(),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = ref.watch(walletSummaryProvider).asData?.value;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFF00C896),
        child: CustomScrollView(
          slivers: [
            // ── AppBar ────────────────────────────────────────────────────────
            SliverAppBar(
              floating: true,
              snap: true,
              title: const Text('Finanzas',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
              actions: [
                IconButton(
                  icon: Icon(
                    _hideAmounts
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  tooltip: _hideAmounts ? 'Mostrar montos' : 'Modo discreto',
                  onPressed: _toggleHideAmounts,
                ),
                IconButton(
                  icon: const Icon(Icons.link),
                  tooltip: 'Conexión con WalletAI',
                  onPressed: _openConnectionSettings,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualizar datos',
                  onPressed: _refresh,
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── WalletAI resumen ────────────────────────────────────────
                  WalletAiSummaryCard(hideAmounts: _hideAmounts),
                  const SizedBox(height: 16),
                  AIAnalysisCard(summary: summary),
                  const SizedBox(height: 20),

                  // ── Gráfico semanal ─────────────────────────────────────────
                  const _SectionTitle(
                      title: 'Actividad semanal',
                      trailing: 'Basado en WalletAI'),
                  const SizedBox(height: 10),
                  _WeeklyChart(
                    isDark: isDark,
                    summary: summary,
                    hideAmounts: _hideAmounts,
                  ),
                  const SizedBox(height: 20),

                  // ── Categorías ──────────────────────────────────────────────
                  const _SectionTitle(
                      title: 'Resumen del mes', trailing: 'WalletAI'),
                  const SizedBox(height: 10),
                  _CategorySummary(
                    isDark: isDark,
                    summary: summary,
                    hideAmounts: _hideAmounts,
                  ),
                  const SizedBox(height: 20),

                  // ── Transacciones recientes ─────────────────────────────────
                  const _SectionTitle(
                    title: 'Información',
                    trailing: 'Administrar en WalletAI',
                  ),
                  const SizedBox(height: 10),
                  _WalletAIGuidance(isDark: isDark),
                ]),
              ),
            ),
          ],
        ),
      ),

      // ── FAB ───────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final ok = await WalletAICommunicationService.openWalletAI();
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'No se pudo abrir WalletAI. Verifica que esté instalada.'),
                backgroundColor: Colors.orangeAccent,
              ),
            );
          }
        },
        tooltip: 'Abrir WalletAI',
        child: const Icon(Icons.open_in_new),
      ),
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;

  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const Spacer(),
        if (trailing != null)
          GestureDetector(
            onTap: () {},
            child: Text(trailing!,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                )),
          ),
      ],
    );
  }
}

// ── Weekly chart ──────────────────────────────────────────────────────────────
class _WeeklyChart extends StatelessWidget {
  final bool isDark;
  final WalletSummary? summary;
  final bool hideAmounts;
  const _WeeklyChart({
    required this.isDark,
    this.summary,
    this.hideAmounts = false,
  });

  static const _days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final surface = isDark ? const Color(0xFF152019) : Colors.white;

    // Usar gastos reales de la semana si WalletAI los publicó
    final hasWeeklyData = summary != null && summary!.weeklyExpenses.length == 7;
    final rawWeekly = hasWeeklyData
        ? summary!.weeklyExpenses
        : const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    final maxWeekly = rawWeekly.fold<double>(0.0, (m, v) => v > m ? v : m);
    final values = hasWeeklyData
        ? rawWeekly
            .map((v) => maxWeekly > 0 ? (v / maxWeekly).clamp(0.08, 1.0) : 0.08)
            .toList()
        : const [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1];

    final today = DateTime.now().weekday - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primary.withValues(alpha: isDark ? 0.15 : 0.1),
        ),
      ),
      child: Column(
        children: [
          if (summary != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    hideAmounts
                        ? 'Gastos del mes: ${summary!.currency} ••••'
                        : 'Gastos del mes: ${summary!.currency} ${summary!.expenses.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF35594A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    hideAmounts
                        ? 'Ingresos: ${summary!.currency} ••••'
                        : 'Ingresos: ${summary!.currency} ${summary!.income.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF00E5FF)
                          : const Color(0xFF00838F),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_days.length, (i) {
                final isActive = i == today;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: Duration(milliseconds: 300 + i * 50),
                          height: 80 * values[i],
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: isActive
                                ? LinearGradient(
                                    colors: [
                                      primary,
                                      primary.withValues(alpha: 0.6)
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  )
                                : null,
                            color: isActive
                                ? null
                                : primary.withValues(alpha: 0.2),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                        color: primary.withValues(alpha: 0.4),
                                        blurRadius: 8)
                                  ]
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              _days.length,
              (i) => Expanded(
                child: Text(
                  _days[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        i == today ? FontWeight.w700 : FontWeight.normal,
                    color: i == today
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category summary ──────────────────────────────────────────────────────────
class _CategorySummary extends ConsumerStatefulWidget {
  final bool isDark;
  final WalletSummary? summary;
  final bool hideAmounts;
  const _CategorySummary({
    required this.isDark,
    this.summary,
    this.hideAmounts = false,
  });

  @override
  ConsumerState<_CategorySummary> createState() => _CategorySummaryState();
}

class _CategorySummaryState extends ConsumerState<_CategorySummary> {
  String _txFilter = 'relevantes';
  Set<String> _processedKeys = const {};
  bool _importingTx = false;

  @override
  void initState() {
    super.initState();
    _loadProcessedKeys();
  }

  Future<void> _loadProcessedKeys() async {
    final keys = await ref.read(walletGroceryBridgeProvider).loadProcessedTxKeys();
    if (mounted) {
      setState(() => _processedKeys = keys);
    }
  }

  Future<void> _sendTxToPantry(
    BuildContext context,
    Map<String, dynamic> tx,
    List<WalletGroceryCandidate> candidates,
  ) async {
    if (_importingTx || candidates.isEmpty) return;
    setState(() => _importingTx = true);
    try {
      final importer = ref.read(walletPantryDirectImportProvider);
      final key = candidates.first.transactionKey;
      int imported = 0;

      if (importer != null) {
        imported = await importer(candidates);
      } else {
        final priceNotifier = ref.read(ingredientPriceCatalogProvider.notifier);
        final bridge = ref.read(walletGroceryBridgeProvider);
        for (final c in candidates) {
          if (c.totalPrice != null && c.totalPrice! > 0) {
            await priceNotifier.recordPurchase(
              name: c.itemName,
              quantity: c.quantity,
              unit: c.unit,
              totalPrice: c.totalPrice!,
              currency: c.currency,
              source: 'walletai',
            );
          }
          imported++;
        }
        await bridge.markTxProcessed(key);
        ref.read(walletPendingGroceryRefreshProvider.notifier).bump();
      }

      await _loadProcessedKeys();
      if (context.mounted) {
        final names = candidates.map((c) => c.itemName).take(2).join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              imported > 0
                  ? '✅ Despensa actualizada: $names${candidates.length > 2 ? ' (+${candidates.length - 2})' : ''}'
                  : '✅ Precios registrados en catálogo ($names)',
            ),
            backgroundColor: const Color(0xFF00C896),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo enviar a Despensa: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _importingTx = false);
    }
  }

  List<Map<String, dynamic>> _filterTransactions(
    List<Map<String, dynamic>> txs,
  ) {
    if (_txFilter == 'todas') return txs.take(8).toList();
    return txs.where((tx) {
      final mod = WalletPantryBridgeService.classifyRelevantModule(tx);
      if (mod == null) return false;
      if (_txFilter == 'relevantes') return true;
      return mod == _txFilter;
    }).take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(walletPendingGroceryRefreshProvider);
    final isDark = widget.isDark;
    final summary = widget.summary;
    final hide = widget.hideAmounts;
    final surface = isDark ? const Color(0xFF152019) : Colors.white;
    final primary = Theme.of(context).colorScheme.primary;

    final balance = summary?.balance ?? 0.0;
    final income = summary?.income ?? 0.0;
    final expenses = summary?.expenses ?? 0.0;
    final savingsRate = income > 0 ? ((income - expenses) / income) : 0.0;
    final filteredTxs = summary != null
        ? _filterTransactions(summary.recentTransactions)
        : const <Map<String, dynamic>>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: primary.withValues(alpha: isDark ? 0.15 : 0.1)),
      ),
      child: Column(
        children: [
          _SummaryRow(
            icon: '💰',
            label: 'Ingresos',
            value: summary?.currency ?? 'PEN',
            amount: income,
            hideAmounts: hide,
            color: const Color(0xFF00E5FF),
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            icon: '📉',
            label: 'Gastos',
            value: summary?.currency ?? 'PEN',
            amount: expenses,
            hideAmounts: hide,
            color: const Color(0xFFFF6B6B),
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            icon: '🏦',
            label: 'Balance',
            value: summary?.currency ?? 'PEN',
            amount: balance,
            hideAmounts: hide,
            color: balance >= 0
                ? const Color(0xFF00C896)
                : const Color(0xFFFF6B6B),
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            icon: '📊',
            label: 'Tasa de ahorro',
            value: '',
            amount: savingsRate * 100,
            color: savingsRate > 0.2
                ? const Color(0xFF00C896)
                : savingsRate > 0
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFFF6B6B),
            isPercentage: true,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: savingsRate.clamp(0.0, 1.0),
              backgroundColor:
                  isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
              color: savingsRate > 0.2
                  ? const Color(0xFF00C896)
                  : savingsRate > 0
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFFF6B6B),
              minHeight: 6,
            ),
          ),
          if (summary != null && summary.byCategory.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(
                height: 1,
                color: isDark
                    ? Colors.white12
                    : Colors.black.withValues(alpha: 0.08)),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Top categorías del mes',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            const SizedBox(height: 10),
            ...summary.byCategory.take(5).map((cat) {
              final ratio = (cat.percentage / 100).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(cat.icon, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cat.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          hide
                              ? '${summary.currency} ••• (${cat.percentage.toStringAsFixed(0)}%)'
                              : '${summary.currency} ${cat.amount.toStringAsFixed(2)} (${cat.percentage.toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF35594A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 4,
                        backgroundColor: isDark
                            ? Colors.white12
                            : Colors.black.withValues(alpha: 0.06),
                        color: primary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (summary != null && summary.recentTransactions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(
                height: 1,
                color: isDark
                    ? Colors.white12
                    : Colors.black.withValues(alpha: 0.08)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Movimientos para MyLifeOS',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                GestureDetector(
                  onTap: () => WalletAICommunicationService.openWalletAI(),
                  child: Text(
                    'Ver todo en WalletAI ↗',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final option in const [
                    ('relevantes', 'Relevantes'),
                    ('cocina', '🍳 Cocina'),
                    ('armario', '👕 Armario'),
                    ('todas', 'Todas'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(option.$2,
                            style: const TextStyle(fontSize: 11)),
                        selected: _txFilter == option.$1,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onSelected: (_) =>
                            setState(() => _txFilter = option.$1),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (filteredTxs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Sin compras de Cocina, Armario o Salud en los últimos movimientos. Toca "Todas" para ver transferencias u otros gastos.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              )
            else
              ...filteredTxs.map((tx) {
                final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                final isIncome = amt >= 0;
                final txKey = WalletPantryBridgeService.txStableKey(tx);
                final candidates = WalletPantryBridgeService.extractCandidatesForTx(
                  tx,
                  currency: summary.currency,
                );
                final alreadyImported = _processedKeys.contains(txKey);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 14,
                        color: isIncome
                            ? const Color(0xFF00C896)
                            : const Color(0xFFFF6B6B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${tx['name'] ?? tx['description'] ?? 'Movimiento'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if ((tx['category'] ?? '').toString().isNotEmpty)
                              Text(
                                '${tx['category']}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (candidates.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        if (alreadyImported)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C896)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '✓ Despensa',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF00C896),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          InkWell(
                            onTap: _importingTx
                                ? null
                                : () => _sendTxToPantry(context, tx, candidates),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: primary.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Text(
                                '→ Despensa',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: primary,
                                ),
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        hide
                            ? '${summary.currency} •••'
                            : '${summary.currency} ${amt.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isIncome
                              ? const Color(0xFF00C896)
                              : const Color(0xFFFF6B6B),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final double amount;
  final Color color;
  final bool isPercentage;
  final bool hideAmounts;
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.amount,
    required this.color,
    this.isPercentage = false,
    this.hideAmounts = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        Text(
          isPercentage
              ? '${amount.toStringAsFixed(1)}%'
              : hideAmounts
                  ? '$value ••••'
                  : '$value ${amount.toStringAsFixed(2)}',
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ── WalletAI Guidance ─────────────────────────────────────────────────────────
class _WalletAIGuidance extends StatelessWidget {
  final bool isDark;
  const _WalletAIGuidance({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF152019) : Colors.white;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: primary.withValues(alpha: isDark ? 0.15 : 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💡 Gestión de Finanzas',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          _GuidanceItem(
            icon: Icons.account_balance_wallet,
            title: 'Abrir WalletAI',
            subtitle: 'Gestiona transacciones, categorías y presupuestos',
            onTap: () async {
              final ok = await WalletAICommunicationService.openWalletAI();
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'No se pudo abrir WalletAI. Verifica que esté instalada.'),
                    backgroundColor: Colors.orangeAccent,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          _GuidanceItem(
            icon: Icons.sync,
            title: 'Sincronizar datos',
            subtitle: 'Abre WalletAI para exportar el resumen actualizado',
            onTap: () async {
              final ok = await WalletAICommunicationService.requestSync();
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Solicitud local guardada, pero no se pudo abrir WalletAI.'),
                    backgroundColor: Colors.orangeAccent,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          _GuidanceItem(
            icon: Icons.settings,
            title: 'Configurar conexión',
            subtitle: 'Ver Project ID y estado de integración',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      const WalletAIConnectionSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GuidanceItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _GuidanceItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF00C896)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(subtitle,
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 16,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.35)),
          ],
        ),
      ),
    );
  }
}
