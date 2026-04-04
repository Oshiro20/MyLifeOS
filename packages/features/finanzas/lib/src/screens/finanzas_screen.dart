import 'package:flutter/material.dart';
import '../widgets/wallet_ai_summary_card.dart';

class FinanzasScreen extends StatelessWidget {
  const FinanzasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── AppBar ────────────────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            snap: true,
            title: const Text('Finanzas',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune_outlined),
                onPressed: () {},
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── WalletAI resumen ────────────────────────────────────────
                const WalletAiSummaryCard(),
                const SizedBox(height: 20),

                // ── Gráfico semanal ─────────────────────────────────────────
                _SectionTitle(
                    title: 'Actividad semanal',
                    trailing: 'Promedio: S/280/día'),
                const SizedBox(height: 10),
                _WeeklyChart(isDark: isDark),
                const SizedBox(height: 20),

                // ── Categorías ──────────────────────────────────────────────
                _SectionTitle(title: 'Categorías', trailing: 'Este mes'),
                const SizedBox(height: 10),
                _CategoryList(isDark: isDark),
                const SizedBox(height: 20),

                // ── Transacciones recientes ─────────────────────────────────
                _SectionTitle(
                  title: 'Transacciones recientes',
                  trailing: 'Ver todas',
                  onTrailingTap: () {},
                ),
                const SizedBox(height: 10),
                _RecentTransactions(isDark: isDark),
              ]),
            ),
          ),
        ],
      ),

      // ── FAB ───────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  const _SectionTitle({required this.title, this.trailing, this.onTrailingTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const Spacer(),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(trailing!,
                style: TextStyle(
                  color: onTrailingTap != null ? primary : Colors.grey,
                  fontSize: 12,
                  fontWeight: onTrailingTap != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                )),
          ),
      ],
    );
  }
}

// ── Weekly chart ──────────────────────────────────────────────────────────────
class _WeeklyChart extends StatelessWidget {
  final bool isDark;
  const _WeeklyChart({required this.isDark});

  static const _days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _values = [0.4, 0.6, 0.9, 0.3, 0.7, 0.5, 0.2];
  static const _activeDay = 2; // Miércoles activo

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final surface = isDark ? const Color(0xFF152019) : Colors.white;

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
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_days.length, (i) {
                final isActive = i == _activeDay;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: Duration(milliseconds: 300 + i * 50),
                          height: 80 * _values[i],
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
                        i == _activeDay ? FontWeight.w700 : FontWeight.normal,
                    color: i == _activeDay
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

// ── Category list ─────────────────────────────────────────────────────────────
class _CategoryList extends StatelessWidget {
  final bool isDark;
  const _CategoryList({required this.isDark});

  static const _categories = [
    ('🍔', 'Alimentación', 420.0, 1200.0, Color(0xFFF59E0B)),
    ('🚗', 'Transporte', 280.0, 800.0, Color(0xFF06B6D4)),
    ('🎮', 'Entretenimiento', 180.0, 500.0, Color(0xFFFF6B6B)),
    ('🏠', 'Hogar', 350.0, 900.0, Color(0xFF8B5CF6)),
  ];

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
        children: _categories.map((c) {
          final progress = c.$3 / c.$4;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(c.$1, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(c.$2,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    Text('S/ ${c.$3.toStringAsFixed(0)}',
                        style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: c.$5.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(c.$5),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Recent transactions ───────────────────────────────────────────────────────
class _RecentTransactions extends StatelessWidget {
  final bool isDark;
  const _RecentTransactions({required this.isDark});

  static const _txns = [
    ('Zara Fashion', 'Ropa', '13/03', -89.90, '👗'),
    ('Nómina MyLifeOS', 'Ingreso', '13/03', 2450.00, '💰'),
    ('Sushi Master', 'Alimentación', '13/03', -45.20, '🍣'),
    ('Luz y Agua', 'Hogar', '13/03', -125.00, '💡'),
  ];

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF152019) : Colors.white;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: primary.withValues(alpha: isDark ? 0.15 : 0.1)),
      ),
      child: Column(
        children: List.generate(_txns.length, (i) {
          final t = _txns[i];
          final isPositive = t.$4 >= 0;
          final isLast = i == _txns.length - 1;

          return Column(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(t.$5, style: const TextStyle(fontSize: 18)),
                  ),
                ),
                title: Text(t.$1,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text('${t.$3} · ${t.$2}',
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                trailing: Text(
                  '${isPositive ? '+' : ''}S/ ${t.$4.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: isPositive
                        ? const Color(0xFF00C896)
                        : const Color(0xFFFF6B6B),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 72,
                  color: primary.withValues(alpha: 0.08),
                ),
            ],
          );
        }),
      ),
    );
  }
}
