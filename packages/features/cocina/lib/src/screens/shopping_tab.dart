import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cocina_providers.dart';

class ShoppingTab extends ConsumerWidget {
  const ShoppingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recipesProvider);
    final items = state.shoppingList;
    final notifier = ref.read(recipesProvider.notifier);

    final pending = items.where((i) => !i.bought).toList();
    final bought = items.where((i) => i.bought).toList();

    return Stack(
      children: [
        items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_cart_outlined,
                        size: 64, color: Colors.white12),
                    const SizedBox(height: 12),
                    const Text('Lista de compras vacía',
                        style: TextStyle(color: Colors.white38, fontSize: 17)),
                    const SizedBox(height: 6),
                    const Text(
                      'Genera una lista desde tus recetas favoritas\nen la pestaña de Sugerencias.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white24, fontSize: 13),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 160),
                children: [
                  // Barra de acciones
                  if (items.isNotEmpty) ...[
                    _ActionBar(
                      onClearAll: () => _confirmClearAll(context, ref),
                      onClearBought: bought.isNotEmpty
                          ? () => _confirmClearBought(context, ref, bought)
                          : null,
                      itemCount: items.length,
                      pendingCount: pending.length,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (pending.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Por comprar',
                          style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                    ...pending.map(
                      (item) => _ShoppingTile(
                        key: ValueKey(item.id),
                        item: item,
                      ),
                    ),
                  ],
                  if (bought.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Ya comprado ✓',
                          style: TextStyle(
                              color: Colors.white24,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                    ...bought.map(
                      (item) => _ShoppingTile(
                        key: ValueKey(item.id),
                        item: item,
                      ),
                    ),
                  ],
                ],
              ),
        // Botones de acción
        Positioned(
          right: 16,
          bottom: 160,
          child: FloatingActionButton(
            heroTag: 'clear_shopping',
            backgroundColor: const Color(0xFFFF5252),
            mini: true,
            onPressed:
                items.isNotEmpty ? () => _confirmClearAll(context, ref) : null,
            child: const Icon(Icons.delete_sweep, color: Colors.white),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 96,
          child: FloatingActionButton.extended(
            heroTag: 'gen_shopping',
            backgroundColor: const Color(0xFF00C896),
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            label: const Text('Generar lista',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            onPressed: () => notifier.generateShoppingList(state.suggestions),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152019),
        title: const Text('🗑️ Limpiar lista completa',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de que quieres eliminar TODOS los items de la lista de compras?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5252)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar todo',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Clear all by toggling and deleting
      final state = ref.read(recipesProvider);
      for (final item in state.shoppingList) {
        await ref.read(recipesProvider.notifier).deleteShoppingItem(item.id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Lista limpiada completamente'),
            backgroundColor: Color(0xFF00C896),
          ),
        );
      }
    }
  }

  Future<void> _confirmClearBought(
      BuildContext context, WidgetRef ref, List<dynamic> bought) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152019),
        title: const Text('🧹 Limpiar comprados',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Eliminar ${bought.length} item(s) ya comprado(s)?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C896)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpiar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      for (final item in bought) {
        await ref.read(recipesProvider.notifier).deleteShoppingItem(item.id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Items comprados eliminados'),
            backgroundColor: Color(0xFF00C896),
          ),
        );
      }
    }
  }
}

// ── Action Bar ───────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final VoidCallback onClearAll;
  final VoidCallback? onClearBought;
  final int itemCount;
  final int pendingCount;

  const _ActionBar({
    required this.onClearAll,
    this.onClearBought,
    required this.itemCount,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF152019),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00C896).withAlpha(40)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$itemCount items en total',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                Text('$pendingCount por comprar',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.54),
                        fontSize: 12)),
              ],
            ),
          ),
          if (onClearBought != null)
            TextButton.icon(
              onPressed: onClearBought,
              icon: const Icon(Icons.cleaning_services,
                  size: 18, color: Color(0xFF00C896)),
              label: const Text('Limpiar comprados',
                  style: TextStyle(color: Color(0xFF00C896), fontSize: 12)),
            ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onClearAll,
            icon: const Icon(Icons.delete_forever, color: Color(0xFFFF5252)),
            tooltip: 'Eliminar toda la lista',
          ),
        ],
      ),
    );
  }
}

// ── Shopping Tile ────────────────────────────────────────────────────────────

class _ShoppingTile extends StatelessWidget {
  final dynamic item;
  const _ShoppingTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: item.bought ? const Color(0xFF1A2E22) : const Color(0xFF152019),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.bought
              ? const Color(0xFF66BB6A).withAlpha(60)
              : const Color(0xFF00C896).withAlpha(40),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Checkbox(
          value: item.bought,
          onChanged: (_) {},
          activeColor: const Color(0xFF00C896),
        ),
        title: Text(
          item.name,
          style: TextStyle(
            color: item.bought ? Colors.white38 : Colors.white,
            decoration: item.bought ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${item.quantity} ${item.unit}',
          style: TextStyle(
            color: item.bought ? Colors.white24 : Colors.white54,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () {},
              icon: Icon(
                item.bought ? Icons.undo : Icons.check,
                size: 20,
                color: item.bought
                    ? const Color(0xFFFFB74D)
                    : const Color(0xFF66BB6A),
              ),
              tooltip: item.bought
                  ? 'Marcar como pendiente'
                  : 'Marcar como comprado',
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: Color(0xFFFF5252)),
              tooltip: 'Eliminar item',
            ),
          ],
        ),
        onTap: () {},
      ),
    );
  }
}
