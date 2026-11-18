import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/cocina_providers.dart';

/// Asistente visual para desglosar "1 pollo entero" (en octavos) o "presas de pollo"
/// en cortes individuales dentro de la Despensa, prorrateando el costo unitario.
class PoultryBreakdownSheet extends ConsumerStatefulWidget {
  final PendingPoultryBreakdown? pendingBreakdown;
  final String? initialTitle;
  final double initialWholeChickens;
  final double? totalPrice;
  final String currency;

  const PoultryBreakdownSheet({
    this.pendingBreakdown,
    this.initialTitle,
    this.initialWholeChickens = 1,
    this.totalPrice,
    this.currency = 'PEN',
    super.key,
  });

  static Future<bool?> show(
    BuildContext context, {
    PendingPoultryBreakdown? pending,
    String? initialTitle,
    double initialWholeChickens = 1,
    double? totalPrice,
    String currency = 'PEN',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PoultryBreakdownSheet(
        pendingBreakdown: pending,
        initialTitle: initialTitle,
        initialWholeChickens: initialWholeChickens,
        totalPrice: totalPrice ?? pending?.totalPrice,
        currency: pending?.currency ?? currency,
      ),
    );
  }

  @override
  ConsumerState<PoultryBreakdownSheet> createState() =>
      _PoultryBreakdownSheetState();
}

class _PoultryBreakdownSheetState extends ConsumerState<PoultryBreakdownSheet> {
  late bool _wholeChickenMode;
  late int _wholeCount;
  bool _includeOffal = false;
  String _storageArea = 'Congelador';
  bool _saving = false;

  final Map<String, int> _customPieces = {
    'Pechuga de pollo': 2,
    'Pierna de pollo': 2,
    'Encuentro de pollo': 2,
    'Ala de pollo': 2,
    'Filete de pollo': 0,
    'Menudencia / Carcasa de pollo': 0,
  };

  @override
  void initState() {
    super.initState();
    final pending = widget.pendingBreakdown;
    _wholeChickenMode = pending?.isWholeChicken ?? true;
    final rawQty = pending?.quantity ?? widget.initialWholeChickens;
    final unitLower = (pending?.unit ?? '').toLowerCase();
    _wholeCount = (unitLower == 'unidades' && rawQty >= 1)
        ? rawQty.round().clamp(1, 10)
        : 1;
    _applyWholePreset();
  }

  void _applyWholePreset() {
    final preset = WalletPantryBridgeService.buildWholeChickenPieces(
      _wholeCount,
      includeOffal: _includeOffal,
    );
    _customPieces.updateAll((_, __) => 0);
    for (final p in preset) {
      _customPieces[p.name] = p.count;
    }
  }

  int get _totalPiecesCount =>
      _customPieces.values.fold<int>(0, (sum, q) => sum + q);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = widget.pendingBreakdown;
    final title =
        pending?.itemName ?? widget.initialTitle ?? 'Desglosar pollo';
    final totalPrice = widget.totalPrice ?? pending?.totalPrice;
    final totalPieces = _totalPiecesCount;
    final perPiecePrice = (totalPrice != null && totalPrice > 0 && totalPieces > 0)
        ? totalPrice / totalPieces
        : null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('🍗', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Desglosar "$title"',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      totalPrice != null && totalPrice > 0
                          ? 'Costo total: ${widget.currency} ${totalPrice.toStringAsFixed(2)}${perPiecePrice != null ? ' (≈ ${perPiecePrice.toStringAsFixed(2)} c/presa)' : ''}'
                          : 'Elige las presas para controlar tu stock exacto',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF00C896),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Modo Pollo entero (octavos) vs Presas sueltas
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Pollo entero (8 presas)'),
                  selected: _wholeChickenMode,
                  onSelected: (_) => setState(() {
                    _wholeChickenMode = true;
                    _applyWholePreset();
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Por presas sueltas'),
                  selected: !_wholeChickenMode,
                  onSelected: (_) => setState(() {
                    _wholeChickenMode = false;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_wholeChickenMode) ...[
            Row(
              children: [
                const Text('Cantidad de pollos:',
                    style: TextStyle(fontSize: 13)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _wholeCount > 1
                      ? () => setState(() {
                            _wholeCount--;
                            _applyWholePreset();
                          })
                      : null,
                ),
                Text('$_wholeCount',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _wholeCount < 10
                      ? () => setState(() {
                            _wholeCount++;
                            _applyWholePreset();
                          })
                      : null,
                ),
              ],
            ),
            SwitchListTile.adaptive(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Incluir menudencia / carcasa para caldo',
                  style: TextStyle(fontSize: 13)),
              value: _includeOffal,
              activeTrackColor: const Color(0xFF00C896),
              onChanged: (v) => setState(() {
                _includeOffal = v;
                _applyWholePreset();
              }),
            ),
          ],
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: _customPieces.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(entry.key,
                            style: const TextStyle(fontSize: 14)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        onPressed: entry.value > 0
                            ? () => setState(() {
                                  _customPieces[entry.key] = entry.value - 1;
                                })
                            : null,
                      ),
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${entry.value}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: entry.value > 0
                                ? const Color(0xFF00C896)
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        onPressed: () => setState(() {
                          _customPieces[entry.key] = entry.value + 1;
                        }),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Guardar en:', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('❄️ Congelador'),
                selected: _storageArea == 'Congelador',
                onSelected: (_) =>
                    setState(() => _storageArea = 'Congelador'),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('🧊 Refri'),
                selected: _storageArea == 'Refrigerador',
                onSelected: (_) =>
                    setState(() => _storageArea = 'Refrigerador'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving || totalPieces == 0 ? null : _savePieces,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, color: Colors.black),
              label: Text(
                'Guardar $totalPieces presa${totalPieces == 1 ? '' : 's'} en Despensa',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C896),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _savePieces() async {
    setState(() => _saving = true);
    try {
      final selectedEntries = _customPieces.entries
          .where((e) => e.value > 0)
          .map((e) => (
                name: e.key,
                quantity: e.value.toDouble(),
                unit: 'unidades',
              ))
          .toList();

      final expiryDays = _storageArea == 'Congelador' ? 90 : 3;
      final expiry = DateTime.now().add(Duration(days: expiryDays));

      await ref.read(inventoryProvider.notifier).upsertPoultryPieces(
            selectedEntries,
            storageArea: _storageArea,
            expirationDate: expiry,
          );

      final totalPrice = widget.totalPrice ?? widget.pendingBreakdown?.totalPrice;
      final totalPieces = _totalPiecesCount;
      if (totalPrice != null && totalPrice > 0 && totalPieces > 0) {
        final priceNotifier =
            ref.read(ingredientPriceCatalogProvider.notifier);
        for (final entry in selectedEntries) {
          final partShare = totalPrice * (entry.quantity / totalPieces);
          await priceNotifier.recordPurchase(
            name: entry.name,
            quantity: entry.quantity,
            unit: entry.unit,
            totalPrice: partShare,
            currency: widget.currency,
            source: 'walletai',
          );
        }
      }

      final pending = widget.pendingBreakdown;
      if (pending != null) {
        await ref.read(pendingPoultryBreakdownsProvider.notifier).resolve(pending.id);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
