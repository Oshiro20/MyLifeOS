import 'package:flutter/material.dart';
import 'package:core/core.dart';

/// Card que muestra el resumen ejecutivo de WalletAI en el módulo de Finanzas.
/// Si WalletAI no está instalado o no ha exportado datos, muestra un estado vacío.
class WalletAiSummaryCard extends StatefulWidget {
  const WalletAiSummaryCard({super.key});

  @override
  State<WalletAiSummaryCard> createState() => _WalletAiSummaryCardState();
}

class _WalletAiSummaryCardState extends State<WalletAiSummaryCard> {
  WalletSummary? _summary;
  WalletConnectionStatus? _connectionStatus;
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final summary = await WalletSummaryReader.read();
    final status = await WalletAICommunicationService.checkConnectionStatus();
    if (mounted) {
      setState(() {
        _summary = summary;
        _connectionStatus = status;
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await _load();
    setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(strokeWidth: 2),
              const SizedBox(height: 8),
              Text(
                'Conectando con WalletAI...',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // Mostrar estado de conexión
    if (_connectionStatus != null && !_connectionStatus!.isConnected) {
      return _WalletNotConnectedCard(
        status: _connectionStatus!,
        onRetry: _refresh,
        onOpenWalletAI: _openWalletAI,
      );
    }

    // Advertencia si los Project IDs no coinciden
    if (_connectionStatus?.isConnected == true &&
        _connectionStatus?.isProjectIdMatched == false) {
      return _WalletIdMismatchCard(
        summary: _summary,
        status: _connectionStatus!,
        onRefresh: _refresh,
        onOpenWalletAI: _openWalletAI,
      );
    }

    if (_summary == null) {
      return _WalletNotConnectedCard(
        status: _connectionStatus ??
            const WalletConnectionStatus(
              isConnected: false,
              isWalletAIAvailable: false,
              isProjectIdMatched: false,
            ),
        onRetry: _refresh,
        onOpenWalletAI: _openWalletAI,
      );
    }

    final s = _summary!;
    final isPositive = s.balance >= 0;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [const Color(0xFF152019), const Color(0xFF1A2E22)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFF00C896).withValues(alpha: 0.2),
            ),
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
                      color: const Color(0xFF00C896).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined,
                            color: Color(0xFF00C896), size: 18),
                        if (_refreshing)
                          Positioned.fill(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                const Color(0xFF00C896),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('WalletAI',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('v${s.version}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                      Text(
                        _getStatusText(),
                        style:
                            const TextStyle(color: Colors.white24, fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${s.currency} ${s.balance.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isPositive
                      ? const Color(0xFF00E5FF)
                      : const Color(0xFFFF6B6B),
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
                    icon: const Icon(Icons.open_in_new,
                        size: 14, color: Color(0xFF00C896)),
                    label: const Text('Abrir',
                        style:
                            TextStyle(color: Color(0xFF00C896), fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText() {
    if (_connectionStatus?.lastSync == null) {
      return 'Sin sincronizar';
    }

    final lastSync = _connectionStatus!.lastSync!;
    final now = DateTime.now();
    final diff = now.difference(lastSync);

    if (diff.inMinutes < 1) {
      return 'Sincronizado ahora';
    } else if (diff.inMinutes < 60) {
      return 'Sinc. hace ${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return 'Sinc. hace ${diff.inHours}h';
    } else {
      return 'Sinc. ${lastSync.day}/${lastSync.month} ${lastSync.hour}:${lastSync.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _openWalletAI() async {
    await WalletAICommunicationService.openWalletAI();
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10)),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Card de estado no conectado con opciones de acción
class _WalletNotConnectedCard extends StatelessWidget {
  final WalletConnectionStatus status;
  final VoidCallback onRetry;
  final VoidCallback onOpenWalletAI;

  const _WalletNotConnectedCard({
    required this.status,
    required this.onRetry,
    required this.onOpenWalletAI,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [const Color(0xFF152019), const Color(0xFF1A2E22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.2),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.link_off,
                    color: Color(0xFFFF6B6B), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WalletAI no conectado',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Abre WalletAI para sincronizar tus datos financieros',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenWalletAI,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Abrir WalletAI'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00C896),
                    side: const BorderSide(
                      color: Color(0xFF00C896),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C896),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card de advertencia cuando los Project IDs no coinciden
class _WalletIdMismatchCard extends StatelessWidget {
  final WalletSummary? summary;
  final WalletConnectionStatus status;
  final VoidCallback onRefresh;
  final VoidCallback onOpenWalletAI;

  const _WalletIdMismatchCard({
    required this.summary,
    required this.status,
    required this.onRefresh,
    required this.onOpenWalletAI,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [const Color(0xFF152019), const Color(0xFF1A2E22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber,
                    color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Project IDs no coinciden',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Verifica la configuración en ambas apps',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (summary != null) ...[
            const SizedBox(height: 12),
            Text(
              '${summary!.currency} ${summary!.balance.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenWalletAI,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Abrir WalletAI'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00C896),
                    side: const BorderSide(
                      color: Color(0xFF00C896),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reescanear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C896),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
