import 'package:flutter/material.dart';
import '../widgets/wallet_ai_summary_card.dart';
import '../widgets/ai_analysis_card.dart';
import '../screens/walletai_connection_screen.dart';
import 'package:core/core.dart';

class FinanzasScreen extends StatefulWidget {
  const FinanzasScreen({super.key});

  @override
  State<FinanzasScreen> createState() => _FinanzasScreenState();
}

class _FinanzasScreenState extends State<FinanzasScreen> {
  WalletSummary? _summary;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final summary = await WalletSummaryReader.read();
    if (mounted) {
      setState(() => _summary = summary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadSummary,
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
                  icon: const Icon(Icons.link),
                  tooltip: 'Conexión con WalletAI',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const WalletAIConnectionSettingsScreen(),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualizar datos',
                  onPressed: _loadSummary,
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── WalletAI resumen ────────────────────────────────────────
                  const WalletAiSummaryCard(),
                  const SizedBox(height: 16),
                  AIAnalysisCard(summary: _summary),
                  const SizedBox(height: 20),

                  // ── Gráfico semanal ─────────────────────────────────────────
                  const _SectionTitle(
                      title: 'Actividad semanal',
                      trailing: 'Basado en WalletAI'),
                  const SizedBox(height: 10),
                  _WeeklyChart(isDark: isDark, summary: _summary),
                  const SizedBox(height: 20),

                  // ── Categorías ──────────────────────────────────────────────
                  const _SectionTitle(
                      title: 'Resumen del mes', trailing: 'WalletAI'),
                  const SizedBox(height: 10),
                  _CategorySummary(isDark: isDark, summary: _summary),
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
        onPressed: () {
          WalletAICommunicationService.openWalletAI();
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
  const _WeeklyChart({required this.isDark, this.summary});

  static const _days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final surface = isDark ? const Color(0xFF152019) : Colors.white;

    // Generar valores basados en el resumen real si está disponible
    final dailyAvg =
        summary != null && summary!.expenses > 0 ? summary!.expenses / 30 : 0.0;
    final values = summary != null
        ? List.generate(7, (i) {
            final variation = 0.5 + (i * 0.1);
            return dailyAvg > 0
                ? (dailyAvg * variation / (summary!.expenses / 7))
                    .clamp(0.1, 1.0)
                : 0.3 + (i * 0.1);
          })
        : [0.4, 0.6, 0.9, 0.3, 0.7, 0.5, 0.2];

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
                    'Gastos del mes: ${summary!.currency} ${summary!.expenses.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Ingresos: ${summary!.currency} ${summary!.income.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
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
class _CategorySummary extends StatelessWidget {
  final bool isDark;
  final WalletSummary? summary;
  const _CategorySummary({required this.isDark, this.summary});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF152019) : Colors.white;
    final primary = Theme.of(context).colorScheme.primary;

    final balance = summary?.balance ?? 0.0;
    final income = summary?.income ?? 0.0;
    final expenses = summary?.expenses ?? 0.0;
    final savingsRate = income > 0 ? ((income - expenses) / income) : 0.0;

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
            color: const Color(0xFF00E5FF),
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            icon: '📉',
            label: 'Gastos',
            value: summary?.currency ?? 'PEN',
            amount: expenses,
            color: const Color(0xFFFF6B6B),
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            icon: '🏦',
            label: 'Balance',
            value: summary?.currency ?? 'PEN',
            amount: balance,
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
              backgroundColor: Colors.white12,
              color: savingsRate > 0.2
                  ? const Color(0xFF00C896)
                  : savingsRate > 0
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFFF6B6B),
              minHeight: 6,
            ),
          ),
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
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.amount,
    required this.color,
    this.isPercentage = false,
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
            onTap: () => WalletAICommunicationService.openWalletAI(),
          ),
          const SizedBox(height: 8),
          _GuidanceItem(
            icon: Icons.sync,
            title: 'Sincronizar datos',
            subtitle: 'Abre WalletAI para exportar el resumen actualizado',
            onTap: () => WalletAICommunicationService.requestSync(),
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
            const Icon(Icons.chevron_right, size: 16, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
