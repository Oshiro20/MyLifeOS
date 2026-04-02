import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:url_launcher/url_launcher.dart';

/// Card que muestra el resumen ejecutivo de WalletAI en el módulo de Finanzas.
/// Si WalletAI no está instalado o no ha exportado datos, muestra un estado vacío.
class WalletAiSummaryCard extends StatefulWidget {
  const WalletAiSummaryCard({super.key});

  @override
  State<WalletAiSummaryCard> createState() => _WalletAiSummaryCardState();
}

class _WalletAiSummaryCardState extends State<WalletAiSummaryCard> {
  WalletSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final summary = await WalletSummaryReader.read();
    if (mounted) setState(() { _summary = summary; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_summary == null) return const _WalletNotConnectedCard();

    final s = _summary!;
    final isPositive = s.balance >= 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [const Color(0xFF152019), const Color(0xFF1A2E22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF00C896).withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C896).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined,
                    color: Color(0xFF00C896), size: 18),
              ),
              const SizedBox(width: 8),
              const Text('WalletAI',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('v${s.version}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${s.currency} ${s.balance.toStringAsFixed(2)}',
            style: TextStyle(
              color: isPositive ? const Color(0xFF00E5FF) : const Color(0xFFFF6B6B),
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text('Balance disponible · ${s.month}',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetricChip(
                label: 'Ingresos',
                value: '+${s.currency} ${s.income.toStringAsFixed(0)}',
                color: const Color(0xFF00E5FF),
              ),
              const SizedBox(width: 8),
              _MetricChip(
                label: 'Gastos',
                value: '-${s.currency} ${s.expenses.toStringAsFixed(0)}',
                color: const Color(0xFFFF6B6B),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _openWalletAI,
                icon: const Icon(Icons.open_in_new, size: 14, color: Color(0xFF00C896)),
                label: const Text('Abrir',
                    style: TextStyle(color: Color(0xFF00C896), fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openWalletAI() async {
    // Deep link a WalletAI — ajusta el scheme si tienes uno configurado
    final uri = Uri.parse('intent://wallet_ai#Intent;scheme=walletai;end');
    if (!await launchUrl(uri)) {
      // Fallback: abrir Play Store
      await launchUrl(Uri.parse('market://details?id=com.oshiro.wallet_ai'));
    }
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _WalletNotConnectedCard extends StatelessWidget {
  const _WalletNotConnectedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF152019),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.link_off, color: Colors.white38, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'WalletAI no conectado. Abre WalletAI para sincronizar tu balance.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
